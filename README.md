# dot-files

These are my dot-files.

# Helpful Ubuntu Tools

- Remap capslock to ctrl using `gnome-tweak-tool`
```
sudo apt-get install unity-tweak-tool gnome-tweak-tool
```
- Manage multiple clipboards using [CopyQ](https://github.com/hluk/CopyQ)
  - Global shortcut:
    - <c-s-1> Show main window
    - <c-s-@> Copy second item
- Take better screenshots using `shutter`
```
sudo add-apt-repository ppa:shutter/ppa
sudo apt-get update && sudo apt-get install shutter
```
- Make `shutter` override built-in printscreen hotkeys using Compiz
```
sudo apt-get install compizconfig-settings-manager
```
- Make shared clipboard work from vagrant guest using lxc:
```
sudo apt-get install xauth xsel
```
- Make iPython use vim key bindings
```
ipython profile create
c.TerminalInteractiveShell.editing_mode = 'vi'

# cf. http://stackoverflow.com/a/38329940
```
- Ubuntu color picker

```
sudo apt-get install gpick
```

- `fzf` -- fuzzy `ctrl-R` (and more) in terminal:

https://github.com/junegunn/fzf

- Custom shortcuts

```
<c-s->> /home/bill/dot-files/bin/add_quote.sh
<c-s-print> shutter -s
```
-
-

- Vim 8

```
sudo add-apt-repository ppa:jonathonf/vim
sudo apt update
sudo apt install vim
```

- Github vim plugin yank fully qualified URL

```
diff --git a/plugin/github.vim b/plugin/github.vim
index 12e1d83..6510b7b 100644
--- a/plugin/github.vim
+++ b/plugin/github.vim
@@ -76,6 +76,12 @@ noremap <silent> <SID>Yank :call <SID>Yank()<CR>
 
 " --- helpers --- "
 
+" commit
+function! s:Commit() "+error checks
+  let dir = expand("%:p:h")
+  return substitute(s:CdExec(dir,'git rev-parse @{0}'), "\n",'','g')
+endfunction
+
 " repository root path of current file
 function! s:RepositoryRoot() "+error checks
   if !exists('b:repos_root')
@@ -153,7 +159,7 @@ endfunction
 " the github repository url
 function! s:ReposUrl()
   if !exists('b:repos_url')
-    let b:repos_url = s:ProjectUrl().'/blob/'.s:CurrentBranch()
+    let b:repos_url = s:ProjectUrl().'/blob/'.s:Commit()
   endif
   return b:repos_url
 endfunction
```

Or:

```
diff --git a/plugin/github.vim b/plugin/github.vim
index 12e1d83..1072f16 100644
--- a/plugin/github.vim
+++ b/plugin/github.vim
@@ -28,7 +28,8 @@ function! s:Yank()
   if empty(s:RepositoryRoot()) || empty(s:Remote())
     call s:error("File not in repository or no remote found!")
   else
-    let url = s:ReposUrl().'/'.s:RelPath() . s:Hash(a:firstline,a:lastline)
+    let commit_lines = split(s:CdExec(expand("%:p:h"),'git rev-parse @{0}'),"\n")
+    let url = s:ProjectUrl().'/blob/'.commit_lines[0].'/'.s:RelPath() . s:Hash(a:firstline,a:lastline)
     call s:YankUrl(url)
     echo "GitHub URL: " . url
   end
```
