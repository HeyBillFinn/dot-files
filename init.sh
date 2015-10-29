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
    git clone https://github.com/VundleVim/Vundle.vim ~/.vim/bundle/Vundle.vim
    second_file_arguments_to_append=( "$current_directory/.zshrc_min"
                                      "$current_directory/.bashrc_min"
                                      "$current_directory/.tmux_min.conf"
                                      "$current_directory/.vimrc" )
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

append_command_to_file ~/.zshrc "export PATH=$current_directory/bin/:\$PATH"
append_command_to_file ~/.bashrc "export PATH=$current_directory/bin/:\$PATH"
