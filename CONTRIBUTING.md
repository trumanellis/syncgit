# Contributing to syncgit

Thanks for thinking about contributing! This is a small project — keep PRs focused and the diff readable.

## Setting up

```sh
git clone https://github.com/trumanellis/syncgit
cd syncgit
./install.sh                # symlinks ~/.local/bin/syncgit and the /sync slash command
```

## Running tests

```sh
bash tests/run.sh
```

The suite needs `bash`, `git`, and `python3`. Tests run in `mktemp` directories
and clean up after themselves.

## Style

- One feature or fix per PR. If it grows beyond ~200 lines of diff, split it.
- Match the existing bash style: `set -euo pipefail`, `local` for function vars,
  quote everything, prefer `[[ ]]` over `[ ]`.
- Keep error messages prefixed with `syncgit:` and concise.
- New subcommands: add to the `usage()` block, the file-header comment, the
  case dispatcher in `main`, and document in README.

## Commit style

Imperative subject under ~70 chars. Body explains *why*, not just *what*.
Example:

```
Sort pending refs by ts suffix instead of committerdate

Rebase rewrites committerdate, which would jumble the merge order if a
peer's ref had been internally rebased. The <ts> suffix is broadcast time
and stable across rebases, so use it directly.
```

## Reporting bugs

Open an issue with:
- `syncgit --version` output
- Bash version (`bash --version`) and OS
- Exact command(s) you ran
- What you expected vs what happened
- Output, with secrets redacted

## Releasing

```
1. Update CHANGELOG.md (move Unreleased entries under a new version)
2. Bump VERSION
3. Commit: "Release vX.Y.Z"
4. Tag: git tag -s vX.Y.Z -m "vX.Y.Z"
5. Push: git push origin main && git push origin vX.Y.Z
6. Create a GitHub Release referencing the CHANGELOG entry
```

## Code of conduct

Be kind. Assume good faith. If something feels off, raise it directly.
