# Neovim cheatsheet

`<leader>` is Space. `<C-x>` = Ctrl+x, `<S-x>` = Shift+x. Keys marked * are stock nvim.

Forgot a key? Press `<leader>` and wait for the menu, or search by description with `<leader>fk`.
This file: `<leader>cc`, type `cheat`.

## Find
| Key | Action |
|---|---|
| `<leader>ff` / `<leader>fg` | Find file / text in project |
| `<leader>fs` / `<leader>fS` | Find symbol in file / project |
| `<leader>fb` | Find open buffer |
| `<leader>fk` / `<leader>fh` | Find keymap / help page |
| `<leader>cc` | Find config file |

In the picker: `<C-n>` / `<C-p>` move, `Enter` open, `<C-v>` / `<C-x>` open in a vertical / horizontal split, `<Esc><Esc>` close.

## Buffers (the tabs on top)
| Key | Action |
|---|---|
| `<S-h>` / `<S-l>` | Previous / next |
| `<leader>bp` | Jump by letter |
| `<leader>bd` / `<leader>bx` | Close current / by letter |
| `<leader>bo` | Close others |
| `<leader>bH` / `<leader>bL` | Close all to the left / right |
| `<leader>bh` / `<leader>bl` | Move tab left / right (`3<leader>bl`: by 3) |

## Windows
| Key | Action |
|---|---|
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Go left / down / up / right |
| `<C-w>v` / `<C-w>s` * | Split vertically / horizontally |
| `<C-w>q` / `<C-w>o` * | Close this window / all others |
| `<C-w>=` * | Make sizes equal |

## Sidebars and panels
| Key | Action |
|---|---|
| `<leader>e` | File explorer (left) |
| `<leader>o` | Outline (right) |
| `<leader>a` or `<C-.>` | Claude (right) |
| `<leader>rr` | Python REPL (right) |
| `<leader>t` or `` <C-`> `` | Terminal (bottom) |
| `<leader>gg` | Lazygit |

- **Explorer:** `a` add, `r` rename, `d` delete, `c` copy, `m` move, `s` open in a vertical split, `H` show hidden files, `?` all keys.
- **Outline:** `Enter` jumps to the symbol.
- **Claude:** `<C-h>` goes back to the code, `i` to type again. Scroll with the mouse wheel or `Fn+↑` / `Fn+↓`; `<C-o>` opens the full conversation (`/` searches, `<C-o>` closes). If it looks garbled: `<C-l>` while typing in it.
- **REPL:** `<C-h>` goes back to the code, `<Esc><Esc>` to scroll, `i` to type again.
- **Terminal:** `<Esc><Esc>` to leave or scroll, `i` to type again.

`<C-.>` and `` <C-`> `` also work while typing in a panel; `<leader>` keys don't.

## Code
| Key | Action |
|---|---|
| `gd` or `<C-]>` * | Go to definition |
| `gri` * / `grt` * | Go to implementation / type definition |
| `grr` * | References |
| `<C-t>` / `<C-o>` * | Back (after a definition / any jump) |
| `K` * | Documentation |
| `grn` * / `gra` * | Rename / code action (add import, fixes) |
| `]d` / `[d` * | Next / previous problem |
| `<C-w>d` * | Show the problem under the cursor |
| `gcc` *, `gc` * | Comment line, selection |
| `<leader>cf` | Format file / selection |
| `<leader>cv` | Choose Python interpreter |

- **Completion:** `Tab` or `Enter` accept, `<C-n>` / `<C-p>` select, `<C-Space>` open, `<C-e>` close (then `Enter` makes a new line).
- **Surround:** `ysiw"` add quotes around a word, `cs"'` change `"` to `'`, `ds"` remove.

## Debug
| Key | Action |
|---|---|
| `F5` or `<leader>dc` | Start / continue |
| `<S-F5>` or `<leader>dq` | Stop |
| `F9` or `<leader>db` | Toggle breakpoint |
| `<leader>dB` / `<leader>dx` | Conditional breakpoint / clear all |
| `F10` or `<leader>dn` | Step over |
| `F11` or `<leader>di` | Step into |
| `<S-F11>` or `<leader>do` | Step out |
| `<leader>dC` | Run to cursor |
| `<leader>dl` / `<leader>dt` | Re-run last / debug Python test under cursor |
| `<leader>du` / `<leader>dw` / `<leader>dr` | Panel / watch expression / REPL |

## Python REPL
Uses the interpreter from `<leader>cv` (IPython if installed there). After switching interpreter: `<leader>rn`.

| Key | Action |
|---|---|
| `<leader>rr` | Show / hide |
| `<leader>rl` | Run the statement under the cursor, go to the next |
| `<leader>r` in visual mode | Run selection |
| `<leader>rn` | Fresh REPL |

## Notebooks
| Key | Action |
|---|---|
| `<leader>ji` / `<leader>jI` | Start kernel / pick or connect |
| `<leader>jj` / `<leader>jc` | Run cell and go to next / run cell |
| `<leader>ja` | Run all |
| `<leader>ju` / `<leader>jb` | Run above / this cell and below |
| `<leader>jl`, `<leader>j` in visual mode | Run line, selection |
| `]j` / `[j` | Next / previous cell |
| `<leader>jo` / `<leader>jh` / `<leader>jd` | Open / hide / clear output |
| `<leader>jp` | Open plot in Preview |
| `<leader>jx` / `<leader>jR` / `<leader>jk` | Interrupt / restart / stop kernel |

## Markdown
| Key | Action |
|---|---|
| `<leader>x` | Toggle checkbox (line or selection) |
| `:RenderMarkdown toggle` | Rendered / raw |

Math (`$...$`, `$$...$$`) is shown as Unicode; the cursor line shows the source. Write `\$5` for a
dollar sign when a line has two of them.

Math snippets (the full list is in `lua/latex_snippets.lua`); they expand while you type:

| Type | Get |
|---|---|
| `mk` / `dm` | `$…$` / `$$…$$` block |
| `<Tab>` / `<S-Tab>` | Next / previous field, and out of the formula |
| `x/`, `(a+b)/`, `//` | `\dfrac{…}{}` |
| `@a`, `alpha` | `\alpha` (same for the other Greek letters) |
| `x1`, `sr`, `rd`, `_`, `^` | `x_{1}`, `^{2}`, `^{…}`, `_{…}`, `^{…}` |
| `xhat`, `xbar`, `xvec`, `xbold` | `\hat{x}`, ... |
| `sum`, `int`, `lim`, `sq`, `<=`, `!=`, `->`, `ooo` | `\sum`, `\int … dx`, ... |
| `bmat`, `case`, `align`, `lr(` | Environments, `\left( … \right)` |
| `par`, `pafx`, `defx`, `red`, `te` then `<Tab>` | Derivatives, colors, `\text{}` |
| select, `<Tab>`, then `U` `O` `B` `C` `K` `S` | Underbrace, overbrace, underset, cancel, cancelto, sqrt |

## Sessions
Saved per directory (and git branch) on quit; plain `nvim` restores the current directory's session.
`nvim file` neither restores nor saves it; loading a session by key turns saving on.
Not saved: breakpoints, the terminal, the REPL, Claude.

| Key | Action |
|---|---|
| `ZR` | Restart nvim, keeping the session |
| `<leader>qs` | Restore this directory's |
| `<leader>ql` / `<leader>qS` | Switch to the last one / pick: saves and closes this one, stops its terminals and Claude |
| `<leader>qd` / `<leader>qD` | Don't save on quit / delete this directory's session |
| `:detach` * | Leave nvim running in the background (note `:echo v:servername` first; back with `nvim --server <address> --remote-ui`) |

## Good to know
- Files save 500ms after a change and reload when something else changes them (not notebooks).
- Undoing past a reload also undoes that outside change on disk. `<C-r>` * redoes.
- Quitting nvim also stops Claude, the REPL and the terminal. `/resume` in Claude brings the conversation back.
- Russian layout: built-in commands work; multi-key mappings need English (see `lua/plugins/keyboard.lua`).
