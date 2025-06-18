**TL;DR — RedwoodSDK gives an LLM‑powered coding agent an ergonomic, zero‑magic path to build full‑stack, Cloudflare‑native React apps.
Start with `npx create‑rwsdk`, treat `src/worker.tsx` as the single entry point, co‑locate UI and server code, bind Cloudflare services (D1, R2, Durable Objects, Queues) in `wrangler.jsonc`, and deploy in one step with `npm run release`.**([docs.rwsdk.com][1], [docs.rwsdk.com][2])

---

## 🔍 IMPORTANT: Example Code Reference

**A complete RedwoodSDK example project is available at `./rwsdk-sandbox/` for reference ONLY.**

### ⚠️ Critical Agent Instructions:

1. **READ-ONLY REFERENCE**: The `rwsdk-sandbox/` directory contains example code to learn RedwoodSDK patterns
2. **DO NOT MODIFY**: Never edit, run, or execute anything in the sandbox directory
3. **DO NOT RUN COMMANDS**: Never run npm/pnpm/wrangler commands inside rwsdk-sandbox/
4. **STUDY THE PATTERNS**: Use it to understand:
   - File structure (`src/worker.tsx`, `src/app/`, etc.)
   - Configuration patterns (`wrangler.jsonc`, `package.json`)
   - Code examples (components, routing, middleware)
   - Testing setup (`src/__tests__/`)

### 📖 How to Use the Example:

```bash
# ✅ CORRECT: Create your own new project
npx create-rwsdk my-actual-project
cd my-actual-project

# ✅ CORRECT: Reference the example structure
ls ../rwsdk-sandbox/src/          # Study the file organization
cat ../rwsdk-sandbox/src/worker.tsx # Learn routing patterns

# ❌ WRONG: Never work in the sandbox
cd rwsdk-sandbox                  # DON'T DO THIS
npm run dev                       # DON'T DO THIS
```

**The sandbox is for learning, not development. Always create fresh projects with `npx create-rwsdk`.**

---;DR — RedwoodSDK gives an LLM‑powered coding agent an ergonomic, zero‑magic path to build full‑stack, Cloudflare‑native React apps.
Start with `npx create‑rwsdk`, treat `src/worker.tsx` as the single entry point, co‑locate UI and server code, bind Cloudflare services (D1, R2, Durable Objects, Queues) in `wrangler.jsonc`, and deploy in one step with `npm run release`.**([docs.rwsdk.com][1], [docs.rwsdk.com][2])

---

## 1. Prerequisites & Local Tooling

| Requirement                                       | Why / Notes                                                                    |
| ------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Node ≥ 18**                                     | Vite 6+ and Wrangler require active LTS Node.([docs.rwsdk.com][2])             |
| **Wrangler v4** (`npm i -g @cloudflare/wrangler`) | Builds, runs Miniflare, deploys to Workers.([developers.cloudflare.com][3])    |
| **pnpm or npm**                                   | The official starters use pnpm lockfiles by default.([github.com][4])          |
| **Git**                                           | The starter template is delivered via `degit`.([developers.cloudflare.com][3]) |

> **Agent hint:** Fail fast if any binary is missing; ask the user to install or upgrade before continuing.

---

## 2. Bootstrapping a Project

```bash
# create & enter a new project
npx create-rwsdk my-app
cd my-app
pnpm install            # or npm install
pnpm dev                # hot‑reload dev server on http://localhost:5173
```

The command scaffolds the minimal starter, arranges a Vite workspace, and generates a typed `worker-configuration.d.ts`.([docs.rwsdk.com][2], [github.com][4])

### 2.1 Directory Map (minimal starter)

```
src/
  worker.tsx        ← single entry for all requests
  app/
    Document.tsx    ← HTML shell (server rendered)
    pages/
      Home.tsx
  client.tsx        ← hydration bootstrap
wrangler.jsonc      ← service bindings & env
.env                ← local secrets (symlinked to .dev.vars)
```

([docs.rwsdk.com][5], [docs.rwsdk.com][6])

---

## 3. Development Workflow

1. **Run `pnpm dev`** – Vite + Miniflare emulate Workers, Durable Objects, D1, R2, KV locally.([docs.rwsdk.com][1])
2. **Live‑reload** – Edit any file under `src/`; Vite pushes HMR to the browser.([docs.rwsdk.com][2])
3. **Type‑safety** – Re‑run `wrangler types` whenever you add a new environment binding.([docs.rwsdk.com][6])

> **Agent hint:** After every code‑gen (Prisma, wrangler types) commit the generated artifacts so CI builds match dev.

---

## 4. Routing & Request Handling

* Use `defineApp([...])` to compose *middleware* followed by *routes*.([docs.rwsdk.com][5])
* `route(path, handler)` matches static, parameter, or wildcard patterns.([docs.rwsdk.com][5])
* Handlers may return a **`Response`** or **JSX**; JSX is rendered server‑side via React Server Components (RSC) and streamed.([docs.rwsdk.com][5])
* Chain **interrupters** inside a route array to gate access (e.g., auth).([docs.rwsdk.com][5])
* Wrap related routes with `render(Document, [...routes])` to share the HTML shell.([docs.rwsdk.com][5])

```ts
export default defineApp([
  sessionMiddleware,
  route("/dashboard", [isAuthenticated, DashboardPage]),
  render(Document, [
    route("/", Home),
    route("/ping", () => <h1>Pong!</h1>),
  ]),
]);
```

---

## 5. React Server Components & Documents

* **Documents** define the outer HTML and must embed the client‑side entry script (`/src/client.tsx`).([docs.rwsdk.com][5])
* Avoid global state; rely on RSC props + context (`ctx`) for server‑driven UI.
* Hydration occurs automatically when the page loads in the browser.([docs.rwsdk.com][5])

---

## 6. Data Layer

### 6.1 Cloudflare D1 (SQLite)

1. `npx wrangler d1 create my-db` → copy binding into `wrangler.jsonc`.([docs.rwsdk.com][7])
2. Install Prisma + D1 adapter:
   `pnpm add prisma @prisma/client @prisma/adapter-d1`([docs.rwsdk.com][7])
3. Use `DATABASE_URL="file:./data.db"` in `.env`.
4. Custom migration scripts: `pnpm run migrate:new "init"`.([docs.rwsdk.com][7])

### 6.2 Postgres on Neon (optional)

Follow Neon’s RedwoodSDK guide for branch‑per‑preview DBs; bind the `PG_URL` secret and connect with Prisma’s `postgresql` provider.([neon.tech][8])

> **Agent hint:** Detect the presence of `PG_URL`; if absent, default to D1.

---

## 7. Object Storage (R2)

* Create bucket: `npx wrangler r2 bucket create my-bucket` and bind as `R2`.([docs.rwsdk.com][9])
* Stream uploads directly from the request body; no buffering.
* Use `env.R2.get/put()` for downloads/uploads.([docs.rwsdk.com][9])

---

## 8. Realtime Collaboration

* Export `RealtimeDurableObject` and wire `realtimeRoute` early in `defineApp`.([docs.rwsdk.com][10])
* Client: `initRealtimeClient({ key })` where `key` scopes the update channel.([docs.rwsdk.com][10])
* Server‑initiated pushes: `renderRealtimeClients({ durableObjectNamespace, key })`.([docs.rwsdk.com][10])

---

## 9. Environment Variables & Secrets

* Store local secrets in `.env`; RedwoodSDK symlinks to `.dev.vars` automatically.([docs.rwsdk.com][6])
* Generate typed bindings with `wrangler types`.([docs.rwsdk.com][6])
* In production, run `npx wrangler secret put <KEY>` or add via the dashboard.([docs.rwsdk.com][6])
* Access in code: `import { env } from "cloudflare:workers"; const token = env.API_TOKEN;`.([docs.rwsdk.com][6])

---

## 10. Queues, Cron & Background Tasks

* Bind a Queue in `wrangler.jsonc` and register a `queueRoute` similar to `realtimeRoute`. (See Core → Queues docs when available.)([docs.rwsdk.com][1])
* Cron triggers are configured under `"triggers": { "crons": ["0 */6 * * *"] }` and handled in `onScheduled` export.([docs.rwsdk.com][1])

---

## 11. Testing

* RedwoodSDK ships with Vitest presets; run `pnpm test`.([developers.cloudflare.com][3])
* For Workers‑specific logic, stub `env` bindings with Miniflare’s test harness.

---

## 12. Security & Middleware Patterns

| Concern     | Pattern                                                                                                        |
| ----------- | -------------------------------------------------------------------------------------------------------------- |
| **Auth**    | Add `ctx.user` in a middleware that verifies a session or JWT; interrupt unauth requests.([docs.rwsdk.com][5]) |
| **CSRF**    | For mutative routes, check `request.headers.get("Sec-Fetch-Site") === "same-origin"`.                          |
| **Headers** | Always return `Cross-Origin-Opener-Policy: same-origin` when using RSC.                                        |

---

## 13. Deployment

```bash
# build & publish to <subdomain>.workers.dev or a custom domain
npm run release
```

The script runs `wrangler deploy --minify --env production` under the hood.([docs.rwsdk.com][2], [developers.cloudflare.com][3])

CI/CD is trivial: add a workflow that authenticates with `CLOUDFLARE_API_TOKEN` and reruns `npm run release`.([developers.cloudflare.com][3])

---

## 14. Command Cheat‑Sheet

| Goal                        | Command                          |
| --------------------------- | -------------------------------- |
| Create project              | `npx create-rwsdk <name>`        |
| Dev server                  | `pnpm dev`                       |
| Generate types              | `wrangler types`                 |
| Apply D1 migrations (local) | `pnpm migrate:dev`               |
| Apply D1 migrations (prod)  | `pnpm migrate:prd`               |
| New migration               | `pnpm migrate:new "description"` |
| Build & deploy              | `npm run release`                |

---

## 15. Further Reading

* **RedwoodSDK Blog Announcement** – vision & philosophy.([redwoodjs.com][11])
* **GitHub README** – examples, starters, and community links.([github.com][4])
* **Cloudflare Workers Guide** – hands‑on deploy tutorial.([developers.cloudflare.com][3])
* **Neon Guide** – Postgres branching with RedwoodSDK.([neon.tech][8])

> **Agent hint:** Surface the above links when users ask “why does Redwood do X?” to give broader context.

---


