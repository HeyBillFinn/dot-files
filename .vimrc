set nocompatible
filetype off                   " required!

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
Bundle 'scrooloose/nerdtree'
Bundle 'kien/ctrlp.vim'
nnoremap ,b :CtrlPBuffer<cr>

filetype on
