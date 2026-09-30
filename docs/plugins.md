# Plugins

A plugin is a git repository of prompt [blocks](blocks.md) and [themes](themes.md)
that anyone can install with `shkit plugin add`.

- [Using plugins](#using-plugins)
- [Updating](#updating)
- [Security](#security)
- [Writing a plugin](#writing-a-plugin)
- [The manifest: `plugin.json`](#the-manifest-pluginjson)
- [Testing and CI](#testing-and-ci)
- [Publishing and versioning](#publishing-and-versioning)

## Using plugins

```zsh
shkit plugin add git@github.com:someone/prompt-extras.git
```

`add` clones the repository into a staging area and checks the manifest and the
files against the schema. It then shows what will be sourced and the commands the
plugin needs that are missing here, and asks. Only on *yes* is the plugin kept, as
`~/.config/shkit/plugins/<name>/`. The name comes from its manifest, not from the URL.

Once installed:

```zsh
shkit show                                  # its blocks are listed, its themes too
shkit set format '{dir} · {git} · {php}'    # use a block
shkit set theme prompt-extras/dark          # use a theme (layer 2)
shkit set -p theme prompt-extras/light      # …or only in this project
shkit plugin list                           # installed plugins, version, commit
shkit plugin remove prompt-extras
```

A plugin theme sits *under* your `theme.zsh` and project files, so your own
settings always win (see [settings layers](configuration.md#settings-layers)).

## Updating

Plugins never update on their own:

```zsh
shkit plugin update                  # every plugin
shkit plugin update prompt-extras    # one
```

For each plugin, `update` fetches, then:

1. refuses a rewritten history (a force push upstream), so remove and add the
   plugin again if you trust the new one;
2. shows the new commits and the diff stat;
3. checks the new `plugin.json` and files, and refuses a plugin that renamed
   itself;
4. asks, then fast-forwards.

## Security

> [!WARNING]
> A plugin is code that every new shell runs. Read it before `add` and before each
> `update`, as you would any script you pipe into a shell.

- Nothing is fetched or updated unless you ask.
- `add` and `update` show what comes and ask first. `-y` skips the question, so
  keep it for scripts and your own plugins.
- Credentials in a URL (`https://user:token@host/…`) are never printed, but git
  stores the URL in the clone's `.git/config`. For a private repository, use an
  ssh URL or a git credential helper instead.

## Writing a plugin

`shkit` scaffolds the layout and keeps `plugin.json` in step with the files:

```zsh
shkit plugin new prompt-extras && cd prompt-extras   # plugin.json + git init
shkit plugin new-block php 'PHP version of the project'
shkit plugin new-theme dark 'Dark background, soft colors'
$EDITOR blocks/php.zsh themes/dark.zsh
shkit plugin check                                   # the check add runs
git add -A && git commit -m 'First version'
```

The result:

```text
prompt-extras/
├── plugin.json        # the manifest
├── blocks/php.zsh     # defines _prompt_seg_php, shown as {php}
└── themes/dark.zsh    # SHKIT_* assignments
```

Other files (README, LICENSE, tests, CI) are free. `blocks/` and `themes/` must
hold exactly the declared files, and each block must define its
`_prompt_seg_<name>`. The block and theme rules are in [Writing a block](blocks.md)
and [Writing a theme](themes.md).

The plugin name (`[a-z0-9-]`) is its install directory and the prefix of its themes
(`prompt-extras/dark`). It can never change: an update that renames the plugin
is refused.

To remove a block or a theme, delete its file **and** its entry in `plugin.json`.

A complete example lives in [`zsh/plugin/example/`](../zsh/plugin/example/).

## The manifest: `plugin.json`

It must follow [`zsh/plugin/schema.json`](../zsh/plugin/schema.json) (JSON Schema
2020-12). Unknown keys are refused.

```json
{
  "$schema": "https://github.com/fmatsos/shellkit/zsh/plugin/schema.json",
  "name": "prompt-extras",
  "version": "1.0.0",
  "description": "PHP version block and a dark theme",
  "author": { "name": "Jane Doe", "email": "jane@example.com", "url": "https://example.com" },
  "license": "MIT",
  "homepage": "https://github.com/jane/prompt-extras",
  "repository": "https://github.com/jane/prompt-extras.git",
  "keywords": ["php", "dark"],
  "requires": ["php"],
  "blocks": [{ "name": "php", "description": "PHP version of the project" }],
  "themes": [{ "name": "dark", "description": "Dark background, soft colors" }]
}
```

| Key | Required | Rule |
|-----|----------|------|
| `name` | ✓ | `^[a-z0-9][a-z0-9-]*$`, never changes |
| `version` | ✓ | [semver](https://semver.org): `1.2.3`, `1.3.0-beta.1` |
| `description` | ✓ | non-empty |
| `blocks` | ✓ `blocks` or `themes` | at least one `{ name, description? }`, name `^[a-z0-9_]+$` |
| `themes` | ✓ `blocks` or `themes` | at least one `{ name, description? }`, name `^[a-z0-9][a-z0-9_-]*$` |
| `author` | | `{ name, email?, url? }` |
| `license`, `homepage`, `repository` | | strings |
| `keywords` | | array of strings |
| `requires` | | commands the blocks run. `add` tells users which are missing |
| `$schema` | | for editors |

## Testing and CI

Locally, `add` needs a commit (it clones):

```zsh
shkit plugin check                            # after each change
git commit -am wip
shkit plugin add -y ~/src/prompt-extras       # a local path works as a URL
shkit set -p format '{php}'                   # see the block alone, in one project
# …change, commit, then:
shkit plugin update -y prompt-extras
shkit plugin remove prompt-extras             # when done
```

In the plugin's own CI, validate the manifest with jq. Copy
[`schema.json`](../zsh/plugin/schema.json) and
[`validate.jq`](../zsh/plugin/validate.jq) into the repository:

```yaml
# .github/workflows/check.yml
on: [push, pull_request]
jobs:
  manifest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: |
          errors=$(jq -r --slurpfile schema schema.json -f validate.jq plugin.json)
          [ -z "$errors" ] || { echo "$errors"; exit 1; }
```

No output means valid. Otherwise there is one error per line, such as
`plugin.json.version: "1" must match …`.

## Publishing and versioning

- Push to any git host users can reach: GitHub, GitLab, your own server.
- Bump `version` with every change users will get.
- **Never rewrite published history** (force push, amended or rebased `main`):
  `update` refuses it, and every user would have to remove and add the plugin again.
- Users only get changes when they run `shkit plugin update`, which shows them
  your commits: keep them small and clearly described.
