# Records demo/demo.gif. Run from the repo root: vhs demo/demo.tape
# The script itself lives in demo/init.lua.

Output demo/demo.gif

Require nvim
Require git

Set Shell bash
Set FontFamily "JetBrainsMono Nerd Font"
Set FontSize 18
Set Width 1200
Set Height 640
Set Padding 14
Set Theme "GruvboxDark"
Set WindowBar Colorful
Set Framerate 24
Set TypingSpeed 0
Set WaitTimeout 90s

# Clone the icon and colorscheme plugins first, so the recording starts on time
Hide
Type "nvim --headless --clean -u demo/init.lua +qa && clear"
Enter
Wait
Type "nvim --clean -u demo/init.lua lua/bufswitch/init.lua"
Enter
Sleep 1s
Show

# Runs until the last caption, then holds it
Wait+Screen /Every key is yours to change/
Sleep 4s
