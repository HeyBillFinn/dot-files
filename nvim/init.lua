vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.lazy")
require("config.options")
require("config.keymaps")
require("config.functions")
require("config.autocmds")

vim.cmd("colorscheme darkblue")
