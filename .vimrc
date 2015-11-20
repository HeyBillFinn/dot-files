set nocompatible
set clipboard=unnamed
filetype off                   " required!

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'kien/ctrlp.vim'
Plugin 'tpope/vim-vinegar'
"Plugin 'nvie/vim-flake8'
Plugin 'vimwiki/vimwiki'
Plugin 'scrooloose/syntastic'

call vundle#end()            " required
filetype plugin indent on    " required

nnoremap ,b :CtrlPBuffer<cr>
nnoremap ,w :CtrlPCurWD<cr>
let g:ctrlp_custom_ignore = {
  \   'dir': '\v[\/](dist|\.git|build)$',
  \   'file': '\v\.(exe|so|dll|class|apk|pyc|bin|dex|jar|png)$',
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
let g:syntastic_javascript_checkers=["jscs"]
let g:syntastic_mode_map = {
      \ "mode": "passive",
      \ "active_filetypes": [],
      \ "passive_filetypes": [] }
