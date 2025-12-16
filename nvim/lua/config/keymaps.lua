local keymap = vim.keymap.set

keymap("n", "<Space>", "<cmd>nohlsearch<Bar>echo<CR>", { silent = true })

keymap("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

keymap("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

keymap("n", ":", ";")
keymap("n", ";", ":")

keymap("n", "-", "O<esc>")
keymap("n", "_", "o<esc>")

keymap("n", "v", "V")
keymap("n", "V", "v")

keymap("n", "n", "nzz")
keymap("n", "N", "Nzz")

keymap("n", "Y", '"+y')
keymap("v", "Y", '"+y')
keymap("n", "<leader><c-v>", ":set paste!<cr>")

keymap("n", "<C-N><C-N>", ":set invnumber<CR>:set invrelativenumber<CR>")

keymap("n", "s", ':let @0 = substitute(@0, "\\\\s\\\\+$","","g")<cr>:%s/<C-r>0/<C-r>0/g<left><left>')
keymap("n", "S", 'ea<space><esc>bdiw"0Plxb')
keymap("v", "S", '"0p')

keymap("n", ",P", ':let @+=expand("%:p")<CR>', { silent = true })

keymap("n", ",q", "<c-w>q")
keymap("n", ",=", "<c-w>=")
keymap("n", ",o", "<c-w>o")
