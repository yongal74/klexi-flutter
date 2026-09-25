# HANDOFF — build54 (1.0.6+54) · 2026-09-25

## Status
- AAB: `KlexiDev/releases/klexi-v1.0.6-build54.aab`. It is signed with the same upload key as build51–53 (META-INF/7EDE361C.SF) and jarsigner reports "jar verified".
- Commits: bf58fda, c3a1a5b, faaeea3, edbbd0e (pushed to master).
- Emulator walkthrough (Pixel_7) passed:
  - guest → onboarding → notification opt-in → 9:00 alarm registered
  - 3-card session → home/progress stats update live
  - settings version 1.0.6 (54) → paywall price-failure Retry state

## ✅ Resolved 2026-09-25 23:40 KST
- The owner registered a new key as secret version 3 and deployed functions and hosting.
- Production smoke tests passed:

  | Check | Result |
  |---|---|
  | `/api/health?deep=1` | `openai: ok` |
  | Chat | SSE 200 |
  | TTS | 200, audio/mpeg |
  | Pronunciation (build52-style upload) | 200, score 100 |
  | Garbage token | 401 |
- Windows deploy notes:
  - Quote the target list: `--only "functions,hosting"`.
  - If discovery times out, set `$env:FUNCTIONS_DISCOVERY_TIMEOUT="60"`.
  - A secret set after a deploy needs a redeploy.

## (history) Production incident — AI features down
- Chat (Dalli), TTS and pronunciation return 500. The logs show `401 Incorrect API key provided` from OpenAI.
- Fix, which only the owner can do:
  1. Create a new OpenAI key and set a monthly hard limit.
  2. Store it and deploy:

     ```
     firebase functions:secrets:set OPENAI_API_KEY --project klexi-30ab5
     firebase deploy --only functions,hosting --project klexi-30ab5
     ```
- The key now lives in Secret Manager (`secrets: ["OPENAI_API_KEY"]`). A rotated secret only takes effect after a redeploy.
- After the deploy, verify:
  - `/api/health?deep=1` returns 200.
  - Chat streams.
  - A garbage token gets 401.
  - TTS returns audio/mpeg.
  - A real m4a pronunciation upload scores.

## Backend changes (not yet deployed)
- **Pronunciation parsing:** switched from multer to busboy on `req.rawBody`. Cloud Functions pre-reads the body, so multer never received the file.
- **Audio format detection:** audio type is sniffed from magic bytes. build52 sends m4a as `recording.webm` with octet-stream.
- **Guards:** `guard.ts` adds per-route body limits and in-memory per-uid/IP rate limits:

  | Route | Body limit | Rate limit |
  |---|---|---|
  | chat | 16KB | 40 per 10 min |
  | tts | 8KB | 150 per 10 min |
  | pronunciation | 3MB | 60 per 10 min |

- **Chat:**
  - The cache applies only to single first messages, keyed by a hash of the full text.
  - The last message must come from the user.
  - The OpenAI call is aborted when the client disconnects.
- **AUTH_MODE:** pinned to `soft` in `functions/.env.klexi-30ab5`. An empty value behaves as hard and would lock out build52.
  - Switch to hard once build53+ reaches ≥90% of users or 14 days have passed.
- **CI:** now builds functions.

## App changes (summary)
- **Payments:**
  - A real paywall is reached from Settings.
  - Price-load failure shows a Retry state.
  - Trial and savings text is derived from store products.
  - Guests must sign in with Google before buying.
  - "Already purchased" triggers a restore.
  - The router is built once, so login no longer resets the navigation stack.
- **Learning data:**
  - Streak is calculated correctly.
  - Premium users get their chosen level first.
  - Ratings map correctly.
  - "Again" brings the word back tomorrow.
  - Quiz and review use today's studied words.
  - Stats refresh live.
  - Progress reset is explicit.
  - Per-user state is cleared on sign-out.
  - The guest id is reused after sign-out.
- **Features:**
  - Theme word cards open the correct word.
  - Pronunciation shows an error state instead of 0 points, with an up-front mic permission check.
  - Dalli handles errors and SSE line splitting, and restores its context after a restart.
  - Cloze quiz respects the user's level.
  - Quiz options are unique.
- **UX:**
  - Onboarding with a notification opt-in (existing users skip it).
  - No permission prompt at launch.
  - Notification settings apply immediately.
  - Remaining Korean UI strings are now English.

## Owner actions
1. Rotate the OpenAI key, then approve the deploy (see above).
2. In Play: promote build52 to 100%, then upload build54. build53 can be skipped. Use internal testing first.
3. Update the Play data safety form: Advertising ID, and voice recordings processed by OpenAI.
4. Add an uptime check on `/api/health?deep=1`.

## Remaining backlog
- Word network performance (WP-11).
- The session list doesn't mark studied words.
- Return to the originally requested feature after a paywall purchase.
- Make TOPIK level per-user.
- On 401, force-refresh the token and retry once.
- Clean up withOpacity and flutter_markdown deprecations.
