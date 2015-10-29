#!/bin/bash

SESSIONNAME="za"

vagrant_ssh() {
  tmux send-keys -t $SESSIONNAME "cd ~/Projects/payg-development/swat" C-m
  tmux send-keys -t $SESSIONNAME "vagrant ssh" C-m
}

execute_commands() {
  declare -a cmds=("${!1}")
  for ((i = 0; i < ${#cmds[@]}; i++)); do
    echo ${cmds[$i]}
    tmux send-keys -t $SESSIONNAME "${cmds[$i]}" C-m
  done
}

configure_tmux_window() {
  name=$1
  declare -a top_cmds=("${!2}")
  declare -a bottom_cmds=("${!3}")
  vagrant_ssh
  execute_commands top_cmds[@]
  sleep 1
  tmux split-window -t $SESSIONNAME
  tmux resize-pane -t $SESSIONNAME -D 8
  vagrant_ssh
  execute_commands bottom_cmds[@]
  tmux rename-window  -t $SESSIONNAME "$name"
}

tmux has-session -t $SESSIONNAME &> /dev/null

if [ $? != 0 ]; then
  tmux new-session -s $SESSIONNAME -n asdf -d

  cmd_top=("cd ~/Projects/Angaza/payg-backend" "vim")
  cmd_bottom=("cd ~/Projects/Angaza/payg-backend")
  configure_tmux_window "backend" cmd_top[@] cmd_bottom[@]

#  tmux new-window -t $SESSIONNAME
#  configure_tmux_window "ui"
#
#  tmux new-window -t $SESSIONNAME
#  configure_tmux_window "deploy"
#
#  tmux new-window -t $SESSIONNAME
#  configure_tmux_window "agent-ui"

fi

tmux attach -t $SESSIONNAME
