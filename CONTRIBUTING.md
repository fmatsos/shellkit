# Contributing to ShellKit

Thanks for helping. For anything larger than a small fix, open an issue first so we can agree
on the direction before you spend time on it.

## Working on ShellKit

Plain zsh and bash, no framework. [docs/development.md](docs/development.md) is the tour of the
repository and [AGENTS.md](AGENTS.md) holds the rules.

```sh
git add <your files>
.claude/skills/config-commit/check.sh   # syntax, prompt self-check, startup budget, secret scan
```

- **Never commit a secret**: the check compares values and never prints them, and CI scans for token shapes.
- **Everything runs on Linux and macOS.** No GNU-only flags, and the install scripts must run on
  macOS's bash 3.2.
- Keep the startup time within the budget (60 ms, about 35 ms is usual).
- Commit messages are short, in English, in the imperative ("Adds {dir.short} and a transient prompt").

## Unlicensing contributions

ShellKit is in the public domain ([Unlicense](LICENSE)). To keep it free of anyone's copyright
monopoly, and to remove any doubt about the terms a contribution was made under, every
[non-trivial](https://www.gnu.org/prep/maintain/maintain.html#Legally-Significant) patch comes with
this statement, taken from the [Unlicense website](https://unlicense.org/#unlicensing-contributions):

> I dedicate any and all copyright interest in this software to the
> public domain. I make this dedication for the benefit of the public at
> large and to the detriment of my heirs and successors. I intend this
> dedication to be an overt act of relinquishment in perpetuity of all
> present and future rights to this software under copyright law.

You do not have to type it: the pull request template pre-fills it in the description of every
pull request, and **leaving it there is how you make the dedication**. If you open a pull request
another way (`gh pr create --body`, the API), paste the statement into its description yourself: the `dedication` workflow fails
the pull request while the statement is missing from its description (pull requests from bots and from
the repository owner are exempt).
If you made the change as an employee of an organization, the statement may not be enough: your
employer has to disclaim its copyright too (see
[how SQLite handles it](https://www.sqlite.org/copyright.html)), so say so in the pull request.
