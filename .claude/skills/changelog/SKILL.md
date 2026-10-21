---
name: changelog
description: Create or update CHANGELOG.md in the project root with dated entries summarising what changed. Run manually before merging a branch.
argument-hint: "[target-branch, default main]"
disable-model-invocation: true
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git branch:*), Bash(date:*), Read, Edit, Write
---

# Changelog

Maintain `CHANGELOG.md` at the repo root. Entries are grouped under one `## YYYY-MM-DD` heading per date, newest date first, with bullets underneath.

## Format

```markdown
# Changelog

All notable changes to the Links Admin Panel and its mobile API.

## 2026-10-14

- Rider app can record its own location during a trip (see `docs/api/<endpoint>.md`).
- **Migration:** adds `<table>`; apply in `links592db` before deploying.

## 2026-10-13

- ...
```

Rules for bullets:

- One bullet per meaningful change, written for a teammate reading the history: what changed and, where it isn't obvious, why. Plain statements ending with a period, no conventional-commit prefixes (`feat:`, `fix(panic):`).
- Rewrite commit subjects into clear prose; don't paste them verbatim. Read the diff (`git show --stat <sha>`, then the relevant hunks) when the subject is vague ("refine", "updates", "Stage B").
- Merge several commits into one bullet when they are the same change (follow-ups, fixups, duplicate commits with the same subject, "Phase 0 fixup"). Skip merge commits, pure formatting, and changes to the changelog itself.
- Call out anything a mobile app developer or operator must act on: changed API request/response shapes (link the `docs/api/*.md` file), new env vars, new `system_config` keys, and migrations needed in `../links592db`. Prefix those bullets with **Breaking:**, **Config:** or **Migration:** as appropriate.
- Name endpoints, admin pages, and config keys in backticks. Don't include commit hashes or author names.
- Keep it to roughly 1 to 8 bullets per date. If a date has many small commits, group by area (e.g. "Analytics: ...").

## Steps

### 1. Bootstrap (only if `CHANGELOG.md` doesn't exist)

1. List history on the target branch, oldest last, without merges:
   ```bash
   git log <target> --no-merges --date=short --format='%ad %h %s'
   ```
2. Group commits by author date. For each date, write bullets following the rules above. Inspect diffs for vague subjects.
3. Write `CHANGELOG.md` with the header, then every date newest first.
4. If the current branch has commits not on the target, continue to step 2 so they're included too.

### 2. Add entries for the pending merge

1. Determine the target branch: `$ARGUMENTS` if given, otherwise `main`. Confirm the current branch with `git rev-parse --abbrev-ref HEAD`.
2. Collect the changes this merge will bring in:
   ```bash
   git log <target>..HEAD --no-merges --date=short --format='%ad %h %s'
   git diff <target>...HEAD --stat
   ```
   Also check `git status` for uncommitted work and ask whether it belongs in this entry.
   - If the current branch **is** the target (nothing to diff), instead use commits newer than the latest date heading in `CHANGELOG.md` (`git log --no-merges --since=<that date> ...`), skipping any already described there.
   - If there are no new changes, say so and stop.
3. Use **today's date** (`date +%F`) as the heading, since that is when the changes land on the target. If a heading for today already exists, add to it rather than creating a duplicate, and don't repeat bullets that are already there.
4. Write the bullets, insert the section directly below the header (above the previous newest date), and save.

### 3. Report

Show the user the new/changed section and stop. Do not commit or stage unless the user asks; they will review it and include it in the merge.
