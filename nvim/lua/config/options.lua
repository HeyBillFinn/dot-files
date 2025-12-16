local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.incsearch = true
opt.wrap = false
opt.breakindent = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.updatetime = 500
opt.timeoutlen = 300
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 8
opt.backspace = "indent,eol,start"
opt.wildmode = "longest,list,full"
opt.wildmenu = true
opt.wildignore:append("*/tmp/*,*.so,*.swp,*.zip,*.pyc")
opt.listchars = { tab = "▸ ", trail = "·" }
opt.list = true
opt.laststatus = 2
opt.colorcolumn = "80"
opt.backup = false
opt.writebackup = false
opt.backupcopy = "no"
opt.re = 0
