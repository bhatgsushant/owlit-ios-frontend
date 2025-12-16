import React, { useState, useRef, useEffect, useCallback, useMemo } from 'react';
import Lottie from 'lottie-react';
import { useNavigate, useLocation } from 'react-router-dom';

import {
  Upload,
  Camera,
  FileText,
  X,
  CheckCircle,
  Save,
  Mic,
  Edit,
  PlusCircle,
  Store,
  Calendar,
  Tag,
  Apple,
  Sprout,
  Drumstick,
  Fish,
  CupSoda,
  Droplet,
  Snowflake,
  Package,
  PoundSterling,
  Coffee,
  Fuel,
  Sparkles,
  HeartPulse,
  Dumbbell,
  Home,
  Cpu,
  Plug,
  Shirt,
  Gem,
  Car,
  Plane,
  PenLine,
  GraduationCap,
  Wallet,
  Clapperboard,
  PawPrint,
  Gift,
  UtensilsCrossed,
  CircleEllipsis,
  Loader2,
  Wrench,
  Trash2,
} from 'lucide-react';
import CameraView from '../components/CameraView';
import { SUB_CATEGORIES } from '../utils/categorize';
import SearchableDropdown from '../components/ui/SearchableDropdown';
import MerchantLogo from '../components/ui/MerchantLogo';
import VoiceInput from '../components/ui/VoiceInput';
import { useAuth } from '@/hooks/useAuth';
import { STORE_DATA, getStoreInfo } from '../utils/logo';
import { cn } from '@/lib/utils';
import { createPageUrl } from '@/utils';
import leafsBlowAnimationUrl from '/images/Leafsblow.json?url';

const PENDING_PREVIEW_STORAGE_KEY = 'pending-receipt-preview';
const RESUME_QUERY_PARAM = 'resume';

const normalizeMerchantName = (name = '') =>
  name
    .toLowerCase()
    .normalize('NFKD')
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9 -]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/(?:^|[\s])\w/g, c => c.toUpperCase());

const useIsMobile = (breakpoint = 768) => {
  const [isMobile, setIsMobile] = useState(false);
  useEffect(() => {
    const check = () => setIsMobile(typeof window !== 'undefined' ? window.innerWidth <= breakpoint : false);
    check();
    window.addEventListener('resize', check);
    return () => window.removeEventListener('resize', check);
  }, [breakpoint]);
  return isMobile;
};

const DEFAULT_CATEGORY_KEYS = Object.keys(SUB_CATEGORIES);
const DEFAULT_CATEGORY_SET = new Set(DEFAULT_CATEGORY_KEYS.map((c) => c.toLowerCase()));
const DEFAULT_SUBCATEGORY_SET = Object.fromEntries(
  Object.entries(SUB_CATEGORIES).map(([cat, subs]) => [cat.toLowerCase(), new Set(subs.map((s) => s.toLowerCase()))])
);

const parseNumberValue = (value) => {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  if (typeof value !== 'string') return 0;
  const sanitized = value.replace(/,/g, '').replace(/[^\d.-]/g, '');
  const parsed = parseFloat(sanitized);
  return Number.isFinite(parsed) ? parsed : 0;
};

const CATEGORY_ICON_MAP = {
  fruit: Apple,
  vegetable: Sprout,
  meat: Drumstick,
  poultry: Drumstick,
  seafood: Fish,
  dairy: Droplet,
  bakery: Package,
  beverages: CupSoda,
  snacks: Package,
  frozen: Snowflake,
  canned_goods: Package,
  personal_care: Sparkles,
  health: HeartPulse,
  fitness: Dumbbell,
  household: Home,
  electronics: Cpu,
  utilities: Plug,
  clothing: Shirt,
  jewelry: Gem,
  transport: Car,
  travel: Plane,
  stationery: PenLine,
  education: GraduationCap,
  finance: Wallet,
  entertainment: Clapperboard,
  pets: PawPrint,
  gifts: Gift,
  dining: UtensilsCrossed,
  other: CircleEllipsis,
};

const getCategoryIconComponent = (category) => {
  if (!category) return Tag;
  const key = String(category).toLowerCase();
  return CATEGORY_ICON_MAP[key] || Tag;
};

const CATEGORY_COLOR_MAP = {
  fruit: '#f97316',
  vegetable: '#22c55e',
  meat: '#ef4444',
  poultry: '#f97316',
  seafood: '#0ea5e9',
  dairy: '#a855f7',
  bakery: '#f59e0b',
  beverages: '#0ea5e9',
  snacks: '#f59e0b',
  frozen: '#6366f1',
  canned_goods: '#22c55e',
  personal_care: '#ec4899',
  health: '#06b6d4',
  fitness: '#22c55e',
  household: '#94a3b8',
  electronics: '#3b82f6',
  utilities: '#14b8a6',
  clothing: '#f472b6',
  jewelry: '#facc15',
  transport: '#64748b',
  travel: '#22c55e',
  stationery: '#06b6d4',
  education: '#8b5cf6',
  finance: '#10b981',
  entertainment: '#f43f5e',
  pets: '#22c55e',
  gifts: '#f472b6',
  dining: '#f97316',
  other: '#22c55e',
};

const getCategoryColor = (category) => CATEGORY_COLOR_MAP[String(category || '').toLowerCase()] || '#10b981';

const SUBCATEGORY_ICON_MATCHERS = [
  // Food & Drinks
  { test: /(coffee|tea|drink|juice|smoothie)/i, icon: Coffee },
  { test: /(beer|wine|spirits|vodka|whiskey|liquor|alcohol)/i, icon: CupSoda },
  { test: /(restaurant|takeaway|fast[_ ]?food|pub|bar|diner|cafe)/i, icon: UtensilsCrossed },
  { test: /(bread|pastr|cake|cookie|muffin|bakery)/i, icon: Package },
  { test: /(milk|cheese|yogurt|butter|cream|egg|dairy)/i, icon: Droplet },
  { test: /(fish|seafood|prawn|shrimp|salmon|tuna)/i, icon: Fish },
  { test: /(fruit|apple|banana|grape|melon|berry|citrus)/i, icon: Apple },
  { test: /(vegetable|greens|onion|tomato|pepper|carrot|broccoli)/i, icon: Sprout },
  { test: /(meat|beef|pork|lamb|steak)/i, icon: Drumstick },
  { test: /(chicken|turkey|duck|poultry)/i, icon: Drumstick },

  // Groceries & Household
  { test: /(laundry|cleaning|detergent|soap|bleach|dish)/i, icon: Sparkles },
  { test: /(toilet|tissue|paper[_ ]?towel|napkin)/i, icon: Package },
  { test: /(beauty|cosmetic|makeup|skincare|lotion)/i, icon: Sparkles },
  { test: /(hair|shampoo|conditioner|barber|salon)/i, icon: Sparkles },

  // Health
  { test: /(medicine|vitamin|pain|supplement|pharmacy|healthcare)/i, icon: HeartPulse },
  { test: /(doctor|clinic|hospital|dentist|therapy)/i, icon: HeartPulse },

  // Fitness
  { test: /(gym|fitness|protein|workout|sport|exercise)/i, icon: Dumbbell },

  // Utilities
  { test: /(electricity|internet|water|bill|utility|gas[_ ]?bill)/i, icon: Plug },
  { test: /(fuel|gas|diesel|petrol)/i, icon: Fuel },

  // Shopping
  { test: /(shoe|shirt|jean|dress|clothing|sock|apparel|fashion)/i, icon: Shirt },
  { test: /(jewel|ring|necklace|bracelet|watch)/i, icon: Gem },
  { test: /(toy|lego|board[_ ]?game|kids|baby)/i, icon: Gift },
  { test: /(furniture|sofa|table|chair|bed|desk)/i, icon: Package },
  { test: /(decor|home[_ ]?decor|frame|vase|art)/i, icon: Package },

  // Electronics & Tech
  { test: /(electronics|charger|laptop|mobile|battery|phone|tablet|computer)/i, icon: Cpu },
  { test: /(software|subscription|cloud|saas|app)/i, icon: Cpu },

  // Transport
  { test: /(bus|train|taxi|uber|lyft|parking|transport|toll)/i, icon: Car },
  { test: /(fuel|gas|diesel|petrol)/i, icon: Fuel }, // duplicate kept for clarity

  // Travel
  { test: /(flight|hotel|visa|tour|luggage|airbnb|travel)/i, icon: Plane },

  // Office & Education
  { test: /(pen|notebook|paper|folder|stationery)/i, icon: PenLine },
  { test: /(book|course|tuition|school|education|class)/i, icon: GraduationCap },

  // Finance
  { test: /(bank|fee|insurance|loan|interest|tax|finance)/i, icon: Wallet },

  // Entertainment
  { test: /(movie|music|game|event|concert|stream|theater)/i, icon: Clapperboard },

  // Pets
  { test: /(pet|vet|groom|petfood|animal)/i, icon: PawPrint },

  // Gifts & Charity
  { test: /(gift|donation|charity|present)/i, icon: Gift },

  // Home & Maintenance
  { test: /(repair|maintenance|plumber|electrician|handyman)/i, icon: Wrench },
  { test: /(garden|plants|soil|flowers|seed)/i, icon: Sprout },

  // Miscellaneous
  { test: /(subscription|membership|service)/i, icon: Wallet },
  { test: /(shipping|delivery|courier)/i, icon: Package },
];


const getSubcategoryIconComponent = (subCategory) => {
  if (!subCategory) return Tag;
  const key = String(subCategory).toLowerCase();
  for (const matcher of SUBCATEGORY_ICON_MATCHERS) {
    if (matcher.test instanceof RegExp) {
      if (matcher.test.test(key)) {
        return matcher.icon;
      }
    } else if (typeof matcher.test === 'function') {
      if (matcher.test(key)) {
        return matcher.icon;
      }
    }
  }
  return Tag;
};

const SUBCATEGORY_COLOR_MAP = {
  coffee: '#f97316',
  tea: '#f59e0b',
  drink: '#0ea5e9',
  beer: '#f59e0b',
  wine: '#a855f7',
  spirits: '#7c3aed',
  fuel: '#ef4444',
  gas: '#ef4444',
  diesel: '#ef4444',
  bread: '#f97316',
  milk: '#22c55e',
  cheese: '#facc15',
  fish: '#0ea5e9',
  seafood: '#0ea5e9',
  vegetable: '#22c55e',
  meat: '#ef4444',
  chicken: '#f97316',
  laundry: '#38bdf8',
  medicine: '#ec4899',
  gym: '#22c55e',
  electronics: '#3b82f6',
  electricity: '#facc15',
  shoe: '#f472b6',
  jewel: '#facc15',
  bus: '#64748b',
  flight: '#22c55e',
  pen: '#06b6d4',
  book: '#8b5cf6',
  bank: '#10b981',
  movie: '#f43f5e',
  pet: '#22c55e',
  gift: '#f472b6',
  restaurant: '#f97316',
};

const getSubcategoryColor = (subCategory) => {
  const key = String(subCategory || '').toLowerCase();
  const entry = Object.entries(SUBCATEGORY_COLOR_MAP).find(([slug]) => key.includes(slug));
  return entry ? entry[1] : '#38bdf8';
};

const formatLineItemsForEditor = (lineItems = []) =>
  lineItems.map((entry) => ({
    ...entry,
    price:
      entry && entry.price !== undefined && entry.price !== null
        ? String(entry.price)
        : '',
  }));

const sanitizeLineItemsForSave = (lineItems = []) =>
  lineItems.map((entry) => {
    const price = parseNumberValue(entry.price);
    const quantity = parseNumberValue(entry.quantity);
    return {
      ...entry,
      price,
      quantity: Number.isFinite(quantity) && quantity > 0 ? quantity : 0,
    };
  });

function ScanModeToggle({ mode, setMode }) {
  return (
    <div className="flex justify-center mb-4">
      <div className="bg-white/10 backdrop-blur-md p-1 rounded-full flex items-center border border-white/20">
        <button onClick={() => setMode('receipt')} className={`px-4 py-2 text-sm font-semibold rounded-full transition-colors ${mode === 'receipt' ? 'bg-green-500 text-white' : 'text-gray-200 hover:bg-white/10'}`}>
          Scan Receipt
        </button>
      </div>
    </div>
  );
}

function ActionButton({ onClick, icon: Icon, text, isActive }) {
  const baseClasses = "w-full flex items-center justify-center py-2 px-4 rounded-full font-semibold text-sm shadow-lg transition-all duration-300 backdrop-blur-md border font-playfair";
  const activeClasses = "bg-green-500 text-white border-transparent";
  const inactiveClasses = "bg-white/10 border-white/20 text-white hover:bg-white/20";
  return (
    <button onClick={onClick} className={`${baseClasses} ${isActive ? activeClasses : inactiveClasses}`}>
      <Icon size={16} className="mr-2" />
      {text}
    </button>
  );
}

function DocumentPreview({ markdown, onApprove, onCancel }) {
  return (
    <div className="font-playfair bg-white text-white backdrop-blur-2xl rounded-[14px] p-6 w-full text-left shadow-2xl border border-white/20 document-preview">
      <div className="flex justify-between items-start mb-4">
        <h2 className="font-bold text-xl leading-[1.3] text-white">Extracted Document</h2>
        <span className="bg-white/20 text-white font-semibold text-xs leading-[1.4] px-2.5 py-1 rounded-full">Preview</span>
      </div>
      <div className="space-y-4 text-base font-normal leading-[1.6] max-h-96 overflow-y-auto pr-2 text-white" style={{ scrollbarWidth: 'thin', scrollbarColor: '#e2e8f0 #0f172a' }}>
        {markdown.split('\n').map((p, i) => <p key={i}>{p}</p>)}
      </div>
      <div className="flex gap-4 mt-8">
        <button
          onClick={onApprove}
          className="w-full bg-green-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-green-700 transition-all duration-300 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-opacity-50 flex items-center justify-center"
        >
          <CheckCircle size={20} className="mr-2" />
          <span className="text-white">Approve & Save</span>
        </button>
        <button
          onClick={onCancel}
          className="w-full bg-red-600 text-white py-3 px-6 rounded-lg font-semibold hover:bg-red-700 transition-all duration-300 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-opacity-50 flex items-center justify-center"
        >
          <X size={20} className="mr-2" />
          <span className="text-white">Discard</span>
        </button>
      </div>
    </div>
  );
}

const InputWithIcon = ({
  icon: IconComponent,
  value,
  onChange,
  type = 'text',
  placeholder,
  iconClassName = 'text-gray-500 dark:text-gray-300',
  inputClassName = 'text-sm',
  ...rest
}) => {
  const displayValue = value === null || value === undefined ? '' : value;
  return (
    <div className="w-full">
      <div className="flex flex-wrap items-center gap-3 rounded-full bg-gray-100 dark:bg-gray-700 px-4 py-2 border border-transparent focus-within:border-green-500 focus-within:ring-2 focus-within:ring-green-500/20 transition">
        <IconComponent className={cn('h-4 w-4', iconClassName)} />
        <input
          type={type}
          value={displayValue}
          onChange={onChange}
          placeholder={placeholder}
          aria-label={placeholder}
          className={cn('flex-1 min-w-0 bg-transparent border-none focus:outline-none text-gray-900 dark:text-gray-100', inputClassName)}
          {...rest}
        />
      </div>
    </div>
  );
};

const LineItemRow = React.memo(({
  item,
  index,
  mainCategoryOptions,
  subCategoryOptionsMap,
  handleLineItemChange,
  removeLineItem,
  setMainCategoryOptions,
  setSubCategoryOptionsMap,
  saveUserCategoryPreference,
  userMainSet,
  masterMainSet,
  userSubMap,
  masterSubMap,
}) => {
  const mainKey = String(item.main_category || '');
  const lowerKey = mainKey.toLowerCase();
  const subCategoryOptions =
    subCategoryOptionsMap[mainKey] ||
    subCategoryOptionsMap[lowerKey] ||
    [];
  const CategoryIconComponent = getCategoryIconComponent(item.main_category);
  const SubcategoryIconComponent = getSubcategoryIconComponent(item.sub_category);
  const categoryColor = getCategoryColor(item.main_category);
  const subcategoryColor = getSubcategoryColor(item.sub_category);

  const orderedMainCategories = useMemo(() => {
    const userMains = Array.from(userMainSet || []);
    const masterMains = Array.from(masterMainSet || []);
    const defaults = DEFAULT_CATEGORY_KEYS;
    const customs = (mainCategoryOptions || []).filter(
      (c) => !DEFAULT_CATEGORY_SET.has(String(c || '').toLowerCase())
    );
    const combined = [...userMains, ...masterMains, ...defaults, ...customs];
    return combined.filter(
      (c, idx) => combined.findIndex((x) => String(x || '').toLowerCase() === String(c || '').toLowerCase()) === idx
    );
  }, [mainCategoryOptions, userMainSet, masterMainSet]);

  const orderedSubcategories = useMemo(() => {
    const key = String(item.main_category || '').toLowerCase();
    const userSubs = Array.from((userSubMap && userSubMap[key]) || []);
    const masterSubs = Array.from((masterSubMap && masterSubMap[key]) || []);
    const defaults = Array.from(DEFAULT_SUBCATEGORY_SET[key] || []);
    const customs = (subCategoryOptions || []).filter(
      (s) => !(DEFAULT_SUBCATEGORY_SET[key] || new Set()).has(String(s || '').toLowerCase())
    );
    const combined = [...userSubs, ...masterSubs, ...defaults, ...customs];
    return combined.filter(
      (s, idx) => combined.findIndex((x) => String(x || '').toLowerCase() === String(s || '').toLowerCase()) === idx
    );
  }, [subCategoryOptions, item.main_category, userSubMap, masterSubMap]);

  const onSubCategoryCreate = (newSub) => {
    const trimmed = newSub.trim();
    if (!trimmed) return;

    setSubCategoryOptionsMap(prev => ({
      ...prev,
      [item.main_category]: (() => {
        const current = prev[item.main_category] || [];
        if (current.some(option => option.toLowerCase() === trimmed.toLowerCase())) {
          return current;
        }
        return [...current, trimmed];
      })(),
    }));

    saveUserCategoryPreference(item.item, item.main_category, trimmed);
  };

  const onMainCategoryCreate = (newCategory) => {
    const trimmed = newCategory.trim();
    if (!trimmed) return;

    setMainCategoryOptions(prev => {
      if (prev.some(option => option.toLowerCase() === trimmed.toLowerCase())) {
        return prev;
      }
      return [...prev, trimmed];
    });
    setSubCategoryOptionsMap(prev => {
      if (prev[trimmed]) {
        return prev;
      }
      return { ...prev, [trimmed]: [] };
    });
  };

  return (
    <div className="p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg grid grid-cols-1 md:grid-cols-7 gap-3 items-center">

      <input type="text" value={item.item} onChange={(e) => handleLineItemChange(index, 'item', e.target.value)} className="w-full p-2 rounded-lg bg-white dark:bg-gray-600 border border-transparent focus:border-green-500 text-sm md:col-span-2" />

      <InputWithIcon
        icon={PoundSterling}
        value={item.price}
        onChange={(e) => handleLineItemChange(index, 'price', e.target.value)}
        type="number"
        placeholder="Price"
        iconClassName="text-emerald-500"
        inputClassName="text-sm font-ubuntu"
        inputMode="decimal"
        autoComplete="off"
        pattern="[0-9]*[.,]?[0-9]*"
      />

      <input type="number" value={item.quantity} onChange={(e) => handleLineItemChange(index, 'quantity', parseInt(e.target.value))} className="w-full p-2 rounded-lg bg-white dark:bg-gray-600 border border-transparent focus:border-green-500 text-sm font-ubuntu" />

      <div className="flex items-center gap-2">
        <CategoryIconComponent
          className="h-4 w-4"
          color={categoryColor}
          stroke={categoryColor}
          strokeWidth={2}
          fill={categoryColor}
        />
        <SearchableDropdown
          options={orderedMainCategories}
          value={item.main_category}
          onChange={(value) => handleLineItemChange(index, 'main_category', value)}
          placeholder="Select Category"
          allowCreate
          pill
          labelClassName="text-xs md:text-sm"
          className="flex-1"
          onCreateOption={onMainCategoryCreate}
        />
      </div>

      <div className="flex items-center gap-2">
        <SubcategoryIconComponent
          className="h-4 w-4"
          color={subcategoryColor}
          stroke={subcategoryColor}
          strokeWidth={2}
          fill={subcategoryColor}
        />
        <SearchableDropdown
          options={orderedSubcategories}
          value={item.sub_category}
          onChange={(value) => handleLineItemChange(index, 'sub_category', value)}
          placeholder="Select Subcategory"
          allowCreate
          pill
          labelClassName="text-xs md:text-sm"
          className="flex-1"
          onCreateOption={onSubCategoryCreate}
        />
      </div>

      <button
        onClick={() => removeLineItem(index)}
        className="text-red-500 hover:text-red-600 justify-self-center"
        title="Remove this line"
        aria-label="Remove line"
      >
        <Trash2 size={20} className="text-red-500" />
      </button>
    </div>
  );
});
LineItemRow.displayName = 'LineItemRow';

function EditableReceipt({ data, setData, onSave, saveUserCategoryPreference, file, userStoreOverrides, isSaving }) {
  const { fetchWithAuth, user } = useAuth();
  const [mainCategoryOptions, setMainCategoryOptions] = useState(() => Object.keys(SUB_CATEGORIES));
  const [subCategoryOptionsMap, setSubCategoryOptionsMap] = useState(() =>
    Object.entries(SUB_CATEGORIES).reduce((acc, [key, values]) => {
      acc[key] = [...values];
      return acc;
    }, {})
  );
  const [userMainSet, setUserMainSet] = useState(new Set());
  const [masterMainSet, setMasterMainSet] = useState(new Set());
  const [userSubMap, setUserSubMap] = useState({});
  const [masterSubMap, setMasterSubMap] = useState({});
  const [storeTypeOptions, setStoreTypeOptions] = useState(() => {
    const base = new Set(
      Object.values(STORE_DATA).map((entry) => entry.StoreName_category)
    );
    base.add('Other');
    return Array.from(base).sort((a, b) => a.localeCompare(b));
  });
  const [storeList, setStoreList] = useState([]);
  const storeTypeManualRef = useRef(false);
  const [userCategoryRows, setUserCategoryRows] = useState([]);
  const [imagePreviewUrl, setImagePreviewUrl] = useState(null);
  const merchantOptions = useMemo(() => {
    const trimmed = (data.merchant_name || '').trim().toLowerCase();
    const matches = [];
    const others = [];
    const seen = new Set();

    if (userStoreOverrides) {
        Object.keys(userStoreOverrides).forEach((merchantName) => {
            const lower = merchantName.toLowerCase();
            if(seen.has(lower)) return;
            seen.add(lower);
            if(!trimmed || lower.includes(trimmed)){
                matches.push(merchantName)
            } else {
                others.push(merchantName)
            }
        });
    }

    storeList.forEach(({ merchant_name }) => {
      if (!merchant_name) return;
      const lower = merchant_name.toLowerCase();
      if (seen.has(lower)) return;
      seen.add(lower);
      if (!trimmed || lower.includes(trimmed)) {
        matches.push(merchant_name);
      } else {
        others.push(merchant_name);
      }
    });

    let combined = [...matches, ...others];
    if (data.merchant_name) {
      const lowerCurrent = data.merchant_name.toLowerCase();
      const alreadyIncluded = combined.some((name) => name.toLowerCase() === lowerCurrent);
      if (!alreadyIncluded) {
        combined = [data.merchant_name, ...combined];
      }
    }
    return combined;
  }, [storeList, data.merchant_name, userStoreOverrides]);

  useEffect(() => {
    if (file) {
      const url = URL.createObjectURL(file);
      setImagePreviewUrl(url);

      return () => {
        URL.revokeObjectURL(url);
      };
    }
  }, [file]);

  useEffect(() => {
    let isMounted = true;
    async function loadStores() {
      try {
        const resp = await fetchWithAuth('/api/store-info');
        if (!resp.ok) return;
        const json = await resp.json();
        if (isMounted) {
          setStoreList(Array.isArray(json) ? json : []);
        }
      } catch (error) {
        console.error('Failed to load store list:', error);
      }
    }
    loadStores();
    return () => {
      isMounted = false;
    };
  }, [fetchWithAuth]);

  useEffect(() => {
    let isMounted = true;
    async function loadCategoryOptions() {
      try {
        const fetcher = fetchWithAuth || fetch;
        const resp = await fetcher('/api/category-options');
        if (!resp.ok) return;
        const payload = await resp.json();
        if (!isMounted) return;

        const userRows = Array.isArray(payload?.userCategories) ? payload.userCategories : [];
        const masterRows = Array.isArray(payload?.masterCategories) ? payload.masterCategories : [];

        setUserCategoryRows(userRows);

        const nextUserMain = new Set();
        const nextMasterMain = new Set();
        const nextUserSubs = {};
        const nextMasterSubs = {};

        userRows.forEach((row) => {
          const main = (row.main_category || '').trim();
          const sub = (row.sub_category || '').trim();
          if (!main) return;
          nextUserMain.add(main);
          if (sub) {
            const key = main.toLowerCase();
            if (!nextUserSubs[key]) nextUserSubs[key] = new Set();
            nextUserSubs[key].add(sub);
          }
        });

        masterRows.forEach((row) => {
          const main = (row.main_category || '').trim();
          const sub = (row.sub_category || '').trim();
          if (!main) return;
          nextMasterMain.add(main);
          if (sub) {
            const key = main.toLowerCase();
            if (!nextMasterSubs[key]) nextMasterSubs[key] = new Set();
            nextMasterSubs[key].add(sub);
          }
        });

        setUserMainSet(nextUserMain);
        setMasterMainSet(nextMasterMain);
        setUserSubMap(Object.fromEntries(Object.entries(nextUserSubs).map(([k, v]) => [k, Array.from(v)])));
        setMasterSubMap(Object.fromEntries(Object.entries(nextMasterSubs).map(([k, v]) => [k, Array.from(v)])));

        setMainCategoryOptions((prev) => {
          const combined = new Set(prev);
          nextUserMain.forEach((m) => combined.add(m));
          nextMasterMain.forEach((m) => combined.add(m));
          return Array.from(combined);
        });

        setSubCategoryOptionsMap((prev) => {
          const next = { ...prev };
          const mergeSubs = (targetMap, source) => {
            Object.entries(source).forEach(([mainLower, subs]) => {
              const existing = new Set(next[mainLower] || next[Object.keys(next).find(k => k.toLowerCase() === mainLower)] || []);
              subs.forEach((s) => existing.add(s));
              const mainKey = Object.keys(next).find((k) => k.toLowerCase() === mainLower) || mainLower;
              next[mainKey] = Array.from(existing);
            });
          };
          mergeSubs(next, Object.fromEntries(Object.entries(nextUserSubs).map(([k, set]) => [k, Array.from(set)])));
          mergeSubs(next, Object.fromEntries(Object.entries(nextMasterSubs).map(([k, set]) => [k, Array.from(set)])));
          return next;
        });
      } catch (error) {
        console.error('Failed to load category options', error);
      }
    }
    loadCategoryOptions();
    return () => {
      isMounted = false;
    };
  }, [fetchWithAuth]);

  useEffect(() => {
    const newTotal = (data.line_items || []).reduce((acc, item) => {
      const price = parseNumberValue(item.price);
      const qty = parseNumberValue(item.quantity);
      return acc + price * (Number.isFinite(qty) ? qty : 0);
    }, 0);
    setData(prev => ({ ...prev, total_amount: newTotal }));
  }, [data.line_items, setData]);

  const updateMerchantSelection = useCallback(
    (rawValue) => {
      const merchantValue = typeof rawValue === 'string' ? rawValue.trim() : '';
      const matchedStore = merchantValue
        ? storeList.find(
          (store) => (store.merchant_name || '').toLowerCase() === merchantValue.toLowerCase()
        )
        : null;
      const info = getStoreInfo(merchantValue, userStoreOverrides);
      const derivedType = matchedStore?.store_type || info?.StoreName_category || 'Other';
      const preserveManual = storeTypeManualRef.current;
      storeTypeManualRef.current = false;

      setData((prev) => {
        const next = {
          ...prev,
          merchant_name: merchantValue,
          selectedMerchantId: matchedStore ? matchedStore.id : null,
        };
        next.store_type = preserveManual ? (prev.store_type || derivedType) : derivedType;
        return next;
      });

      if (derivedType) {
        setStoreTypeOptions((prevOptions) => {
          if (prevOptions.some((option) => option.toLowerCase() === derivedType.toLowerCase())) {
            return prevOptions;
          }
          return [...prevOptions, derivedType].sort((a, b) => a.localeCompare(b));
        });
      }
    },
    [setData, storeList, userStoreOverrides]
  );

  useEffect(() => {
    const merchantValue = (data.merchant_name || '').trim();
    const matchedStore = merchantValue
      ? storeList.find(
        (store) => (store.merchant_name || '').toLowerCase() === merchantValue.toLowerCase()
      )
      : null;
    const info = getStoreInfo(merchantValue, userStoreOverrides);
    // Prefer live store_info match, then existing value, then local mapping
    const derivedType =
      matchedStore?.store_type ||
      data.store_type ||
      info?.StoreName_category ||
      'Other';

    if (derivedType) {
      setStoreTypeOptions((prevOptions) => {
        if (prevOptions.some((option) => option.toLowerCase() === derivedType.toLowerCase())) {
          return prevOptions;
        }
        return [...prevOptions, derivedType].sort((a, b) => a.localeCompare(b));
      });
    }

    const shouldUpdateStoreType =
      !storeTypeManualRef.current &&
      derivedType &&
      data.store_type !== derivedType;

    const shouldUpdateSelected =
      !data.canonical_merchant_id &&
      matchedStore &&
      data.selectedMerchantId !== matchedStore.id;

    if (shouldUpdateStoreType || shouldUpdateSelected) {
      setData((prev) => {
        let updated = prev;
        if (shouldUpdateStoreType && prev.store_type !== derivedType) {
          updated = { ...updated, store_type: derivedType };
        }
        if (shouldUpdateSelected && matchedStore) {
          if (updated === prev) {
            updated = { ...updated };
          }
          updated.selectedMerchantId = matchedStore.id;
        }
        return updated;
      });
    }
  }, [
    data.merchant_name,
    data.store_type,
    data.selectedMerchantId,
    data.canonical_merchant_id,
    storeList,
    userStoreOverrides,
    setData,
  ]);

  const handleFieldChange = (field, value) => {
    if (field === 'merchant_name') {
      updateMerchantSelection(typeof value === 'string' ? value : '');
      return;
    }
    setData(prev => ({ ...prev, [field]: value }));
  };

  const handleStoreTypeChange = async (value) => {
    if (!value) return;
    const trimmed = typeof value === 'string' ? value.trim() : value;
    if (!trimmed) return;
    storeTypeManualRef.current = true;
    setStoreTypeOptions(prevOptions => {
      if (prevOptions.some(option => option.toLowerCase() === trimmed.toLowerCase())) {
        return prevOptions;
      }
      return [...prevOptions, trimmed].sort((a, b) => a.localeCompare(b));
    });
    setData(prev => ({ ...prev, store_type: trimmed }));

    // Call the new endpoint to save the override
    try {
      await fetchWithAuth('/api/user-store-type-overrides', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          merchant_name: data.merchant_name,
          store_type: trimmed,
        }),
      });
    } catch (error) {
      console.error('Failed to save store type override:', error);
    }
  };

  const handleLineItemChange = useCallback((index, field, value) => {
    const normalizedValue =
      field === 'price'
        ? (typeof value === 'string' ? value.replace(/,/g, '').replace(/[^\d.-]/g, '') : value)
        : (typeof value === 'string' ? value.replace(/[^a-zA-Z0-9\s]/g, '') : value);

    setData(prev => {
      const currentItems = Array.isArray(prev.line_items) ? [...prev.line_items] : [];
      if (!currentItems[index]) return prev;

      const updatedItem = { ...currentItems[index], [field]: normalizedValue };

      if (field === 'price') {
        updatedItem.price = normalizedValue;
      } else if (field === 'main_category') {
        updatedItem.sub_category = ''; // reset subcategory on main category change
      }

      currentItems[index] = updatedItem;

      if (field === 'sub_category') {
        const preference = {
          itemName: (updatedItem.item || updatedItem.Item_Name || '').trim(),
          mainCategory: (updatedItem.main_category || '').trim(),
          subCategory: (updatedItem.sub_category || '').trim(),
        };
        if (preference.itemName && preference.mainCategory && preference.subCategory) {
          saveUserCategoryPreference(
            preference.itemName,
            preference.mainCategory,
            preference.subCategory
          );
        }
      }

      return { ...prev, line_items: currentItems };
    });
  }, [saveUserCategoryPreference]);

  const addLineItem = () => {
    setData(prev => ({
      ...prev,
      line_items: [...(prev.line_items || []), { item: '', price: '', quantity: 1, main_category: 'other', sub_category: 'miscellaneous' }]
    }));
  };

  const removeLineItem = useCallback((index) => {
    setData(prev => ({
      ...prev,
      line_items: (prev.line_items || []).filter((_, i) => i !== index),
    }));
  }, []);

  return (
    <div className="bg-white/90 dark:bg-gray-800/90 backdrop-blur-2xl p-6 rounded-2xl shadow-2xl w-full text-left space-y-6 font-playfair text-gray-800">
      {imagePreviewUrl && (
        <div className="mb-4 rounded-2xl overflow-hidden receipt-frame sticky top-6 z-20">
          <img
            src={imagePreviewUrl}
            alt="Receipt Preview"
            className="w-full h-auto object-contain max-h-96"
          />
        </div>
      )}
      <div className="bg-gray-50/60 dark:bg-gray-800/40 border border-gray-200/40 dark:border-gray-700/40 rounded-3xl p-4 md:p-5 mb-6">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3 md:gap-4 items-center">
          <div className="flex flex-col">
            <span className="text-[10px] font-semibold uppercase tracking-[0.28em] text-gray-400 dark:text-gray-500 mb-2">Store Name</span>
            <div className="flex items-center gap-3">
              <MerchantLogo merchantName={data.merchant_name} />
              <SearchableDropdown
                options={merchantOptions}
                value={data.merchant_name || ''}
                onChange={updateMerchantSelection}
                placeholder="Select merchant"
                allowCreate
                startIcon={<Store className="h-3.5 w-3.5 text-emerald-500" />}
                pill
                labelClassName="text-xs md:text-sm"
                className="flex-1"
              />
            </div>
          </div>
          <div className="flex flex-col">
            <span className="text-[10px] font-semibold uppercase tracking-[0.28em] text-gray-400 dark:text-gray-500 mb-2">Receipt Date</span>
            <InputWithIcon
              icon={Calendar}
              value={data.transaction_date || ''}
              onChange={(e) => handleFieldChange('transaction_date', e.target.value)}
              type="date"
              placeholder="Transaction date"
              iconClassName="text-blue-500"
              inputClassName="text-xs md:text-sm font-ubuntu"
            />
          </div>
          <div className="flex flex-col">
            <span className="text-[10px] font-semibold uppercase tracking-[0.28em] text-gray-400 dark:text-gray-500 mb-2">Store Type</span>
            <SearchableDropdown
              options={storeTypeOptions}
              value={data.store_type || ''}
              onChange={handleStoreTypeChange}
              placeholder="Store type"
              allowCreate
              startIcon={<Tag className="h-3.5 w-3.5 text-amber-500" />}
              pill
              labelClassName="text-xs md:text-sm"
              onCreateOption={(newType) => {
                const trimmed = newType.trim();
                if (!trimmed) return;
                setStoreTypeOptions(prev => {
                  if (prev.some(option => option.toLowerCase() === trimmed.toLowerCase())) {
                    return prev;
                  }
                  return [...prev, trimmed].sort((a, b) => a.localeCompare(b));
                });
              }}
            />
          </div>
          <div className="flex flex-col">
            <span className="text-[10px] font-semibold uppercase tracking-[0.28em] text-gray-400 dark:text-gray-500 mb-2">Total</span>
            <div className="flex flex-wrap items-center gap-2 rounded-full bg-gray-100 dark:bg-gray-700 px-4 py-2 border border-transparent text-xs md:text-sm font-semibold font-ubuntu">
              <span className="text-emerald-500">£</span>
              <span className="receipt-number">{(data.total_amount ?? 0).toFixed(2)}</span>
            </div>
          </div>
        </div>
      </div>

      <div>
        <div className="flex justify-between items-center mb-2">
          <h4 className="font-semibold text-gray-700 dark:text-gray-300">Line Items</h4>
          <button
            onClick={addLineItem}
            className="text-green-500 hover:text-green-600"
            title="Add a new line item"
            aria-label="Add line item"
          >
            <PlusCircle size={22} className="text-green-500" />
          </button>
        </div>
        <div className="hidden md:grid grid-cols-7 gap-3 px-3 py-2 text-sm font-semibold text-gray-500 dark:text-gray-400">
          <div className="col-span-2">Item Name</div>
          <div>Price</div>
          <div>Qty</div>
          <div>Category</div>
          <div>Subcategory</div>
          <div></div>
        </div>
        <div className="space-y-4">
          {(data.line_items || []).map((item, index) => (
            <LineItemRow
              key={index}
              item={item}
              index={index}
              mainCategoryOptions={mainCategoryOptions}
              subCategoryOptionsMap={subCategoryOptionsMap}
              handleLineItemChange={handleLineItemChange}
              removeLineItem={removeLineItem}
              setMainCategoryOptions={setMainCategoryOptions}
              setSubCategoryOptionsMap={setSubCategoryOptionsMap}
              saveUserCategoryPreference={saveUserCategoryPreference}
              userMainSet={userMainSet}
              masterMainSet={masterMainSet}
              userSubMap={userSubMap}
              masterSubMap={masterSubMap}
            />
          ))}
        </div>
      </div>
      <div className="flex gap-4 mt-6">
        <button
          onClick={onSave}
          disabled={isSaving}
          className={`w-full py-3 px-6 rounded-lg font-semibold transition-colors flex items-center justify-center ${isSaving ? 'bg-green-400/60 text-white cursor-not-allowed' : 'bg-green-500 text-white hover:bg-green-600'
            }`}
        >
          {isSaving ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Saving…
            </>
          ) : (
            <>
              <Save size={20} className="mr-2" />
              Save Receipt
            </>
          )}
        </button>
      </div>
    </div>
  );
}

export default function ScanReceipt() {
  const [file, setFile] = useState(null);
  const [isCameraOpen, setIsCameraOpen] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [extractedDataState, setExtractedDataState] = useState(null);
  const setExtractedData = useCallback((value) => {
    setExtractedDataState((prev) => {
      const next = typeof value === 'function' ? value(prev) : value;
      if (!next) return next;
      return {
        ...next,
        line_items: formatLineItemsForEditor(next.line_items || []),
      };
    });
  }, []);
  const extractedData = extractedDataState;
  const [mode, setMode] = useState('upload');
  const [scanMode, setScanMode] = useState('receipt');
  const [markdownPreview, setMarkdownPreview] = useState(null);
  const [duplicatePrompt, setDuplicatePrompt] = useState(null);
  const [saveSuccessPrompt, setSaveSuccessPrompt] = useState(false);
  const fileInputRef = useRef(null);
  const savedPreferencesRef = useRef(new Set());
  const { user, userStoreOverrides, fetchWithAuth } = useAuth();
  const [loadingAnimation, setLoadingAnimation] = useState(null);
  const [leafsAnimation, setLeafsAnimation] = useState(null);
  const [isHighAccuracy, setIsHighAccuracy] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const processingRef = useRef(null);
  const isMobile = useIsMobile();
  const pageBackgroundStyle = useMemo(() => {
    const base = "url('/images/ScanPageBackgroundImage.svg')";
    const gradient = "linear-gradient(135deg, rgba(255,247,251,0.9), rgba(255,241,246,0.85))";
    return {
      backgroundImage: extractedData ? `${gradient}, ${base}` : base,
      backgroundSize: extractedData ? 'cover, cover' : 'cover',
      backgroundRepeat: 'no-repeat',
      backgroundPosition: 'center',
    };
  }, [extractedData]);

  const [showLoginPrompt, setShowLoginPrompt] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    fetch(leafsBlowAnimationUrl)
      .then((res) => res.json())
      .then((json) => setLeafsAnimation(json))
      .catch((err) => console.error('Failed to load Leafsblow animation', err));
  }, []);

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const shouldEdit = params.get('edit');
    if (shouldEdit) {
      const dataToEdit = sessionStorage.getItem('edit-receipt-data');
      if (dataToEdit) {
        try {
          const parsed = JSON.parse(dataToEdit);
          setExtractedData(parsed);
          setMode('upload');
        } catch (err) {
          console.error('Failed to parse receipt data for editing', err);
        } finally {
          sessionStorage.removeItem('edit-receipt-data');
        }
      }
    }
  }, [location.search, setExtractedData]);

  const persistPendingPreview = useCallback(() => {
    if (typeof window === 'undefined') return;
    if (!extractedData && !markdownPreview) return;
    try {
      const payload = {
        type: markdownPreview ? 'document' : 'receipt',
        extractedData: markdownPreview ? null : extractedData,
        markdown: markdownPreview || null,
        timestamp: Date.now(),
      };
      sessionStorage.setItem(PENDING_PREVIEW_STORAGE_KEY, JSON.stringify(payload));
    } catch (err) {
      console.error('Failed to persist pending preview', err);
    }
  }, [extractedData, markdownPreview]);

  const clearPendingPreview = useCallback(() => {
    if (typeof window === 'undefined') return;
    sessionStorage.removeItem(PENDING_PREVIEW_STORAGE_KEY);
  }, []);

  useEffect(() => {
    fetch('/images/ai-cpu-loading.json')
      .then((response) => response.json())
      .then((data) => setLoadingAnimation(data));
  }, []);

  useEffect(() => {
    if (isProcessing && processingRef.current) {
      processingRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }, [isProcessing]);

  useEffect(() => {
    const prefilled = sessionStorage.getItem('multi-scan-result');
    if (prefilled) {
      try {
        const parsed = JSON.parse(prefilled);
        if (parsed) {
          setExtractedData(parsed);
          setMarkdownPreview(null);
          setFile(null);
          setMode('upload');
          setScanMode('receipt');
        }
      } catch (err) {
        console.error('Failed to load multi scan result', err);
      } finally {
        sessionStorage.removeItem('multi-scan-result');
      }
    }
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const params = new URLSearchParams(location.search);
    const shouldResume = params.get(RESUME_QUERY_PARAM);
    if (!shouldResume) return;

    try {
      const snapshot = sessionStorage.getItem(PENDING_PREVIEW_STORAGE_KEY);
      if (snapshot) {
        const payload = JSON.parse(snapshot);
        if (payload?.type === 'receipt' && payload.extractedData) {
          setExtractedData(payload.extractedData);
          setMarkdownPreview(null);
          setScanMode('receipt');
          setMode('upload');
        } else if (payload?.type === 'document' && payload.markdown) {
          setMarkdownPreview(payload.markdown);
          setExtractedData(null);
          setScanMode('document');
          setMode('upload');
        }
      }
    } catch (err) {
      console.error('Failed to restore pending preview', err);
    } finally {
      clearPendingPreview();
      params.delete(RESUME_QUERY_PARAM);
      navigate(`${location.pathname}${params.toString() ? `?${params.toString()}` : ''}`, { replace: true });
      setShowLoginPrompt(false);
    }
  }, [location.pathname, location.search, navigate, clearPendingPreview]);

  const saveUserCategoryPreference = useCallback(async (itemName, mainCategory, subCategory) => {
    const trimmedName = (itemName || '').trim();
    const trimmedMain = (mainCategory || '').trim();
    const trimmedSub = (subCategory || '').trim();

    if (!trimmedName || !trimmedMain || !trimmedSub) return;

    const normalizedName = trimmedName.toLowerCase();
    const cacheKey = `${normalizedName}__${trimmedMain.toLowerCase()}__${trimmedSub.toLowerCase()}`;
    if (savedPreferencesRef.current.has(cacheKey)) return;

    try {
      const response = await fetchWithAuth('/api/update-user-category', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          item_name: normalizedName,
          main_category: trimmedMain,
          sub_category: trimmedSub,
        }),
      });

      if (response.ok) {
        savedPreferencesRef.current.add(cacheKey);
      }
    } catch (err) {
      console.error('Failed to save user category preference', err);
    }
  }, [fetchWithAuth]);


  const processFile = async (fileToProcess) => {
    if (!fileToProcess) return;
    setIsProcessing(true);
    const formData = new FormData();
    formData.append('file', fileToProcess);
    formData.append('scanMode', scanMode);
    formData.append('highAccuracy', String(isHighAccuracy));
    let pendingExtractedData = null;
    let pendingMarkdown = null;
    try {
      const resp = await fetchWithAuth('/api/scan', {
        method: 'POST',
        body: formData,
      });
      if (!resp.ok) throw new Error('Server error');
      if (scanMode === 'receipt') {
        pendingExtractedData = await resp.json();
      } else {
        pendingMarkdown = await resp.text();
      }
      if (pendingExtractedData) {
        setExtractedData(pendingExtractedData);
      }
      if (pendingMarkdown) {
        setMarkdownPreview(pendingMarkdown);
      }
    } catch (error) {
      console.error(error);
      alert(`Failed to process file: ${error.message}`);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile) {
      setFile(selectedFile);
      setExtractedData(null);
      setMarkdownPreview(null);
      setMode('upload');
      processFile(selectedFile);
    }
  };

  const handleDragOver = (e) => e.preventDefault();

  const handleDrop = (e) => {
    e.preventDefault();
    const droppedFile = e.dataTransfer.files[0];
    if (droppedFile) {
      setFile(droppedFile);
      setExtractedData(null);
      setMarkdownPreview(null);
      setMode('upload');
      processFile(droppedFile);
    }
  };

  const handleUploadClick = () => {
    setMode('upload');
    fileInputRef.current.click();
  }

  const handleModeChange = (newMode) => {
    if (isMobile && newMode === 'camera') {
      setMode('manual');
      setIsCameraOpen(false);
      return;
    }
    setMode(newMode);
    if (newMode !== 'upload') {
      setFile(null);
    }
    if (newMode === 'camera') {
      setIsCameraOpen(true);
    }
    if (newMode === 'manual') {
      setExtractedData({
        merchant_name: '',
        transaction_date: new Date().toISOString().split('T')[0],
        total_amount: 0,
        line_items: [],
      });
    }
  };

  const handleCapture = (capturedFile) => {
    setFile(capturedFile);
    setExtractedData(null);
    setMarkdownPreview(null);
    setIsCameraOpen(false);
    setMode('upload');
    processFile(capturedFile);
  };

  const handleLoginRedirect = useCallback(() => {
    persistPendingPreview();
    setShowLoginPrompt(false);
    navigate(`/login?redirect=${encodeURIComponent('/scan?resume=1')}`);
  }, [navigate, persistPendingPreview]);

  const closeLoginPrompt = useCallback(() => {
    setShowLoginPrompt(false);
  }, []);

  const handleReset = (options = {}) => {
    const { skipReload = false } = options;
    setFile(null);
    setExtractedData(null);
    setMarkdownPreview(null);
    setMode('upload');
    setScanMode('receipt');
    setIsCameraOpen(false);
    setDuplicatePrompt(null);
    setSaveSuccessPrompt(false);
    clearPendingPreview();
    navigate('/scan');
    if (!skipReload) {
      window.location.reload();
    }
  };

  const handleSave = async (options = {}) => {
    if (!extractedData || !Array.isArray(extractedData.line_items)) {
      alert('No receipt data to save.');
      return;
    }

    if (!user) {
      setShowLoginPrompt(true);
      return;
    }

    const isEditing = extractedData && extractedData.id;

    if (isEditing) {
      if (!options.existingReceiptId) {
        options.existingReceiptId = extractedData.id;
      }
      if (!options.duplicateAction) {
        options.duplicateAction = 'replace';
      }
    }

    if (!extractedData.canonical_merchant_id && extractedData.selectedMerchantId) {
      const aliasSource = extractedData.merchant_alias || extractedData.merchant_name || '';
      const alias = normalizeMerchantName(aliasSource);
      if (alias) {
        try {
          fetchWithAuth('/api/merchant-aliases', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              alias,
              merchant_id: extractedData.selectedMerchantId,
            }),
          }).catch(async (error) => {
            console.error('Failed to save merchant alias:', error);
          });
        } catch (error) {
          console.error('Failed to save merchant alias:', error);
        }
      }
    }

    const preparedReceipt = {
      ...extractedData,
      line_items: sanitizeLineItemsForSave(extractedData.line_items || []),
      transaction_date: extractedData.transaction_date || new Date().toISOString().split('T')[0],
    };
    const formData = new FormData();
    formData.append('receiptData', JSON.stringify(preparedReceipt));
    if (file) {
      formData.append('receiptImage', file);
    }
    if (options.duplicateAction) {
      formData.append('duplicateAction', options.duplicateAction);
    }
    if (options.existingReceiptId) {
      formData.append('existingReceiptId', options.existingReceiptId);
    }

    try {
      setIsSaving(true);
      const response = await fetchWithAuth('/api/receipts', {
        method: 'POST',
        body: formData,
      });

      if (!response.ok) {
        let message = 'Failed to save receipt';
        let errorPayload = null;
        try {
          errorPayload = await response.json();
          if (errorPayload?.error) {
            message = errorPayload.error;
          }
        } catch (_) {
          // ignore JSON parse issues
        }

        if (response.status === 409) {
          if (errorPayload?.code === 'DUPLICATE_RECEIPT' && errorPayload?.existingReceiptId) {
            setDuplicatePrompt({
              receiptId: errorPayload.existingReceiptId,
              message,
            });
            return;
          }

          alert(message);
          return;
        }

        throw new Error(message);
      }

      setSaveSuccessPrompt(true);
    } catch (error) {
      console.error(error);
      alert(`Failed to save receipt: ${error.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleDuplicateDecision = (action) => {
    if (!duplicatePrompt) return;
    const payload = {
      duplicateAction: action,
      existingReceiptId: duplicatePrompt.receiptId,
    };
    setDuplicatePrompt(null);
    handleSave(payload);
  };

  const pageTitle = 'Scan Receipt';

  return (
    <>
      {duplicatePrompt && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl">
            <p className="text-lg font-semibold text-gray-900">This receipt already exists.</p>
            <p className="mt-2 text-sm text-gray-600">
              {duplicatePrompt.message && duplicatePrompt.message !== 'This receipt already exists.'
                ? duplicatePrompt.message
                : 'Choose whether to replace the existing record or keep both copies.'}
            </p>
            <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
              <button
                onClick={() => handleDuplicateDecision('replace')}
                className="rounded-xl bg-red-500 px-4 py-3 text-white font-semibold hover:bg-red-600 transition-colors"
              >
                Replace
              </button>
              <button
                onClick={() => handleDuplicateDecision('keep')}
                className="rounded-xl border border-gray-300 px-4 py-3 font-semibold text-gray-800 hover:bg-gray-50 transition-colors"
              >
                Keep Both
              </button>
              <button
                onClick={() => setDuplicatePrompt(null)}
                className="rounded-xl border border-gray-200 px-4 py-3 font-semibold text-gray-600 hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
      {saveSuccessPrompt && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm px-4">
          <div className="w-full max-w-md rounded-3xl border border-white/15 bg-white/10 text-white shadow-[0_30px_120px_rgba(0,0,0,0.6)] backdrop-blur-2xl p-6 md:p-7 text-center">
            <div className="flex flex-col items-center gap-3">
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-emerald-500/20 border border-emerald-300/30 shadow-inner shadow-emerald-500/30">
                <CheckCircle size={28} className="text-emerald-300" />
              </div>
              <p className="text-xl font-semibold font-playfair">Receipt saved</p>
              <p className="text-sm text-white/80">
                Your receipt has been stored successfully. Would you like to scan another?
              </p>
            </div>
            <div className="mt-6 grid grid-cols-2 gap-3">
              <button
                onClick={() => {
                  handleReset({ skipReload: true });
                  setSaveSuccessPrompt(false);
                }}
                className="w-full rounded-xl bg-emerald-500/90 px-4 py-3 text-white font-semibold hover:bg-emerald-500 transition-colors shadow-lg shadow-emerald-500/30"
              >
                Scan Another
              </button>
              <button
                onClick={() => {
                  setSaveSuccessPrompt(false);
                  navigate(createPageUrl('Insights'));
                }}
                className="w-full rounded-xl bg-white/10 px-4 py-3 text-white font-semibold hover:bg-white/20 transition-colors border border-white/20"
              >
                No
              </button>
            </div>
          </div>
        </div>
      )}
      {isSaving && (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/50 px-4">
          <div className="flex items-center gap-3 rounded-2xl bg-slate-900/90 px-6 py-4 text-white shadow-2xl">
            <Loader2 className="h-5 w-5 animate-spin text-emerald-400" />
            <span className="text-sm font-medium">Saving receipt…</span>
          </div>
        </div>
      )}
      {showLoginPrompt && (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/70 px-4">
          <div className="w-full max-w-md rounded-2xl border border-white/10 bg-slate-900 p-6 text-white shadow-2xl">
            <h2 className="text-2xl font-semibold mb-2">Login required</h2>
            <p className="text-sm text-slate-300">
              Sign in to save this receipt to your account. We&apos;ll keep your current scan ready so you can pick up
              right where you left off.
            </p>
            <div className="mt-6 flex flex-col sm:flex-row gap-3">
              <button
                onClick={closeLoginPrompt}
                className="w-full rounded-xl border border-white/20 px-4 py-2 font-semibold text-white hover:bg-white/10 transition-colors"
              >
                Not now
              </button>
              <button
                onClick={handleLoginRedirect}
                className="w-full rounded-xl bg-emerald-500 px-4 py-2 font-semibold text-white hover:bg-emerald-600 transition-colors"
              >
                Login to save
              </button>
            </div>
          </div>
        </div>
      )}
      <button
        data-testid="set-data-button"
        style={{ display: 'none' }}
        onClick={(e) => setExtractedData(e.detail)}
      />
      <style>{`
          .dark-bg { background-color: #000; width: 100%; }
          .receipt-preview-bg {
            background: linear-gradient(135deg, #fff7fb, #fff1f6);
            width: 100%;
          }
          .receipt-preview {
            font-family: 'Playfair Display', serif;
            color: #2b1b24;
          }
          .receipt-preview .receipt-number,
          .receipt-preview input[type="number"],
          .receipt-preview input[type="date"],
          .receipt-preview .numeric {
            font-family: 'Ubuntu Sans', system-ui, sans-serif;
          }
          .receipt-frame {
            border: 4px solid #ffffff;
            box-shadow: 0 16px 40px rgba(0, 0, 0, 0.08);
            background: #ffffff;
          }
          .scan-scope * {
            color: #0a0a0a !important;
            text-shadow: 0 1px 1px rgba(34, 197, 94, 0.5);
          }
          .scan-scope *::placeholder {
            color: #0a0a0a !important;
            text-shadow: 0 1px 1px rgba(34, 197, 94, 0.5);
          }
          /* Remove green glow in the receipt preview/editor area */
          .scan-scope .receipt-preview * {
            text-shadow: none !important;
          }
          /* Remove glow from document preview text */
          .scan-scope .document-preview * {
            text-shadow: none !important;
            color: inherit !important;
          }
          .scan-scope .document-preview {
            color: #000000 !important;
          }
          .scan-scope .document-preview button,
          .scan-scope .document-preview button span,
          .scan-scope .document-preview button svg {
            color: #ffffff !important;
          }
          .dark .scan-scope * {
            color: #f8fafc !important;
            text-shadow: 0 1px 1px rgba(34, 197, 94, 0.5);
          }
          .dark .scan-scope *::placeholder {
            color: #e2e8f0 !important;
            text-shadow: 0 1px 1px rgba(34, 197, 94, 0.5);
          }
          .dark .scan-scope .receipt-preview * {
            text-shadow: none !important;
          }
          .dark .scan-scope .document-preview * {
            text-shadow: none !important;
            color: inherit !important;
          }
          .scan-scope button:hover {
            color: #000 !important;
            border-color: #22c55e !important;
          }
      `}</style>

      <div
        className="scan-scope pt-8 md:pt-12 pb-12 min-h-screen overflow-y-auto font-playfair"
        style={pageBackgroundStyle}
      >
        {isCameraOpen && <CameraView onCapture={handleCapture} onClose={() => setIsCameraOpen(false)} />}

        {extractedData ? (
          <div className="p-4 md:p-8 flex flex-col items-center h-full receipt-preview">
            <div className="max-w-4xl w-full">
              <div className="text-center mb-4">
                <CheckCircle size={48} className="text-green-500 mx-auto mb-2" />
                <h1 className="text-3xl md:text-4xl font-bold text-gray-900">Review & Edit</h1>
              </div>
              <EditableReceipt
                data={extractedData}
                setData={setExtractedData}
                onSave={handleSave}
                saveUserCategoryPreference={saveUserCategoryPreference}
                file={file}
                userStoreOverrides={userStoreOverrides}
                isSaving={isSaving}
              />
              <button onClick={handleReset} className="mt-8 w-full bg-blue-500 text-white py-3 px-6 rounded-lg font-semibold hover:bg-blue-600 transition-colors">Scan Another</button>
            </div>
          </div>
        ) : markdownPreview ? (
          <div className="p-6 md:p-10 flex flex-col items-center h-full">
            <div className="max-w-4xl w-full">
              <DocumentPreview markdown={markdownPreview} onApprove={() => { }} onCancel={handleReset} />
            </div>
          </div>
        ) : (
          <div className="p-6 md:p-8 lg:p-10 flex flex-col items-center text-center min-h-[calc(100vh-8rem)] justify-start">
            <div className="relative max-w-xl w-full min-h-[520px] bg-white/20 backdrop-blur-2xl border border-white/30 shadow-2xl p-8 rounded-3xl overflow-hidden">
              {leafsAnimation && (
                <div className="absolute -top-6 -left-6 w-1/2 h-1/2 pointer-events-none opacity-80">
                  <Lottie animationData={leafsAnimation} loop autoplay />
                </div>
              )}
              <div className="flex flex-col items-center gap-3">
                <ScanModeToggle mode={scanMode} setMode={setScanMode} />
                <h1 className="text-3xl md:text-4xl font-bold text-black">{pageTitle}</h1>
                <p className="text-md text-black/90">Choose your input method to get started.</p>
              </div>

              {file ? (
                <div className="bg-white/25 backdrop-blur-xl border border-white/30 shadow-xl p-6 rounded-2xl w-full text-left">
                  <div className="flex justify-between items-center mb-4">
                    <h3 className="text-lg font-semibold text-black">Uploaded File</h3>
                    <button
                      onClick={() => {
                        setFile(null);
                        setExtractedData(null);
                        setMarkdownPreview(null);
                      }}
                      className="text-gray-600 hover:text-black"
                    >
                      <X size={20} />
                    </button>
                  </div>
                  <div className="flex items-center p-4 bg-black/25 backdrop-blur-xl rounded-lg border border-white/20">
                    <FileText size={24} className="text-green-400 mr-4" />
                    <div>
                      <p className="font-medium text-black">{file.name}</p>
                      <p className="text-sm text-gray-700">{(file.size / 1024).toFixed(2)} KB</p>
                    </div>
                  </div>

                  {isProcessing && (
                    <div ref={processingRef} className="flex flex-col items-center justify-center mt-6">
                      {loadingAnimation && <Lottie animationData={loadingAnimation} loop={true} style={{ width: 300, height: 300 }} />}
                      <p className="text-white mt-4">Processing your receipt...</p>
                    </div>
                  )}
                </div>
              ) : (
                <div className="rounded-2xl p-10 text-center cursor-pointer transition-colors bg-white/25 backdrop-blur-2xl shadow-xl mt-6" onDragOver={handleDragOver} onDrop={handleDrop} onClick={handleUploadClick}>
                  <input type="file" ref={fileInputRef} onChange={handleFileChange} className="hidden" accept="image/*,application/pdf" />
                  <Upload size={48} className="text-gray-300 mb-4 mx-auto" />
                  <p className="text-lg font-semibold text-black">Drag & Drop or Click to Upload</p>
                </div>
              )}

              <div className="mt-4 flex flex-col sm:flex-row items-center justify-center gap-6 text-sm">
                <button
                  type="button"
                  onClick={() => navigate(createPageUrl('ScanReceiptMulti'))}
                  className="inline-flex items-center gap-2 rounded-full border border-emerald-500/30 bg-emerald-500/10 px-4 py-2 text-sm font-semibold text-emerald-700 transition hover:bg-emerald-500 hover:text-white"
                >
                  <PlusCircle size={16} />
                  Scan multiple pages
                </button>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setIsHighAccuracy((prev) => !prev)}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition ${isHighAccuracy ? 'bg-sky-500' : 'bg-white/20'
                      }`}
                    aria-pressed={isHighAccuracy}
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition ${isHighAccuracy ? 'translate-x-5' : 'translate-x-1'
                        }`}
                    />
                  </button>
                  <span className="text-sm font-small">Blurred Receipt?</span>
                </div>
              </div>
              <div className="mt-2 text-center text-xs">
                {isHighAccuracy ? 'Best detail, slightly slower' : 'Faster processing'}
              </div>

              {!file && (
                <div className="mt-8 grid grid-cols-2 md:grid-cols-4 gap-4">
                  {!isMobile && (
                    <>
                      <ActionButton text="Upload" icon={Upload} onClick={handleUploadClick} isActive={mode === 'upload'} />
                      <ActionButton text="Camera" icon={Camera} onClick={() => handleModeChange('camera')} isActive={mode === 'camera'} />
                    </>
                  )}
                  <ActionButton text="Manual" icon={Edit} onClick={() => handleModeChange('manual')} isActive={mode === 'manual'} />
                  <ActionButton text="Voice" icon={Mic} onClick={() => handleModeChange('voice')} isActive={mode === 'voice'} />
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </>
  );
}
