set nocompatible
set clipboard=unnamed
filetype off                   " required!

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
Bundle 'scrooloose/nerdtree'
Bundle 'kien/ctrlp.vim'

nnoremap ,b :CtrlPBuffer<cr>
autocmd vimenter * if !argc() | NERDTree | endif
nnoremap ,n :NERDTreeToggle<CR>

filetype on
