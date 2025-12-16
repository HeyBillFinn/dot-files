# Migration Guide: Vim → Neovim

## What Was Ported

### ✅ All Vundle Plugins → lazy.nvim
- NERDTree
- CtrlP + vim-vinegar
- vim-gitgutter
- vim-surround
- vim-argwrap
- Tabular
- vim-polyglot
- kotlin-vim
- JavaScript-Indent
- pythonhelper
- github-vim colorscheme
- ALE (linting/formatting)
- vim-unstack

### ✅ All Settings
- Tab/indent settings (2 spaces, expandtab)
- Line numbers (number + relativenumber)
- Search settings (incsearch, hlsearch, ignorecase, smartcase)
- Clipboard integration
- Wildmenu configuration
- Colorcolumn at 80
- Listchars (tab/trail markers)
- All performance settings (re=0, updatetime, etc.)

### ✅ All Keybindings
- `:` and `;` swap
- Window navigation with smart split creation
- NERDTree toggles
- CtrlP shortcuts
- GitGutter navigation
- ALE shortcuts
- All editing shortcuts (Y for system clipboard, etc.)
- Custom function mappings

### ✅ All Custom Functions
- `WinMove()` - Smart window navigation with auto-split
- `CopyTest()` - Copy Python test name
- `CopyMethod()` - Copy Python method name
- `RemoveUnusedImportsPy()` - Python import cleanup
- `ZaFixStyle()` - za-fix-style formatter
- `ClangFormat()` - clang-format runner
- `LuhnChecksumDigit()` - Luhn algorithm
- `AddStripes()` - Markdown autocomplete for Stripe usernames
- Long line highlight toggle

### ✅ All Auto Commands
- Trailing whitespace removal on save
- Filetype-specific indentation
- Git commit text width (72)
- Markdown Stripe autocomplete setup

### ✅ All ALE Configuration
- Linters: flake8, eslint, rubocop
- Fixers: black, isort, eslint, trim whitespace
- All custom fixer functions
- Status line color changes on fix

## What Changed

### Plugin Manager
**Before (Vundle):**
```vim
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'scrooloose/nerdtree'
call vundle#end()
```

**After (lazy.nvim):**
```lua
-- Automatic bootstrap in lua/config/lazy.lua
require("lazy").setup({ spec = { { import = "plugins" } } })
```

### Configuration Language
**Before:** VimScript (`.vimrc`)
**After:** Lua (`.lua` files)

### Configuration Structure
**Before:** Single `.vimrc` file
**After:** Modular structure
- `init.lua` - Entry point
- `lua/config/*.lua` - Core configuration
- `lua/plugins/*.lua` - Plugin specifications

### Colorscheme Loading
**Before:** Vundle managed colorschemes
**After:** Colorschemes as lazy.nvim plugins, but using built-in darkblue by default

## New Features Added

### Telescope
Modern fuzzy finder with:
- `<leader>ff` - Find files
- `<leader>fg` - Live grep
- `<leader>fb` - Buffers
- `<leader>fh` - Help tags

### Treesitter
Better syntax highlighting with automatic language installation.

### Better Plugin Management
- Lazy loading for faster startup
- Automatic updates
- Nice UI (`:Lazy`)
- Built-in profiling

## Things to Know

### Plugin Installation
First time you open Neovim, lazy.nvim will:
1. Auto-install itself
2. Auto-install all plugins
3. Show installation progress

Just open `nvim` and wait!

### Checking Configuration
```vim
:checkhealth              " Check Neovim health
:Lazy                     " Open plugin manager
:Lazy profile             " Check startup time
```

### Updating Plugins
```vim
:Lazy sync               " Update all plugins
:Lazy update             " Update without clean
:Lazy clean              " Remove unused plugins
```

### Adding New Plugins
Create a new file in `lua/plugins/`:

```lua
-- lua/plugins/myplugin.lua
return {
  {
    "author/plugin-name",
    config = function()
      -- setup here
    end,
  },
}
```

## Potential Issues

### Python Tools Paths
These may need adjustment for your system:
```lua
-- In lua/plugins/ale.lua
vim.g.ale_python_black_executable = '/home/vagrant/local/venv36/bin/black'
vim.g.ale_python_flake8_executable = '/home/vagrant/local/venv/bin/flake8'
```

Update these paths if your Python environment is different.

### External Commands
These custom commands require external tools:
- `:Sqlformat` - needs `sqlformat`
- `<leader>z` - needs `za-fix-style`
- `<leader>F` - needs `clang-format`
- `<leader>r` - needs `isort`, `autoflake`

Install these tools as needed for your workflow.

### Stripe-Specific Features
Markdown autocomplete references:
```
/Users/billfinn/dot-files/.stripe-android-usernames.txt
```

Ensure this file exists if you use the markdown autocomplete feature.

## Rollback to Vim

If you need to go back to your Vim config:
```bash
rm ~/.config/nvim
# Original .vimrc is unchanged in ~/dot-files/.vimrc
```

## Next Steps

1. **Test your workflow** - Try your common tasks
2. **Adjust paths** - Update Python tool paths if needed
3. **Explore Telescope** - Try the new fuzzy finder
4. **Check `:Lazy`** - See all installed plugins
5. **Add more plugins** - Browse [awesome-neovim](https://github.com/rockerBOO/awesome-neovim)

## Getting Help

- `:help <topic>` - Neovim built-in help
- `:Lazy` - Check plugin status
- `:checkhealth` - Diagnose issues
- `:messages` - See recent messages
