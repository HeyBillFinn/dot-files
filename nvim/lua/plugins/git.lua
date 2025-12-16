return {
  {
    "airblade/vim-gitgutter",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      vim.keymap.set("n", "]p", ":GitGutterPreviewHunk<cr>")
      vim.keymap.set("n", "]r", ":GitGutterUndoHunk<cr>")
      vim.keymap.set("n", "<c-j>", ":GitGutterNextHunk<cr>")
      vim.keymap.set("n", "<c-k>", ":GitGutterPrevHunk<cr>")
      vim.opt.updatetime = 500
    end,
  },
}
