---
description: Create a git commit following project standards and safety protocols
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git add:*), Bash(git diff:*), Bash(git commit:*), Bash(make test:*)
---

# commit

Create a git commit following all project standards and safety protocols for pgxntool-test.

**FIRST: Check ALL three repositories for changes**

**CRITICAL**: Before doing ANYTHING else, you MUST check git status in all 3 repositories to understand the full scope of changes:

```bash
# Check pgxntool (main framework)
echo "=== pgxntool status ==="
cd ../pgxntool && git status

# Check pgxntool-test (test harness)
echo "=== pgxntool-test status ==="
cd ../pgxntool-test && git status

# Check pgxntool-test-template (test template)
echo "=== pgxntool-test-template status ==="
cd ../pgxntool-test-template && git status
```

**Why this matters**: Work on pgxntool frequently involves changes across all 3 repositories. You need to understand the complete picture before committing anywhere.

**IMPORTANT**: If ANY of the 3 repositories have changes, you should commit ALL of them that have changes (unless the user explicitly says otherwise). This ensures related changes stay synchronized across the repos.

**DO NOT create empty commits** - Only commit repos that actually have changes (modified/untracked files). If a repo has no changes, skip it.

---

**CRITICAL REQUIREMENTS:**

1. **Git Safety**: Never update `git config`, never force push to `main`/`master`, never skip hooks unless explicitly requested

2. **Commit Attribution**: Do NOT add "Generated with Claude Code" to commit message body. The standard Co-Authored-By trailer is acceptable per project CLAUDE.md.

3. **Testing**: ALL tests must pass before committing:
   - Run `make test`
   - Check the output carefully for any "not ok" lines
   - Count passing vs total tests
   - **If ANY tests fail: STOP. Do NOT commit. Ask the user what to do.**
   - There is NO such thing as an "acceptable" failing test
   - Do NOT rationalize failures as "pre-existing" or "unrelated"

**WORKFLOW:**

1. Run in parallel: `git status`, `git diff --stat`, `git log -10 --oneline`

2. Check test status - THIS IS MANDATORY:
   - Run `make test 2>&1 | tee /tmp/test-output.txt`
   - Check for failing tests: `grep "^not ok" /tmp/test-output.txt`
   - If ANY tests fail: STOP immediately and inform the user
   - Only proceed if ALL tests pass

3. Analyze changes and draft concise commit message following this repo's style:
   - Look at `git log -10 --oneline` to match existing style
   - Be factual and direct (e.g., "Fix BATS dist test to create its own distribution")
   - Focus on "why" when it adds value, otherwise just describe "what"
   - List items in roughly decreasing order of impact
   - Keep related items grouped together
   - **In commit messages**: Wrap all code references in backticks - filenames, paths, commands, function names, variables, make targets, etc.
     - Examples: `helpers.bash`, `make test-recursion`, `setup_sequential_test()`, `TEST_REPO`, `.envs/`, `01-meta.bats`
     - Prevents markdown parsing issues and improves clarity

4. **PRESENT the proposed commit message to the user and WAIT for approval before proceeding**

5. After receiving approval, stage changes appropriately using `git add`

   **CRITICAL: Include ALL new files**
   - Check `git status` for untracked files
   - **ALL untracked files that are part of the feature/change MUST be staged**
   - New scripts, new documentation, new helper files, etc. should all be included
   - Do NOT leave new files uncommitted unless explicitly told to exclude them
   - When in doubt, include the file - it's better to commit too much than to leave important files uncommitted

6. **VERIFY staged files with `git status`**:
   - If user did NOT specify a subset: Confirm ALL modified AND untracked files are staged
   - If user specified only certain files: Confirm ONLY those files are staged
   - **Check for any untracked files that should be part of this commit**
   - STOP and ask user if staging doesn't match intent

7. After verification, commit using `HEREDOC` format:
```bash
git commit -m "$(cat <<'EOF'
Subject line (imperative mood, < 72 chars)

Additional context if needed, wrapped at 72 characters.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

8. Run `git status` after commit to verify success

9. If pre-commit hook modifies files: Check authorship (`git log -1 --format='%an %ae'`) and branch status, then amend if safe or create new commit

10. **Repeat steps 1-9 for each repository that has changes**:
    - After committing one repo, move to the next repo with changes (usually: pgxntool → pgxntool-test → pgxntool-test-template)
    - Draft appropriate commit messages that reference the primary changes
    - **ONLY commit repos with actual changes** - skip any repo that has no modified/untracked files
    - Ensure ALL repos with changes get committed before finishing

**MULTI-REPO COMMIT CONTEXT:**

**CRITICAL**: Work on pgxntool frequently involves changes across all 3 repositories simultaneously:
- **pgxntool** (this repo) - The main framework
- **pgxntool-test** (at `../pgxntool-test/`) - Test harness
- **pgxntool-test-template** (at `../pgxntool-test-template/`) - Test template

**This is why you MUST check all 3 repositories at the start** (see FIRST step above).

**DEFAULT BEHAVIOR: Commit ALL repos with changes together** - If any of the 3 repos have changes when you check them, you should plan to commit ALL repos that have changes (unless user explicitly specifies otherwise). This keeps related changes synchronized. **Do NOT create empty commits** - only commit repos with actual modified/untracked files.

When committing changes that span repositories:
1. **Commit messages in pgxntool-test and pgxntool-test-template should reference the main changes in pgxntool**
   - Example: "Add tests for pg_tle support (see pgxntool commit for implementation)"
   - Example: "Update template for pg_tle feature (see pgxntool commit for details)"

2. **When working across repos, commit in logical order:**
   - Usually: pgxntool → pgxntool-test → pgxntool-test-template
   - But adapt based on dependencies

**REPOSITORY CONTEXT:**

This is pgxntool, a PostgreSQL extension build framework. Key facts:
- Main Makefile is `base.mk`
- Scripts live in root directory
- Documentation is in `README.asc` (generates `README.html`)

**RESTRICTIONS:**
- DO NOT push unless explicitly asked
- DO NOT commit files with actual secrets (`.env`, `credentials.json`, etc.)
- Never use `-i` flags (`git commit -i`, `git rebase -i`, etc.)
