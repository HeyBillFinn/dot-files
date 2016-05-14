#!/bin/bash

SESSIONNAME="za"

vagrant_ssh() {
  tmux send-keys -t $SESSIONNAME "cd ~/Projects/payg-development/swat" C-m
  tmux send-keys -t $SESSIONNAME "vagrant ssh" C-m
  sleep 1
}

configure_tmux_window() {
  name=$1
  vagrant_ssh
  tmux send-keys -t $SESSIONNAME "cd ~/Projects/Angaza/payg-$name" C-m
  tmux send-keys -t $SESSIONNAME "vim" C-m
  tmux split-window -t $SESSIONNAME
  tmux resize-pane -t $SESSIONNAME -D 8
  vagrant_ssh
  tmux send-keys -t $SESSIONNAME "cd ~/Projects/Angaza/payg-$name" C-m
  tmux rename-window  -t $SESSIONNAME "$name"
}

tmux has-session -t $SESSIONNAME &> /dev/null

if [ $? != 0 ]; then
  tmux new-session -s $SESSIONNAME -d

  configure_tmux_window "backend"

  tmux new-window -t $SESSIONNAME
  configure_tmux_window "ui"

  tmux new-window -t $SESSIONNAME
  configure_tmux_window "deploy"

  tmux new-window -t $SESSIONNAME
  configure_tmux_window "agent-ui"

  #tmux new-window -t $SESSIONNAME
  #configure_tmux_window "embedded"

  #tmux new-window -t $SESSIONNAME
  #configure_tmux_window "client"

  tmux new-window -t $SESSIONNAME
  vagrant_ssh
  tmux send-keys -t $SESSIONNAME "cd ~/Projects/Angaza/payg-backend" C-m
  tmux split-window -t $SESSIONNAME -h
  vagrant_ssh
  tmux send-keys -t $SESSIONNAME "cd ~/Projects/Angaza/payg-backend" C-m
  tmux send-keys -t $SESSIONNAME "ngrok http -subdomain=za 80"
  tmux split-window -t $SESSIONNAME
  vagrant_ssh
  tmux send-keys -t $SESSIONNAME "cd ~/Projects/Angaza/payg-backend" C-m
  tmux select-pane -L -t $SESSIONNAME
  tmux split-window -t $SESSIONNAME
  vagrant_ssh
  tmux send-keys -t $SESSIONNAME "cd ~/Projects/Angaza/payg-backend" C-m
  tmux rename-window  -t $SESSIONNAME "server"
fi

tmux attach -t $SESSIONNAME
