"use strict";
var __asyncValues = (this && this.__asyncValues) || function (o) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var m = o[Symbol.asyncIterator], i;
    return m ? m.call(o) : (o = typeof __values === "function" ? __values(o) : o[Symbol.iterator](), i = {}, verb("next"), verb("throw"), verb("return"), i[Symbol.asyncIterator] = function () { return this; }, i);
    function verb(n) { i[n] = o[n] && function (v) { return new Promise(function (resolve, reject) { v = o[n](v), settle(resolve, reject, v.done, v.value); }); }; }
    function settle(resolve, reject, d, v) { Promise.resolve(v).then(function(v) { resolve({ value: v, done: d }); }, reject); }
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.setupAIChatRoutes = setupAIChatRoutes;
const openai_1 = __importDefault(require("openai"));
let _openai = null;
function getOpenAI() {
    if (!_openai)
        _openai = new openai_1.default({ apiKey: process.env.OPENAI_API_KEY });
    return _openai;
}
const SYSTEM_PROMPT = `You are a friendly Korean language tutor named "달리 (Dalli)". You help users practice Korean conversation.

Rules:
- Respond in a mix of Korean and English based on the user's level
- For beginners: use simple Korean with English translations in parentheses
- For intermediate+: use more Korean, less English
- Keep responses concise (2-3 sentences max). Do NOT write long responses.
- Correct grammar mistakes gently
- Use natural, everyday Korean expressions
- Add romanization for Korean words when helpful
- If the user writes in English, respond with Korean translation and explanation
- If the user writes in Korean, praise their effort and continue the conversation
- Be encouraging and warm
- Include relevant vocabulary tips when natural
- Use honorific speech (존댓말) by default`;
const CACHED_RESPONSES = {
    "안녕하세요! (hello!)": "안녕하세요! (annyeonghaseyo!) 👋 반가워요! (bangawoyo - Nice to meet you!) 오늘 한국어 공부할 준비 됐어요? (Ready to study Korean today?)",
    "안녕하세요": "안녕하세요! (annyeonghaseyo!) 👋 반가워요! (bangawoyo - Nice to meet you!) 무엇을 배우고 싶으세요? (What would you like to learn?)",
    "hello": "안녕하세요! (annyeonghaseyo - Hello!) 👋 한국어로 인사하는 법을 배웠어요! (You just learned how to greet in Korean!) 잘했어요! (jalhesseoyo - Well done!)",
    "hi": "안녕! (annyeong - Hi!) 👋 This is the casual way to say hello in Korean. The polite form is 안녕하세요 (annyeonghaseyo). 오늘 뭐 배울까요? (What shall we learn today?)",
    "what does '감사합니다' mean?": "감사합니다 (gamsahamnida) means 'Thank you'! 🙏 It's the formal/polite way. You can also say 고마워요 (gomawoyo) in casual-polite situations, or 고마워 (gomawo) with close friends.",
    "how do i introduce myself?": "자기소개를 해볼까요? (Shall we try self-introduction?) 📝\n\n저는 [name]이에요/예요. (jeoneun [name]-ieyo/yeyo - I am [name])\n\nUse 이에요 after consonants, 예요 after vowels.\n\nExample: 저는 Sarah예요! (I am Sarah!)\n만나서 반가워요! (mannaseo bangawoyo - Nice to meet you!)",
    "teach me ordering food in korean": "한국 음식 주문해볼까요? (Shall we try ordering Korean food?) 🍜\n\n이것 주세요. (igeos juseyo - This one, please.)\n메뉴판 주세요. (menupan juseyo - Menu, please.)\n얼마예요? (eolmayeyo? - How much?)\n맛있어요! (masisseoyo! - It's delicious!)\n\nTry saying: 비빔밥 하나 주세요! (bibimbap hana juseyo - One bibimbap, please!)",
};
function findCachedResponse(userMessage) {
    const normalized = userMessage.trim().toLowerCase();
    return CACHED_RESPONSES[normalized] || null;
}
const responseCache = new Map();
const CACHE_TTL = 1000 * 60 * 60;
const MAX_CACHE_SIZE = 200;
function getCacheKey(message, level) {
    return `${level}:${message.trim().toLowerCase().slice(0, 100)}`;
}
function cleanCache() {
    if (responseCache.size <= MAX_CACHE_SIZE)
        return;
    const now = Date.now();
    for (const [key, val] of responseCache) {
        if (now - val.timestamp > CACHE_TTL)
            responseCache.delete(key);
    }
    if (responseCache.size > MAX_CACHE_SIZE) {
        const keys = Array.from(responseCache.keys());
        for (let i = 0; i < keys.length - MAX_CACHE_SIZE; i++) {
            responseCache.delete(keys[i]);
        }
    }
}
function setupAIChatRoutes(app) {
    app.post("/api/ai-chat", async (req, res) => {
        var _a, e_1, _b, _c;
        var _d, _e;
        try {
            const { messages, userLevel = 1, mode = 'freeChat' } = req.body;
            if (!messages || !Array.isArray(messages)) {
                return res.status(400).json({ error: "messages array is required" });
            }
            const lastUserMsg = messages[messages.length - 1];
            if (lastUserMsg && messages.length <= 1) {
                const cached = findCachedResponse(lastUserMsg.content);
                if (cached) {
                    res.setHeader("Content-Type", "text/event-stream");
                    res.setHeader("Cache-Control", "no-cache");
                    res.setHeader("Connection", "keep-alive");
                    res.write(`data: ${JSON.stringify({ content: cached })}\n\n`);
                    res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
                    res.end();
                    return;
                }
            }
            if (lastUserMsg && messages.length <= 2) {
                const cacheKey = getCacheKey(lastUserMsg.content, userLevel);
                const cachedDynamic = responseCache.get(cacheKey);
                if (cachedDynamic && Date.now() - cachedDynamic.timestamp < CACHE_TTL) {
                    res.setHeader("Content-Type", "text/event-stream");
                    res.setHeader("Cache-Control", "no-cache");
                    res.setHeader("Connection", "keep-alive");
                    res.write(`data: ${JSON.stringify({ content: cachedDynamic.content })}\n\n`);
                    res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
                    res.end();
                    return;
                }
            }
            const levelContext = userLevel <= 2
                ? "The user is a beginner (TOPIK Level 1-2). Use very simple Korean with English translations."
                : userLevel <= 4
                    ? "The user is intermediate (TOPIK Level 3-4). Use more Korean, add English only for difficult words."
                    : "The user is advanced (TOPIK Level 5-6). Respond mostly in Korean, minimal English.";
            const modeContext = mode === 'wordReview'
                ? "Mode: Word Review. Focus on vocabulary. When the user mentions a word, give its meaning, pronunciation, and a short example sentence."
                : mode === 'rolePlay'
                    ? "Mode: Role Play. Act out a real-life Korean scenario (cafe, subway, shopping, etc). Stay in character and guide the user through the conversation naturally."
                    : mode === 'grammarCoach'
                        ? "Mode: Grammar Coach. Carefully analyze the user's Korean sentences for grammar mistakes. Gently correct errors and explain the grammar rule in one sentence."
                        : "Mode: Free Chat. Have a natural, encouraging Korean conversation.";
            const systemMessage = {
                role: "system",
                content: `${SYSTEM_PROMPT}\n\n${levelContext}\n\n${modeContext}`,
            };
            res.setHeader("Content-Type", "text/event-stream");
            res.setHeader("Cache-Control", "no-cache");
            res.setHeader("Connection", "keep-alive");
            const stream = await getOpenAI().chat.completions.create({
                model: "gpt-4o-mini",
                messages: [systemMessage, ...messages.slice(-8)],
                stream: true,
                max_tokens: 250,
            });
            let fullContent = "";
            try {
                for (var _f = true, stream_1 = __asyncValues(stream), stream_1_1; stream_1_1 = await stream_1.next(), _a = stream_1_1.done, !_a; _f = true) {
                    _c = stream_1_1.value;
                    _f = false;
                    const chunk = _c;
                    const content = ((_e = (_d = chunk.choices[0]) === null || _d === void 0 ? void 0 : _d.delta) === null || _e === void 0 ? void 0 : _e.content) || "";
                    if (content) {
                        fullContent += content;
                        res.write(`data: ${JSON.stringify({ content })}\n\n`);
                    }
                }
            }
            catch (e_1_1) { e_1 = { error: e_1_1 }; }
            finally {
                try {
                    if (!_f && !_a && (_b = stream_1.return)) await _b.call(stream_1);
                }
                finally { if (e_1) throw e_1.error; }
            }
            if (lastUserMsg && messages.length <= 2 && fullContent) {
                const cacheKey = getCacheKey(lastUserMsg.content, userLevel);
                responseCache.set(cacheKey, { content: fullContent, timestamp: Date.now() });
                cleanCache();
            }
            res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
            res.end();
        }
        catch (error) {
            console.error("AI Chat error:", (error === null || error === void 0 ? void 0 : error.message) || error);
            if (res.headersSent) {
                res.write(`data: ${JSON.stringify({ error: "AI response failed" })}\n\n`);
                res.end();
            }
            else {
                res.status(500).json({ error: "Failed to get AI response" });
            }
        }
    });
}
//# sourceMappingURL=ai-chat.js.map