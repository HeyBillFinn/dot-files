local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

local trim_whitespace = augroup("TrimWhitespace", { clear = true })
autocmd("FileType", {
  pattern = { "conf", "xml", "java", "vim", "c", "cpp", "php", "ruby", "python", "javascript" },
  group = trim_whitespace,
  callback = function()
    autocmd("BufWritePre", {
      buffer = 0,
      command = [[%s/\s\+$//e]],
    })
  end,
})

local filetype_settings = augroup("FiletypeSettings", { clear = true })
autocmd("FileType", {
  pattern = { "xml", "python", "javascript", "html", "java", "c" },
  group = filetype_settings,
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
})

autocmd("FileType", {
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.textwidth = 72
  end,
})

autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    require('config.functions').add_stripes()
  end,
})

vim.api.nvim_create_user_command("Sqlformat", "%!sqlformat --reindent --keywords upper --identifiers lower -", {})
