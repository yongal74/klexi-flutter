"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.setupPronunciationRoutes = setupPronunciationRoutes;
// pronunciation.ts — OpenAI Whisper 기반 발음 채점 엔드포인트
const openai_1 = __importStar(require("openai"));
const multer_1 = __importDefault(require("multer"));
let _openai = null;
function getOpenAI() {
    if (!_openai)
        _openai = new openai_1.default({ apiKey: process.env.OPENAI_API_KEY });
    return _openai;
}
// 메모리 저장 (디스크 없이 Buffer로 처리)
const upload = (0, multer_1.default)({ storage: multer_1.default.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });
/** Levenshtein 거리 기반 유사도 점수 (0~100) */
function computeScore(expected, transcript) {
    const normalize = (s) => s.trim().toLowerCase().replace(/[^가-힣a-z0-9]/g, "");
    const exp = normalize(expected);
    const got = normalize(transcript);
    if (exp === got)
        return 100;
    if (exp.length === 0)
        return 0;
    const m = exp.length;
    const n = got.length;
    const dp = Array.from({ length: m + 1 }, (_, i) => Array.from({ length: n + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0)));
    for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
            dp[i][j] =
                exp[i - 1] === got[j - 1]
                    ? dp[i - 1][j - 1]
                    : 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
        }
    }
    const similarity = 1 - dp[m][n] / Math.max(m, n);
    return Math.max(0, Math.min(100, Math.round(similarity * 100)));
}
function buildFeedback(score, expected, transcript) {
    if (score >= 90)
        return "발음이 정확해요! 훌륭합니다 🎉";
    if (score >= 75)
        return `거의 다 왔어요! "${expected}"를 다시 한번 천천히 말해보세요.`;
    if (score >= 50)
        return `"${expected}"를 여러 번 들어보고 따라 말해보세요.`;
    if (transcript)
        return `"${transcript}"라고 들렸어요. "${expected}"에 집중해보세요.`;
    return "목소리가 잘 들리지 않았어요. 마이크에 가까이 대고 다시 시도해주세요.";
}
function setupPronunciationRoutes(app) {
    app.post("/api/pronunciation/score", upload.single("audio"), async (req, res) => {
        var _a;
        try {
            const audioFile = req.file;
            const expectedText = (_a = req.body) === null || _a === void 0 ? void 0 : _a.text;
            if (!audioFile) {
                return res.status(400).json({ error: "audio field is required" });
            }
            if (!expectedText) {
                return res.status(400).json({ error: "text field is required" });
            }
            // Buffer → OpenAI File 변환 (toFile 헬퍼 사용)
            const openaiFile = await (0, openai_1.toFile)(audioFile.buffer, audioFile.originalname || "recording.m4a", { type: audioFile.mimetype || "audio/m4a" });
            // OpenAI Whisper STT
            const transcription = await getOpenAI().audio.transcriptions.create({
                file: openaiFile,
                model: "whisper-1",
                language: "ko",
                response_format: "text",
            });
            const transcript = transcription.trim();
            const score = computeScore(expectedText, transcript);
            const feedback = buildFeedback(score, expectedText, transcript);
            // 음절 단위 상세 비교
            const expChars = [...expectedText.replace(/\s/g, "")];
            const gotChars = [...transcript.replace(/\s/g, "")];
            const details = expChars.map((ch, i) => {
                var _a;
                return ({
                    expected: ch,
                    heard: (_a = gotChars[i]) !== null && _a !== void 0 ? _a : "",
                    correct: ch === gotChars[i],
                });
            });
            const result = {
                score,
                transcript,
                expected: expectedText,
                feedback,
                details,
            };
            return res.json(result);
        }
        catch (error) {
            const msg = error instanceof Error ? error.message : String(error);
            console.error("[Pronunciation] Error:", msg);
            return res.status(500).json({
                score: 0,
                transcript: "",
                expected: "",
                feedback: "채점 서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
                details: [],
            });
        }
    });
}
//# sourceMappingURL=pronunciation.js.map