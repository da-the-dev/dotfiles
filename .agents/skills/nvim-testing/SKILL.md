---
name: nvim-testing
description: Test and debug this repo's Neovim config in a real, isolated nvim (private tmux server, separate state) with real keypresses. Use when changing anything under nvim/.config/nvim, checking that a keymap, plugin, panel, session or LSP feature works, or reproducing an nvim bug the user reports.
---

# Testing the nvim config

`scripts/nvt` (next to this file) starts a real nvim and drives it. Run it without arguments for
all commands. Needs tmux and lsof.

```sh
N=$PWD/.agents/skills/nvim-testing/scripts/nvt   # from the root of the checkout
D=$(mktemp -d)/t                               # or a folder in your scratchpad
mkdir -p $D/work; printf 'x = {  "a":1 }\n' > $D/work/a.py   # fixtures go in $D/work
$N $D start -c nvim/.config a.py               # -c: the config in this checkout
$N $D until 'return #vim.lsp.get_clients({bufnr=0, name="ruff"}) > 0' 15
$N $D keys Space c f                           # <leader>cf
sleep 1; cat $D/work/a.py                      # autosave has written it
$N $D screen; $N $D stop
```

`-c` matters: without it nvim loads `~/.config/nvim`, which is the main checkout, so a worktree's
changes wouldn't be tested. To compare variants, copy `nvim/.config` and pass the copy.

## Before testing
- **Look the problem up first** (issue trackers, plugin docs). Plugin and terminal bugs usually have
  a report with a trigger and a workaround, which is cheaper than finding it by experiment.
- **Read the installed source** in `~/.local/share/nvim/lazy/<plugin>` instead of recalling an API.
- `git status` and `git diff` first: the user edits these files in their own nvim at the same time.

## What isolation covers
Each `DIR` has its own sessions, swap, undo, shada and tmux server. Still shared with the user,
through `stdpath("data")`:
- plugins, parsers and `lazy-lock.json` handling: a *new* plugin spec installs for real (ask first)
- `python-interpreters.json` (written by `<leader>cv`)
- `jupyter/kernels` (written by `<leader>ji`): don't clean it up, the user's kernelspecs are there

Stay out of the user's projects: copy the files you need into `$D/work`. Put stand-ins for external
programs (`claude`, ...) in a folder and start with `-e PATH=that-folder:$PATH`.

## Getting trustworthy results
- **Reproduce before fixing**, and rerun the same steps after. A fix that was never seen failing, or a
  rare bug that didn't show up this time, proves little. Say which one it is.
- **Wait for conditions** (`wait`, `until`), not fixed sleeps. Check that a panel or picker is up
  before typing: otherwise the keys edit the file, and autosave writes that to disk.
- **A surprising result is usually the harness.** Look at the raw `screen` before drawing conclusions,
  and don't filter output until you've seen it once.
- **Check the effect where it lands:** file contents on disk, `lua` state, then the screen.
- **Cursor column:** `12G` keeps the old column (nvim's `nostartofline`), often the indentation. Code
  actions and symbol lookups need the cursor on the name itself.
- Cover restart (`:qa` then `start` again in the same `DIR`), `ZR`, hidden and reopened panels,
  neo-tree open, an empty buffer, and no language server, when the change could touch them.

## This config's traps
- Plain `nvim` restores the directory's session; quitting saves it. `nvim file` does neither.
- Files autosave 500ms after a change and reload about 1s after an outside change. `u` can undo past
  a reload and write the old content back.
- `persistence.save()` (used by `ZR`) doesn't fire `PersistenceSavePre`; quitting and switching sessions do.
- `:restart` replays the original command line, so `nvim a.py` reopens `a.py` (`ZR` handles this).
- The argument list is saved in sessions, along with globals that start with a capital letter.
- `langmap` only translates the first key of a multi-key mapping.

## Without a UI
`$N $D headless [-c nvim/.config] a.py probe.lua` runs Lua on a file: good for LSP answers.
Wait for the server (`vim.wait`), then `client:request_sync(...)`. Plugins that need a UI (sessions,
images) behave differently there, so confirm keymaps and layout with `start`.

## The user's running nvim
Read-only, and only to diagnose: `nvim --server <socket> --remote-expr ...`. Never send it keys. Don't
print process environments (they contain tokens); pick single variables by name.

## Shell
macOS has no `timeout` and no `cat -A` (use `cat -e`); zsh fails on globs that match nothing.

## Finishing
1. `$N $D stop`: it reports anything still running in `$D`. Never kill processes outside it.
2. Update `nvim/.config/nvim/CHEATSHEET.md` if keys changed.
3. The checks in `AGENTS.md`; confirm `lazy-lock.json` is unchanged unless that was the point.
4. Stage only your own files, after reading their diff.
5. `git merge` and `git pull` run `.githooks/post-merge`, which restows packages and restarts yabai
   and skhd, also from a worktree. Rebase or cherry-pick instead, or leave it to the user.
