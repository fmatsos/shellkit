Set Shell "zsh"
Set Theme "Dracula"
Set WindowBar Colorful
Set BorderRadius 10
Set Padding 20
Set FontFamily "JetBrains Mono, Symbols Nerd Font Mono"
Set FontSize 18
Set Width 1200
Set Height 400
Set TypingSpeed 60ms
Set Framerate 24
Env PATH "/demo/stubs:/home/dev/.local/bin:/usr/local/bin:/usr/bin:/bin"
Env SHKIT_FORMAT "{dir} · {git} · {mr}"
Output "/out/demo-async.gif"

Hide
Type "exec zsh"
Enter
Sleep 1.5s
Type "clear"
Enter
Show
Type "cd ~/code/shop"
Enter
# Nothing typed from here: the real prompt redraws itself when the jobs end.
Sleep 6s
