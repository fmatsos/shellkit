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
Env SHKIT_FORMAT "{dir} · {git}"
Output "/out/demo-git.gif"

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
Type "echo 'More checkout notes.' >> README.md"
Enter
Sleep 1s
Type "echo 'syrup,2' >> catalog.csv"
Enter
Sleep 1s
# Clear only the two scene edits so switching branches is safe.
Hide
Type "git restore README.md catalog.csv"
Enter
Type "git switch -q rebase-conflict"
Enter
Type "clear"
Enter
Show
Type "git rebase main"
Enter
Sleep 2s
Hide
Type "git rebase --abort"
Enter
Type "git switch feature/SHOP-482-checkout"
Enter
Show
Sleep 2s
