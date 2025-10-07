# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Commit Guidelines

**IMPORTANT**: When creating commit messages, do not attribute commits to yourself (Claude). Commit messages should reflect the work being done without AI attribution in the message body. The standard Co-Authored-By trailer is acceptable.

## Critical: What This Repo Actually Is

**pgxntool is NOT a standalone project.** It is a meta-framework that exists ONLY to be embedded into PostgreSQL extension projects via `git subtree`. This repo cannot be built, tested, or run directly.

**Think of it like this**: pgxntool is to PostgreSQL extensions what a Makefile template library is to C projects - it's infrastructure code that gets copied into other projects, not a project itself.

## Three-Repository Development Pattern

This codebase uses an unusual three-repository testing pattern:

1. **pgxntool/** (this repo) - The framework code that gets embedded into extension projects
2. **../pgxntool-test-template/** - A minimal "dummy" PostgreSQL extension that has pgxntool embedded (serves as an example consumer)
3. **../pgxntool-test/** - The test harness that clones the template, exercises pgxntool's functionality, and validates outputs

**To test changes to pgxntool**, you must:
1. Ensure changes are visible to pgxntool-test (via git commit or using the rsync mechanism in the test harness)
2. Run tests from `../pgxntool-test/`
3. The test harness will clone `../pgxntool-test-template/`, sync in pgxntool changes, and validate behavior

## How Extension Developers Use pgxntool

Extension projects include pgxntool via git subtree:

```bash
git subtree add -P pgxntool --squash git@github.com:decibel/pgxntool.git release
pgxntool/setup.sh
```

After setup, their Makefile typically contains just:
```makefile
include pgxntool/base.mk
```

## Architecture: Two-Phase Build System

### Phase 1: Meta Generation (`build_meta.sh`)
- Processes `META.in.json` (template with placeholders/empty values)
- Strips out X_comment fields and empty values
- Produces clean `META.json`

### Phase 2: Variable Extraction (`meta.mk.sh`)
- Parses `META.json` using `JSON.sh` (a bash-based JSON parser)
- Generates `meta.mk` with Make variables:
  - `PGXN` - distribution name
  - `PGXNVERSION` - version number
  - `EXTENSIONS` - list of extensions provided
  - `EXTENSION_*_VERSION` - per-extension versions
  - `EXTENSION_VERSION_FILES` - auto-generated versioned SQL files
- `base.mk` includes `meta.mk` via `-include`

### The Magic of base.mk

`base.mk` provides a complete PGXS-based build system:
- Auto-detects extension SQL files in `sql/`
- Auto-detects C modules in `src/*.c`
- Auto-detects tests in `test/sql/*.sql`
- Auto-generates versioned extension files (`extension--version.sql`)
- Handles Asciidoc → HTML conversion
- Integrates with PGXN distribution format
- Manages git tagging and release packaging

## File Structure for Consumer Projects

Projects using pgxntool follow this layout:
```
project/
├── Makefile                    # include pgxntool/base.mk
├── META.in.json               # Template metadata (customize for your extension)
├── META.json                  # Auto-generated from META.in.json
├── extension.control          # Standard PostgreSQL control file
├── pgxntool/                  # This repo, embedded via git subtree
├── sql/
│   └── extension.sql          # Base extension SQL
├── src/                       # Optional C code (*.c files)
├── test/
│   ├── deps.sql              # Load extension and test dependencies
│   ├── sql/*.sql             # Test SQL files
│   └── expected/*.out        # Expected test outputs
└── doc/                       # Optional docs (*.adoc, *.asciidoc)
```

## Commands for Extension Developers (End Users)

These are the commands extension developers use (documented for context):

```bash
make                    # Build extension (generates versioned SQL, docs)
make test              # Full test: testdeps → install → installcheck → show diffs
make results           # Run tests and update expected output files
make html              # Generate HTML from Asciidoc sources
make tag               # Create git branch for current META.json version
make dist              # Create PGXN .zip (auto-tags, places in ../)
make pgxntool-sync     # Update to latest pgxntool via git subtree pull
```

## Development Workflow (for pgxntool Contributors)

When modifying pgxntool:

1. **Make changes** in this repo (pgxntool/)
2. **Test changes** by running `make test` in `../pgxntool-test/`
   - The test harness clones `../pgxntool-test-template/`
   - If pgxntool is dirty, it rsyncs your uncommitted changes
   - Runs setup, builds, tests, and validates outputs
3. **Examine results** in `../pgxntool-test/results/` and `../pgxntool-test/diffs/`
4. **Update expected outputs** if needed: `make sync-expected` in `../pgxntool-test/`
5. **Commit changes** once tests pass

## Key Implementation Details

### PostgreSQL Version Handling
- `MAJORVER` = version × 10 (e.g., 9.6 → 96, 13 → 130)
- Tests use `--load-language=plpgsql` for versions < 13
- Version detection via `pg_config --version`

### Test System (pg_regress based)
- Tests in `test/sql/*.sql`, outputs compared to `test/expected/*.out`
- Setup via `test/pgxntool/setup.sql` (loads pgTap and deps.sql)
- `.IGNORE: installcheck` prevents build failures on test errors
- `make results` updates expected outputs after test runs

### Document Generation
- Auto-detects `asciidoctor` or `asciidoc`
- Generates HTML from `*.adoc` and `*.asciidoc` in `$(DOC_DIRS)`
- HTML required for `make dist`, optional for `make install`
- Template-based rules via `ASCIIDOC_template`

### Distribution Packaging
- `make dist` creates `../PGXN-VERSION.zip`
- Always creates git branch tag matching version
- Uses `git archive` to package
- Validates repo is clean before tagging

### Subtree Sync Support
- `make pgxntool-sync` pulls latest release
- Multiple sync targets: release, stable, local variants
- Uses `git subtree pull --squash`
- Requires clean repo (no uncommitted changes)

## Critical Gotchas

1. **Empty Variables**: If `DOCS` or `MODULES` is empty, base.mk sets to empty to prevent PGXS errors
2. **testdeps Pattern**: Never add recipes to `testdeps` - create separate target and make it a prerequisite
3. **META.json is Generated**: Always edit `META.in.json`, never `META.json` directly
4. **Control File Versions**: No automatic validation that `.control` matches `META.json` version
5. **PGXNTOOL_NO_PGXS_INCLUDE**: Setting this skips PGXS inclusion (for special scenarios)
6. **Distribution Placement**: `.zip` files go in parent directory (`../`) to avoid repo clutter

## Scripts

- **setup.sh** - Initializes pgxntool in a new extension project (copies templates, creates directories)
- **build_meta.sh** - Strips empty fields from META.in.json to create META.json
- **meta.mk.sh** - Parses META.json via JSON.sh and generates meta.mk with Make variables
- **JSON.sh** - Third-party bash JSON parser (MIT licensed)
- **safesed** - Utility for safe sed operations

## Related Repositories

- **../pgxntool-test/** - Test harness for validating pgxntool functionality
- **../pgxntool-test-template/** - Minimal extension project used as test subject
