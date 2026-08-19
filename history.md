# Project History & Guidelines

## Overall Plan & Features
- [x] Dotfiles setup & system configuration management
- [x] Shell hooks and environment bootstrapping
- [x] Mandatory `history.md` rule configuration added to global `AGENTS.md`

## DOs and DON'Ts
### DOs
- Always maintain `history.md` with timestamped entries for features implemented or problems fixed.
- Record problem descriptions, fixes attempted/applied, and inter-session context.
- Use `uv` for Python environments and dependencies.
- Commit changes regularly with standard commit messages.

### DON'Ts
- Do NOT leave half-baked code or truncated files.
- Do NOT bypass `history.md` updates when implementing features or fixing bugs.
- Do NOT pollute global Python environments.

## Inter-Session AI Context
- **Global Rule updated**: `AGENTS.md` in `~/.gemini/config/AGENTS.md` now includes Rule 12 (`Mandatory history.md Tracking Rule`).
- **Workspace**: `/home/skc/dev/dotfiles`

---

## Event Log

### [2026-08-19 11:42 IST] Rule Definition & Initial Setup
- **Feature / Problem**: User requested rule enforcement to always create and maintain a `history.md` file listing timestamps, features/fixes, problem descriptions, fixes tried, overall plans, DOs & DON'Ts, and inter-session context.
- **Description**: Standardize tracking across all AI coding sessions so context and project history are preserved.
- **Fix / Action**: 
  1. Updated global guidelines in `~/.gemini/config/AGENTS.md` with Rule 12 (`Mandatory history.md Tracking Rule`).
  2. Created `history.md` for current workspace (`/home/skc/dev/dotfiles`).
