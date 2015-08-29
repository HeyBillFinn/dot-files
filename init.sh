current_directory=${PWD}

function find_line {
  file="$1"
  line_to_find="$2"
  while read line; do
    if [ "$line_to_find" = "$line" ]
      then
        return 0
    fi
  done < "$file"
  return -1
}

function append_command_to_file {
  file="$1"
  command_to_append="$2"
  if [ -f $file ]
    then
      if find_line "$file" "$command_to_append";
        then
          echo "Command '$command_to_append' already in $file."
        else
          echo $command_to_append >> $file
      fi
    else
      echo $command_to_append >> $file
  fi
}

file=~/.zshrc
command_to_append="source $current_directory/.zshrc_min" 
append_command_to_file "$file" "$command_to_append"
