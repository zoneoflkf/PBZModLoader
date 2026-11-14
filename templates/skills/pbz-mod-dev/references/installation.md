# Install and diagnose a MOD

## Installation

1. Identify the intended game installation and verify PBZModLoader is present. When deploying with the game closed, put the built MOD folder directly under `ProjectPBZ/PBZModLoader/mods/`. Confirm `mods/<mod-id>/main.js` exists with no extra `dist/` layer. Keep development files in the project, and leave the loader's `Content/JavaScript/PBZModLoader/` cache alone.
2. When updating, back up the old MOD outside `mods/` and replace its entire folder so removed modules do not linger. Keep the user's other MODs and configuration. An old `main.ts` takes precedence over `main.js` and can mask a new build.
3. Discovery is automatic. If a MOD is disabled, inspect the existing `[Mods]` section of `ProjectPBZ/PBZModLoader/mods.ini`; `<mod-id>=0` disables it. Preserve the user's choices unless asked to change them.

## Runtime verification and hot reload

- The user normally tests in the game. In the loader checkout, start tests only via `scripts/影之刃零-窗口模式1280x720.cmd` and confirm a windowed **1280×720 client area**. If already running or the size is wrong, use `scripts/影之刃零-恢复1280x720.cmd` and confirm again. Those scripts live in the loader checkout and are not part of the standalone template. Follow any project-specific testing instructions.
- Inspect `ProjectPBZ/PBZModLoader/evidence/<this-run>/loader.log`. Match the relevant run, MOD ID, `[PBZMOD]` output, and first load error. `ue` and `puerts` are supplied by the game, so `node dist/<mod-id>/main.js` does not test the real runtime.
- In the foreground game window, **Alt+F5** reloads the enabled MOD set after stopping old instances; it is not a file watcher. Search for `hot reload published`, `stopped`, `reload complete`, or `reload blocked`. A missing or throwing `stop()` blocks replacement for that MOD; a pending cleanup Promise can stall the reload. An entry that throws after it starts executing will not be retried in the same game session; fix it and restart.
- Report the observed checks separately: build, load, requested behavior, and cleanup after reload. Ask the user to test the relevant map transition or UI when those behaviors need runtime evidence.
