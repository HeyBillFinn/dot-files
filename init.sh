#! /bin/bash

# Symlink nvim config
ln -sf /Users/billfinn/dot-files/nvim /Users/billfinn/.config/nvim

# Symlink inputrc
ln -sf /Users/billfinn/dot-files/.inputrc ~/.inputrc

# Symlink tmux
ln -sf /Users/billfinn/dot-files/.tmux_min.conf ~/.tmux.conf

# Update ~/.bash_profile, so it sources ~/.bashrc
# # Source ~/.bashrc for interactive shells
# if [ -f ~/.bashrc ]; then
#   source ~/.bashrc
# fi

# Update ~/.bashrc, so it sources dot-files.bashrc
# [ -f ~/dot-files/.bashrc ] && source ~/dot-files/.bashrc
