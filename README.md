# dot-files

These are my dot-files.

# Helpful Ubuntu Tools

- Remap capslock to ctrl using `gnome-tweak-tool`
```
sudo apt-get install unity-tweak-tool gnome-tweak-tool
```
- Manage multiple clipboards using [CopyQ](https://github.com/hluk/CopyQ)
- Take better screenshots using `shutter`
```
sudo add-apt-repository ppa:shutter/ppa
sudo apt-get update && sudo apt-get install shutter
```
- Make `shutter` override built-in printscreen hotkeys using Compiz
```
sudo apt-get install compizconfig-settings-manager
```
- Make shared clipboard work.
```
sudo apt-get install xauth xsel
```
- Make iPython use vim key bindings
```
ipython profile create
c.TerminalInteractiveShell.editing_mode = 'vi'

# cf. http://stackoverflow.com/a/38329940
```

