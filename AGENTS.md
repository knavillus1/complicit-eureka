
# Contributor Guide
**This is the only AGENTS.md file, do not look for others.**

## CODEX Dev Environment Tips

Do NOT attempt to run any command which requires open network communication.  Your Dev environment has no network access and is sandboxed. No harm will come from trying but you will waste your effort.

## Development Instructions
You are to only develop for the Redwood SDK, Refer to `REDWOOD_SDK.INSTRUCTIONS.md` for details.

Your environment has been setup with `install.sh`.  Please review this script to understand your environment.

• Always prefer RedwoodSDK helpers over bespoke code.
• Keep all server‑side logic inside src/worker.tsx routes or server functions.
• Co‑locate UI and server functions per feature directory.
• Use env bindings; never hard‑code secrets.
• For data, default to D1 via Prisma; fall back to Neon if PG_URL present.
• Add realtime support with initRealtimeClient when collaborative UI detected.
• Run tests (pnpm test) before every commit.
• Deploy with npm run release and report the live URL.