# Base Inventory Monitor — Progress Ledger

Plan: docs/superpowers/plans/2026-06-24-base-inventory-monitor.md
Lua interpreter (use instead of `lua54`): /c/Users/pawel/AppData/Local/Programs/Lua/bin/lua.exe
Working dir: D:\Source\claude\DULua  (run tests with relative paths from here)

Bootstrap: Lua 5.4.6 installed (winget DEVCOM.Lua), git initialized (base 7f99ac4).
Task 0 steps 1-2 (Lua install, git init) already DONE by controller.

## Status
- [x] Group A (Tasks 0,1,2): complete (a70f94d..6bd59ff, 19 tests pass, review clean)
- [x] Group B (Tasks 3,4): complete (040c5cf..28acc4c, 40 tests pass, review clean)
- [x] Group C (Tasks 5,6): complete (0101206..6b9968c, 52 tests pass, review clean)
- [x] Group D (Tasks 7,8,9): complete (7ee0737..a36df3f, 61 tests pass, review clean)

### Minor findings (for final review triage)
- Group A: readContainer reads (getItemsVolume/MaxVolume/ItemsMass) rely on outer pcall rather than per-call guard — acceptable, no crash.
- Group A: round1 uses %s float formatting; whole numbers would show ".0". Watch in later tasks if whole-number volumes surface.
- Group B: aggregate.pct rounded to int (NECESSARY — (1100/2000)*100=55.0000000000000071 ~= 55 fails ==). Accepted by review; agg.pct is int while row.pct is float (latent, harmless; renderHTML floors both).
- Group B (minor): sortRows "none" mode untested; esc() does not escape double-quote (labels only used in element body, not attributes — safe now).
- Group C (minor): test `has` helper duplicated per do-block; Task6 block doesn't assert BIM.config values directly; run() defined after start/tick (works, Lua call-time resolution); double-round agg.pct→renderHTML (harmless).
- Group D (minor): build.ps1 strips ALL `return M` lines (use tail-only strip); README dev cmd says `lua54` but DEVCOM.Lua ships `lua.exe`; inlined blank lines carry 16-space trailing whitespace (harmless).

## Final whole-branch review: READY TO MERGE
- Found cross-cutting gap: --export tunables not wired (conf emitted none; DU exports are locals not _G). FIXED (commit 84e8e76): build.ps1 now emits 5 --export locals + bridges them to _G before BIM.start(); README binary-name note; build.ps1 tail-only `return M` strip. 65 tests pass, conf verified.
- Accepted minors (no fix): agg.pct int vs row.pct float (harmless); esc() no quote-escape (body-only); test `has` dup; cosmetic trailing whitespace in conf blanks.
- PROJECT COMPLETE. All groups done. HEAD has full deliverable set.
