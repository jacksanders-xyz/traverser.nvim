# traverser.nvim

A code exploration dashboard for Neovim. Combines Trouble.nvim, edgy.nvim, and LSP into a persistent, multi-pane workspace with a trace/bookmark system for navigating code paths across files.

## Features

- **Dashboard layout** -- LSP-powered side panes (symbols, references/definitions, incoming calls, outgoing calls, diagnostics) arranged by edgy.nvim
- **Traces** -- Persistent, named bookmark collections with alphabetical tags. Stored per-project on disk, survive restarts.
- **Scoped references** (`<C-r>`) -- From the call hierarchy panes, find all references to a function *scoped to the caller's body*
- **Library filter** (`L`) -- Hide calls into vendor/library paths in the outgoing calls pane
- **Severity filter** (`S`) -- Cycle through diagnostic severity levels in any Trouble pane
- **Symbol pickers** -- Buffer or workspace symbol search with peek-in-code-window behavior
- **Focus & maximize** -- Quickly focus or toggle-maximize any pane

## Requirements

- Neovim >= 0.10
- [folke/trouble.nvim](https://github.com/folke/trouble.nvim) (v3)
- [folke/edgy.nvim](https://github.com/folke/edgy.nvim)
- One picker backend:
  - [folke/snacks.nvim](https://github.com/folke/snacks.nvim) (preferred), or
  - [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- An LSP server for your language (e.g. `gopls`, `ts_ls`, `lua_ls`)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) (required for `<C-r>` scoped references)

## Installation

### lazy.nvim

```lua
{
  "yourusername/traverser.nvim",
  dependencies = {
    "folke/trouble.nvim",
    "folke/edgy.nvim",
    -- pick one:
    "folke/snacks.nvim",
    -- "nvim-telescope/telescope.nvim",
  },
  opts = {},
  keys = {
    { "<leader>tm", "<cmd>TraverserToggle<cr>", desc = "Toggle traverser dashboard" },
  },
}
```

## Configuration

Default options (pass overrides to `setup()` or `opts`):

```lua
require("traverser").setup({
  picker = "auto",           -- "auto", "telescope", or "snacks"
  drawer_size = 56,          -- width of left/right panes (columns)
  bottom_size = 12,          -- height of bottom panes (lines)
  resize_step_width = 76,    -- maximize resize step (width)
  resize_step_height = 10,   -- maximize resize step (height)
  resize_fine = 2,           -- fine resize amount (ctrl-arrow)
  animate = false,           -- edgy animation
  dashboard_modes = {        -- panes opened on toggle (order matters)
    "traverser_symbols",
    "traverser_lsp",
    "traverser_incoming",
    "traverser_outgoing",
  },
  refresh_events = { "CursorHold", "BufEnter" },  -- events that refresh call/ref panes
  keymaps = true,            -- set false to disable default keymaps, or provide a table
})
```

## Dashboard Layout

When you run `:TraverserToggle`, the following panes open:

```
+------------------+-------------------------+------------------+
|                  |                         |                  |
|    Symbols       |                         |   Incoming Calls |
|    (left)        |      Code Editor        |   (right, top)   |
|                  |                         |                  |
|                  |                         +------------------+
|------------------+                         |                  |
|   Diagnostics    |                         |   Outgoing Calls |
|   (left, bottom) |                         |   (right, bottom)|
|                  |                         |                  |
+------------------+-------------------------+------------------+
|                    Refs / Defs (bottom)                       |
+--------------------------------------------------------------+
```

All panes follow the cursor in the code editor and auto-refresh on `CursorHold` and `BufEnter`.

## Keybindings

### Suggested Global Keymaps

These are not set by the plugin itself -- bind them in your config:

```lua
-- Dashboard
vim.keymap.set("n", "<leader>tm", "<cmd>TraverserToggle<cr>")

-- Traces
vim.keymap.set("n", "<leader>ta", "<cmd>TraverserAddNode<cr>")    -- add/remove trace node
vim.keymap.set("n", "<leader>ty", "<cmd>TraverserTree<cr>")       -- open trace tree
vim.keymap.set("n", "<leader>tN", "<cmd>TraverserNewTrace<cr>")   -- new trace
vim.keymap.set("n", "<leader>tS", "<cmd>TraverserSwitchTrace<cr>")-- switch trace (picker)
vim.keymap.set("n", "<leader>tE", "<cmd>TraverserEdit<cr>")       -- reorder trace items
vim.keymap.set("n", "<leader>tc", function()                      -- jump to tag
  require("traverser.traces").prompt_and_jump()
end)

-- Focus panes
vim.keymap.set("n", "<leader>ts", "<cmd>TraverserFocusSymbols<cr>")
vim.keymap.set("n", "<leader>td", "<cmd>TraverserFocusDiagnostics<cr>")
vim.keymap.set("n", "<leader>tr", "<cmd>TraverserFocusReferences<cr>")
vim.keymap.set("n", "<leader>ti", "<cmd>TraverserFocusIncoming<cr>")
vim.keymap.set("n", "<leader>to", "<cmd>TraverserFocusOutgoing<cr>")

-- Maximize panes (toggle)
vim.keymap.set("n", "<leader>t,s", "<cmd>TraverserMaximizeSymbols<cr>")
vim.keymap.set("n", "<leader>t,d", "<cmd>TraverserMaximizeDiagnostics<cr>")
vim.keymap.set("n", "<leader>t,r", "<cmd>TraverserMaximizeReferences<cr>")
vim.keymap.set("n", "<leader>t,i", "<cmd>TraverserMaximizeIncoming<cr>")
vim.keymap.set("n", "<leader>t,o", "<cmd>TraverserMaximizeOutgoing<cr>")

-- Symbol pickers
vim.keymap.set("n", "<C-p>",      "<cmd>TraverserSymbolsBuf<cr>")
vim.keymap.set("n", "<leader>O",  "<cmd>TraverserSymbolsWorkspace<cr>")

-- Navigation (next/prev in last-focused Trouble pane)
vim.keymap.set("n", "<leader>J",  "<cmd>TraverserNext<cr>")
vim.keymap.set("n", "<leader>K",  "<cmd>TraverserPrev<cr>")
```

### Inside Trouble Panes

| Key | Description |
|-----|-------------|
| `S` | Cycle severity filter (0 = off, 1 = Error, 2 = Warn, 3 = Info, 4 = Hint) |
| `L` | Toggle library filter (outgoing calls only). Hides items from `/usr`, `/pkg/mod/`, `/vendor/`, `node_modules`. |
| `<C-r>` | **Scoped references.** From the incoming/outgoing calls pane, find all references to the item under cursor filtered to the enclosing function in the code window. Results go to the quickfix list (1 result jumps directly). |

### Inside Edgy-managed Windows

| Key | Description |
|-----|-------------|
| `<C-Right>` / `<C-Left>` | Fine resize width (+/- 2) |
| `<C-Up>` / `<C-Down>` | Fine resize height (+/- 2) |

### Inside the Trace Editor Float

| Key | Description |
|-----|-------------|
| `<C-k>` | Move item up |
| `<C-j>` | Move item down |
| `q` | Save order and close |

### Inside Symbol Pickers

**Telescope:** `<C-e>` to peek (jump in code window without closing picker), `<C-d>` to delete trace, `<C-r>` to rename trace.

**Snacks:** Selection change automatically peeks. `<C-d>` to delete trace, `<C-r>` to rename trace.

## Traces

Traces are named, ordered collections of code bookmarks. Use them to mark a path through your codebase.

- **Add a node:** Place your cursor on a line and run `:TraverserAddNode`. An extmark appears and the location is saved. Run it again on the same line to remove it.
- **Tags:** Each item gets an alphabetical tag (`[a]`, `[b]`, ..., `[z]`, `[aa]`, `[ab]`, ...). Jump to a tag with `:TraverserJump a` or use `<leader>tc` to type a tag letter interactively.
- **Multiple traces:** Create new traces with `:TraverserNewTrace [name]` and switch between them with `:TraverserSwitchTrace`.
- **Reorder:** Open the floating editor with `:TraverserEdit` and use `<C-j>`/`<C-k>` to rearrange items.
- **Persistence:** Traces are saved per-project (keyed by working directory) to `~/.local/share/nvim/traverser/`. They survive Neovim restarts.
- **View:** `:TraverserTree` opens a Trouble pane showing the active trace as a quickfix list.

## Scoped References (`<C-r>`)

The `<C-r>` binding in the call hierarchy panes solves a specific problem: when exploring outgoing calls, you want to see *where in the caller's function body* a callee is referenced -- not every reference in the entire project.

**How it works:**

1. Cursor is on an item in the incoming/outgoing calls pane
2. Treesitter detects the enclosing function in the code window
3. Jumps to the item's definition, requests `textDocument/references` from LSP
4. Filters results to only those within the caller function's line range
5. If 1 result: jumps directly. If multiple: populates quickfix with title "Scoped refs (in caller)"

**Limitation:** The code window must be showing the caller's file for treesitter scope detection to work. If it isn't, you'll see a warning: "Navigate to the caller's file first."

## Commands

| Command | Description |
|---------|-------------|
| `TraverserToggle` | Toggle the dashboard |
| `TraverserOpen` | Open the dashboard |
| `TraverserClose` | Close the dashboard |
| `TraverserAddNode` | Toggle a trace bookmark at cursor |
| `TraverserTree` | Open the trace tree pane |
| `TraverserNewTrace` | Create a new trace (optional: name) |
| `TraverserSwitchTrace` | Pick a trace to switch to |
| `TraverserEdit` | Floating editor to reorder trace items |
| `TraverserJump` | Jump to a trace tag (e.g. `:TraverserJump a`) |
| `TraverserFocusSymbols` | Focus the symbols pane |
| `TraverserFocusDiagnostics` | Focus the diagnostics pane |
| `TraverserFocusReferences` | Focus the references pane |
| `TraverserFocusIncoming` | Focus the incoming calls pane |
| `TraverserFocusOutgoing` | Focus the outgoing calls pane |
| `TraverserMaximizeSymbols` | Toggle-maximize the symbols pane |
| `TraverserMaximizeDiagnostics` | Toggle-maximize the diagnostics pane |
| `TraverserMaximizeReferences` | Toggle-maximize the references pane |
| `TraverserMaximizeIncoming` | Toggle-maximize the incoming calls pane |
| `TraverserMaximizeOutgoing` | Toggle-maximize the outgoing calls pane |
| `TraverserSymbolsBuf` | Buffer symbols picker (with peek) |
| `TraverserSymbolsWorkspace` | Workspace symbols picker (with peek) |
| `TraverserNext` | Next item in last-focused Trouble pane |
| `TraverserPrev` | Previous item in last-focused Trouble pane |

## Development

From the repo root:

```sh
make test
```

Runs `nvim --clean -u test/init.lua`. First launch clones lazy.nvim and all dependencies into `.test/` (takes a minute), then you're in a clean Neovim with traverser loaded.

To open against an actual file (recommended -- LSP needs a real project):

```sh
make test-file FILE=/path/to/some/file.go
```

To configure the picker backend, edit the top of `test/init.lua`:

```lua
local USE_PICKER = "snacks"    -- or "telescope" or "auto"
```

To clean up:

```sh
make clean
```

## Architecture

```
lua/traverser/
  init.lua          -- setup(), config defaults
  trouble.lua       -- Trouble mode definitions, in-pane keybindings (S, L, <C-r>)
  edgy.lua          -- Edgy layout, resize keys, focus/maximize
  traces.lua        -- Persistent trace system (extmarks, quickfix, disk I/O)
  dashboard.lua     -- Open/close/toggle, auto-refresh autocmds
  commands.lua      -- All user commands
  picker/
    init.lua        -- Backend dispatcher (auto/telescope/snacks)
    telescope.lua   -- Telescope integration
    snacks.lua      -- Snacks.picker integration

plugin/traverser.lua  -- Deferred auto-setup fallback
test/init.lua         -- Test harness with recommended keymaps
```
