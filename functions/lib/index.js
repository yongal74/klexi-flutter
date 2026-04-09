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
exports.api = void 0;
const admin = __importStar(require("firebase-admin"));
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const https_1 = require("firebase-functions/v2/https");
const ai_chat_1 = require("./ai-chat");
const ai_tts_1 = require("./ai-tts");
const pronunciation_1 = require("./pronunciation");
admin.initializeApp();
const app = (0, express_1.default)();
app.use((0, cors_1.default)({
    origin: [
        "https://klexi-30ab5.web.app",
        "https://klexi-30ab5.firebaseapp.com",
        "http://localhost:3000",
        "http://localhost:8080",
    ],
    credentials: true,
}));
app.use(express_1.default.json());
app.get("/api/health", (_req, res) => {
    res.json({ status: "ok", timestamp: new Date().toISOString() });
});
(0, ai_chat_1.setupAIChatRoutes)(app);
(0, ai_tts_1.setupAITTSRoutes)(app);
(0, pronunciation_1.setupPronunciationRoutes)(app);
exports.api = (0, https_1.onRequest)({ timeoutSeconds: 60, memory: "512MiB", region: "us-central1", invoker: "public" }, app);
//# sourceMappingURL=index.js.map