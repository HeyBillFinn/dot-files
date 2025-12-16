return {
  {
    "ctrlpvim/ctrlp.vim",
    dependencies = { "tpope/vim-vinegar" },
    keys = {
      { ",b", "<cmd>CtrlPBuffer<cr>", desc = "CtrlP Buffers" },
      { ",w", "<cmd>CtrlPCurWD<cr>", desc = "CtrlP Current Directory" },
      { ",c", "<cmd>CtrlPClearCache<cr>", desc = "CtrlP Clear Cache" },
    },
    config = function()
      vim.g.ctrlp_max_files = 0
      vim.g.ctrlp_custom_ignore = {
        dir = '\\v[\\/](dist|\\.git|build|node_modules)$',
        file = '\\v\\.(png|exe|so|dll|class|apk|pyc|bin|dex|jar|png|prepreed.c|obfuscated.c|obfmap|o)$',
      }
    end,
  },
}
