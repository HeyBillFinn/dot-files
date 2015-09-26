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

call vundle#end()            " required
filetype plugin indent on    " required

nnoremap ,b :CtrlPBuffer<cr>
autocmd vimenter * if !argc() | NERDTree | endif
nnoremap ,n :NERDTreeToggle<CR>

filetype on
