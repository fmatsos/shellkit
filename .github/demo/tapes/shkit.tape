Set Shell "zsh"
Set Theme "Dracula"
Set WindowBar Colorful
Set BorderRadius 10
Set Padding 20
Set FontFamily "JetBrains Mono, Symbols Nerd Font Mono"
Set FontSize 18
Set Width 1200
Set Height 440
Set TypingSpeed 60ms
Set Framerate 24
Env PATH "/demo/stubs:/home/dev/.local/bin:/usr/local/bin:/usr/bin:/bin"
Output "/out/demo-shkit.gif"

Hide
Type "exec zsh"
Enter
Sleep 1.5s
Type "clear"
Enter
Type "cd ~/code/shop"
Enter
Sleep 3s
Type "clear"
Enter
Show
Type "shkit set format '{dir} · {git}'"
Enter
Type "shkit set color_accent '38;5;201'"
Enter
Type "shkit project"
Enter
Type "shkit set -p format '{dir}'"
Enter
Type "cd ~"
Enter
Sleep 1.5s
Sleep 1s
