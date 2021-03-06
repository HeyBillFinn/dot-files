#! /bin/bash

current_directory=${PWD}

function find_line {
  file="$1"
  line_to_find="$2"
  while read line; do
    if [ "$line_to_find" = "$line" ]; then
      return 0
    fi
  done < "$file"
  return -1
}

function append_command_to_file {
  file="$1"
  command_to_append="$2"
  if [ -f $file ]; then
    if find_line "$file" "$command_to_append"; then
      echo "Command '$command_to_append' already in $file."
    else
      echo $command_to_append >> $file
      echo "Appended $command_to_append to $file."
    fi
  else
    echo "File $file doesn't exist. Creating it."
    echo $command_to_append > $file
  fi
}

files_to_edit=( ~/.zshrc ~/.bashrc ~/.tmux.conf ~/.vimrc )
commands_to_append=( "source" "source" "source-file" "source" )
file_arguments_to_append=( "$current_directory/.zshrc_min"
                           "$current_directory/.bashrc_min"
                           "$current_directory/.tmux_min.conf"
                           "$current_directory/.vimrc_min" )
FULL=0
if [ -n "$1" ]; then
  case $1 in
    -f)
    FULL=1
    rm -rf ~/.vim/bundle/Vundle.vim
    git clone https://github.com/VundleVim/Vundle.vim ~/.vim/bundle/Vundle.vim
    # pip install watchdog
    # vim-gnome provides clipboard support
    sudo apt-get install tmux ack-grep ctags vim-gnome silversearcher-ag python-pip uuid
    # Install vim 8.x
    sudo add-apt-repository ppa:jonathonf/vim
    sudo apt update
    sudo apt install vim

    sudo apt install moreutils

    # Make shared clipboard work from vagrant guest using lxc:
    sudo apt-get install xauth xsel

    # FZF
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --completion --no-key-bindings --update-rc

    sudo pip install virtualenv
    mkdir -p ~/local
    if [ ! -d ~/local/venv ]; then
        virtualenv ~/local/venv
    fi
    # Let's always activate our virtual env
    source ~/local/venv/bin/activate
    pip install watchdog
    pip install nose-progressive
    mkdir -p ~/.config
    if [ ! -f ~/.config/flake8 ]; then
      echo "[flake8]" > ~/.config/flake8
      echo "max-line-length = 80" >> ~/.config/flake8
    fi
    second_file_arguments_to_append=( "$current_directory/.zshrc_min"
                                      "$current_directory/.bashrc"
                                      "$current_directory/.tmux_min.conf"
                                      "$current_directory/.vimrc" )
    git config --global user.name "Bill Finn"
    git config --global alias.br "for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'"
    git config --global alias.ld "log --all --decorate"
    ;;
    *)
    echo "Unknown argument $1."
    exit -1
    ;;
  esac
fi

num_files_to_edit=${#files_to_edit[@]}
num_commands_to_append=${#commands_to_append[@]}
num_arguments_to_append=${#file_arguments_to_append[@]}
if [ $num_files_to_edit -ne $num_commands_to_append ] ||
   [ $num_files_to_edit -ne $num_arguments_to_append ]; then
  echo "Number of commands and number of files should be the same."
  exit -1
fi

ERROR=0
for i in `seq 1 $num_files_to_edit`; do
  file_argument_to_append=${file_arguments_to_append[$i-1]}
  if [ ! -e "$file_argument_to_append" ]; then
    echo "File not found: $file_argument_to_append"
    ERROR=1
  fi
done
if [ $ERROR -eq 1 ] ; then
  exit -1
fi

for i in `seq 1 $num_files_to_edit`; do
  file=${files_to_edit[$i-1]}
  cmd_to_append=${commands_to_append[$i-1]}
  file_argument_to_append=${file_arguments_to_append[$i-1]}
  append_command_to_file $file "$cmd_to_append $file_argument_to_append"
  if [ $FULL -eq 1 ]; then
    second_file_argument_to_append=${second_file_arguments_to_append[$i-1]}
    append_command_to_file $file "$cmd_to_append $second_file_argument_to_append"
  fi
done

append_command_to_file ~/.inputrc "set editing-mode vi"

append_command_to_file ~/.zshrc "export PATH=$current_directory/bin/:\$PATH"
append_command_to_file ~/.bashrc "export PATH=$current_directory/bin/:\$PATH"
# Sourcing the virtual env should be last, please
if [ $FULL -eq 1 ]; then
  append_command_to_file ~/.bashrc "source ~/local/venv/bin/activate"
fi
