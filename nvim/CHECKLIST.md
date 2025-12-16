# Post-Migration Checklist

## ✅ Installation (Already Done)
- [x] Configuration ported to `~/dot-files/nvim/`
- [x] Symlink created: `~/.config/nvim -> ~/dot-files/nvim`
- [x] All plugins configured
- [x] All keybindings mapped
- [x] All custom functions ported

## 🚀 First Launch

### Step 1: Open Neovim
```bash
nvim
```

**Expected:** lazy.nvim will automatically:
1. Bootstrap itself
2. Install all plugins
3. Show installation progress

**Action:** Wait for installation to complete (may take 1-2 minutes)

### Step 2: Restart Neovim
```bash
# Close nvim, then reopen
nvim
```

### Step 3: Run Health Check
```vim
:checkhealth
```

**Look for:**
- ✅ Neovim version (should be 0.8+)
- ✅ Python provider
- ✅ Clipboard support
- ⚠️ Any warnings (usually safe to ignore)

## 🔧 Configuration Adjustments

### Python Tool Paths (If Needed)
Edit `nvim/lua/plugins/ale.lua`:

```lua
-- Update these paths for your system:
vim.g.ale_python_black_executable = '/path/to/your/black'
vim.g.ale_python_flake8_executable = '/path/to/your/flake8'
```

**Check current paths:**
```bash
which black
which flake8
```

### External Tools (Optional)
Install if you use these features:

```bash
# Python formatting/linting
pip install black isort flake8 autoflake

# SQL formatting
pip install sqlparse

# C/C++ formatting (if needed)
brew install clang-format  # macOS
# or apt-get install clang-format  # Linux
```

## ✅ Testing Your Workflow

### Test 1: File Navigation
- [ ] `<leader>n` - Toggle NERDTree
- [ ] `<leader>f` - Focus NERDTree  
- [ ] `<leader>ff` - Telescope find files
- [ ] `<leader>b` - CtrlP buffers

### Test 2: Window Navigation
- [ ] `<leader>h` - Move/split left
- [ ] `<leader>j` - Move/split down
- [ ] `<leader>k` - Move/split up
- [ ] `<leader>l` - Move/split right

### Test 3: Git Features
Open a file in a git repo:
- [ ] Make a change
- [ ] `]p` - Preview hunk
- [ ] `]r` - Undo hunk
- [ ] `<c-j>` - Next hunk

### Test 4: Code Editing
Open a Python/JavaScript file:
- [ ] `<leader>a` - ArgWrap function args
- [ ] `<F5>` - Auto-fix with ALE
- [ ] `<F8>/<F9>` - Navigate errors
- [ ] `<leader>r` - Remove unused imports (Python)

### Test 5: Core Remaps
- [ ] `;` - Enter command mode
- [ ] `v` - Visual line mode
- [ ] `V` - Visual char mode  
- [ ] `Y` - Yank to system clipboard
- [ ] `Space` - Clear search highlight

### Test 6: Custom Functions
- [ ] `<leader>P` - Copy file path
- [ ] `<leader>[` - Toggle long line highlight
- [ ] `<leader>=` - Equalize windows
- [ ] `<leader>o` - Close other windows

## 🔍 Troubleshooting

### Plugins Not Installing
```vim
:Lazy sync
```

### Syntax Highlighting Broken
```vim
:TSUpdate
```

### LSP/Treesitter Issues
```vim
:checkhealth telescope
:checkhealth treesitter
```

### Git Signs Not Showing
```vim
:GitGutterEnable
:GitGutterAll
```

### ALE Not Working
```vim
:ALEInfo
```
Check paths to linters/fixers in the output.

## 📊 Performance Check

### Check Startup Time
```vim
:Lazy profile
```

**Expected:** < 50ms startup time with lazy loading

### Check Loaded Plugins
```vim
:Lazy
```

**Look for:**
- Green checkmarks ✓ on all plugins
- "Loaded" count should be low initially
- Plugins load on-demand

## 📝 Optional Enhancements

### Consider Adding
- **nvim-lspconfig** - Native LSP support
- **nvim-cmp** - Autocompletion
- **vim-fugitive** - Git commands (was commented in original)
- **which-key.nvim** - Show keybinding hints
- **neo-tree** - Modern alternative to NERDTree

### Update Colorscheme
Currently using `darkblue`. Try modern alternatives:

```vim
:colorscheme tokyonight-night
:colorscheme github
```

Or install others via lazy.nvim in `lua/plugins/colorscheme.lua`.

## ✅ Final Verification

### All Features Working
- [ ] File navigation (NERDTree, CtrlP, Telescope)
- [ ] Window management (smart split navigation)
- [ ] Git integration (GitGutter)
- [ ] Code formatting (ALE)
- [ ] Syntax highlighting (Treesitter)
- [ ] Custom keybindings
- [ ] Custom functions
- [ ] Autocommands (whitespace trimming, etc.)

### Documentation Read
- [ ] Read `README.md` for full reference
- [ ] Read `MIGRATION.md` for details
- [ ] Bookmark `:help` for Neovim docs
- [ ] Know how to use `:Lazy` for plugins

## 🎉 Success!

If all items are checked, your Neovim setup is complete!

**Next steps:**
- Use Neovim daily and note any issues
- Gradually explore new plugins
- Check `:Lazy` periodically for updates
- Enjoy faster, more modern Vim!

## 🔄 Rollback (If Needed)

If something goes wrong:

```bash
# Remove Neovim config
rm ~/.config/nvim

# Your original .vimrc is safe
vim  # Works as before
```

Fix the issue, then re-symlink:
```bash
ln -s ~/dot-files/nvim ~/.config/nvim
```
