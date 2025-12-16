return {
  {
    "preservim/nerdtree",
    keys = {
      { ",n", "<cmd>NERDTreeToggle<cr>", desc = "Toggle NERDTree" },
      { ",f", "<cmd>NERDTreeFocus<cr>", desc = "Focus NERDTree" },
    },
    config = function()
      vim.g.NERDTreeIgnore = { '\\.pyc$' }
    end,
  },
}
