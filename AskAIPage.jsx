import React, { useState, useEffect, useRef } from 'react';
import { Send, Loader2, Sparkles, Plus, ThumbsUp, ThumbsDown } from 'lucide-react';
import { useAuth } from '@/hooks/useAuth';
import { motion, AnimatePresence } from 'framer-motion';
import AnimatedSection from '@/components/ui/AnimatedSection';

// Feedback Buttons Component
const FeedbackButtons = ({ onFeedback }) => {
  const [feedback, setFeedback] = useState(null);

  const handleClick = (type) => {
    const newVal = feedback === type ? null : type;
    setFeedback(newVal);
    if (newVal) onFeedback(newVal);
  };

  return (
    <div className="flex gap-2 mt-1.5 px-1">
      <button
        onClick={() => handleClick('good')}
        className={`flex items-center gap-1.5 text-xs font-medium transition-colors border border-black/5 rounded-full px-2 py-0.5 bg-white/50 backdrop-blur-sm shadow-sm ${feedback === 'good' ? 'text-slate-700 bg-emerald-50 border-emerald-200' : 'text-slate-400 hover:text-slate-600'}`}
      >
        Good <ThumbsUp className={`w-3 h-3 ${feedback === 'good' ? 'fill-slate-700' : ''}`} />
      </button>
      <button
        onClick={() => handleClick('bad')}
        className={`flex items-center gap-1.5 text-xs font-medium transition-colors border border-black/5 rounded-full px-2 py-0.5 bg-white/50 backdrop-blur-sm shadow-sm ${feedback === 'bad' ? 'text-slate-700 bg-red-50 border-red-200' : 'text-slate-400 hover:text-slate-600'}`}
      >
        Bad <ThumbsDown className={`w-3 h-3 ${feedback === 'bad' ? 'fill-slate-700' : ''}`} />
      </button>
    </div>
  );
};

export default function AskAIPage() {
  const { user, fetchWithAuth } = useAuth();
  const [question, setQuestion] = useState('');
  const [loading, setLoading] = useState(false);
  // State for active messages (always starts fresh)
  const [messages, setMessages] = useState([]);

  // State for recent chat history (recommendations)
  const [recentPrompts, setRecentPrompts] = useState(() => {
    try {
      const saved = localStorage.getItem('owlit_recent_prompts');
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      return [];
    }
  });

  const [error, setError] = useState('');
  const bottomRef = useRef(null);

  const savePromptToHistory = (text) => {
    const updated = [text, ...recentPrompts.filter((p) => p !== text)].slice(0, 5);
    setRecentPrompts(updated);
    localStorage.setItem('owlit_recent_prompts', JSON.stringify(updated));
  };

  useEffect(() => {
    if (bottomRef.current) {
      bottomRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages]);

  const handleFeedback = async (msg, type) => {
    try {
      console.log('Sending feedback:', type, 'for memory:', msg.memory_id);
      await fetchWithAuth('/api/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          question: msg.question,
          answer: msg.text,
          feedback: type,
          memory_id: msg.memory_id
        }),
      });
    } catch (err) {
      console.error('Failed to send feedback:', err);
    }
  };

  const handleSend = async (textOverride = null) => {
    const text = textOverride || question.trim();
    if (!text || loading) return;

    setError('');
    savePromptToHistory(text);

    const userMsg = { role: 'user', text };
    setMessages((prev) => [...prev, userMsg]);
    setLoading(true);
    setQuestion(''); // Clear input immediately for better UX

    try {
      const resp = await fetchWithAuth('/api/ask-ai', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          question: text,
          history: messages // Send recent chat history for context
        }),
      });

      if (!resp.ok) {
        throw new Error('Request failed');
      }
      const data = await resp.json();
      const aiMsg = {
        role: 'ai',
        text: data?.answer || 'No response',
        items: Array.isArray(data?.items_used) ? data.items_used : [],
        memory_id: data?.memory_id,
        question: text, // Store original question for feedback context
        suggested_questions: data?.suggested_questions || []
      };
      setMessages((prev) => [...prev, aiMsg]);
    } catch (err) {
      console.error('AskAI error:', err);
      setError('Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const sendMessage = (e) => {
    e.preventDefault();
    handleSend();
  };

  const suggestions = recentPrompts.length > 0 ? recentPrompts : [
    "Spend Summary",
    "Recent Grocery",
    "How much did I spend in Tesco?",
    "Last Receipt"
  ];

  return (
    <div
      className="min-h-screen w-full flex flex-col items-center justify-start pt-28 md:pt-32 px-4 font-sans text-slate-900 bg-fixed bg-cover bg-center"
      style={{
        backgroundImage: "url('/images/colorful-gradients-3840x2160-22838.jpg')",
      }}
    >
      <div className="absolute inset-0 bg-black/20 pointer-events-none" />

      {/* Creapy White Background Container */}
      <AnimatedSection className="relative w-full max-w-md h-[600px] flex flex-col rounded-3xl border border-white/40 bg-[#FDFBF7] shadow-[0_40px_130px_rgba(0,0,0,0.2)] overflow-hidden font-fk-grotesk">

        {/* Header */}
        <header className="px-6 py-4 border-b border-black/5 bg-white/40 backdrop-blur-md flex items-center justify-between z-10">
          <div className="flex items-center gap-3">
            <div>
              <h1 className="text-xl font-semibold tracking-tight text-slate-900 drop-shadow-sm font-playfair">Owlit AI</h1>
              <p className="text-xs text-slate-500 font-medium font-fk-grotesk">Your Personal Receipt AI Assistant</p>
            </div>
          </div>
          <div>
            {/* New Chat Button */}
            <button
              onClick={() => {
                setMessages([]);
                setError('');
                if (window.confirm('Start a new chat?')) {
                  setMessages([]);
                }
              }}
              className="p-1.5 rounded-full bg-black/5 hover:bg-black/10 text-slate-600 transition-colors"
              title="New Chat"
            >
              <Plus className="w-4 h-4" />
            </button>
          </div>
        </header>

        {/* Messages Area */}
        <main className="flex-1 overflow-y-auto p-4 md:p-6 space-y-6 scrollbar-thin scrollbar-thumb-black/10 scrollbar-track-transparent">
          {messages.length === 0 && (
            <div className="h-full flex flex-col items-center justify-center text-center p-8 opacity-90">
              <h3 className="text-2xl font-bold text-slate-900 mb-2 tracking-tight font-fk-grotesk">How can I help?</h3>
              <p className="text-slate-500 max-w-xs text-sm leading-relaxed mb-8 font-fk-grotesk font-semibold">
                Ask about your spending or get insights from your receipts.
              </p>

              <div className="flex flex-wrap gap-2 justify-center max-w-sm">
                {suggestions.map((tag) => (
                  <button
                    key={tag}
                    onClick={() => {
                      setQuestion(tag);
                    }}
                    className="px-3 py-1.5 rounded-full bg-white hover:bg-emerald-50 border border-black/5 hover:border-emerald-200 text-xs font-semibold text-slate-600 hover:text-emerald-700 transition-all font-fk-grotesk shadow-sm"
                  >
                    {tag}
                  </button>
                ))}
              </div>
            </div>
          )}

          <AnimatePresence mode="popLayout">
            {messages.map((msg, idx) => (
              <motion.div
                key={idx}
                initial={{ opacity: 0, y: 10, scale: 0.98 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                transition={{ duration: 0.2 }}
                className={`flex w-full ${msg.role === 'user' ? 'justify-end' : 'justify-start'} mb-4 group`}
              >
                <div className={`flex flex-col ${msg.role === 'user' ? 'items-end' : 'items-start'} max-w-[80%]`}>
                  <div
                    className={`relative px-4 py-2.5 text-xs leading-snug font-fk-grotesk ${msg.role === 'user'
                      ? 'bg-[#007AFF] text-white rounded-[20px] rounded-tr-sm'
                      : 'bg-[#F2F2F7] text-slate-900 rounded-[20px] rounded-tl-sm border border-black/5'
                      }`}
                  >
                    <div className="whitespace-pre-wrap tracking-wide">
                      {msg.text.replace(/\*\*/g, '').split(/([£$]?\d+(?:[.,]\d+)?)/).map((part, i) =>
                        /^[£$]?\d+(?:[.,]\d+)?$/.test(part) ? (
                          <span key={i} className="font-berkeley bg-white text-slate-900 px-1.5 py-0.5 rounded-md mx-0.5 shadow-sm inline-block">{part}</span>
                        ) : (
                          part
                        )
                      )}
                    </div>
                  </div>

                  {/* Feedback Buttons */}
                  {msg.role === 'ai' && (
                    <div className="flex flex-col gap-2">
                      <FeedbackButtons onFeedback={(type) => handleFeedback(msg, type)} />

                      {msg.suggested_questions && msg.suggested_questions.length > 0 && (
                        <div className="flex flex-wrap gap-2 mt-1">
                          {msg.suggested_questions.map((suggestion, sIdx) => (
                            <button
                              key={sIdx}
                              onClick={() => handleSend(suggestion)}
                              className="text-xs bg-white/50 hover:bg-white border border-black/5 rounded-full px-3 py-1.5 text-slate-600 font-medium transition-all text-left shadow-sm hover:shadow active:scale-95"
                            >
                              {suggestion}
                            </button>
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              </motion.div>
            ))}
          </AnimatePresence>

          {loading && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="flex justify-start pl-1"
            >
              <div className="bg-[#F2F2F7] px-4 py-3 rounded-[20px] flex gap-1.5 items-center">
                <span className="w-1.5 h-1.5 bg-slate-400 rounded-full animate-bounce [animation-delay:-0.3s]"></span>
                <span className="w-1.5 h-1.5 bg-slate-400 rounded-full animate-bounce [animation-delay:-0.15s]"></span>
                <span className="w-1.5 h-1.5 bg-slate-400 rounded-full animate-bounce"></span>
              </div>
            </motion.div>
          )}
          {error && <div className="text-sm text-red-500 bg-red-50 border border-red-100 p-2 rounded-lg text-center">{error}</div>}
          <div ref={bottomRef} />
        </main>

        {/* Input Area */}
        <footer className="p-4 border-t border-black/5 bg-white/50 backdrop-blur-xl z-10">
          <form
            onSubmit={sendMessage}
            className="flex items-center gap-2 bg-white border border-black/5 px-3 py-1.5 rounded-[24px] shadow-sm transition-all focus-within:shadow-md min-h-[40px]"
          >
            <input
              type="text"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              placeholder="Ask Me"
              className="flex-1 bg-transparent border-none outline-none text-slate-900 placeholder:text-slate-400 text-xs leading-snug font-fk-grotesk font-semibold h-full ml-1"
              disabled={loading}
            />

            <AnimatePresence>
              {question.trim().length > 0 && (
                <motion.button
                  initial={{ scale: 0, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={{ scale: 0, opacity: 0 }}
                  whileTap={{ scale: 0.9 }}
                  type="submit"
                  disabled={loading}
                  className="w-7 h-7 flex items-center justify-center rounded-full bg-[#007AFF] text-white shadow-sm hover:bg-[#006fe6] transition-colors"
                >
                  {loading ? (
                    <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  ) : (
                    <div className="mb-0.5 ml-0.5">
                      <Send className="w-3.5 h-3.5 fill-current" />
                    </div>
                  )}
                </motion.button>
              )}
            </AnimatePresence>
          </form>
        </footer>
      </AnimatedSection>
    </div>
  );
}
