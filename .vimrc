set nocompatible
set clipboard=unnamed
filetype off                   " required!

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
"Plugin 'Vimjas/vim-python-pep8-indent'
Plugin 'FooSoft/vim-argwrap'
Plugin 'VundleVim/Vundle.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'kien/ctrlp.vim'
Plugin 'tpope/vim-vinegar'
"Plugin 'tpope/vim-fugitive'
"Plugin 'nvie/vim-flake8'
Plugin 'vim-scripts/JavaScript-Indent'
" Plugin 'vimwiki/vimwiki'
" Plugin 'scrooloose/syntastic'
Plugin 'airblade/vim-gitgutter'
Plugin 'tpope/vim-surround'
"Plugin 'bling/vim-airline'
Plugin 'godlygeek/tabular'
"Plugin 'plasticboy/vim-markdown'
Plugin 'mgedmin/pythonhelper'
Plugin 'solars/github-vim'
Plugin 'w0rp/ale'
Plugin 'mattboehm/vim-unstack'
let g:airline#extensions#branch#displayed_head_limit = 10

call vundle#end()            " required
filetype plugin indent on    " required

nnoremap ]p :GitGutterPreviewHunk<cr>
nnoremap ]r :GitGutterUndoHunk<cr>
nnoremap <c-j> :GitGutterNextHunk<cr>
nnoremap <c-k> :GitGutterPrevHunk<cr>
" Help gitgutter refresh faster
set updatetime=500

nnoremap ,b :CtrlPBuffer<cr>
nnoremap ,w :CtrlPCurWD<cr>
nnoremap ,c :CtrlPClearCache<cr>
let g:ctrlp_custom_ignore = {
  \   'dir': '\v[\/](dist|\.git|build|node_modules)$',
  \   'file': '\v\.(exe|so|dll|class|apk|pyc|bin|dex|jar|png|prepreed.c|obfuscated.c|obfmap|o)$',
  \ }
"Auto-open NerdTree for empty vim session
"autocmd vimenter * if !argc() | NERDTree | endif

augroup ALEProgress
  autocmd!
  autocmd User ALEFixPre  hi Statusline ctermbg=darkgrey
  autocmd User ALEFixPost hi Statusline ctermbg=white
augroup end

nnoremap ,a :ArgWrap<CR>
" let g:argwrap_wrap_closing_brace = 0
nnoremap ,n :NERDTreeToggle<CR>
nnoremap ,f :NERDTreeFocus<CR>
let NERDTreeIgnore = ['\.pyc$']
au FileType gitcommit set tw=72
" nnoremap <F6> :SyntasticReset<cr>
" nnoremap <F7> :SyntasticCheck<cr>:ll<cr>
" nnoremap <F9> :lnext<cr>
" nnoremap <F8> :lprevious<cr>
nmap <F5> <Plug>(ale_fix)
nmap <F8> <Plug>(ale_previous_wrap)
nmap <F9> <Plug>(ale_next_wrap)
nnoremap ,r :ALEFix RemoveUnusedImportsPy <bar> e<CR>
nnoremap ,z :ALEFix ZaFixStyle <bar> e<CR>
nnoremap ,F :ALEFix ClangFormat <bar> e<CR>

function RemoveUnusedImportsPy(buffer)
  let l:filePath = expand("#" . a:buffer . ":p")
  exec system('isort -sl ' . l:filePath . ' > /dev/null && autoflake --remove-all-unused-imports --in-place ' . l:filePath . ' > /dev/null && isort ' . l:filePath . ' > /dev/null')
  return 0
endfunction

function ZaFixStyle(buffer)
  let l:filePath = expand("#" . a:buffer . ":p")
  exec system('za-fix-style ' . l:filePath . '> /dev/null')
  return 0
endfunction

let g:ale_python_black_executable = '/home/vagrant/local/venv36/bin/black'
let g:ale_fixers = { '*': ['remove_trailing_lines', 'trim_whitespace'], 'python': ['isort', 'black'], 'javascript': ['eslint'] }
let g:ale_python_flake8_executable = '/home/vagrant/local/venv/bin/flake8'

" let g:ale_enabled = 0
let g:ale_linters = { 'python': ['flake8'], 'javascript': ['eslint'] }
" let g:ale_lint_on_enter = 0
" let g:ale_lint_on_filetype_changed = 0
" let g:ale_lint_on_insert_leave = 0
" let g:ale_lint_on_save = 0
" let g:ale_lint_on_text_changed = 'never'

" let g:syntastic_enable_highlighting = 0
" let g:syntastic_enable_signs = 0
" let g:syntastic_always_populate_loc_list = 1
" let g:syntastic_auto_loc_list = 1
" let g:syntastic_check_on_wq = 0
" let g:syntastic_javascript_checkers = ['eslint']
" let g:syntastic_python_checkers = ['flake8']
" " Allow Syntastic to find eslint
" let $PATH .= ':' . getcwd() . '/node_modules/.bin'
" let $PATH .= ':/home/vagrant/local/node-linux-x64/bin'
" let g:syntastic_mode_map = {
"       \ "mode": "passive",
"       \ "active_filetypes": [],
"       \ "passive_filetypes": [] }
set statusline=%<%f\ %h%m%r\ %1*%{TagInStatusLine()}%*%=%-14.(%l,%c%V%)\ %P
