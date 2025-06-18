
# Contributor Guide
**This is the only AGENTS.md file, do not look for others.**

## CODEX Dev Environment Tips

Do NOT attempt to run any command which requires open network communication.  Your Dev environment has no network access and is sandboxed. No harm will come from trying but you will waste your effort.

DO NOT run `install.sh`.  This script is used in the Codex Environment configuration setup and is executed for you in the start up of your environment.

## 📖 Example Code Reference: rwsdk-sandbox/

**IMPORTANT**: A complete RedwoodSDK example is available at `./rwsdk-sandbox/` for reference ONLY.

### ⚠️ Critical Instructions:
- **READ-ONLY**: Study the code structure, patterns, and configuration
- **DO NOT MODIFY**: Never edit files in rwsdk-sandbox/
- **DO NOT EXECUTE**: Never run npm/dev/build commands in rwsdk-sandbox/
- **LEARN FROM IT**: Use it to understand RedwoodSDK patterns and file organization

## Development Instructions
You are to only develop for the Redwood SDK, Refer to `REDWOOD_SDK.INSTRUCTIONS.md` for details.

Your environment has been setup with `install.sh`.  Please review this script to understand your environment.

**For actual development, always create fresh projects with `npx create-rwsdk your-project-name`.**

• Always prefer RedwoodSDK helpers over bespoke code.
• Keep all server‑side logic inside src/worker.tsx routes or server functions.
• Co‑locate UI and server functions per feature directory.
• Use env bindings; never hard‑code secrets.
• For data, default to D1 via Prisma; fall back to Neon if PG_URL present.
• Add realtime support with initRealtimeClient when collaborative UI detected.
• Run tests (pnpm test) before every commit.
• Deploy with npm run release and report the live URL.