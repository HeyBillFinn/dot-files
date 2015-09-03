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
    fi
  else
    echo "File $file doesn't exist. Creating it."
    echo $command_to_append >> $file
  fi
}

files_to_edit=( ~/.zshrc ~/.bashrc ~/.tmux.conf ~/.vimrc )
commands_to_append=( "source" "source" "source-file" "source" )
file_arguments_to_append=( "$current_directory/.zshrc_min"
                              "$current_directory/.bashrc_min"
                              "$current_directory/.tmux_min.conf"
                              "$current_directory/.vimrc_min" )

num_files_to_edit=${#files_to_edit[@]}
num_commands_to_append=${#commands_to_append[@]}
num_arguments_to_append=${#file_arguments_to_append[@]}
if [ $num_files_to_edit -ne $num_commands_to_append ] ||
   [ $num_files_to_edit -ne $num_arguments_to_append ]; then
  echo "Number of commands and number of files should be the same."
  exit -1
fi

for i in `seq 1 $num_files_to_edit`; do
  file=${files_to_edit[$i-1]}
  command_to_append=${commands_to_append[$i-1]}
  file_argument_to_append=${file_arguments_to_append[$i-1]}
  if [ ! -f $file_argument_to_append ]; then
    echo "File $file_argument_to_append does not exist."
    exit -1
  fi
  append_command_to_file $file "$command_to_append $file_argument_to_append"
done
