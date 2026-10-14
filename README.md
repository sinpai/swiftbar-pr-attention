# swiftbar-pr-attention

A [SwiftBar](https://github.com/swiftbar/SwiftBar) plugin that checks your open GitHub pull requests every hour and lists the ones that need you:

- PRs with unresolved review threads where someone else wrote the last comment. If you replied last, the thread is waiting on the reviewer and is not listed.
- PRs with failing checks on the latest commit. For GitHub Actions jobs it shows the step that failed, for example `test: Run rspec`.

The menu bar shows `PR ✓` when nothing needs you and `PR 3` in red when three PRs do. Click a PR to open it. For a failing check, the click opens the PR's Checks tab. If the GitHub query fails, the menu bar shows `PR ⚠` with the error, so a failed run never looks like "nothing to do".

## Requirements

- macOS with SwiftBar
- GitHub CLI (`gh`), logged in with `gh auth login`. The plugin uses the login that `gh` stores, so the script contains no token.
- `jq`. Recent macOS versions include it. Otherwise run `brew install jq`.

## Install

1. Clone this repository.
2. Link the script into your SwiftBar plugin folder:

   ```sh
   ln -s "$PWD/pr-attention.1h.sh" "$(defaults read com.ameba.SwiftBar PluginDirectory)/"
   ```

SwiftBar picks up new plugins on its own. If the plugin does not appear, choose "Refresh All" in the SwiftBar menu.

## Settings

- **How often it runs:** set by the `1h` in the file name. For example, name the link `pr-attention.30m.sh` to run every 30 minutes.
- **Ignored steps:** `IGNORE_STEPS` at the top of the script. A check is not reported when all of its failed steps are in this list. Set `IGNORE_STEPS=()` to report every failure.

## What it checks

It runs one GitHub GraphQL query for open PRs that you authored in repositories that are not archived. It reads the first 50 PRs, the first 100 review threads on each PR, and the first 50 checks on each PR's latest commit.

To see the menu text without SwiftBar, run the script in a terminal:

```sh
./pr-attention.1h.sh
```
