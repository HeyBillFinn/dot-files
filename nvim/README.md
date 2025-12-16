# Neovim Configuration (Ported from Vim)

Modern Neovim configuration using lazy.nvim plugin manager, ported from your original .vimrc.

## Installation

The configuration is already symlinked:
```bash
~/.config/nvim -> ~/dot-files/nvim
```

Open Neovim to trigger automatic plugin installation:
```bash
nvim
```

## Key Differences from Original Vim Config

### Plugin Manager
- **Vundle** → **lazy.nvim** (faster, modern, better lazy loading)

### Mappings Changed
- `:` and `;` are swapped (as before)
- Leader key is `Space` (but many original `,` mappings preserved)
- Git gutter uses `<c-j>/<c-k>` for next/prev hunk (as before)

## Keybindings

### Core Mappings
- `Space` - Clear search highlight
- `:` / `;` - Swapped (use `;` for commands)
- `-` - Insert line above
- `_` - Insert line below
- `v` / `V` - Swapped (v for visual line, V for visual char)
- `n` / `N` - Center screen after search
- `Y` - Yank to system clipboard
- `<C-N><C-N>` - Toggle line numbers

### Leader Mappings (Leader = Space)
- `<leader>n` - Toggle NERDTree
- `<leader>f` - Focus NERDTree
- `<leader>a` - ArgWrap
- `<leader>b` - CtrlP buffers
- `<leader>w` - CtrlP current working directory
- `<leader>c` - CtrlP clear cache
- `<leader>P` - Copy full file path to clipboard
- `<leader>t` - Copy test name to clipboard
- `<leader>m` - Copy method name to clipboard
- `<leader>q` - Close window
- `<leader>=` - Equalize window sizes
- `<leader>o` - Close other windows
- `<leader><c-v>` - Toggle paste mode
- `<leader>[` - Toggle long line highlight (80+ columns)

### Window Navigation (Smart Split)
- `<leader>h/j/k/l` - Move to window or create split if at edge

### Git (GitGutter)
- `]p` - Preview hunk
- `]r` - Undo hunk
- `<c-j>` - Next hunk
- `<c-k>` - Previous hunk

### ALE (Linting/Fixing)
- `<F5>` - Fix with ALE
- `<F8>` - Previous error
- `<F9>` - Next error
- `<leader>r` - Remove unused Python imports
- `<leader>z` - Run za-fix-style
- `<leader>F` - Run clang-format

### Telescope
- `<leader>ff` - Find files
- `<leader>fg` - Live grep
- `<leader>fb` - Find buffers
- `<leader>fh` - Find help

## Plugins

### File Navigation
- **NERDTree** - File tree explorer
- **CtrlP** - Fuzzy file finder
- **vim-vinegar** - Enhanced netrw
- **Telescope** - Modern fuzzy finder

### Git
- **vim-gitgutter** - Git diff in sign column

### Editing
- **vim-surround** - Surround text objects
- **vim-argwrap** - Wrap/unwrap function arguments
- **Tabular** - Text alignment
- **vim-unstack** - Parse stack traces

### Languages
- **vim-polyglot** - Language pack (includes Terraform, etc.)
- **kotlin-vim** - Kotlin support
- **JavaScript-Indent** - JavaScript indentation
- **pythonhelper** - Python utilities
- **nvim-treesitter** - Better syntax highlighting

### Linting/Formatting
- **ALE** - Async Lint Engine
  - Python: flake8, black, isort, autoflake
  - JavaScript: eslint
  - Ruby: rubocop
  - C/C++: clang-format

### Colorschemes
- **darkblue** - Default (Vim built-in)
- **github-vim** - GitHub theme (available)
- **tokyonight.nvim** - Modern theme (available)

## Auto Commands

### Whitespace Trimming
Auto-removes trailing whitespace on save for:
- conf, xml, java, vim, c, cpp, php, ruby, python, javascript

### Indentation
4-space indentation for:
- xml, python, javascript, html, java, c

### Git Commits
- Text width set to 72 columns

### Markdown
- Enables autocomplete for Stripe usernames

## Custom Functions

### Available Commands
- `:Sqlformat` - Format SQL (requires sqlformat tool)
- `:RemoveUnusedImportsPy` - Remove unused Python imports
- `:ZaFixStyle` - Run za-fix-style formatter
- `:ClangFormat` - Run clang-format

### Custom Functions (mapped)
- Copy test/method names (Python-specific)
- Smart window navigation with auto-split
- Toggle long line highlight
- Luhn checksum calculator (defined but not mapped)

## Configuration Structure

```
nvim/
├── init.lua                    # Entry point
├── lua/
│   ├── config/
│   │   ├── lazy.lua           # Plugin manager setup
│   │   ├── options.lua        # Vim options
│   │   ├── keymaps.lua        # Core keybindings
│   │   ├── functions.lua      # Custom functions
│   │   └── autocmds.lua       # Auto commands
│   └── plugins/
│       ├── ale.lua            # Linting/formatting
│       ├── colorscheme.lua    # Color schemes
│       ├── ctrlp.lua          # Fuzzy finder
│       ├── editing.lua        # Editing enhancements
│       ├── git.lua            # Git integration
│       ├── languages.lua      # Language support
│       ├── nerdtree.lua       # File tree
│       ├── telescope.lua      # Modern fuzzy finder
│       └── treesitter.lua     # Syntax highlighting
└── README.md
```

## Plugin Manager Commands

- `:Lazy` - Open lazy.nvim UI
- `:Lazy sync` - Install/update/clean plugins
- `:Lazy update` - Update plugins
- `:Lazy clean` - Remove unused plugins
- `:Lazy profile` - Profile startup time

## Notes

- ALE paths for Python tools may need adjustment for your system
- Some features require external tools (sqlformat, za-fix-style, etc.)
- GitGutter refresh time set to 500ms for faster updates
- Colorcolumn set at 80 characters by default
