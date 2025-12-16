local M = {}

function M.win_move(key)
  local curwin = vim.fn.winnr()
  vim.cmd("wincmd " .. key)
  if curwin == vim.fn.winnr() then
    if key:match('[jk]') then
      vim.cmd("sp")
      if key == 'j' then
        vim.cmd("wincmd j")
      else
        vim.cmd("wincmd k")
      end
    else
      vim.cmd("vsp")
      if key == 'l' then
        vim.cmd("wincmd l")
      else
        vim.cmd("wincmd h")
      end
    end
  end
end

function M.copy_test()
  vim.cmd("normal ma[[w\"cye`a")
  vim.cmd("?^    def test")
  vim.cmd("normal w\"tye`a")
  vim.fn.setreg('+', vim.fn.expand('%') .. ':' .. vim.fn.getreg('c') .. '.' .. vim.fn.getreg('t'))
end

function M.copy_method()
  vim.cmd("normal ma[[w\"cye`a")
  vim.cmd("?^    def")
  vim.cmd("normal w\"tye`a")
  vim.fn.setreg('+', vim.fn.getreg('c') .. '.' .. vim.fn.getreg('t'))
end

function M.toggle_long_line_highlight()
  if vim.w.long_line_match then
    vim.opt_local.colorcolumn = "0"
    vim.w.long_line_match = nil
  else
    local cols = {}
    for i = 81, 335 do
      table.insert(cols, tostring(i))
    end
    vim.opt_local.colorcolumn = table.concat(cols, ',')
    vim.w.long_line_match = true
  end
end

function M.luhn_checksum_digit(str)
  local reverse = string.reverse(str)
  local sum = 0
  for i = 1, #reverse do
    local digit = tonumber(reverse:sub(i, i))
    if (i - 1) % 2 == 0 then
      digit = digit * 2
      if digit > 9 then
        digit = digit - 9
      end
    end
    sum = sum + digit
  end
  local remainder = sum % 10
  return remainder == 0 and 0 or (10 - remainder)
end

function M.add_stripes()
  vim.opt_local.complete:append('k')
  vim.opt_local.dictionary:append('/Users/billfinn/dot-files/.stripe-android-usernames.txt')
  vim.opt_local.iskeyword:append('-')
  vim.opt_local.iskeyword:append('/')
end

vim.keymap.set("n", ",h", function() M.win_move('h') end, { silent = true })
vim.keymap.set("n", ",k", function() M.win_move('k') end, { silent = true })
vim.keymap.set("n", ",l", function() M.win_move('l') end, { silent = true })
vim.keymap.set("n", ",j", function() M.win_move('j') end, { silent = true })

vim.keymap.set("n", ",t", M.copy_test, { silent = true })
vim.keymap.set("n", ",m", M.copy_method, { silent = true })

vim.keymap.set("n", ",[", M.toggle_long_line_highlight, { silent = true })

return M
