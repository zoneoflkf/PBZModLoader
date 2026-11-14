---
name: pbz-mod-dev
description: Create, update, build, or debug TypeScript script mods for Phantom Blade Zero (影之刃零) using PBZModLoader's development template and UE/PuerTS SDK. Use for MOD entry points, game API lookup, packaging, and Alt+F5 hot reload or loader log issues. Loader DLL development and Nexus publishing are separate workflows.
---

# Develop a Phantom Blade Zero mod

Work in the user's MOD project. For an existing project, read its `package.json`, `tsconfig.json`, `src/main.ts`, and SDK version before editing; keep its build layout and dependencies unless a migration is requested or necessary.

## Start a new MOD

Choose a unique MOD ID using ASCII letters, digits, `_` and `-`. Run the helper relative to this skill directory, using a new project directory under an existing parent:

```text
node <skill-dir>/scripts/new-mod.cjs <mod-id> <new-project-dir> [template-dir]
```

If the user supplies a template, pass the extracted directory containing `package.json` and `vendor/game-api/`. Otherwise the helper uses the bundled template in `assets/ts-mod/` or `templates/ts-mod/` in the loader checkout. It sets `tsconfig.json`'s `outDir` and the sample's `MOD_ID`. The installed folder name is the actual MOD ID. Replace the sample behavior with the requested feature.

## Implement against the project's SDK

- Import runtime modules from `ue` and `puerts`. `@pbz-mod-loader/game-api` is a type-only development dependency loaded through `tsconfig.json`. The embedded runtime does not provide Node.js or DOM APIs. TypeScript emits CommonJS modules; use relative imports for MOD-local modules. Build output does not automatically bundle npm dependencies or copy assets.
- Start from `vendor/game-api/types/ue.d.ts` and `puerts.d.ts` for common APIs. Search `types/generated/` by symbol or use `type-index.json` to locate a full reflection path. Consult `api-surface.json` and the SDK README for runtime evidence and game build compatibility. Reflection or binding visibility alone does not establish a successful call. Read [UE/PuerTS notes](references/game-api.md) for Blueprint paths, native values, or UI text.
- Get a fresh `argv.getByName('GameInstance')` when work depends on the current world. Guard missing values and check native object validity before use. Reacquire world-dependent objects after map changes.
- Start from top-level entry code. Export a repeatable `stop()` that releases timers, subscriptions, and owned UI or other persistent resources; keep an empty `stop()` if none are needed. The loader awaits it during hot reload and does not call it on map changes or game exit. If initialization fails, roll back any resources already created before surfacing the error. Use the `[PBZMOD] <mod-id>` prefix for loader-captured log messages.
- Keep strict checking. Add any independently verified declarations in `types/custom.d.ts`; do not patch generated declarations or use casts to hide uncertain runtime behavior.

## Build and verify

From the MOD project, run `npm ci` for a fresh dependency install, then `npm run check` and `npm run build` (`npm.cmd` on Windows PowerShell if needed). The template clears `dist/` before building. Confirm `dist/<mod-id>/main.js` and its required modules or assets exist. Deliver the entire `dist/<mod-id>/` folder. Build and host tests do not establish that the MOD works in the game.

Read [installation and logs](references/installation.md) when asked to install a MOD, troubleshoot load failures, or verify hot reload. Check the project's `AGENTS.md` for game test and deployment rules.
