# Claude Development Notes

This file contains guidance for Claude Code when working in this repository.
It is excluded from distributions via `.gitattributes export-ignore`.

@../../ai/CLAUDE.md

If that import didn't resolve (`../../ai/CLAUDE.md`, relative to this file,
doesn't exist locally — see https://github.com/Postgres-Extensions/ai),
clone it now per its own first instruction, then re-read it: run `git clone
https://github.com/Postgres-Extensions/ai.git ../ai` from this repo's root
(`pgxntool/`, not from inside `.claude/`) so `ai/` lands as a sibling of
`pgxntool/`.

Also see the `ai/` repo's `PR.md` (`../ai/PR.md` from this repo's root) for
cross-repo conventions not restated below (CI monitoring's general
principle, multi-session PR-ownership hygiene, executable-bit safety, shell
script standards, etc.). This repo pairs with **pgxntool-test**, so the
section below is a deliberate addition specific to that pairing, on top of
those general conventions.

## CI Monitoring After Every Push

Addition specific to this paired repo, on top of the general convention in
`../../ai/CLAUDE.md`: if you pushed to both pgxntool and pgxntool-test,
start a background task for each — do not monitor them sequentially.
