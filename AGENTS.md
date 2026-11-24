# AGENTS.md

Personal dotfiles managed by GNU Stow.

## Where to edit
- Edit files inside the package directory (e.g. `nvim/.config/nvim/init.lua`).
  The `~/.config/nvim/...` path is a symlink back to this repo.
- Each top-level directory configures the tool of the same name.
- Check for a nearer AGENTS.md in the subdirectory before editing.
- Never hand-edit generated files.

## Workflow
- Inspect `git diff` first; preserve unrelated and staged changes.
- Keep changes minimal and machine-agnostic (no hardcoded
  usernames, hostnames, or absolute paths; use templates/conditionals).
- Preserve existing behavior unless the task requires otherwise.

## Validate
- Dry run first: `stow -n -v -t ~ <package>`
- Apply only when asked: `stow -t ~ <package>`
- Remove only when asked: `stow -D -t ~ <package>`

## Boundaries
- Always: edit source files, show the diff, run the checks.
- Ask first: installing packages, changing shell startup order,
  or deleting files.
- Never: run apply/update/remove against the host unless asked,
  make privileged changes, or commit or print secrets.
- Free rein: inside your own scratchpad directory, create, change,
  run and delete anything without asking (secrets rules still apply).

## Secrets
- Do not print suspected secrets in logs or replies.
- Scan changed files for tokens and keys before finishing.

## Rules
- Add new files at the path they should have under `~`.
- Use `.stow-local-ignore` for repo-only files (README, scripts).
- No secrets in tracked files; scan the diff before finishing.
