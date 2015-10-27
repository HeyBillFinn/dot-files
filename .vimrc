set nocompatible
set clipboard=unnamed
filetype off                   " required!

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'kien/ctrlp.vim'
Plugin 'tpope/vim-vinegar'
Plugin 'nvie/vim-flake8'
Plugin 'vimwiki/vimwiki'

call vundle#end()            " required
filetype plugin indent on    " required

nnoremap ,b :CtrlPBuffer<cr>
nnoremap ,w :CtrlPCurWD<cr>
let g:ctrlp_custom_ignore = {
  \   'dir': '\v[\/]dist$',
  \   'file': '\.pyc$',
  \ }
"Auto-open NerdTree for empty vim session
"autocmd vimenter * if !argc() | NERDTree | endif
nnoremap ,n :NERDTreeToggle<CR>
nnoremap ,f :NERDTreeFocus<CR>
let NERDTreeIgnore = ['\.pyc$']
au FileType gitcommit set tw=72
nnoremap <F9> :cn<cr>
nnoremap <F8> :cp<cr>
