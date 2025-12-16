return {
  {
    "dense-analysis/ale",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      vim.g.ale_python_black_executable = '/home/vagrant/local/venv36/bin/black'
      vim.g.ale_fixers = {
        ['*'] = {'remove_trailing_lines', 'trim_whitespace'},
        python = {'isort', 'black'},
        javascript = {'eslint'},
      }
      vim.g.ale_python_flake8_executable = '/home/vagrant/local/venv/bin/flake8'
      vim.g.ale_linters = {
        python = {'flake8'},
        javascript = {'eslint'},
        ruby = {'rubocop'},
      }
      vim.g.ale_ruby_rubocop_executable = 'bundle'

      vim.keymap.set("n", "<F5>", "<Plug>(ale_fix)")
      vim.keymap.set("n", "<F8>", "<Plug>(ale_previous_wrap)")
      vim.keymap.set("n", "<F9>", "<Plug>(ale_next_wrap)")

      local function remove_unused_imports_py(buffer)
        local file_path = vim.fn.expand("#" .. buffer .. ":p")
        vim.fn.system('isort -sl ' .. file_path .. ' > /dev/null && autoflake --remove-all-unused-imports --in-place ' .. file_path .. ' > /dev/null && isort ' .. file_path .. ' > /dev/null')
        return 0
      end

      local function za_fix_style(buffer)
        local file_path = vim.fn.expand("#" .. buffer .. ":p")
        vim.fn.system('za-fix-style ' .. file_path .. '> /dev/null')
        return 0
      end

      local function clang_format(buffer)
        local file_path = vim.fn.expand("#" .. buffer .. ":p")
        vim.fn.system('clang-format -i ' .. file_path .. '> /dev/null')
        return 0
      end

      vim.api.nvim_create_user_command("RemoveUnusedImportsPy", function()
        remove_unused_imports_py(vim.fn.bufnr())
      end, {})

      vim.api.nvim_create_user_command("ZaFixStyle", function()
        za_fix_style(vim.fn.bufnr())
      end, {})

      vim.api.nvim_create_user_command("ClangFormat", function()
        clang_format(vim.fn.bufnr())
      end, {})

      vim.keymap.set("n", ",r", ":RemoveUnusedImportsPy<bar>e<CR>")
      vim.keymap.set("n", ",z", ":ZaFixStyle<bar>e<CR>")
      vim.keymap.set("n", ",F", ":ClangFormat<bar>e<CR>")

      vim.api.nvim_create_augroup("ALEProgress", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        pattern = "ALEFixPre",
        group = "ALEProgress",
        command = "hi Statusline ctermbg=darkgrey",
      })
      vim.api.nvim_create_autocmd("User", {
        pattern = "ALEFixPost",
        group = "ALEProgress",
        command = "hi Statusline ctermbg=white",
      })
    end,
  },
}
