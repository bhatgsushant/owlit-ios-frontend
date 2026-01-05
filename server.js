

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const sharp = require('sharp');
const { OpenAI } = require('openai');
const { DocumentProcessorServiceClient } = require('@google-cloud/documentai').v1;
const { createWorker } = require('tesseract.js');
const fs = require('fs').promises;
const path = require('path');
const { SUB_CATEGORIES } = require('./categorize.js');
const session = require('express-session');
const cookieParser = require('cookie-parser');
const passport = require('./auth.js');
const supabase = require('./supabaseClient.js');
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

// Diagnostics
const maskUrl = (url) => url ? url.replace(/:\/\/([^:]+):([^@]+)@/, '://$1:****@') : 'NOT_SET';
console.log('🔌 Database Config:', maskUrl(process.env.DATABASE_URL));
pool.on('error', (err) => console.error('❌ DB Pool Error:', err));
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const ITEM_SYNONYMS = {
  coffee: ["coffee", "latte", "flat white", "espresso", "americano", "mocha", "cappuccino", "macchiato"],
  tea: ["tea", "chai", "green tea", "matcha"],
  chocolate: ["chocolate", "choc", "cadbury", "kitkat"],
};
const {
  normalizeMerchantName,
  buildReceiptHash,
  buildLooseReceiptHash,
} = require('./utils/receiptHash.js');
const { resolveAiDateRange, analyzeSpendingResults } = require('./utils/askAiHelpers.js');
const AskController = require('./controllers/ask_controller');
const ASK_AI_SUPPORTED_OPERATIONS = new Set(['total_spend', 'item_spend', 'top_merchants', 'list_receipts']);

// --- PROMPTS ---
const ROUTER_SYSTEM_PROMPT = `
You are the Router. Classify user questions into: [SQL_AGENT] or [VECTOR_STORE].
DATA: Table 'v_receipt_line_items_enriched' has columns: transaction_date, merchant_name, item, total_price, main_category, sub_category.
LOGIC:
- SQL_AGENT: DEFAULT CHOICE. Use this for ANY question about items, spending, prices, dates, categories, "favorite", "most bought", "how much", or analysis.
- VECTOR_STORE: ONLY for questions like "Show me receipts", "What did I buy", or specific text search (e.g. "Find receipts with text X").
- If unsure, use SQL_AGENT.
OUTPUT JSON: { "tool": "SQL_AGENT" | "VECTOR_STORE" }
`;

const { SQL_AGENT_SYSTEM_PROMPT } = require('./agents/sql_agent_prompts');

class ValidationError extends Error {
  constructor(message, statusCode = 400) {
    super(message);
    this.name = 'ValidationError';
    this.statusCode = statusCode;
  }
}

const ALLOWED_UPLOAD_MIME_TYPES = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/heic',
  'application/pdf'
]);

const MAX_MARKDOWN_LENGTH = 20000;

const normalizeMerchantKey = (name = '') => {
  if (!name || typeof name !== 'string') return '';
  return name.toLowerCase().replace(/\s+/g, ' ').trim();
};

const ensureEnvVar = (key) => {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
};

const handleApiError = (res, error, fallbackMessage = 'An unexpected error occurred.') => {
  if (error instanceof ValidationError) {
    return res.status(error.statusCode).json({ error: error.message });
  }
  console.error(fallbackMessage, error);
  return res.status(500).json({ error: fallbackMessage });
};

const generateJoinCode = (length = 8) => {
  const base = crypto.randomBytes(12).toString('base64url').replace(/[^a-zA-Z0-9]/g, '');
  return base.slice(0, length).toUpperCase();
};

const assignUserReceiptsToFamily = async (userId, familyId) => {
  if (!userId || !familyId) return;
  try {
    const { error } = await supabase
      .from('receipts')
      .update({ family_id: familyId })
      .eq('user_id', userId);
    if (error) {
      console.error('Failed to assign receipts to family', { userId, familyId, error });
    }
  } catch (err) {
    console.error('Unexpected error assigning receipts to family', err);
  }
};

const getUserFamilyMembership = async (userId) => {
  if (!userId) return null;
  const { data, error } = await supabase
    .from('family_members')
    .select('family_id, role')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) {
    throw error;
  }

  return data || null;
};

const selectActiveInvite = (invites = []) => {
  const now = Date.now();
  return invites.find((invite) => {
    const notExpired = !invite.expires_at || new Date(invite.expires_at).getTime() > now;
    const hasUses = invite.max_uses == null || invite.used_count < invite.max_uses;
    return invite.status === 'active' && notExpired && hasUses;
  }) || null;
};

const getUserFamilyId = async (userId) => {
  const membership = await getUserFamilyMembership(userId);
  return membership?.family_id || null;
};

const validateFields = (payload, schema) => {
  Object.entries(schema).forEach(([field, rules]) => {
    const value = payload[field];
    if (rules.required && (value === undefined || value === null || value === '')) {
      throw new ValidationError(rules.message || `${field} is required.`);
    }
    if (value === undefined || value === null) {
      return;
    }

    if (rules.type === 'string') {
      if (typeof value !== 'string') {
        throw new ValidationError(rules.message || `${field} must be a string.`);
      }
      if (rules.trim && value.trim().length === 0) {
        throw new ValidationError(rules.message || `${field} cannot be empty.`);
      }
      if (rules.maxLength && value.length > rules.maxLength) {
        throw new ValidationError(rules.message || `${field} must be ${rules.maxLength} characters or fewer.`);
      }
      if (rules.allowed && !rules.allowed.includes(value)) {
        throw new ValidationError(rules.message || `${field} contains an invalid value.`);
      }
      if (rules.pattern && !rules.pattern.test(value)) {
        throw new ValidationError(rules.message || `${field} is invalid.`);
      }
    } else if (rules.type === 'number') {
      if (typeof value !== 'number' || Number.isNaN(value)) {
        throw new ValidationError(rules.message || `${field} must be a valid number.`);
      }
      if (rules.min !== undefined && value < rules.min) {
        throw new ValidationError(rules.message || `${field} must be at least ${rules.min}.`);
      }
    } else if (rules.type === 'array') {
      if (!Array.isArray(value)) {
        throw new ValidationError(rules.message || `${field} must be an array.`);
      }
    }

    if (typeof rules.validate === 'function') {
      const validationResult = rules.validate(value);
      if (validationResult !== true) {
        throw new ValidationError(
          typeof validationResult === 'string' ? validationResult : (rules.message || `${field} is invalid.`)
        );
      }
    }
  });
};

const safeJsonParse = (value, errorMessage) => {
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new ValidationError(errorMessage);
  }
};

const safeJsonParseWithMarkdown = (text) => {
  if (!text) return null;
  // Remove markdown code blocks if present
  const cleanText = text.replace(/```json\n?|\n?```/g, '').trim();
  try {
    return JSON.parse(cleanText);
  } catch (e) {
    console.error('Failed to parse JSON:', text);
    throw new Error('Invalid JSON format from AI');
  }
};

const validateLineItems = (lineItems = []) => {
  if (!Array.isArray(lineItems)) {
    throw new ValidationError('line_items must be an array.');
  }
  if (lineItems.length === 0) {
    throw new ValidationError('line_items must include at least one item.');
  }

  lineItems.forEach((item, index) => {
    if (!item || typeof item !== 'object') {
      throw new ValidationError(`line_items[${index}] must be an object.`);
    }
    const name = item.item || item.name || item.Item_Name;
    if (!name || typeof name !== 'string' || !name.trim()) {
      throw new ValidationError(`line_items[${index}] must include a valid item name.`);
    }
    const price = Number(item.price ?? item.Price ?? 0);
    if (Number.isNaN(price) || price < 0) {
      throw new ValidationError(`line_items[${index}] must include a valid non-negative price.`);
    }
    const quantity = Number(item.quantity ?? item.Quantity ?? 1);
    if (!Number.isFinite(quantity) || quantity <= 0) {
      throw new ValidationError(`line_items[${index}] must include a valid quantity.`);
    }
  });
};

const isSupportedUpload = (mimeType = '') => {
  if (!mimeType) return false;
  return ALLOWED_UPLOAD_MIME_TYPES.has(mimeType.toLowerCase());
};

const startOfCurrentMonth = () => {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), 1);
};

const startOfLastMonth = () => {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth() - 1, 1);
};

const startOfCurrentWeek = () => {
  const now = new Date();
  const day = now.getDay(); // 0 (Sun) - 6 (Sat)
  const diff = (day + 6) % 7; // convert to Monday = 0
  const start = new Date(now);
  start.setDate(now.getDate() - diff);
  start.setHours(0, 0, 0, 0);
  return start;
};

const toISODate = (date) => date.toISOString().split('T')[0];

const getDateRangeForIntent = (timeRange) => {
  const now = new Date();
  let from = null;
  let to = null;

  switch (timeRange) {
    case 'this_month':
      from = startOfCurrentMonth();
      to = now;
      break;
    case 'last_month':
      from = startOfLastMonth();
      to = startOfCurrentMonth();
      break;
    case 'this_week':
      from = startOfCurrentWeek();
      to = now;
      break;
    case 'last_7_days':
      from = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      to = now;
      break;
    case 'all_time':
    default:
      break;
  }

  return {
    from: from ? toISODate(from) : null,
    to: to ? toISODate(to) : null,
  };
};

async function resolveMerchant(rawMerchantName, supabaseClient) {
  const alias = normalizeMerchantName(rawMerchantName);

  const { data: aliasMatch } = await supabaseClient
    .from("merchant_aliases")
    .select("merchant_id")
    .eq("alias", alias)
    .maybeSingle();

  if (aliasMatch) {
    return { merchant_id: aliasMatch.merchant_id, alias };
  }

  return { merchant_id: null, alias };
}

// --- Auth Helpers & Middleware ---
const buildUserPayload = (user = {}) => ({
  id: user.id,
  email: user.email,
  displayName: user.displayName,
  firstName: user.firstName,
  lastName: user.lastName,
  avatar: user.avatar_url || user.avatar,
  provider: user.provider,
});

const issueJwtForUser = (user) => {
  if (!user?.id) {
    throw new ValidationError('Unable to issue token for missing user profile.');
  }
  return jwt.sign(buildUserPayload(user), JWT_SECRET, { expiresIn: JWT_EXPIRY });
};

const extractTokenFromHeader = (req) => {
  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) {
    return null;
  }
  return authHeader.slice(7);
};

const authenticateRequest = (req, res, next) => {
  const token = extractTokenFromHeader(req);

  if (!token) {
    console.warn('🔒 authenticateRequest: Missing Authorization header');
    return res.status(401).json({ error: 'Missing authentication token' });
  }

  try {
    // Just for debugging, print first/last chars so we know what arrived
    console.log(
      '🔑 Incoming JWT (truncated):',
      token.slice(0, 20) + '...' + token.slice(-20)
    );
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    console.log('✅ JWT verified for user:', decoded.email || decoded.id);
    return next();
  } catch (err) {
    console.error('❌ JWT verification failed:', {
      message: err.message,
      name: err.name,
    });
    // (Optional) log decoded payload without verifying signature, to inspect exp etc.
    try {
      const decodedLoose = jwt.decode(token, { complete: true });
      console.log('🧩 Decoded (UNVERIFIED) token payload:', decodedLoose);
    } catch (decodeErr) {
      console.error('⚠️ Failed to decode token even without verify:', decodeErr);
    }

    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};


const optionalAuthenticate = (req, res, next) => {
  const token = extractTokenFromHeader(req);
  if (!token) {
    return next();
  }
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    return next();
  } catch (err) {
    console.error('JWT verification failed (optional):', err);
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};


// --- Catch uncaught errors for debugging ---
process.on('uncaughtException', (err) => console.error('Uncaught Exception:', err));
process.on('unhandledRejection', (err) => console.error('Unhandled Rejection:', err));

console.log("🟢 Starting server...");

// --- Express App ---
const app = express();
const port = process.env.PORT || 3001;
const SESSION_SECRET = ensureEnvVar('SESSION_SECRET');
const JWT_SECRET = ensureEnvVar('JWT_SECRET');
const JWT_EXPIRY = process.env.JWT_EXPIRY || '24h';
const isProduction = process.env.NODE_ENV === 'production';

if (isProduction) {
  app.set('trust proxy', 1);
}

// --- OpenAI Setup ---
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
if (!OPENAI_API_KEY) {
  console.error('❌ Missing OPENAI_API_KEY in your .env file!');
} else {
  console.log('✅ Loaded OpenAI API Key');
}
const openai = new OpenAI({ apiKey: OPENAI_API_KEY });
const ASK_AI_INTERPRETER_MODEL = process.env.ASK_AI_MODEL || 'gpt-4o-mini';
const ASK_AI_SYSTEM_PROMPT = `
You are an intent parser for a personal finance assistant.
Convert the user's spending question into structured JSON with this schema:
{
  "operation": "total_spend|item_spend|top_merchants|list_receipts|clarify",
  "date_range": { "preset": "this_month|last_month|this_week|last_week|last_7_days|last_30_days|this_year|custom|all_time", "start": "YYYY-MM-DD", "end": "YYYY-MM-DD" },
  "merchant_terms": ["optional", "merchant", "keywords"],
  "item_terms": ["optional", "item keywords"],
  "category_terms": ["optional", "category names"],
  "amount_filter": { "operator": ">|>=|<|<=|=", "value": 0 },
  "needs_clarification": false,
  "clarification_prompt": ""
}

Rules:
- Always fill arrays (empty if no filters).
- Use "clarify" operation and set needs_clarification=true when the request is ambiguous.
- Prefer presets such as "this_month", but if the user gives explicit dates, set preset to "custom" and include start/end.
- For questions about individual items (e.g., eggs, coffee), include them in item_terms and set operation to "item_spend".
- Use the "top_merchants" operation when the user asks for merchants with the highest spend.
- Use the "list_receipts" operation when the user wants to see actual receipts.
- Leave amount_filter empty unless the user makes a clear comparison like "over 100".
- Respond with JSON only.
`;

// --- Google Document AI Setup ---
const DOCAI_PROJECT_ID = ensureEnvVar('DOCAI_PROJECT_ID');
const DOCAI_LOCATION = ensureEnvVar('DOCAI_LOCATION');
const DOCAI_PROCESSOR_ID = ensureEnvVar('DOCAI_PROCESSOR_ID');

async function interpretSpendingQuestion(question) {
  try {
    const response = await openai.chat.completions.create({
      model: ASK_AI_INTERPRETER_MODEL,
      temperature: 0,
      messages: [
        { role: 'system', content: ASK_AI_SYSTEM_PROMPT },
        { role: 'user', content: question },
      ],
      response_format: { type: 'json_object' },
    });
    const content = response.choices[0]?.message?.content;
    if (!content) {
      throw new Error('Empty interpretation response');
    }
    return safeJsonParse(content, {});
  } catch (error) {
    console.error('interpretSpendingQuestion error:', error);
    throw new Error('I had trouble understanding that question. Please try rephrasing it.');
  }
}
//const docAIClient = new DocumentProcessorServiceClient();
const { GoogleAuth } = require('google-auth-library');

const createGoogleAuth = () => {
  const scopes = ['https://www.googleapis.com/auth/cloud-platform'];
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (keyPath && keyPath !== 'none') {
    console.log('🔐 Using Google credentials from file path defined in GOOGLE_APPLICATION_CREDENTIALS');
    return new GoogleAuth({ keyFilename: keyPath, scopes });
  }

  const inlineJson = process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON;
  if (inlineJson) {
    try {
      const credentials = JSON.parse(inlineJson);
      console.log('🔐 Using inline Google credentials from GOOGLE_APPLICATION_CREDENTIALS_JSON');
      return new GoogleAuth({ credentials, scopes });
    } catch (error) {
      console.warn('⚠️  Failed to parse GOOGLE_APPLICATION_CREDENTIALS_JSON. Falling back to other auth methods.');
    }
  }

  const base64Creds = process.env.GOOGLE_APPLICATION_CREDENTIALS_BASE64;
  if (base64Creds) {
    try {
      const decoded = Buffer.from(base64Creds, 'base64').toString('utf8');
      const credentials = JSON.parse(decoded);
      console.log('🔐 Using inline Google credentials from GOOGLE_APPLICATION_CREDENTIALS_BASE64');
      return new GoogleAuth({ credentials, scopes });
    } catch (error) {
      console.warn('⚠️  Failed to decode GOOGLE_APPLICATION_CREDENTIALS_BASE64. Falling back to other auth methods.');
    }
  }

  console.log('🆔 Using Application Default Credentials for Google Auth');
  return new GoogleAuth({
    clientId: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    scopes,
  });
};

const docAIClient = new DocumentProcessorServiceClient({ auth: createGoogleAuth() });

console.log('🧠 Initialized Google Document AI Client');

// --- Master Items ---
let masterItems = {}; // In-memory cache now fed from Supabase only


async function loadMasterItems() {
  console.log("🔄 Loading master items from Supabase...");
  const { data, error } = await supabase
    .from('master_items')
    .select('item_name, main_category, sub_category');

  if (error) {
    console.error('❌ Error loading master items from Supabase:', error);
    masterItems = {};
    return;
  }

  masterItems = {};

  for (const row of data) {
    masterItems[row.item_name.toLowerCase().trim()] = {
      main_category: row.main_category,
      sub_category: row.sub_category,
      Item_Name: row.item_name,
      receipt_ItemNames: [row.item_name]
    };
  }

  console.log(`✅ Loaded ${Object.keys(masterItems).length} items from Supabase.`);
}


async function saveMasterItem(itemName, main_category, sub_category) {
  await supabase
    .from('master_items')
    .upsert(
      { item_name: itemName, main_category, sub_category },
      { onConflict: 'item_name' }
    );

  masterItems[itemName.toLowerCase().trim()] = {
    main_category,
    sub_category,
    Item_Name: itemName,
    receipt_ItemNames: [itemName]
  };

  console.log(`💾 Saved to Supabase master_items: ${itemName}`);
}


// --- Middleware ---
app.set("trust proxy", 1);
const CLIENT_URL = process.env.CLIENT_URL || "https://owlit.vercel.app";

const allowedOrigins = [
  process.env.CLIENT_URL,           // Vercel frontend
  'http://localhost:5173',          // local dev
];
const vercelPreview = /^https:\/\/owlit(-git-[a-z0-9-]+)?-bhatgsushants-projects\.vercel\.app$/i;

app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin) || vercelPreview.test(origin)) { return callback(null, true); }

    if (/\.vercel\.app$/.test(origin)) return callback(null, true); // ✅ Allow all Vercel previews

    console.log("❌ Blocked by CORS:", origin);
    return callback(new Error(`Not allowed by CORS: ${origin}`));

  },
  credentials: true
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());
// Required for proper secure cookies on Render
//app.set("trust proxy", 1);
app.use(session({
  secret: SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: true,           // Always true in production HTTPS
    sameSite: "none",       // MUST be none for cross-domain cookies
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  }
}));
app.use(passport.initialize());

// --- Debug route to check cookies + session ---
app.get('/api/debug-session', (req, res) => {
  res.cookie('rw_test', '1', {
    httpOnly: true,
    secure: true,
    sameSite: 'none'
  });

  res.json({
    origin: req.get('origin'),
    cookieSeenByServer: Boolean(req.headers.cookie),
    hasSessionObject: Boolean(req.session),
    sessionID: req.sessionID,
    isAuthenticated: Boolean(req.user),
    user: req.user || null,
  });
});


const MAX_UPLOAD_SIZE_BYTES = Number(process.env.MAX_UPLOAD_SIZE_BYTES || 10 * 1024 * 1024);
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_UPLOAD_SIZE_BYTES },
  fileFilter: (req, file, cb) => {
    if (isSupportedUpload(file.mimetype)) {
      return cb(null, true);
    }
    cb(new ValidationError('Unsupported file type. Please upload a PDF or image.'));
  },
});

// --- Helper Functions ---
async function preprocessImage(imageBuffer) {
  console.log('🔧 Preprocessing image...');
  return await sharp(imageBuffer).grayscale().linear(1.5, -128).sharpen().toBuffer();
}

async function runTesseract(imageBuffer) {
  console.log('🏃 Running Tesseract.js OCR prepass...');
  const worker = await createWorker('eng');
  const { data: { text } } = await worker.recognize(imageBuffer);
  await worker.terminate();
  console.log('✅ Tesseract prepass complete.');
  return text;
}

function formatDate(dateString) {
  if (!dateString) return '';
  try {
    // Attempt to parse DD/MM/YYYY
    const parts = dateString.match(/^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$/);
    if (parts) {
      // parts[1] = DD, parts[2] = MM, parts[3] = YYYY
      const date = new Date(`${parts[3]}-${parts[2]}-${parts[1]}`);
      if (!isNaN(date)) {
        return date.toISOString().split('T')[0];
      }
    }

    // Fallback for other formats like YYYY-MM-DD or ISO strings
    const date = new Date(dateString);
    if (isNaN(date)) throw new Error('Invalid date');
    return date.toISOString().split('T')[0];
  } catch (e) {
    return dateString;
  }
}

// Icon key helpers
const CATEGORY_ICON_KEYS = new Set([
  'fruit', 'vegetable', 'meat', 'poultry', 'seafood', 'dairy', 'bakery', 'beverages', 'snacks', 'frozen', 'canned_goods',
  'personal_care', 'health', 'fitness', 'household', 'electronics', 'utilities', 'clothing', 'jewelry', 'transport',
  'travel', 'stationery', 'education', 'finance', 'entertainment', 'pets', 'gifts', 'dining', 'other'
]);

const SUBCATEGORY_ICON_MATCHERS = [
  { key: 'coffee', test: /(coffee|tea|drink)/ },
  { key: 'beer_wine', test: /(beer|wine|spirits)/ },
  { key: 'fuel', test: /(fuel|gas|diesel)/ },
  { key: 'bread', test: /(bread|pastr|cake|cookie|muffin)/ },
  { key: 'dairy', test: /(milk|cheese|yogurt|butter|cream|egg)/ },
  { key: 'fish', test: /(fish|seafood|prawn|shrimp)/ },
  { key: 'fruit', test: /(fruit|apple|banana|grape|melon)/ },
  { key: 'vegetable', test: /(vegetable|greens|onion|tomato|pepper)/ },
  { key: 'meat', test: /(meat|beef|pork|lamb)/ },
  { key: 'chicken', test: /(chicken|turkey|duck)/ },
  { key: 'cleaning', test: /(laundry|cleaning|detergent)/ },
  { key: 'medicine', test: /(medicine|vitamin|pain|supplement)/ },
  { key: 'fitness', test: /(gym|fitness|protein)/ },
  { key: 'electronics', test: /(electronics|charger|laptop|mobile|battery)/ },
  { key: 'utilities', test: /(electricity|internet|water|bill)/ },
  { key: 'clothing', test: /(shoe|shirt|jean|dress|clothing|sock)/ },
  { key: 'jewelry', test: /(jewel|ring|necklace|bracelet)/ },
  { key: 'transport', test: /(bus|train|taxi|uber|parking)/ },
  { key: 'travel', test: /(flight|hotel|visa|tour|luggage)/ },
  { key: 'stationery', test: /(pen|notebook|paper|folder)/ },
  { key: 'education', test: /(book|course|tuition|school)/ },
  { key: 'finance', test: /(bank|fee|insurance|loan|interest)/ },
  { key: 'entertainment', test: /(movie|music|game|event|stream)/ },
  { key: 'pets', test: /(pet|vet|groom)/ },
  { key: 'gifts', test: /(gift|donation|charity)/ },
  { key: 'dining', test: /(restaurant|takeaway|fast_food|pub|bar)/ },
];

const SUBCATEGORY_ICON_KEYS = new Set(SUBCATEGORY_ICON_MATCHERS.map((m) => m.key));

const normalizeCategoryIconKey = (key) => {
  if (!key) return null;
  const normalized = String(key).toLowerCase();
  return CATEGORY_ICON_KEYS.has(normalized) ? normalized : null;
};

const normalizeSubcategoryIconKey = (key) => {
  if (!key) return null;
  const normalized = String(key).toLowerCase();
  return SUBCATEGORY_ICON_KEYS.has(normalized) ? normalized : null;
};

const inferSubcategoryIconKey = (subCategory) => {
  if (!subCategory) return null;
  const value = String(subCategory).toLowerCase();
  for (const matcher of SUBCATEGORY_ICON_MATCHERS) {
    if (matcher.test.test(value)) return matcher.key;
  }
  return null;
};

const CATEGORY_PROMPT_TEXT = `
**Taxonomy for Categorization:**
- fruit: ["apples", "bananas", "berries", "citrus", "tropical", "grapes", "melons", "stone_fruit"]
- vegetable: ["leafy_greens", "root_vegetables", "cruciferous", "peppers", "tomatoes", "onions", "mushrooms", "squash"]
- meat: ["beef", "pork", "lamb", "veal", "processed_meats"]
- poultry: ["chicken", "turkey", "duck"]
- seafood: ["fish", "shellfish", "frozen_seafood", "canned_seafood"]
- dairy: ["milk", "cheese", "yogurt", "butter", "cream", "eggs"]
- bakery: ["bread", "pastries", "cakes", "cookies", "bagels", "muffins"]
- beverages: ["water", "soft_drinks", "coca cola", "juice", "coffee", "tea", "beer", "wine", "spirits", "energy_drinks"]
- snacks: ["chips", "crackers", "nuts", "candy", "chocolate", "popcorn", "protein_bars"]
- frozen: ["ice_cream", "frozen_meals", "frozen_vegetables", "frozen_pizza", "frozen_desserts"]
- canned_goods: ["canned_vegetables", "canned_fruits", "canned_soups", "canned_beans", "canned_fish", "sauces"]
- personal_care: ["soap", "shampoo", "toothpaste", "deodorant", "skincare", "cosmetics", "razor"]
- health: ["medicines", "vitamins", "first_aid", "sanitizer", "pain_relief", "supplements"]
- fitness: ["gym_membership", "yoga", "protein_powder", "fitness_equipment"]
- household: ["cleaning_supplies", "paper_products", "laundry", "kitchen_supplies", "furniture", "decor","bin_bags","light_bulbs"]
- electronics: ["mobile", "laptop", "tv", "earphones", "chargers", "home_appliances", "batteries"]
- utilities: ["electricity", "gas", "water", "internet", "mobile_bill"]
- clothing: ["t_shirts", "jeans", "jackets", "dresses", "shoes", "accessories", "socks", "belts", "hats"]
- jewelry: ["necklace", "rings", "bracelet", "earrings", "watches"]
- transport: ["fuel", "parking", "bus", "train", "taxi", "uber", "bike_service"]
- travel: ["flight", "hotel", "restaurant", "tour", "car_rental", "visa_fee", "luggage"]
- stationery: ["pens", "notebooks", "printer_paper", "markers", "folders", "office_supplies"]
- education: ["books", "courses", "tuition", "software", "subscriptions", "school_fees"]
- finance: ["bank_fees", "interest", "investment", "insurance", "tax", "loan_repayment"]
- entertainment: ["movies", "music", "games", "subscriptions", "events", "streaming", "concerts"]
- pets: ["pet_food", "veterinary", "toys", "grooming"]
- gifts: ["birthday", "festival", "anniversary", "donation", "charity"]
- dining: ["restaurant", "takeaway", "coffee_shop", "fast_food", "pub", "bar"]
- other: ["miscellaneous"]

**Allowed Category Icon Keys:** fruit, vegetable, meat, poultry, seafood, dairy, bakery, beverages, snacks, frozen, canned_goods, personal_care, health, fitness, household, electronics, utilities, clothing, jewelry, transport, travel, stationery, education, finance, entertainment, pets, gifts, dining, other

**Allowed Subcategory Icon Keys (choose the closest):** coffee, beer_wine, fuel, bread, dairy, fish, fruit, vegetable, meat, chicken, cleaning, medicine, fitness, electronics, utilities, clothing, jewelry, transport, travel, stationery, education, finance, entertainment, pets, gifts, dining
`;

async function processWithOpenAI(imageBase64, tesseractText = '') {
  const MAX_RETRIES = 2;
  for (let i = 0; i <= MAX_RETRIES; i++) {
    try {
      console.log(`🤖 Calling OpenAI API (Attempt ${i + 1}/${MAX_RETRIES + 1})...`);
      const prompt = `


You are an OCR correction and structuring expert. 
Read every line of text from the provided receipt image carefully and logically correct OCR mistakes. 
Maintain numeric accuracy for prices and totals. 
${tesseractText ? `Tesseract.js pre-scanned the following text, which may contain errors. Use it as a hint, but trust the image more: 

${tesseractText}

` : ''}

CRITICAL INSTRUCTION FOR DISCOUNTS (BLOCK LOGIC):
Treat the text as a sequence of "Item Blocks".
A block starts with an Item Name & Price and ends *only* when the NEXT Item Name & Price appears.
Scan the ENTIRE block between two items for discount lines.
- IGNORE garbage text (like "viqqs...").
- If you find "Cc Price", "Savings", "Offer" *anywhere* in that block, apply it to the item at the start of the block.

Example Block:
"Almonds £5.25"  <-- Item Start
"viqqs noise"    <-- Ignore
"Cc £4.50"       <-- Valid Discount in block -> Apply! 4.50 is the price.
"Bananas..."     <-- Next Block Starts

Do not let noise break the link between Item and Discount.

${CATEGORY_PROMPT_TEXT}
Output clean structured JSON in this format. The date should be in DD/MM/YYYY format. if you cannot find a date, use today's date as a sensible defaults:
{
  "MerchantName": "",
  "Date": "DD/MM/YYYY",
  "Items": [
     {
       "Name": "",
       "Quantity": 1,
       "Price": 0.0,
       "Category": "",
       "SubCategory": "",
       "CategoryIconKey": "",
       "SubCategoryIconKey": ""
     }
  ],
  "Subtotal": "",
  "Tax": "",
  "TotalAmount": ""
}
For CategoryIconKey pick from the allowed category icon keys. For SubCategoryIconKey pick from the allowed subcategory icon keys. If unsure, choose the closest match.
Return **only JSON**, no explanations.
`;
      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: prompt },
              {
                type: 'image_url',
                image_url: {
                  url:
                    `data:image/jpeg;base64,${imageBase64}`
                },
              },
            ],
          },
        ],
        temperature: 0,
        max_tokens: 4000,
        response_format: { type: "json_object" },
      });
      const content = response.choices[0]?.message?.content;
      if (!content) throw new Error('No content returned from OpenAI');
      const jsonData = JSON.parse(content);
      console.log('✅ Successfully parsed JSON from OpenAI response');
      return jsonData;
    } catch (error) {
      console.error(`❌ OpenAI API error on attempt ${i + 1}:`, error.message);
      if (i === MAX_RETRIES) {
        throw new Error('Failed to get a valid response from OpenAI after multiple retries.');
      }
      console.log('Retrying...');
    }
  }
}

async function generateUserInsightFromSupabase(userId) {
  if (!userId) return null;
  try {
    const { data: receipts, error } = await supabase
      .from('receipts')
      .select('merchant_name, transaction_date, total_amount, line_items')
      .eq('user_id', userId)
      .order('transaction_date', { ascending: false })
      .limit(500);

    if (error || !receipts || receipts.length === 0) return null;

    // Largest receipt
    let largest = receipts.reduce((acc, r) => {
      const total = Number(r.total_amount) || 0;
      if (!acc || total > acc.total) return { total, merchant: r.merchant_name, date: r.transaction_date };
      return acc;
    }, null);

    // Top merchant by total
    const merchantTotals = {};
    receipts.forEach((r) => {
      const total = Number(r.total_amount) || 0;
      const key = (r.merchant_name || 'Unknown').trim();
      merchantTotals[key] = (merchantTotals[key] || 0) + total;
    });
    const topMerchant = Object.entries(merchantTotals)
      .sort((a, b) => b[1] - a[1])
      .map(([merchant, total]) => ({ merchant, total }))[0];

    const templates = [];
    if (largest) {
      templates.push(
        `Your largest recent receipt was £${largest.total.toFixed(2)} at ${largest.merchant || 'a store'} on ${largest.date || 'a recent date'}.`
      );
    }
    if (topMerchant) {
      templates.push(
        `Across your history, you spent about £${topMerchant.total.toFixed(2)} at ${topMerchant.merchant || 'your top merchant'}.`
      );
    }
    if (!templates.length) return null;
    const insight = templates[Math.floor(Math.random() * templates.length)];
    console.log('🧠 User insight generated:', { userId, insight });
    return insight;
  } catch (err) {
    console.error('Failed to generate user insight:', err.message);
    return null;
  }
}

async function generateScanInsight({ merchant_name, total_amount, line_items }) {
  try {
    const total = Number(total_amount) || 0;
    const items = Array.isArray(line_items) ? line_items : [];
    const topCategories = Array.from(
      items.reduce((acc, item) => {
        const key = (item.main_category || item.category || '').toString().trim();
        if (key) acc.add(key);
        return acc;
      }, new Set())
    ).slice(0, 3);

    const templates = [
      `Give two short sentences about a receipt from ${merchant_name || 'this store'} totaling £${total.toFixed(2)}.`,
      `In two sentences, highlight anything notable in this receipt from ${merchant_name || 'the merchant'}. Total: £${total.toFixed(2)}.`,
      `Provide two concise sentences on this purchase (merchant: ${merchant_name || 'unknown'}, total £${total.toFixed(2)}, categories: ${topCategories.join(', ') || 'n/a'}).`,
      `Give two brief lines of insight about this receipt (total £${total.toFixed(2)}, merchant ${merchant_name || 'unknown'}).`,
    ];
    const prompt = templates[Math.floor(Math.random() * templates.length)];

    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content:
            'Return exactly two short sentences. Be neutral and concise. Keep under 220 characters total.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      temperature: 0.3,
      max_tokens: 120,
    });

    const content = response.choices[0]?.message?.content?.trim();
    if (!content) return null;
    console.log('🧠 Scan insight generated (OpenAI):', content);
    return content;
  } catch (err) {
    console.error('Failed to generate AI insight for scan:', err.message);
    return null;
  }
}

// --- Embedding Ingestion for Receipt Line Items ---
async function ingestReceiptItems(receipt, userId) {
  if (!receipt || !Array.isArray(receipt.line_items) || !userId) return;

  const receiptId = receipt.id;
  const merchantName = receipt.merchant_name || '';
  const canonicalMerchantId = receipt.canonical_merchant_id || null;
  const transactionDate = receipt.transaction_date || null;

  for (const rawItem of receipt.line_items) {
    try {
      const itemName = rawItem.item || rawItem.Item_Name || rawItem.name || rawItem.Name || '';
      const mainCategory = rawItem.main_category || rawItem.category || '';
      const subCategory = rawItem.sub_category || rawItem.SubCategory || '';
      const quantity = Number(rawItem.quantity || rawItem.Quantity || 1) || 1;
      const unitPrice = Number(rawItem.price || rawItem.Price || 0) || 0;
      const totalPrice = Number(rawItem.total_price || quantity * unitPrice) || 0;

      const descriptor = [
        `Item: ${itemName}`,
        mainCategory ? `Main category: ${mainCategory}` : null,
        subCategory ? `Sub category: ${subCategory}` : null,
        merchantName ? `Merchant: ${merchantName}` : null,
        transactionDate ? `Date: ${transactionDate}` : null,
        `Price: £${unitPrice.toFixed(2)} x ${quantity} = £${totalPrice.toFixed(2)}`
      ]
        .filter(Boolean)
        .join('. ');

      const embeddingResp = await openai.embeddings.create({
        model: 'text-embedding-3-small',
        input: descriptor,
      });

      const embedding = embeddingResp.data?.[0]?.embedding;
      if (!embedding) {
        console.warn('No embedding returned for line item', { itemName, receiptId });
        continue;
      }

      const { error } = await supabase
        .from('receipt_item_embeddings')
        .upsert(
          {
            user_id: userId,
            receipt_id: receiptId,
            item_name: itemName,
            main_category: mainCategory,
            sub_category: subCategory,
            quantity,
            unit_price: unitPrice,
            total_price: totalPrice,
            merchant_name: merchantName,
            canonical_merchant_id: canonicalMerchantId,
            transaction_date: transactionDate,
            embedding,
          },
          { onConflict: 'receipt_id,item_name,total_price' }
        );

      if (error) {
        console.error('Failed to upsert receipt_item_embedding', { receiptId, itemName, error });
      }
    } catch (err) {
      console.error('Error ingesting line item embedding', err.message);
    }
  }
}

module.exports.ingestReceiptItems = ingestReceiptItems;

// --- Query Parser (GPT-4o-mini) ---
async function parseUserQuery(question) {
  if (!question || typeof question !== 'string') {
    throw new Error('Question is required');
  }
  const prompt = `
You are a query parser. Fix spelling. Return strict JSON only, no extra text.
Fields:
- task: string (e.g., "spend_summary", "top_merchants", "find_receipts")
- keywords: array of strings
- merchant: string or null
- category: string or null
- date_range: string or null (e.g., "last_30_days", "last_90_days", "this_month", "last_month", "ytd", "all_time")
- start_date: string or null (ISO YYYY-MM-DD)
- end_date: string or null (ISO YYYY-MM-DD)
- use_vector: boolean (true if semantic search is implied)

Input: "${question}"

Return JSON only:
{
  "task": "",
  "keywords": [],
  "merchant": null,
  "category": null,
  "date_range": null,
  "start_date": null,
  "end_date": null,
  "use_vector": false
}
`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: 'You return strict JSON only.' },
      { role: 'user', content: prompt },
    ],
    temperature: 0,
    max_tokens: 300,
    response_format: { type: 'json_object' },
  });

  const content = response.choices[0]?.message?.content;
  if (!content) throw new Error('No content returned from OpenAI');
  return JSON.parse(content);
}

module.exports.parseUserQuery = parseUserQuery;

// --- SQL-based item search (no vectors) ---
async function searchItemsSQL(parsed, userId) {
  if (!userId) return [];
  const {
    keywords = [],
    merchant = null,
    category = null,
    date_range = null,
    start_date = null,
    end_date = null,
  } = parsed || {};

  // Build base query with receipt-level filters
  let query = supabase
    .from('receipts')
    .select('id, merchant_name, transaction_date, canonical_merchant_id, line_items')
    .eq('user_id', userId)
    .order('transaction_date', { ascending: false });

  // Date range filter
  const today = new Date();
  const iso = (d) => d.toISOString().split('T')[0];
  const applyBetween = (from, to) => {
    query = query.gte('transaction_date', from).lte('transaction_date', to);
  };

  if (start_date && end_date) {
    applyBetween(start_date, end_date);
  } else if (date_range) {
    const range = date_range.toLowerCase();
    if (range === 'last_7_days') {
      const d = new Date(today);
      d.setDate(d.getDate() - 7);
      applyBetween(iso(d), iso(today));
    } else if (range === 'last_30_days' || range === 'last_30') {
      const d = new Date(today);
      d.setDate(d.getDate() - 30);
      applyBetween(iso(d), iso(today));
    } else if (range === 'last_90_days' || range === 'last_90') {
      const d = new Date(today);
      d.setDate(d.getDate() - 90);
      applyBetween(iso(d), iso(today));
    } else if (range === 'last_month') {
      const firstDayThisMonth = new Date(today.getFullYear(), today.getMonth(), 1);
      const lastDayLastMonth = new Date(firstDayThisMonth.getTime() - 1);
      const firstDayLastMonth = new Date(lastDayLastMonth.getFullYear(), lastDayLastMonth.getMonth(), 1);
      applyBetween(iso(firstDayLastMonth), iso(lastDayLastMonth));
    } else if (range === 'this_month') {
      const firstDay = new Date(today.getFullYear(), today.getMonth(), 1);
      applyBetween(iso(firstDay), iso(today));
    } else if (range === 'ytd') {
      const firstDay = new Date(today.getFullYear(), 0, 1);
      applyBetween(iso(firstDay), iso(today));
    }
  }

  // Merchant filter (receipt-level)
  if (merchant) {
    query = query.ilike('merchant_name', `%${merchant}%`);
  }

  const { data: receipts, error } = await query.limit(200); // limit rows before flattening
  if (error) {
    console.error('searchItemsSQL error:', error.message);
    return [];
  }
  if (!receipts || receipts.length === 0) return [];

  // Flatten line items and apply item-level filters
  const keywordList = Array.isArray(keywords) ? keywords.filter(Boolean) : [];
  const results = [];
  for (const receipt of receipts) {
    const lineItems = Array.isArray(receipt.line_items) ? receipt.line_items : [];
    for (const li of lineItems) {
      const itemName = li.item || li.Item_Name || li.name || li.Name || '';
      const mainCat = li.main_category || li.category || '';
      const subCat = li.sub_category || li.SubCategory || '';
      const quantity = Number(li.quantity || li.Quantity || 1) || 1;
      const price = Number(li.price || li.Price || 0) || 0;

      // Item-level filters
      if (keywordList.length) {
        const nameLower = itemName.toLowerCase();
        const pass = keywordList.some((kw) => nameLower.includes(String(kw).toLowerCase()));
        if (!pass) continue;
      }
      if (category) {
        const catLower = String(category).toLowerCase();
        if (String(mainCat || '').toLowerCase() !== catLower) continue;
      }

      results.push({
        item_name: itemName,
        main_category: mainCat,
        sub_category: subCat,
        price,
        quantity,
        merchant_name: receipt.merchant_name,
        transaction_date: receipt.transaction_date,
        receipt_id: receipt.id,
      });

      if (results.length >= 50) break;
    }
    if (results.length >= 50) break;
  }

  return results;
}

module.exports.searchItemsSQL = searchItemsSQL;

// --- Vector search for items ---
async function searchItemsVector(question, userId, limit = 20) {
  try {
    if (!question || !userId) return [];
    const embeddingResp = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: question,
    });
    const embedding = embeddingResp.data?.[0]?.embedding;
    if (!embedding) return [];

    const { data, error } = await supabase.rpc('match_receipt_items', {
      query_embedding: embedding,
      match_count: limit,
      _user_id: userId,
    });

    if (error) {
      console.error('searchItemsVector RPC error:', error.message);
      return [];
    }
    if (!data || !Array.isArray(data)) return [];

    return data
      .map((row) => ({
        receipt_id: row.receipt_id,
        item_name: row.item_name,
        main_category: row.main_category,
        sub_category: row.sub_category,
        price: row.total_price,
        merchant_name: row.merchant_name,
        transaction_date: row.transaction_date,
        similarity: row.similarity,
      }))
      .sort((a, b) => (b.similarity || 0) - (a.similarity || 0));
  } catch (err) {
    console.error('searchItemsVector error:', err.message);
    return [];
  }
}

module.exports.searchItemsVector = searchItemsVector;

// --- Final answer generation ---
async function generateFinalAnswer(question, items, parsed) {
  try {
    const sysPrompt = `You are Owlit, a personal finance assistant. 
    Your job is to answer the user's question using ONLY the provided receipt item JSON.
    If there are no items, reply: 'No matching purchases found.'
    Keep answers short, clear, and friendly.
    Use GBP formatting (example: £2.50).
    If the question asks for:
      - total spend → sum item prices
      - last purchase → use the most recent date
      - list → summarize items in a single short paragraph
      - compare → highlight differences
      - trend → describe simple patterns
    NEVER invent items. NEVER use knowledge outside the JSON.`;

    const userContent = `User question: ${question}
Parsed filters: ${JSON.stringify(parsed || {})}
Matching items: ${JSON.stringify(items || [])}`;

    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: sysPrompt },
        { role: 'user', content: userContent },
      ],
      temperature: 0.2,
      max_tokens: 200,
    });

    const content = response.choices[0]?.message?.content?.trim();
    return content || "Sorry, I couldn't process that.";
  } catch (err) {
    console.error('generateFinalAnswer error:', err.message);
    return "Sorry, I couldn't process that.";
  }
}


module.exports.generateFinalAnswer = generateFinalAnswer;

async function getNormalizedItemName(itemName) {
  try {
    // 1. Check if the item is already normalized in the database
    const { data: existingItem, error: fetchError } = await supabase
      .from('Item_Table')
      .select('normalized_name')
      .ilike('item_name', itemName)
      .maybeSingle();

    if (fetchError) {
      console.error('Error fetching normalized item name:', fetchError);
    }

    if (existingItem) {
      console.log(`✅ Found cached normalized name for "${itemName}": "${existingItem.normalized_name}"`);
      return existingItem.normalized_name;
    }

    // 2. If not found, call OpenAI to normalize it
    const prompt = `You are a data normalization expert. Your task is to provide a concise, standardized name for a given grocery item. For example, if the item is "WBTN Toast Slice White", the normalized name should be "Bread".

Item: ${itemName}
Normalized Name:`;

    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are a data normalization expert.' },
        { role: 'user', content: prompt },
      ],
      temperature: 0,
      max_tokens: 60,
    });

    const normalizedName = response.choices[0]?.message?.content?.trim();
    if (!normalizedName) return itemName;

    // 3. Save the normalized name to the database for future use
    const { error: insertError } = await supabase
      .from('Item_Table')
      .insert([{ item_name: itemName, normalized_name: normalizedName }]);

    if (insertError) {
      console.error('Error saving normalized item name:', insertError);
    }

    return normalizedName;
  } catch (error) {
    console.error('Error getting normalized item name:', error);
    return itemName;
  }
}


async function processDocumentWithDocAI(buffer, mimeType) {
  console.log('🚀 Starting Document AI Processing...');
  const name = `projects/${DOCAI_PROJECT_ID}/locations/${DOCAI_LOCATION}/processors/${DOCAI_PROCESSOR_ID}`;
  const request = {
    name,
    rawDocument: {
      content: buffer.toString('base64'),
      mimeType: mimeType,
    },
  };
  try {
    const [result] = await docAIClient.processDocument(request);
    console.log('✅ Document AI processing complete.');
    console.log('📜 Document AI Raw Text:\n', result.document.text);
    return result.document.text;
  } catch (error) {
    console.error('❌ Google Document AI API error:', error);
    throw new Error('Failed to process document with Google Document AI.');
  }
}

async function structureTextWithOpenAI(text, tesseractHint = '') {
  console.log('🤖 Structuring text with OpenAI...');
  const MAX_RETRIES = 2;
  const jsonPrompt = `
Convert the OCR text from a receipt into structured JSON.

**OCR Text from Google Document AI:**
${text}

${tesseractHint ? `**Hint from Tesseract Pre-pass:**\n${tesseractHint}\n` : ''}

${CATEGORY_PROMPT_TEXT}

**JSON Structure:**
{
  "merchant": "",
  "transaction_date": "DD/MM/YYYY",
  "main_category": "",
  "store_type": "",
  "items": [
    {
      "name": "",
      "quantity": 1,
      "price": 0.0,
      "category": "",
      "sub_category": "",
      "category_icon_key": "",
      "subcategory_icon_key": ""
    }
  ],
  "total_amount": 0.0
}

**Rules:**
1. Use the Google Document AI text as the primary source. Use the Tesseract hint to resolve ambiguities.
2. Quantity defaults to 1 if missing.
3. Price must be a number only (no currency symbols).
4. Assign a logical category/sub_category from the provided taxonomy for each item.
5. Also provide category_icon_key and subcategory_icon_key for each item, choosing from the allowed icon key lists above (closest match).
5. Based on the merchant name and items, infer the store's main_category (e.g., "Groceries", "Fashion", "Electronics") and store_type (e.g., "Supermarket", "Clothing Store", "Electronics Store").
6. The date should be in DD/MM/YYYY format.
7. Return **JSON only**, no explanations.
`;
  for (let i = 0; i <= MAX_RETRIES; i++) {
    try {
      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        messages: [{ role: 'user', content: jsonPrompt }],
        temperature: 0,
        max_tokens: 4000,
        response_format: { type: "json_object" },
      });
      const content = response.choices[0]?.message?.content;
      if (!content) throw new Error('No JSON content returned from OpenAI');
      const jsonData = JSON.parse(content);
      console.log('✅ OpenAI structuring complete.');
      return jsonData;
    } catch (error) {
      console.error(`❌ OpenAI API error on attempt ${i + 1}:`, error.message);
      if (i === MAX_RETRIES) {
        throw new Error('Failed to get a valid response from OpenAI for structuring after multiple retries.');
      }
      console.log('Retrying structuring...');
    }
  }
}

// New function to convert markdown to JSON
async function convertMarkdownToJSON(markdown) {
  console.log('🤖 Converting Markdown to JSON with OpenAI...');
  const prompt = `
        Convert this markdown document into a structured JSON format.
        Preserve the hierarchy and meaning of the document.
        Use clear, descriptive field names.

        **Markdown Content:**
        ${markdown}

        **Output:**
        Return only the structured JSON object.
    `;
  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.2,
      max_tokens: 4000,
      response_format: { type: "json_object" },
    });
    const content = response.choices[0]?.message?.content;
    if (!content) throw new Error('No JSON content returned from OpenAI');
    console.log('✅ OpenAI Markdown-to-JSON conversion complete.');
    return JSON.parse(content);
  } catch (error) {
    console.error('❌ OpenAI Markdown-to-JSON conversion error:', error.message);
    throw new Error('Failed to convert markdown to JSON with OpenAI.');
  }
}

async function extractIntent(question = '') {
  const prompt = `You are an intent extraction assistant for a receipt management app. Read the user question and return strict JSON with the following shape:
{
  "time_range": "this_month" | "last_month" | "this_week" | "last_7_days" | "all_time",
  "item_terms": [string],
  "categories": [string],
  "subcategories": [string],
  "merchants": [string]
}

Rules:
- ONLY include values explicitly mentioned. Do not guess.
- If no time range mentioned, use "all_time".
- Strings should use the exact phrasing from the user when possible.

Question: ${question}`;

  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      temperature: 0,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: 'Extract structured intent without guessing.' },
        { role: 'user', content: prompt },
      ],
    });

    const content = response.choices[0]?.message?.content;
    if (!content) throw new Error('No intent returned');
    const parsed = JSON.parse(content);
    return {
      time_range: parsed.time_range || 'all_time',
      item_terms: Array.isArray(parsed.item_terms) ? parsed.item_terms : [],
      categories: Array.isArray(parsed.categories) ? parsed.categories : [],
      subcategories: Array.isArray(parsed.subcategories) ? parsed.subcategories : [],
      merchants: Array.isArray(parsed.merchants) ? parsed.merchants : [],
    };
  } catch (error) {
    console.error('extractIntent error:', error);
    return {
      time_range: 'all_time',
      item_terms: [],
      categories: [],
      subcategories: [],
      merchants: [],
    };
  }
}

const makeQueryKey = (intent) => JSON.stringify(intent || {});

async function fetchFacts(intent, userId) {
  if (!userId) {
    throw new ValidationError('User session is required to fetch facts.');
  }

  const { from, to } = getDateRangeForIntent(intent.time_range || 'all_time');

  let query = supabase
    .from('v_receipt_line_items_enriched')
    .select('*')
    .eq('user_id', userId);

  if (from) {
    query = query.gte('transaction_date', from);
  }
  if (to && intent.time_range === 'last_month') {
    query = query.lt('transaction_date', to);
  } else if (to && intent.time_range !== 'last_month') {
    query = query.lte('transaction_date', to);
  }

  if (intent.merchants && intent.merchants.length > 0) {
    query = query.in('merchant_name', intent.merchants);
  }

  const { data, error } = await query;
  if (error) {
    console.error('fetchFacts supabase error:', error);
    throw new Error('Failed to fetch receipt facts.');
  }

  const categories = (intent.categories || []).map((c) => c.toLowerCase());
  const subcategories = (intent.subcategories || []).map((c) => c.toLowerCase());
  const itemTerms = (intent.item_terms || []).map((t) => t.toLowerCase());

  const filtered = (data || []).filter((row) => {
    if (categories.length && (!row.main_category || !categories.includes(row.main_category.toLowerCase()))) {
      return false;
    }
    if (subcategories.length && (!row.sub_category || !subcategories.includes(row.sub_category.toLowerCase()))) {
      return false;
    }
    if (itemTerms.length) {
      const item = (row.item || '').toLowerCase();

      // Expand item terms with synonyms
      const expandedTerms = itemTerms.flatMap(term => ITEM_SYNONYMS[term] || [term]);

      if (!expandedTerms.some((term) => item.includes(term))) {
        return false;
      }
    }
    return true;
  });

  const totalsByMerchant = {};
  let totalSpend = 0;
  const receiptIds = new Set();

  filtered.forEach((row) => {
    const price = Number(row.unit_price) || 0;
    const quantity = Number(row.quantity) || 0;
    const spend = Number(row.total_price) || (price * quantity); // Prefer pre-calculated total
    totalSpend += spend;
    const merchant = row.merchant_name || 'Unknown';
    totalsByMerchant[merchant] = (totalsByMerchant[merchant] || 0) + spend;
    if (row.receipt_id) {
      receiptIds.add(row.receipt_id);
    }
  });

  const merchant_breakdown = Object.entries(totalsByMerchant)
    .map(([merchant, spend]) => ({ merchant, spend }))
    .sort((a, b) => b.spend - a.spend);

  return {
    total_spend: Number(totalSpend.toFixed(2)),
    merchant_breakdown,
    receipt_ids: Array.from(receiptIds),
  };
}

const containsSQL = (text = '') => {
  if (!text) return false;
  const sqlPattern = /\b(select|with|insert|update|delete)\b[\s\S]+?\b(from|into)\b/i;
  return sqlPattern.test(text);
};

const summarizeFacts = (facts) => {
  if (
    !facts ||
    !Array.isArray(facts.receipt_ids) ||
    facts.receipt_ids.length === 0 ||
    !facts.total_spend ||
    Number(facts.total_spend) === 0
  ) {
    return `
Aisa lagta hai ki is time range me aapne coffee purchase nahi ki ☕️
(Ya ho sakta hai item line me "coffee" word mention na ho.)

Agar chaaho to main:
• "tea", "latte", "cappuccino", "cafe" jaise alternate keywords check kar sakta hun
• Ya iss mahine ka poora beverages spend bata du

Bol do: "Check beverages this month" 🍵
`;
  }

  const total = Number(facts.total_spend).toFixed(2);
  const count = facts.receipt_ids.length;
  const topMerchant =
    facts.merchant_breakdown && facts.merchant_breakdown.length
      ? facts.merchant_breakdown[0]
      : null;

  let summary = `Maine ${count} receipt(s) check ki aur total spend approx ₹${total} raha.`;
  if (topMerchant) {
    summary += ` Sabse zyada kharch ${topMerchant.merchant} par (₹${topMerchant.spend.toFixed(2)}) hua.`;
  }
  summary += ' Agar chaho to main aur detail mein bata sakta hun.';
  return summary;
};

async function generateAnswer(question, facts) {
  if (
    !facts ||
    !Array.isArray(facts.receipt_ids) ||
    facts.receipt_ids.length === 0 ||
    !facts.total_spend ||
    Number(facts.total_spend) === 0
  ) {
    return summarizeFacts(facts);
  }

  const resp = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      {
        role: 'system',
        content: `
Use ONLY the provided facts. Never guess or invent numbers.
Keep the answer warm, friendly, and short.
If merchant_breakdown exists, summarize top merchants.
Never output SQL queries or code – reply in natural language only.
`,
      },
      {
        role: 'user',
        content: `Question: ${question}\nFacts: ${JSON.stringify(facts)}`,
      },
    ],
  });

  const answer = resp.choices?.[0]?.message?.content?.trim() || '';
  if (containsSQL(answer)) {
    return summarizeFacts(facts);
  }
  return answer;
}



// --- New Self-Learning Categorization Logic ---
function findInMasterList(itemName) {
  const lowercasedItem = itemName.toLowerCase().trim();
  // First, check for an exact match on a canonical name
  if (masterItems[lowercasedItem]) {
    return { ...masterItems[lowercasedItem] };

  }
  // Then, check all OCR variations
  for (const canonicalName in masterItems) {
    const itemData = masterItems[canonicalName];
    if (itemData.receipt_ItemNames.some(name => name.toLowerCase().trim() === lowercasedItem)) {
      return { ...itemData, Item_Name: canonicalName };
    }
  }
  return null;
}

function findInCategoryKeywords(itemName) {
  const lowercasedItem = itemName.toLowerCase().trim();
  for (const mainCategory in SUB_CATEGORIES) {
    for (const subCategory of SUB_CATEGORIES[mainCategory]) {
      if (lowercasedItem.includes(subCategory.replace('_', ' '))) {
        return { main_category: mainCategory, sub_category: subCategory };
      }
    }
  }
  return null;
}

async function categorizeLineItems(lineItems, userId) {
  let isMasterListUpdated = false;

  // Process all items in parallel
  const itemPromises = lineItems.map(async (item) => {
    const rawItemName = item.name || item.Name || '';
    if (!rawItemName) return null;

    const normalizedItemName = rawItemName.trim();
    const canonicalItemName = normalizedItemName.toLowerCase();

    const aiCategoryIconKey = normalizeCategoryIconKey(item.category_icon_key || item.CategoryIconKey);
    const aiSubcategoryIconKey = normalizeSubcategoryIconKey(
      item.subcategory_icon_key || item.SubCategoryIconKey || item.sub_category_icon_key
    );

    // ✅ 1) Check user-specific category override *if* user is logged in
    let userOverride = null;

    if (userId) {
      const exactMatch = await supabase
        .from('user_categories')
        .select('main_category, sub_category')
        .eq('user_id', userId)
        .eq('item_name', normalizedItemName)
        .maybeSingle();

      if (exactMatch.data) {
        userOverride = exactMatch.data;
      } else {
        const normalizedMatch = await supabase
          .from('user_categories')
          .select('main_category, sub_category')
          .eq('user_id', userId)
          .eq('item_name', canonicalItemName)
          .maybeSingle();

        userOverride = normalizedMatch.data;
      }
    }

    let masterListEntry;

    if (userOverride) {
      masterListEntry = {
        Item_Name: rawItemName,
        main_category: userOverride.main_category,
        sub_category: userOverride.sub_category
      };
      console.log(`🎨 Used USER-SPECIFIC category for "${rawItemName}"`);
    } else {
      // ✅ Fallback to global master list
      masterListEntry = findInMasterList(rawItemName);
    }

    if (masterListEntry) { // Found in master list
      const categoryIconKey = aiCategoryIconKey || normalizeCategoryIconKey(masterListEntry.main_category);
      const subcategoryIconKey = aiSubcategoryIconKey || inferSubcategoryIconKey(masterListEntry.sub_category);
      const normalized_name = await getNormalizedItemName(rawItemName);

      const categoryItem = {
        item: rawItemName,
        Item_Name: masterListEntry.Item_Name,
        main_category: masterListEntry.main_category,
        sub_category: masterListEntry.sub_category,
        category_icon_key: categoryIconKey || null,
        subcategory_icon_key: subcategoryIconKey || null,
        price: parseFloat(item.price || item.Price) || 0,
        quantity: parseInt(item.quantity || item.Quantity, 10) || 1,
        normalized_name: normalized_name,
      };

      console.log(`🧠 Found "${rawItemName}" in master list as "${masterListEntry.Item_Name}".`);

      // Also check if this specific OCR variation is new and add it
      const canonicalEntry = masterItems[masterListEntry.Item_Name];
      const lowercasedRaw = rawItemName.toLowerCase().trim();
      if (canonicalEntry && !canonicalEntry.receipt_ItemNames.some(n => n.toLowerCase().trim() === lowercasedRaw)) {
        canonicalEntry.receipt_ItemNames.push(rawItemName);
        isMasterListUpdated = true;
        console.log(`🔄 Updated "${masterListEntry.Item_Name}" with new OCR variation: "${rawItemName}"`);
      }

      return categoryItem;

    } else { // Not found in master list, needs to be added
      let categoryInfo = findInCategoryKeywords(rawItemName);
      const source = categoryInfo ? 'keywords' : 'openai';

      if (!categoryInfo) {
        categoryInfo = {
          main_category: item.category || item.Category || 'other',
          sub_category: item.sub_category || item.SubCategory || 'miscellaneous'
        };
      }

      const categoryIconKey = aiCategoryIconKey || normalizeCategoryIconKey(categoryInfo.main_category);
      const subcategoryIconKey = aiSubcategoryIconKey || inferSubcategoryIconKey(categoryInfo.sub_category);
      const canonicalName = rawItemName; // Use the first seen name as canonical
      const normalized_name = await getNormalizedItemName(rawItemName);

      const categoryItem = {
        item: rawItemName,
        Item_Name: canonicalName,
        main_category: categoryInfo.main_category,
        sub_category: categoryInfo.sub_category,
        category_icon_key: categoryIconKey || null,
        subcategory_icon_key: subcategoryIconKey || null,
        price: parseFloat(item.price || item.Price) || 0,
        quantity: parseInt(item.quantity || item.Quantity, 10) || 1,
        normalized_name: normalized_name,
      };

      // Add the new item to the master list
      await saveMasterItem(
        canonicalName,
        categoryInfo.main_category,
        categoryInfo.sub_category
      );

      console.log(`✨ Added "${canonicalName}" to master list from ${source}.`);

      return categoryItem;
    }
  });

  const results = await Promise.all(itemPromises);
  return results.filter(item => item !== null);
}

// --- API Routes ---
app.post('/api/scan', optionalAuthenticate, upload.single('file'), async (req, res) => {
  try {
    console.log("📥 Received file:", req.file ? req.file.originalname : "No file");
    if (!req.file) {
      throw new ValidationError('A file upload is required.');
    }

    if (!isSupportedUpload(req.file.mimetype)) {
      throw new ValidationError('Unsupported file type. Please upload a PDF or image.');
    }

    const scanMode = (req.body?.scanMode || 'receipt').toLowerCase();
    const highAccuracy = String(req.body?.highAccuracy || 'false').toLowerCase() === 'true';
    validateFields({ scanMode }, {
      scanMode: {
        type: 'string',
        required: true,
        allowed: ['receipt', 'document'],
        message: 'scanMode must be either "receipt" or "document".'
      }
    });

    if (scanMode === 'document') {
      console.log('🚀 === STARTING DOCUMENT PROCESSING ===');
      try {
        const rawText = await processDocumentWithDocAI(req.file.buffer, req.file.mimetype);
        const markdown = rawText.split('\n').join('  \n');
        res.setHeader('Content-Type', 'text/plain');
        return res.send(markdown);
      } catch (error) {
        return handleApiError(res, error, 'Failed to process document.');
      }
    }

    console.log('🚀 === STARTING RECEIPT PROCESSING ===');
    console.log(`🎯 High accuracy mode: ${highAccuracy ? 'ENABLED' : 'disabled'}`);
    try {
      console.log(`⚙️ Using Google Document AI pipeline with Tesseract pre-pass.`);

      const preprocessedImageBuffer = await preprocessImage(req.file.buffer);

      let tesseractText = '';
      if (highAccuracy) {
        console.log('🏃 Running Tesseract.js OCR prepass (high accuracy enabled)...');
        tesseractText = await runTesseract(preprocessedImageBuffer);
        console.log('✅ Tesseract prepass complete.');
      } else {
        console.log('⏭️ Skipping Tesseract prepass (high accuracy disabled).');
      }

      const extractedText = await processDocumentWithDocAI(preprocessedImageBuffer, 'image/jpeg');

      const processedData = await structureTextWithOpenAI(extractedText, tesseractText);

      const lineItems = processedData.items || processedData.Items || [];
      const categorizedLineItems = await categorizeLineItems(lineItems, req.user?.id || null);

      const rawMerchant = processedData.merchant || processedData.MerchantName || '';
      const merchant_name = rawMerchant
        .toLowerCase()
        .replace(/[^a-z0-9 -]/gi, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .replace(/(?:^|[\s])\w/g, c => c.toUpperCase());

      let store_type = 'Other';
      let main_category = 'Other';
      const userId = req.user?.id || null;
      const merchantOverrideKey = normalizeMerchantKey(merchant_name);

      if (userId && merchantOverrideKey) {
        const { data: override } = await supabase
          .from('user_store_type_overrides')
          .select('store_type')
          .eq('user_id', userId)
          .ilike('merchant_name', merchantOverrideKey)
          .maybeSingle();

        if (override) {
          store_type = override.store_type;
          console.log(`🎨 Used USER-SPECIFIC store type for "${merchant_name}": ${store_type}`);
        }
      }

      if (store_type === 'Other') {
        const { data: storeInfo, error: storeInfoError } = await supabase
          .from('store_info')
          .select('main_category, store_type')
          .eq('merchant_name', merchant_name)
          .maybeSingle();

        if (storeInfoError) {
          console.error('Error fetching store info:', storeInfoError);
        }

        if (storeInfo) {
          main_category = storeInfo.main_category;
          store_type = storeInfo.store_type;
        } else {
          main_category = processedData.main_category || 'Other';
          store_type = processedData.store_type || 'Other';
          if (store_type !== 'Other') {
            const { error: insertError } = await supabase
              .from('store_info')
              .insert({
                merchant_name,
                main_category,
                store_type,
              });
            if (insertError) {
              console.error('Error inserting new store type:', insertError);
            }
          }
        }
      }

      const transformedData = {
        merchant_name,
        transaction_date: formatDate(processedData.transaction_date || processedData.Date),
        line_items: categorizedLineItems,
        total_amount: parseFloat(processedData.total_amount || processedData.TotalAmount) || 0,
        main_category,
        store_type,
        ai_insight:
          await generateUserInsightFromSupabase(req.user?.id || null) ||
          await generateScanInsight({
            merchant_name,
            total_amount: processedData.total_amount || processedData.TotalAmount || 0,
            line_items: categorizedLineItems,
          }),
      };

      // Check for duplicate receipt
      if (req.user?.id) {
        const { data: existingReceipt } = await supabase
          .from('receipts')
          .select('id')
          .eq('user_id', req.user.id)
          .eq('merchant_name', transformedData.merchant_name)
          .eq('transaction_date', transformedData.transaction_date)
          .eq('total_amount', transformedData.total_amount)
          .maybeSingle();

        if (existingReceipt) {
          console.log(`⚠️ Duplicate found: ${existingReceipt.id}`);
          transformedData.id = existingReceipt.id; // iOS app looks for this 'id'
        }
      }

      console.log(`🟢 Processed single receipt for user ${req.user?.id || 'anonymous'} with ${categorizedLineItems.length} line item(s).`);
      const responsePayload = { ...transformedData };
      res.json(responsePayload);

      // Fire-and-forget embedding ingestion
      // Only run if it's NOT a duplicate (no ID present in transformedData)
      if (req.user?.id && !transformedData.id) {
        setImmediate(async () => {
          try {
            await ingestReceiptItems(
              {
                id: null,
                ...transformedData,
                receipt_url: null,
                canonical_merchant_id: null,
              },
              req.user.id
            );
          } catch (err) {
            console.error('🔴 Failed to ingest receipt items (single receipt):', err.message);
          }
        });
      }
      return;

    } catch (error) {
      return handleApiError(res, error, 'Failed to process receipt.');
    }
  } catch (error) {
    return handleApiError(res, error, 'Failed to process upload.');
  }
});

app.post('/api/scan-multi', optionalAuthenticate, upload.array('files', 10), async (req, res) => {
  try {
    if (!req.files || req.files.length < 2) {
      throw new ValidationError('Please upload between 2 and 10 pages to process a multi-page receipt.');
    }

    const files = req.files.slice(0, 10);
    console.log(`🗂️ Processing ${files.length} pages for multi-page receipt`);

    const combinedTexts = [];
    const combinedHints = [];

    for (const file of files) {
      const preprocessedImageBuffer = await preprocessImage(file.buffer);
      const tesseractText = await runTesseract(preprocessedImageBuffer);
      if (tesseractText) {
        combinedHints.push(tesseractText);
      }
      const docText = await processDocumentWithDocAI(preprocessedImageBuffer, 'image/jpeg');
      if (docText) {
        combinedTexts.push(docText);
      }
    }

    if (!combinedTexts.length) {
      throw new Error('Failed to extract text from uploaded images.');
    }

    const mergedText = combinedTexts.join('\n\n---- PAGE BREAK ----\n\n');
    const mergedHints = combinedHints.join('\n');

    const processedData = await structureTextWithOpenAI(mergedText, mergedHints);
    const lineItems = processedData.items || processedData.Items || [];
    const categorizedLineItems = await categorizeLineItems(lineItems, req.user?.id || null);

    const rawMerchant = processedData.merchant || processedData.MerchantName || '';
    const merchant_name = rawMerchant
      .toLowerCase()
      .replace(/[^a-z0-9 ]/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/\b\w/g, c => c.toUpperCase());

    let store_type = 'Other';
    let main_category = 'Other';
    const userId = req.user?.id || null;
    const merchantOverrideKey = normalizeMerchantKey(merchant_name);

    if (userId && merchantOverrideKey) {
      const { data: override } = await supabase
        .from('user_store_type_overrides')
        .select('store_type')
        .eq('user_id', userId)
        .ilike('merchant_name', merchantOverrideKey)
        .maybeSingle();

      if (override) {
        store_type = override.store_type;
        console.log(`🎨 Used USER-SPECIFIC store type for "${merchant_name}": ${store_type}`);
      }
    }

    if (store_type === 'Other') {
      const { data: storeInfo, error: storeInfoError } = await supabase
        .from('store_info')
        .select('main_category, store_type')
        .eq('merchant_name', merchant_name)
        .maybeSingle();

      if (storeInfoError) {
        console.error('Error fetching store info:', storeInfoError);
      }

      if (storeInfo) {
        main_category = storeInfo.main_category;
        store_type = storeInfo.store_type;
      } else {
        main_category = processedData.main_category || 'Other';
        store_type = processedData.store_type || 'Other';
        if (store_type !== 'Other') {
          const { error: insertError } = await supabase
            .from('store_info')
            .insert({
              merchant_name,
              main_category,
              store_type,
            });
          if (insertError) {
            console.error('Error inserting new store type:', insertError);
          }
        }
      }
    }

    let receipt_url = null;
    const firstFile = files[0];
    if (firstFile) {
      const receiptId = require('crypto').randomUUID();
      const extension = path.extname(firstFile.originalname) || '.jpg';
      const now = new Date();
      const time = now.toTimeString().split(' ')[0].replace(/:/g, '');
      const fileName = `${merchant_name || 'receipt'}-${now.toISOString().split('T')[0]}-${time}-${receiptId}${extension}`;

      const { error: uploadError } = await supabase.storage
        .from('receipts')
        .upload(fileName, firstFile.buffer, {
          contentType: firstFile.mimetype,
        });

      if (!uploadError) {
        const { data: publicUrlData } = supabase.storage
          .from('receipts')
          .getPublicUrl(fileName);
        receipt_url = publicUrlData?.publicUrl || null;
      } else {
        console.error('Error uploading multi-page preview:', uploadError);
      }
    }

    const transaction_date = formatDate(processedData.transaction_date || processedData.Date);
    const total_amount = parseFloat(processedData.total_amount || processedData.TotalAmount) || 0;

    const { merchant_id: canonicalMerchantId, alias: merchantAlias } = await resolveMerchant(merchant_name || '', supabase);

    const normalizedTransactionDate = transaction_date;
    const normalizedTotalAmount = total_amount;
    const familyId = req.user?.id ? await getUserFamilyId(req.user.id) : null;
    const dedupeHash = buildReceiptHash(req.user?.id || 'multi', {
      merchant_name,
      transaction_date: normalizedTransactionDate,
      total_amount: normalizedTotalAmount,
      line_items: categorizedLineItems,
    });
    const receiptHashToStore = dedupeHash;

    // --- Loose Fingerprint for Multi-Page ---
    const looseHash = buildLooseReceiptHash(req.user?.id || 'multi', {
      merchant_name,
      transaction_date: normalizedTransactionDate,
      total_amount: normalizedTotalAmount,
      line_items: categorizedLineItems,
    });

    let isPotentialDuplicate = false;
    if (req.user?.id) {
      const { data: looseMatches } = await supabase
        .from('receipts')
        .select('id')
        .eq('user_id', req.user.id)
        .eq('receipt_fingerprint_loose', looseHash)
        .limit(1);

      if (looseMatches && looseMatches.length > 0) {
        isPotentialDuplicate = true;
      }
    }
    // ----------------------------------------

    if (req.user?.id) {
      const { error: saveError } = await supabase
        .from('receipts')
        .insert({
          user_id: req.user.id,
          merchant_name,
          merchant_alias: merchantAlias,
          canonical_merchant_id: canonicalMerchantId,
          transaction_date: normalizedTransactionDate,
          total_amount: normalizedTotalAmount,
          line_items: categorizedLineItems,
          receipt_url,
          receipt_hash: receiptHashToStore,
          receipt_fingerprint_loose: looseHash,
          is_potential_duplicate: isPotentialDuplicate,
          family_id: familyId,
        });

      if (saveError) {
        console.error('Error saving multi-page receipt:', saveError);
      }
    }

    const transformedData = {
      merchant_name,
      transaction_date: normalizedTransactionDate,
      line_items: categorizedLineItems,
      total_amount: normalizedTotalAmount,
      main_category,
      store_type,
      receipt_url,
      ai_insight:
        await generateUserInsightFromSupabase(req.user?.id || null) ||
        await generateScanInsight({
          merchant_name,
          total_amount: normalizedTotalAmount,
          line_items: categorizedLineItems,
        }),
    };

    console.log(`🟢 Processed multi-page receipt for user ${req.user?.id || 'anonymous'} with ${categorizedLineItems.length} line item(s).`);
    res.json(transformedData);

    if (req.user?.id) {
      setImmediate(async () => {
        try {
          await ingestReceiptItems(
            {
              id: null,
              ...transformedData,
              canonical_merchant_id,
            },
            req.user.id
          );
        } catch (err) {
          console.error('🔴 Failed to ingest receipt items (multi-page):', err.message);
        }
      });
    }
    return;
  } catch (error) {
    return handleApiError(res, error, 'Failed to process multi-page receipt.');
  }
});

app.post('/api/process-document', authenticateRequest, async (req, res) => {
  console.log('📥 Received markdown for processing');
  try {
    const { markdown } = req.body || {};
    validateFields({ markdown }, {
      markdown: {
        type: 'string',
        required: true,
        trim: true,
        maxLength: MAX_MARKDOWN_LENGTH,
        message: 'markdown content is required.'
      }
    });

    const structuredJson = await convertMarkdownToJSON(markdown);
    return res.json(structuredJson);
  } catch (error) {
    return handleApiError(res, error, 'Failed to convert markdown to JSON.');
  }
});

app.post('/api/summarize-markdown', authenticateRequest, async (req, res) => {
  console.log('📥 Received markdown for summarization');
  try {
    const { markdown } = req.body || {};
    validateFields({ markdown }, {
      markdown: {
        type: 'string',
        required: true,
        trim: true,
        maxLength: MAX_MARKDOWN_LENGTH,
        message: 'markdown content is required.'
      }
    });

    const prompt = `
        You are a document summarization expert specializing in creating clean, card-style layouts from raw text. Your task is to transform the following unstructured text into a well-organized Markdown summary.

        **Instructions:**
        1. **Create Clear Sections:** Use level-2 headings (##) to group related information (e.g., "Patient Information", "Medication", "Instructions").
        2. **Clean & Readable**: The layout must be clean and easy to read. Use bullet points (-) for lists.
        3. **No Raw Text**: Do not include irrelevant information or artifacts from the scanning process. Only present the final, clean information.
        4. **Card-Style Layout**: Use horizontal rules (---) to visually separate the major sections of the card (e.g., between the header, the main content, and a footer/notes section).
        5. **Output valid Markdown only.**

        **Raw Text:**
        ${markdown}

        **Formatted Card-Style Markdown Output:**
    `;

    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.3,
      max_tokens: 1500,
    });
    const structuredMarkdown = response.choices[0]?.message?.content;
    if (!structuredMarkdown) throw new Error('No content returned from OpenAI for summarization');

    console.log('✅ OpenAI summarization complete.');
    res.setHeader('Content-Type', 'text/plain');
    return res.send(structuredMarkdown);
  } catch (error) {
    return handleApiError(res, error, 'Failed to summarize markdown.');
  }
});

// --- Semantic Caching Helpers ---
async function searchSqlMemory(question, matchThreshold = 0.8) {
  try {
    const embeddingResp = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: question,
    });
    const embedding = embeddingResp.data?.[0]?.embedding;

    const { data, error } = await supabase.rpc('match_sql_memory', {
      query_embedding: embedding,
      match_threshold: matchThreshold,
      match_count: 1
    });

    if (error) {
      console.error('Error searching SQL memory:', error);
      return null;
    }

    if (data && data.length > 0) {
      console.log('🧠 Found relevant SQL memory:', data[0].question);
      return data[0];
    }
    return null;
  } catch (err) {
    console.error('searchSqlMemory failed:', err);
    return null;
  }
}

async function saveSqlMemory(question, sqlQuery) {
  try {
    const embeddingResp = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: question,
    });
    const embedding = embeddingResp.data?.[0]?.embedding;

    const { data, error } = await supabase.from('sql_memory').insert({
      question,
      sql_query: sqlQuery,
      embedding
    }).select('id').single();

    if (error) {
      console.error('Error saving SQL memory:', error);
      return null;
    } else {
      console.log('💾 Saved successful SQL query to memory ID:', data.id);
      return data.id;
    }
  } catch (err) {
    console.error('saveSqlMemory failed:', err);
    return null;
  }
}

// --- Feedback Endpoint ---
app.post('/api/feedback', authenticateRequest, async (req, res) => {
  const { question, answer, feedback, memory_id } = req.body;
  const userId = req.user?.id;

  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!feedback || !['good', 'bad'].includes(feedback)) {
    return res.status(400).json({ error: 'Invalid feedback. Must be "good" or "bad".' });
  }

  try {
    // 1. Save Feedback
    const { error: insertError } = await supabase
      .from('feedbacks')
      .insert({
        user_id: userId,
        question,
        answer,
        feedback,
        memory_id: memory_id || null
      });

    if (insertError) {
      console.error('❌ Error saving feedback:', insertError);
      return res.status(500).json({ error: 'Failed to save feedback' });
    }
    console.log(`📝 Feedback "${feedback}" saved for user ${userId}.`);

    // 2. Memory Cleanup (Logic: If BAD feedback + Memory was used -> DELETE Memory)
    if (feedback === 'bad' && memory_id) {
      console.log(`🗑️ Bad feedback received. Deleting SQL memory ID: ${memory_id}`);
      const { error: deleteError } = await supabase
        .from('sql_memory')
        .delete()
        .eq('id', memory_id);

      if (deleteError) {
        console.error('❌ Error deleting bad memory:', deleteError);
      } else {
        console.log('✅ Bad memory deleted to prevent recurrence.');
      }

      // AUTO-RETRY LOGIC
      console.log('🔄 Triggering Auto-Retry for bad feedback...');
      try {
        const retryResult = await AskController.processQuestion({
          userId,
          question,
          history: [], // Feedback endpoint doesn't carry full history, assume context-free retry for now
          isRetry: true
        });

        return res.json({
          success: true,
          memory_deleted: true,
          new_answer: retryResult.answer,
          new_tool: retryResult.tool
        });
      } catch (retryErr) {
        console.error("⚠️ Auto-Retry failed:", retryErr);
        // Fallback to normal success response if retry fails
        return res.json({ success: true, memory_deleted: true });
      }
    }

    res.json({ success: true });

  } catch (error) {
    console.error('Feedback API Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.post('/api/ask-ai', authenticateRequest, async (req, res) => {
  const { question, history = [], isRetry = false } = req.body;
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  try {
    const result = await AskController.processQuestion({
      userId,
      question,
      history,
      isRetry
    });

    res.json({
      tool: result.tool,
      answer: result.answer,
      memory_id: result.usedMemoryId,
      suggested_questions: result.suggestedQuestions
    });

  } catch (err) {
    console.error('AskController Error:', err);
    res.status(500).json({ error: 'Failed to process question' });
  }
});

// --- Auth Routes ---
const sanitizeRedirectPath = (value) => {
  if (typeof value !== 'string' || !value.trim()) return '/scan';
  if (!value.startsWith('/')) return '/scan';
  return value;
};

app.get('/auth/google', (req, res, next) => {
  const platform = req.query.platform || 'web';
  const redirect = req.query.redirect || '/scan';
  // Encode the platform and redirect in the 'state' parameter to survive the redirect
  const state = Buffer.from(JSON.stringify({ platform, redirect })).toString('base64');

  const authenticator = passport.authenticate('google', {
    scope: ['profile', 'email'],
    state: state, // Pass state to Google
    session: false // Disable session for the handshake to avoid cross-domain cookie blocks
  });

  authenticator(req, res, next);
});

app.get('/auth/google/callback',
  // Disable session creation for the callback, as we are using JWT tokens
  passport.authenticate('google', { failureRedirect: '/login', session: false }),
  (req, res) => {
    try {
      // Issue a JWT for the authenticated user
      const token = issueJwtForUser(req.user);

      let platform = 'web';
      let redirectPath = '/scan';
      // Decode the platform from the 'state' parameter returned by Google
      if (req.query.state) {
        try {
          const decodedState = JSON.parse(Buffer.from(req.query.state, 'base64').toString('ascii'));
          platform = decodedState.platform || 'web';
          redirectPath = decodedState.redirect || '/scan';
        } catch (e) {
          console.error("Error decoding state:", e);
        }
      }

      // ---------------------------------------
      // 📱 iOS FLOW → deep link
      // ---------------------------------------
      if (platform === "ios") {
        console.log(`📱 iOS platform detected. Redirecting to deep link with token.`);
        return res.redirect(`owlit://auth-callback?token=${token}`);
      }

      // ---------------------------------------
      // 💻 WEB FLOW → redirect to Vercel
      // ---------------------------------------
      console.log(`💻 Web platform detected. Redirecting to client URL.`);
      const redirectUrl = new URL(process.env.AUTH_CALLBACK_PATH || '/auth/callback', CLIENT_URL);
      redirectUrl.searchParams.set('token', token);
      redirectUrl.searchParams.set('redirect', redirectPath || '/scan'); // honor requested redirect

      return res.redirect(redirectUrl.toString());
    } catch (error) {
      console.error('Failed to issue JWT after Google OAuth:', error);
      return res.redirect(`${CLIENT_URL}/login?error=auth_failed`);
    }
  }
);


app.get('/api/user', authenticateRequest, async (req, res) => {
  try {
    // Basic user info from JWT
    const jwtUser = req.user;
    if (!jwtUser || !jwtUser.id) {
      return res.json(null);
    }

    // Fetch rich profile from Supabase
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', jwtUser.id)
      .single();

    if (error && error.code !== 'PGRST116') {
      console.error("Error fetching user profile:", error);
    }

    // Merge JWT info with Profile info (Profile takes precedence)
    const mergedUser = {
      ...jwtUser,
      ...(profile || {})
    };

    res.json(mergedUser);
  } catch (err) {
    console.error("Error in /api/user:", err);
    // Fallback to minimal user if DB fails
    res.json(req.user || null);
  }
});

app.post('/auth/logout', (req, res) => {
  if (req.session) {
    req.session.destroy(() => { });
  }
  res.json({ message: 'Logged out successfully' });
});

// --- Health Check ---
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'ReceiptWise server running' });
});

app.get('/api/store-info', optionalAuthenticate, async (req, res) => {
  const { data, error } = await supabase
    .from('store_info')
    .select('id, merchant_name, store_type')
    .order('merchant_name', { ascending: true });

  if (error) {
    console.error('Error fetching store info:', error);
    return res.status(500).json({ error: 'Failed to fetch store info' });
  }
  res.json(data);
});

// --- Receipt API Routes ---
app.get('/api/receipts', authenticateRequest, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('receipts')
      .select('*')
      .eq('user_id', req.user.id)
      .order('transaction_date', { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (error) {
    console.error('Error fetching receipts:', error);
    res.status(500).json({ error: 'Failed to fetch receipts' });
  }
});

app.post('/api/receipts', authenticateRequest, upload.single('receiptImage'), async (req, res) => {
  try {
    const payload = req.body?.receiptData;
    if (!payload) {
      throw new ValidationError('receiptData payload is required.');
    }

    const receiptData = safeJsonParse(payload, 'receiptData must be valid JSON.');
    const { merchant_name, transaction_date, total_amount, line_items } = receiptData;
    const normalizedTotalAmount = typeof total_amount === 'number' ? total_amount : Number(total_amount);

    validateFields({ merchant_name, total_amount: normalizedTotalAmount }, {
      merchant_name: { type: 'string', required: true, trim: true, maxLength: 255, message: 'merchant_name is required.' },
      total_amount: { type: 'number', required: true, min: 0 }
    });

    if (!transaction_date || Number.isNaN(Date.parse(transaction_date))) {
      throw new ValidationError('transaction_date must be a valid date string.');
    }

    validateLineItems(line_items);

    const normalizedTransactionDate = new Date(transaction_date).toISOString().split('T')[0];
    const familyId = await getUserFamilyId(req.user.id);
    const requestedReceiptId = req.body?.existingReceiptId;

    // If an existing receipt ID is provided, handle it as an update.
    if (requestedReceiptId) {
      let receipt_url = null;
      const { data: existingReceipt, error: fetchError } = await supabase
        .from('receipts')
        .select('id, receipt_url')
        .eq('user_id', req.user.id)
        .eq('id', requestedReceiptId)
        .single();

      if (fetchError || !existingReceipt) {
        return res.status(404).json({ error: 'The receipt you are trying to edit does not exist.' });
      }

      if (req.file) {
        if (!isSupportedUpload(req.file.mimetype)) {
          throw new ValidationError('Unsupported receipt image type.');
        }
        const receiptId = crypto.randomUUID();
        const extension = path.extname(req.file.originalname || '');
        const now = new Date();
        const time = now.toTimeString().split(' ')[0].replace(/:/g, '');
        const safeMerchant = merchant_name.replace(/[^a-z0-9-_]/gi, '_');
        const fileName = `${safeMerchant}-${normalizedTransactionDate}-${time}-${receiptId}${extension}`;

        const { error: uploadError } = await supabase.storage
          .from('receipts')
          .upload(fileName, req.file.buffer, {
            contentType: req.file.mimetype,
          });

        if (uploadError) {
          throw uploadError;
        }

        const { data: publicUrlData } = supabase.storage
          .from('receipts')
          .getPublicUrl(fileName);

        receipt_url = publicUrlData.publicUrl;
      }

      const { merchant_id: canonicalMerchantId, alias: merchantAlias } = await resolveMerchant(merchant_name || '', supabase);
      const finalReceiptUrl = receipt_url || existingReceipt.receipt_url;

      const { data: updatedData, error: updateError } = await supabase
        .from('receipts')
        .update({
          merchant_name,
          merchant_alias: merchantAlias,
          canonical_merchant_id: canonicalMerchantId,
          transaction_date: normalizedTransactionDate,
          total_amount: normalizedTotalAmount,
          line_items,
          receipt_url: finalReceiptUrl,
          family_id: familyId,
        })
        .eq('id', requestedReceiptId)
        .select()
        .single();

      if (updateError) {
        throw updateError;
      }

      return res.status(200).json(updatedData);
    }

    // --- Logic for creating a new receipt ---
    const dedupeHash = buildReceiptHash(req.user.id, {
      merchant_name,
      transaction_date: normalizedTransactionDate,
      total_amount: normalizedTotalAmount,
      line_items,
    });

    const { data: duplicateMatches, error: duplicateLookupError } = await supabase
      .from('receipts')
      .select('id')
      .eq('user_id', req.user.id)
      .like('receipt_hash', `${dedupeHash}%`);

    if (duplicateLookupError) {
      throw duplicateLookupError;
    }

    if (duplicateMatches && duplicateMatches.length > 0) {
      return res.status(409).json({
        error: 'This receipt already exists.',
        code: 'DUPLICATE_RECEIPT',
        existingReceiptId: duplicateMatches[0].id,
      });
    }

    // --- Loose Fingerprint (Soft Duplicate) Check ---
    const looseHash = buildLooseReceiptHash(req.user.id, {
      merchant_name,
      transaction_date: normalizedTransactionDate,
      total_amount: normalizedTotalAmount,
      line_items,
    });

    let isPotentialDuplicate = false;
    const { data: looseMatches } = await supabase
      .from('receipts')
      .select('id')
      .eq('user_id', req.user.id)
      .eq('receipt_fingerprint_loose', looseHash)
      .limit(1);

    if (looseMatches && looseMatches.length > 0) {
      console.log(`⚠️ Potential duplicate detected (loose match) for user ${req.user.id}`);
      isPotentialDuplicate = true;
    }
    // ------------------------------------------------

    let receipt_url = null;
    if (req.file) {
      if (!isSupportedUpload(req.file.mimetype)) {
        throw new ValidationError('Unsupported receipt image type.');
      }
      const receiptId = crypto.randomUUID();
      const extension = path.extname(req.file.originalname || '');
      const now = new Date();
      const time = now.toTimeString().split(' ')[0].replace(/:/g, '');
      const safeMerchant = merchant_name.replace(/[^a-z0-9-_]/gi, '_');
      const fileName = `${safeMerchant}-${normalizedTransactionDate}-${time}-${receiptId}${extension}`;

      const { error: uploadError } = await supabase.storage
        .from('receipts')
        .upload(fileName, req.file.buffer, {
          contentType: req.file.mimetype,
        });

      if (uploadError) {
        throw uploadError;
      }

      const { data: publicUrlData } = supabase.storage
        .from('receipts')
        .getPublicUrl(fileName);

      receipt_url = publicUrlData.publicUrl;
    }

    const { merchant_id: canonicalMerchantId, alias: merchantAlias } = await resolveMerchant(merchant_name || '', supabase);

    const { data, error } = await supabase
      .from('receipts')
      .insert({
        user_id: req.user.id,
        merchant_name,
        merchant_alias: merchantAlias,
        canonical_merchant_id: canonicalMerchantId,
        transaction_date: normalizedTransactionDate,
        total_amount: normalizedTotalAmount,
        line_items,
        receipt_url,
        receipt_hash: dedupeHash,
        receipt_fingerprint_loose: looseHash,
        is_potential_duplicate: isPotentialDuplicate,
        family_id: familyId,
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') { // unique constraint violation
        throw new ValidationError('Duplicate receipt detected for this account.', 409);
      }
      throw error;
    }
    res.status(201).json(data);
  } catch (error) {
    return handleApiError(res, error, 'Failed to save receipt');
  }
});

app.delete('/api/receipts', authenticateRequest, async (req, res) => {
  const receiptId = req.body?.id || req.query?.id;
  if (!receiptId) {
    return res.status(400).json({ error: 'Receipt id is required' });
  }

  try {
    const { data, error } = await supabase
      .from('receipts')
      .delete()
      .eq('id', receiptId)
      .eq('user_id', req.user.id)
      .select('id')
      .maybeSingle();

    if (error) throw error;
    if (!data) {
      return res.status(404).json({ error: 'Receipt not found' });
    }

    return res.json({ success: true });
  } catch (error) {
    return handleApiError(res, error, 'Failed to delete receipt');
  }
});

app.delete('/api/receipts/:id', authenticateRequest, async (req, res) => {
  const receiptId = req.params.id;
  if (!receiptId) {
    return res.status(400).json({ error: 'Receipt id is required' });
  }

  try {
    const { data, error } = await supabase
      .from('receipts')
      .delete()
      .eq('id', receiptId)
      .eq('user_id', req.user.id)
      .select('id')
      .maybeSingle();

    if (error) throw error;

    if (!data) {
      return res.status(404).json({ error: 'Receipt not found' });
    }

    return res.json({ success: true });
  } catch (error) {
    return handleApiError(res, error, 'Failed to delete receipt');
  }
});

// --- NEW ANALYTICS ENDPOINTS ---

// GET /api/merchants/resolve?name=Tesco
app.get('/api/merchants/resolve', authenticateRequest, async (req, res) => {
  const { name } = req.query;
  const userId = req.user.id;

  if (!name) return res.status(400).json({ error: "Missing 'name' parameter" });

  try {
    // Search for the most frequent merchant matching the input name for this user
    const query = `
      SELECT merchant_name, COUNT(*) as count
      FROM v_receipt_line_items_enriched
      WHERE user_id = $1 AND merchant_name ILIKE $2
      GROUP BY merchant_name
      ORDER BY count DESC
      LIMIT 1;
    `;
    const result = await pool.query(query, [userId, name]);

    if (result.rows.length > 0) {
      const bestName = result.rows[0].merchant_name;
      // Return structured result used by iOS app
      return res.json({ id: bestName, display_name: bestName });
    }

    // Fallback if not found
    return res.json({ id: name, display_name: name });

  } catch (err) {
    console.error("Error resolving merchant:", err);
    res.status(500).json({ error: "Database error" });
  }
});
// --- Merchant Insights Endpoint ---
app.get('/api/insights/merchant', authenticateRequest, async (req, res) => {
  const { merchant_name } = req.query;
  if (!merchant_name) return res.status(400).json({ error: 'Merchant name is required' });

  // Get User ID from your auth middleware
  const userId = req.user.id;

  // Decode and allow for simple fuzzy matching/names
  const merchantName = decodeURIComponent(merchant_name);

  try {
    // 1. Period Stats (This Month, Prev Month, This Year, Prev Year)
    // Uses Conditional Aggregation for efficiency (1 Query instead of 4)
    const statsQuery = `
      SELECT
        COALESCE(SUM(CASE WHEN transaction_date >= date_trunc('month', CURRENT_DATE) THEN total_price ELSE 0 END), 0) as this_month,
        COALESCE(SUM(CASE WHEN transaction_date >= date_trunc('month', CURRENT_DATE) - INTERVAL '1 month' AND transaction_date < date_trunc('month', CURRENT_DATE) THEN total_price ELSE 0 END), 0) as prev_month,
        COALESCE(SUM(CASE WHEN transaction_date >= date_trunc('year', CURRENT_DATE) THEN total_price ELSE 0 END), 0) as this_year,
        COALESCE(SUM(CASE WHEN transaction_date >= date_trunc('year', CURRENT_DATE) - INTERVAL '1 year' AND transaction_date < date_trunc('year', CURRENT_DATE) THEN total_price ELSE 0 END), 0) as prev_year
      FROM v_receipt_line_items_enriched
      WHERE user_id = $1
        AND merchant_name ILIKE $2
    `;

    // 2. Trend Graph (Weekly for last 12 weeks)
    const trendQuery = `
        SELECT
            date_trunc('week', transaction_date) as period_start,
            SUM(total_price) as total
        FROM v_receipt_line_items_enriched
        WHERE user_id = $1
          AND merchant_name ILIKE $2
          AND transaction_date >= CURRENT_DATE - INTERVAL '12 weeks'
        GROUP BY period_start
        ORDER BY period_start ASC
    `;

    // 3. Top Category (Highest Spend)
    const topCatQuery = `
      SELECT main_category, SUM(total_price) as spend
      FROM v_receipt_line_items_enriched
      WHERE user_id = $1 AND merchant_name ILIKE $2
      GROUP BY main_category
      ORDER BY spend DESC
      LIMIT 1
    `;

    // 4. Top Item (Most Frequent)
    const topItemQuery = `
      SELECT item, COUNT(*) as freq
      FROM v_receipt_line_items_enriched
      WHERE user_id = $1 AND merchant_name ILIKE $2
      GROUP BY item
      ORDER BY freq DESC
      LIMIT 1
    `;

    // 8. Store Main Category (General category for the merchant)
    const storeCatQuery = `
      SELECT store_main_category
      FROM v_receipt_line_items_enriched
      WHERE user_id = $1 AND merchant_name ILIKE $2
      LIMIT 1
    `;

    // 5. Health Score (Healthy vs Unhealthy Percentage)
    const healthQuery = `
      SELECT
        COUNT(CASE WHEN main_category IN ('fruit', 'vegetable', 'meat', 'poultry', 'seafood', 'dairy', 'health', 'fitness') THEN 1 END) as healthy_count,
        COUNT(CASE WHEN main_category IN ('snacks', 'beverages', 'alcohol', 'fast_food', 'dessert') THEN 1 END) as unhealthy_count
      FROM v_receipt_line_items_enriched
      WHERE user_id = $1 AND merchant_name ILIKE $2
    `;

    // [New] 6. Contribution Percentage (Merchant vs Total Spending this Month)
    // "How much of my monthly grocery budget goes to Tesco?"
    const contribQuery = `
      WITH monthly_totals AS (
          SELECT
              COALESCE(SUM(total_price), 0) AS total_spent
          FROM v_receipt_line_items_enriched
          WHERE user_id = $1
            AND transaction_date >= date_trunc('month', CURRENT_DATE)
            AND transaction_date <  date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
      ),
      merchant_month_totals AS (
          SELECT
              COALESCE(SUM(total_price), 0) AS merchant_spent
          FROM v_receipt_line_items_enriched
          WHERE user_id = $1
            AND merchant_name ILIKE $2  -- Dynamic merchant name
            AND transaction_date >= date_trunc('month', CURRENT_DATE)
            AND transaction_date <  date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
      )
      SELECT
          CASE 
            WHEN total_spent > 0 THEN ROUND((merchant_spent / total_spent) * 100, 2) 
            ELSE 0 
          END AS contribution_percentage
      FROM monthly_totals, merchant_month_totals;
    `;

    // [New] 7. Total Visit Count (This Month)
    // "How many times have I visited this store this month?"
    const visitQuery = `
        SELECT COUNT(DISTINCT receipt_id) AS visit_count
        FROM v_receipt_line_items_enriched
        WHERE user_id = $1 
          AND merchant_name ILIKE $2
          AND transaction_date >= date_trunc('month', CURRENT_DATE)
          AND transaction_date <  date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
    `;

    // Execute Parallel Queries
    const [statsRes, trendRes, topCatRes, topItemRes, healthRes, contribRes, visitRes, storeCatRes] = await Promise.all([
      pool.query(statsQuery, [userId, merchantName]),
      pool.query(trendQuery, [userId, merchantName]),
      pool.query(topCatQuery, [userId, merchantName]),
      pool.query(topItemQuery, [userId, merchantName]),
      pool.query(healthQuery, [userId, merchantName]),
      pool.query(contribQuery, [userId, merchantName]),
      pool.query(visitQuery, [userId, merchantName]),
      pool.query(storeCatQuery, [userId, merchantName])
    ]);

    // Extract Results
    const stats = statsRes.rows[0];
    const thisMonth = parseFloat(stats?.this_month || 0);
    const prevMonth = parseFloat(stats?.prev_month || 0);
    const thisYear = parseFloat(stats?.this_year || 0);
    const prevYear = parseFloat(stats?.prev_year || 0);

    // Calculate Percentage Changes (Handle division by zero)
    const monthChange = prevMonth > 0 ? ((thisMonth - prevMonth) / prevMonth) * 100 : (thisMonth > 0 ? 100 : 0);
    const yearChange = prevYear > 0 ? ((thisYear - prevYear) / prevYear) * 100 : (thisYear > 0 ? 100 : 0);

    // Trend
    const trendGraph = trendRes.rows.map(r => parseFloat(r.total));

    // Top Category
    const topCategory = topCatRes.rows[0]?.main_category || 'General';

    // Store Category
    const storeCategory = storeCatRes.rows[0]?.store_main_category || topCategory; // Fallback to top category

    // Top Item
    const topItem = topItemRes.rows[0]?.item || 'Unknown';

    // Health Score
    const hCount = parseInt(healthRes.rows[0]?.healthy_count || 0);
    const uCount = parseInt(healthRes.rows[0]?.unhealthy_count || 0);
    const totalHealth = hCount + uCount;
    const healthyPerc = totalHealth > 0 ? Math.round((hCount / totalHealth) * 100) : 100; // Default to 100% healthy if no data (optimistic)
    const unhealthyPerc = totalHealth > 0 ? Math.round((uCount / totalHealth) * 100) : 0;

    // Contribution & Visits
    const contributionPercentage = parseFloat(contribRes.rows[0]?.contribution_percentage || 0);
    const visitCount = parseInt(visitRes.rows[0]?.visit_count || 0);

    // Construct the Response
    res.json({
      merchant: merchantName,
      category: storeCategory,
      period_stats: {
        current_month: {
          total: thisMonth,
          percentage_change: monthChange
        },
        current_year: {
          total: thisYear,
          percentage_change: yearChange
        },
        previous_month: {
          total: prevMonth,
          percentage_change: null
        }
      },
      trend_graph: trendGraph,
      insights: {
        top_category: topCategory,
        top_item: topItem,
        health_score: {
          healthy_percentage: healthyPerc,
          unhealthy_percentage: unhealthyPerc
        },
        contribution_percentage: contributionPercentage,
        visit_count: visitCount
      }
    });

  } catch (error) {
    console.error('❌ Error fetching merchant insights:', error);
    res.status(500).json({ error: `Failed to fetch merchant insights: ${error.message}` });
  }
});

app.get('/api/family/status', authenticateRequest, async (req, res) => {
  try {
    const membership = await getUserFamilyMembership(req.user.id);
    if (!membership) {
      return res.json({ family: null, membership: null, members: [], invite: null });
    }

    const { data: family, error: familyError } = await supabase
      .from('families')
      .select('id, name, join_code, created_at, created_by')
      .eq('id', membership.family_id)
      .maybeSingle();
    if (familyError) throw familyError;

    const { data: members, error: membersError } = await supabase
      .from('family_members')
      .select('user_id, role, created_at, member_name, member_email')
      .eq('family_id', membership.family_id);
    if (membersError) throw membersError;

    // Ensure current user's name/email are stored
    const selfEntry = (members || []).find((m) => m.user_id === req.user.id);
    const desiredName =
      `${req.user.firstName || ''} ${req.user.lastName || ''}`.trim() ||
      req.user.displayName ||
      req.user.name ||
      null;
    const desiredEmail = req.user.email || null;
    if (selfEntry && (!selfEntry.member_name || !selfEntry.member_email) && (desiredName || desiredEmail)) {
      await supabase
        .from('family_members')
        .update({
          member_name: selfEntry.member_name || desiredName,
          member_email: selfEntry.member_email || desiredEmail,
        })
        .eq('family_id', membership.family_id)
        .eq('user_id', req.user.id);
      if (selfEntry && desiredName && !selfEntry.member_name) {
        selfEntry.member_name = desiredName;
      }
      if (selfEntry && desiredEmail && !selfEntry.member_email) {
        selfEntry.member_email = desiredEmail;
      }
    }

    const enrichedMembers = (members || []).map((m) => ({
      ...m,
      member_name:
        m.member_name ||
        (m.user_id === req.user.id
          ? (`${req.user.firstName || ''} ${req.user.lastName || ''}`.trim() ||
            req.user.displayName ||
            req.user.name ||
            null)
          : null),
      member_email: m.member_email || (m.user_id === req.user.id ? (req.user.email || null) : null),
    }));

    const { data: invites, error: inviteError } = await supabase
      .from('family_invites')
      .select('code, expires_at, max_uses, used_count, status, created_at')
      .eq('family_id', membership.family_id)
      .order('created_at', { ascending: false })
      .limit(5);
    if (inviteError) throw inviteError;

    const invite = selectActiveInvite(invites || []);

    return res.json({
      family,
      membership,
      members: enrichedMembers,
      invite: invite || null,
    });
  } catch (error) {
    return handleApiError(res, error, 'Failed to load family status.');
  }
});

const generateUniqueInviteCode = async () => {
  for (let i = 0; i < 5; i++) {
    const code = generateJoinCode();
    const { data: inviteHit, error: inviteError } = await supabase
      .from('family_invites')
      .select('code')
      .eq('code', code)
      .maybeSingle();
    if (inviteError) throw inviteError;

    const { data: familyHit, error: familyError } = await supabase
      .from('families')
      .select('id')
      .eq('join_code', code)
      .maybeSingle();
    if (familyError) throw familyError;

    if (!inviteHit && !familyHit) {
      return code;
    }
  }
  throw new Error('Failed to generate a unique invite code.');
};

app.post('/api/family', authenticateRequest, async (req, res) => {
  try {
    const nameRaw = req.body?.name;
    const name = typeof nameRaw === 'string' ? nameRaw.trim() : '';
    if (!name) {
      throw new ValidationError('Family name is required.');
    }

    const existingMembership = await getUserFamilyMembership(req.user.id);
    if (existingMembership) {
      return res
        .status(409)
        .json({ error: 'You already belong to a family. Leave it before creating another.' });
    }

    const joinCode = await generateUniqueInviteCode();
    const { data: family, error: familyError } = await supabase
      .from('families')
      .insert({
        name,
        created_by: req.user.id,
        join_code: joinCode,
      })
      .select()
      .single();

    if (familyError) throw familyError;

    const { error: membershipError } = await supabase
      .from('family_members')
      .insert({
        family_id: family.id,
        user_id: req.user.id,
        role: 'owner',
        member_name: `${req.user.firstName || ''} ${req.user.lastName || ''}`.trim() || req.user.displayName || req.user.name || null,
        member_email: req.user.email || null,
      });
    if (membershipError) throw membershipError;

    const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();
    const { error: inviteError } = await supabase
      .from('family_invites')
      .insert({
        code: joinCode,
        family_id: family.id,
        created_by: req.user.id,
        expires_at: expiresAt,
        status: 'active',
      });
    if (inviteError) throw inviteError;

    await assignUserReceiptsToFamily(req.user.id, family.id);

    return res.status(201).json({ family, invite: { code: joinCode, expires_at: expiresAt } });
  } catch (error) {
    return handleApiError(res, error, 'Failed to create family.');
  }
});

app.post('/api/family/invite', authenticateRequest, async (req, res) => {
  try {
    const membership = await getUserFamilyMembership(req.user.id);
    if (!membership) {
      throw new ValidationError('Join or create a family before generating an invite code.');
    }

    const joinCode = await generateUniqueInviteCode();
    const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();

    const { error: inviteError, data: inviteRow } = await supabase
      .from('family_invites')
      .insert({
        code: joinCode,
        family_id: membership.family_id,
        created_by: req.user.id,
        expires_at: expiresAt,
        status: 'active',
      })
      .select()
      .single();
    if (inviteError) throw inviteError;

    const { error: familyUpdateError } = await supabase
      .from('families')
      .update({ join_code: joinCode })
      .eq('id', membership.family_id);
    if (familyUpdateError) throw familyUpdateError;

    return res.status(201).json({ invite: inviteRow });
  } catch (error) {
    return handleApiError(res, error, 'Failed to generate invite code.');
  }
});

app.post('/api/family/join', authenticateRequest, async (req, res) => {
  try {
    const rawCode = req.body?.code || '';
    const code = rawCode.trim().toUpperCase();
    if (!code) {
      throw new ValidationError('Join code is required.');
    }

    const existingMembership = await getUserFamilyMembership(req.user.id);
    if (existingMembership) {
      return res
        .status(409)
        .json({ error: 'You already belong to a family. Leave it before joining another.' });
    }

    const { data: invites, error: inviteError } = await supabase
      .from('family_invites')
      .select('code, family_id, expires_at, max_uses, used_count, status')
      .eq('code', code)
      .limit(1);
    if (inviteError) throw inviteError;

    const invite = invites?.[0] || null;
    if (!invite) {
      return res.status(404).json({ error: 'Invite code not found.' });
    }

    const activeInvite = selectActiveInvite([invite]);
    if (!activeInvite) {
      return res.status(410).json({ error: 'This invite code is expired or inactive.' });
    }

    const { data: family, error: familyError } = await supabase
      .from('families')
      .select('id, name, join_code')
      .eq('id', invite.family_id)
      .maybeSingle();
    if (familyError) throw familyError;
    if (!family) {
      return res.status(404).json({ error: 'Family not found for this invite code.' });
    }

    const { error: membershipError } = await supabase
      .from('family_members')
      .insert({
        family_id: family.id,
        user_id: req.user.id,
        role: 'member',
        member_name: `${req.user.firstName || ''} ${req.user.lastName || ''}`.trim() || req.user.displayName || req.user.name || null,
        member_email: req.user.email || null,
      });
    if (membershipError) {
      if (membershipError.code === '23505') {
        return res.status(409).json({ error: 'You are already a member of a family.' });
      }
      throw membershipError;
    }

    await assignUserReceiptsToFamily(req.user.id, family.id);

    const usedCount = (invite.used_count || 0) + 1;
    const updates = { used_count: usedCount };
    if (invite.max_uses != null && usedCount >= invite.max_uses) {
      updates.status = 'expired';
    }
    const { error: updateInviteError } = await supabase
      .from('family_invites')
      .update(updates)
      .eq('code', invite.code);
    if (updateInviteError) throw updateInviteError;

    return res.json({ family, membership: { family_id: family.id, role: 'member' } });
  } catch (error) {
    return handleApiError(res, error, 'Failed to join family.');
  }
});

app.post('/api/family/leave', authenticateRequest, async (req, res) => {
  try {
    const membership = await getUserFamilyMembership(req.user.id);
    if (!membership) {
      return res.status(400).json({ error: 'You are not part of a family.' });
    }

    // Remove member from family
    const { error } = await supabase
      .from('family_members')
      .delete()
      .eq('family_id', membership.family_id)
      .eq('user_id', req.user.id);
    if (error) throw error;

    // Detach this user's receipts from the family
    const { error: receiptsError } = await supabase
      .from('receipts')
      .update({ family_id: null })
      .eq('family_id', membership.family_id)
      .eq('user_id', req.user.id);
    if (receiptsError) throw receiptsError;

    return res.json({ success: true });
  } catch (error) {
    return handleApiError(res, error, 'Failed to leave family.');
  }
});

app.get('/api/family/receipts', authenticateRequest, async (req, res) => {
  try {
    const membership = await getUserFamilyMembership(req.user.id);
    if (!membership) {
      return res
        .status(403)
        .json({ error: 'Join or create a family to view family receipts.' });
    }

    const { data: members, error: membersError } = await supabase
      .from('family_members')
      .select('user_id')
      .eq('family_id', membership.family_id);
    if (membersError) throw membersError;
    const memberIds = (members || []).map((m) => m.user_id).filter(Boolean);

    const { data: familyReceipts, error: familyError } = await supabase
      .from('receipts')
      .select('*')
      .eq('family_id', membership.family_id)
      .order('transaction_date', { ascending: true });
    if (familyError) throw familyError;

    let orphanReceipts = [];
    if (memberIds.length) {
      const { data: orphans, error: orphanError } = await supabase
        .from('receipts')
        .select('*')
        .is('family_id', null)
        .in('user_id', memberIds)
        .order('transaction_date', { ascending: true });
      if (orphanError) throw orphanError;
      orphanReceipts = orphans || [];

      if (orphanReceipts.length) {
        const orphanIds = orphanReceipts.map((r) => r.id);
        await supabase
          .from('receipts')
          .update({ family_id: membership.family_id })
          .in('id', orphanIds);
        // mark them in the response as part of the family to avoid reassign in subsequent calls
        orphanReceipts = orphanReceipts.map((r) => ({ ...r, family_id: membership.family_id }));
      }
    }

    // Deduplicate by receipt id in case of overlap
    const dedupMap = new Map();
    [...(familyReceipts || []), ...orphanReceipts].forEach((r) => {
      if (!dedupMap.has(r.id)) dedupMap.set(r.id, r);
    });

    return res.json({ receipts: Array.from(dedupMap.values()), familyId: membership.family_id });
  } catch (error) {
    return handleApiError(res, error, 'Failed to load family receipts.');
  }
});



app.post('/api/merchant-aliases', authenticateRequest, async (req, res) => {
  try {
    const { alias, merchant_id } = req.body || {};
    validateFields({ alias, merchant_id }, {
      alias: { type: 'string', required: true, trim: true, maxLength: 255, message: 'alias is required.' },
      merchant_id: { type: 'string', required: true, trim: true, maxLength: 255, message: 'merchant_id is required.' }
    });

    const { data, error } = await supabase
      .from('merchant_aliases')
      .insert({ alias, merchant_id })
      .select();

    if (error) {
      throw error;
    }

    res.status(201).json(data?.[0] || null);
  } catch (error) {
    return handleApiError(res, error, 'Failed to save merchant alias');
  }
});

app.post('/api/update-user-category', authenticateRequest, async (req, res) => {
  try {
    const { item_name, main_category, sub_category } = req.body || {};
    validateFields({ item_name, main_category, sub_category }, {
      item_name: { type: 'string', required: true, trim: true, maxLength: 255, message: 'item_name is required.' },
      main_category: { type: 'string', required: true, trim: true, maxLength: 255 },
      sub_category: { type: 'string', required: true, trim: true, maxLength: 255 }
    });
    const normalizedItemName = item_name.trim().toLowerCase();

    const { error } = await supabase
      .from('user_categories')
      .upsert(
        { user_id: req.user.id, item_name: normalizedItemName, main_category, sub_category },
        { onConflict: 'user_id,item_name' }
      );

    if (error) {
      throw error;
    }

    console.log(`✨ Saved user-specific override: ${item_name} → ${main_category}/${sub_category}`);
    res.json({ success: true });

  } catch (error) {
    return handleApiError(res, error, 'Failed to update user category');
  }
});

app.get('/api/user-categories', authenticateRequest, async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('user_categories')
      .select('main_category, sub_category')
      .eq('user_id', req.user.id);

    if (error) {
      throw error;
    }

    res.json(Array.isArray(data) ? data : []);
  } catch (error) {
    return handleApiError(res, error, 'Failed to load user categories');
  }
});

app.get('/api/category-options', authenticateRequest, async (req, res) => {
  try {
    const userId = req.user.id;

    const userPromise = supabase
      .from('user_categories')
      .select('main_category, sub_category')
      .eq('user_id', userId);

    const masterPromise = supabase
      .from('master_items')
      .select('main_category, sub_category');

    const [{ data: userData, error: userError }, { data: masterData, error: masterError }] = await Promise.all([
      userPromise,
      masterPromise,
    ]);

    if (userError) throw userError;
    if (masterError) throw masterError;

    res.json({
      userCategories: Array.isArray(userData) ? userData : [],
      masterCategories: Array.isArray(masterData) ? masterData : [],
    });
  } catch (error) {
    return handleApiError(res, error, 'Failed to load category options');
  }
});

app.post('/api/reset-user-category', authenticateRequest, async (req, res) => {
  try {
    const { item_name } = req.body || {};
    validateFields({ item_name }, {
      item_name: { type: 'string', required: true, trim: true, maxLength: 255, message: 'item_name is required.' }
    });

    await supabase
      .from('user_categories')
      .delete()
      .eq('user_id', req.user.id)
      .eq('item_name', item_name);

    console.log(`🔄 Reset override for: ${item_name}`);
    res.json({ success: true });

  } catch (error) {
    return handleApiError(res, error, 'Failed to reset category');
  }
});

app.post('/api/user-store-type-overrides', authenticateRequest, async (req, res) => {
  const userId = req.user.id;

  try {
    const { merchant_name, store_type } = req.body || {};
    validateFields({ merchant_name, store_type }, {
      merchant_name: { type: 'string', required: true, trim: true, maxLength: 255, message: 'merchant_name is required.' },
      store_type: { type: 'string', required: true, trim: true, maxLength: 255, message: 'store_type is required.' }
    });

    const normalizedMerchant = normalizeMerchantKey(merchant_name);
    const trimmedStoreType = typeof store_type === 'string' ? store_type.trim() : '';

    if (!normalizedMerchant) {
      throw new ValidationError('merchant_name is required.');
    }
    if (!trimmedStoreType) {
      throw new ValidationError('store_type is required.');
    }

    const { error } = await supabase
      .from('user_store_type_overrides')
      .upsert({
        user_id: userId,
        merchant_name: normalizedMerchant,
        store_type: trimmedStoreType
      }, { onConflict: 'user_id,merchant_name' });

    if (error) {
      throw error;
    }

    res.json({ success: true, message: 'Store type override saved.' });
  } catch (error) {
    return handleApiError(res, error, 'Failed to save store type override');
  }
});

app.get('/api/user-store-type-overrides', authenticateRequest, async (req, res) => {
  const userId = req.user.id;

  try {
    const { data, error } = await supabase
      .from('user_store_type_overrides')
      .select('merchant_name, store_type')
      .eq('user_id', userId);

    if (error) {
      throw error;
    }

    const overrides = data.reduce((acc, row) => {
      const normalized = normalizeMerchantKey(row.merchant_name);
      if (normalized) {
        acc[normalized] = row.store_type;
      }
      return acc;
    }, {});

    res.json(overrides);
  } catch (error) {
    console.error('Error fetching store type overrides:', error);
    res.status(500).json({ error: 'Failed to fetch store type overrides' });
  }
});

// --- Ask AI endpoint ---
// [DUPLICATE ROUTE DELETED]


// --- Line Item Inputs for Client-Side (Optional use) ---
app.get('/api/insights/line-items', authenticateRequest, async (req, res) => {
  const { merchant_id } = req.query;
  const userId = req.user.id;

  if (!merchant_id) return res.status(400).json({ error: "Missing 'merchant_id'" });

  try {
    const query = `
      SELECT 
        transaction_date, 
        merchant_name,
        item,
        unit_price,
        quantity,
        total_price, 
        main_category,
        sub_category
      FROM v_receipt_line_items_enriched
      WHERE user_id = $1 AND merchant_name ILIKE $2
      ORDER BY transaction_date DESC;
    `;
    const result = await pool.query(query, [userId, merchant_id]);

    // Remap for frontend compatibility if needed, or rely on CodingKeys
    // Frontend expects: price (unit), totalPrice
    const mapped = result.rows.map(row => ({
      ...row,
      price: row.unit_price // Alias unit_price to price for frontend
    }));

    res.json(mapped);
  } catch (error) {
    console.error('Error fetching insight line items:', error);
    res.status(500).json({ error: 'Failed to fetch line items.' });
  }
});

// --- Analytics: All Line Items (Enriched) ---
app.get('/api/analytics/line-items', authenticateRequest, async (req, res) => {
  const userId = req.user.id;
  try {
    const query = `
      SELECT 
        transaction_date, 
        merchant_name,
        item,
        normalized_name,
        unit_price,
        quantity,
        total_price, 
        main_category,
        sub_category,
        store_type
      FROM v_receipt_line_items_enriched
      WHERE user_id = $1
      ORDER BY transaction_date DESC;
    `;
    const result = await pool.query(query, [userId]);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching analytics line items:', error);
    res.status(500).json({ error: 'Failed to fetch analytics data.' });
  }
});

// --- Start Server ---
app.listen(port, async () => {
  console.log('🟢 Server starting...');
  try {
    await loadMasterItems();
  } catch (err) {
    console.error('❌ Failed to load master items:', err);
  }
  console.log(`🚀 Server listening at http://localhost:${port}`);
  console.log('📦 Current Master Items:', masterItems);
});
