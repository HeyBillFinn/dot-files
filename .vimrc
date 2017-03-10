set nocompatible
set clipboard=unnamed
filetype off                   " required!

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'kien/ctrlp.vim'
Plugin 'tpope/vim-vinegar'
Plugin 'tpope/vim-fugitive'
"Plugin 'nvie/vim-flake8'
Plugin 'vim-scripts/JavaScript-Indent'
Plugin 'vimwiki/vimwiki'
Plugin 'scrooloose/syntastic'
Plugin 'airblade/vim-gitgutter'
Plugin 'tpope/vim-surround'
"Plugin 'bling/vim-airline'
Plugin 'godlygeek/tabular'
Plugin 'plasticboy/vim-markdown'
let g:airline#extensions#branch#displayed_head_limit = 10

call vundle#end()            " required
filetype plugin indent on    " required

nnoremap ]p :GitGutterPreview<cr>
nnoremap ]r :GitGutterRevert<cr>

nnoremap ,b :CtrlPBuffer<cr>
nnoremap ,w :CtrlPCurWD<cr>
nnoremap ,c :CtrlPClearCache<cr>
let g:ctrlp_custom_ignore = {
  \   'dir': '\v[\/](dist|\.git|build|node_modules)$',
  \   'file': '\v\.(exe|so|dll|class|apk|pyc|bin|dex|jar|png|prepreed.c|obfuscated.c|obfmap|o)$',
  \ }
"Auto-open NerdTree for empty vim session
"autocmd vimenter * if !argc() | NERDTree | endif
nnoremap ,n :NERDTreeToggle<CR>
nnoremap ,f :NERDTreeFocus<CR>
let NERDTreeIgnore = ['\.pyc$']
au FileType gitcommit set tw=72
nnoremap <F7> :SyntasticCheck<cr>:ll<cr>
nnoremap <F9> :lnext<cr>
nnoremap <F8> :lprevious<cr>

let g:syntastic_enable_highlighting = 0
let g:syntastic_enable_signs = 0
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_javascript_checkers = ['eslint']
" Allow Syntastic to find eslint
let $PATH .= ':' . getcwd() . '/node_modules/.bin'
let $PATH .= ':/home/vagrant/local/node-linux-x64/bin'
let g:syntastic_mode_map = {
      \ "mode": "passive",
      \ "active_filetypes": ['javascript'],
      \ "passive_filetypes": [] }
