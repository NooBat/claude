---
name: review-pr
description: Use when reviewing a GitHub pull request. Automatically detects re-reviews by checking GitHub for prior reviews by the current user - no need to say "re-review". Say "fresh review" to force a full first review. Gathers architectural context, dispatches a code-reviewer subagent, posts structured review with inline line-range comments to GitHub. On re-review, reads author replies and thread resolution status to avoid re-flagging explained or acknowledged issues.
user-invocable: true
argument-hint: "<pr-number-or-url>"
---

# Review PR

Dispatch a code-review subagent to review a GitHub PR, then post the review to GitHub with inline file comments (with line ranges) and a general review body.

**Announce at start:** "Reviewing PR #$0 — fetching data, running code review, and posting to GitHub."

## Process

### Step 0: Normalize input

`$0` may be a PR number or a full URL. Extract the numeric PR number and define `PR_NUMBER`. Use `PR_NUMBER` (not `$0`) in all subsequent commands and paths.

### Step 0a: Derive repo identity and check PR state

Get repo identifier (save as `REPO`):
```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

Get GitHub hostname for GHE (save as `GH_HOST`):
```bash
GH_HOST=$(gh repo view --json url -q '.url | split("/") | .[2]')
```

Check that the PR is still open:
```bash
gh pr view $PR_NUMBER --json state -q .state
```
If the state is `MERGED` or `CLOSED`, report to the user and stop — reviewing a non-open PR is not useful.

Get the PR author (save as `PR_AUTHOR`):
```bash
gh pr view $PR_NUMBER --json author -q .author.login
```

### Step 0b: Detect re-review (stateless)

Get the current user's GitHub login:
```bash
gh api user --hostname $GH_HOST --jq .login
```
Save as `CURRENT_USER`.

Query GitHub for the most recent non-pending review by this user:
```bash
gh api repos/$REPO/pulls/$PR_NUMBER/reviews --hostname $GH_HOST --paginate \
  --jq '[.[] | select(.user.login == "'"$CURRENT_USER"'" and .state != "PENDING") | {id, commit_id, submitted_at, state}] | sort_by(.submitted_at) | last'
```

If the result is `null` or empty: no baseline exists. Set `HAS_BASELINE=false`.

If the result is valid JSON but `commit_id` is `null` or empty: the prior review has no commit anchor. Warn the user: "Prior review found but has no commit reference — proceeding with first review." Set `HAS_BASELINE=false`.

If the result is valid JSON with a `commit_id`: set `HAS_BASELINE=true`. Save `commit_id` as `OLD_HEAD`, `submitted_at` as `V1_REVIEW_TIME`, and `id` as `V1_REVIEW_ID`.

### Step 0c: Route

Determine user intent from the input:

| Intent | Phrases |
|--------|---------|
| Re-review | "re-review", "review again", "another look", "follow up review" |
| Fresh review | "fresh review", "start fresh", "from scratch", "ignore previous", "clean review" |
| Default | Anything else (e.g., "review PR #123", a URL) |

**Route:**
- `HAS_BASELINE=false` + intent is re-review -> warn: "No prior review found on GitHub for this PR — proceeding with first review." Continue to Step 1.
- `HAS_BASELINE=false` + any other intent -> first review. Continue to Step 1. Do NOT read `SKILL-REREVIEW.md`.
- `HAS_BASELINE=true` + intent is fresh review -> first review. Continue to Step 1.
- `HAS_BASELINE=true` + any other intent (including default) -> **re-review**. Announce: "Found your review from {V1_REVIEW_TIME} — running re-review. Say `fresh review` to override." Read `SKILL-REREVIEW.md` and follow it from Step R0. Do NOT continue to Step 1.

### Step 1: Gather PR context

Each line below is a **separate Bash call**. Save all outputs in conversation context.

Get PR metadata (save as `PR_JSON`, extract `BASE_SHA` and `HEAD_SHA` from it):
```bash
gh pr view $PR_NUMBER --json title,body,baseRefName,headRefName,baseRefOid,headRefOid,files,author
```

Get changed file paths, excluding lock files (save as `CHANGED_FILES`):
```bash
gh pr view $PR_NUMBER --json files -q '.files[].path | select(test("(pnpm-lock|package-lock|yarn\\.lock|Cargo\\.lock|go\\.sum)") | not)'
```

Get the diff, excluding lock files:
```bash
gh pr diff $PR_NUMBER | awk '/^diff --git.*(pnpm-lock|package-lock|yarn\.lock|Cargo\.lock|go\.sum)/{skip=1; next} /^diff --git/{skip=0} !skip'
```

### Step 1a: Create or reuse worktree at the PR's HEAD

**Never check out a different branch in the main worktree** — other agents may be reading files concurrently. Use a dedicated worktree instead.

**First, clean up stale worktrees** (older than 7 days):
```bash
find /tmp -maxdepth 1 -name "pr-review-*" -type d -mtime +7 -exec git worktree remove {} 2>/dev/null \;
```

Derive `REPO_SLUG` from `REPO` (replace `/` with `-`). Set `WORKTREE_PATH=/tmp/pr-review-$REPO_SLUG-$PR_NUMBER`.

Fetch PR head:
```bash
git fetch origin pull/$PR_NUMBER/head
```

Check if worktree already exists:
```bash
if test -d $WORKTREE_PATH; then echo "EXISTS"; else echo "NEW"; fi
```

If `EXISTS` — reuse, update to latest HEAD:
```bash
git -C $WORKTREE_PATH checkout $HEAD_SHA --detach
```

If `NEW` — create:
```bash
git worktree add $WORKTREE_PATH $HEAD_SHA --detach
```

Use `WORKTREE_PATH` as the base path for **all file reads** from here on.

**Do NOT delete the worktree after the review** — it will be reused if the PR is re-reviewed.

### Step 1b: Gather architectural context

The diff alone only shows what changed. Insightful reviews need to understand **where the code is going** and **what patterns already exist**. Gather:

1. **Related specs/plans** — search for spec/plan docs related to the PR's feature area. Read any that relate. These reveal the **destination** — what's planned next, how many more files will follow this pattern.
2. **Sibling files** — read files adjacent to the changed ones that follow (or should follow) the same patterns.
3. **Consumers/callers** — for new APIs, helpers, or exports: who will use them?

Include all of this in the subagent prompt as `## Architectural Context`.

### Step 1c: Discover review rules and checklists

Two layers of review rules exist. Discover both, then tell the subagent which takes priority.

#### Layer 1: Repo review-rules (authoritative)

Check if the PR's repo has its own review rules:
```bash
ls "$WORKTREE_PATH/.claude/review-rules/"*.md 2>/dev/null
```

If files are found, save as `REPO_RULES`. These are **authoritative** for the topics they cover.

#### Layer 2: Workspace/user checklist (gap-filler)

Classify the PR's domain from its files:

| Signal | Domain |
|--------|--------|
| >50% of changed files are `.ts`/`.tsx`/`.css` | `frontend` |
| >50% of changed files are `.go` | `backend-go` |
| >50% of changed files are `.scala` | `backend-scala` |
| >50% of changed files are `.py` | `backend-python` |
| >50% of changed files are `.rs` | `backend-rust` |

If a domain is identified, check for a checklist file at `skills/review-pr/checklists/$DOMAIN.md`.

#### Priority

- **Repo rules only**: Use repo rules as the sole review standard.
- **Checklist only**: Use checklist as the sole review standard.
- **Both exist**: Repo rules are authoritative. Checklist applies only for checks NOT covered by any repo rule.
- **Neither**: Review uses architectural lenses only.

### Step 2: Dispatch code-reviewer subagent

Use the Agent tool with `model: "sonnet"` (no `isolation` — the worktree from Step 1a is shared).

**Build the subagent prompt by reading `PROMPT-TEMPLATE.md`** (same directory as this file). It contains the file reading budget, review lenses, and output format.

Assemble the prompt in this order:
1. PR diff + changed files list + `WORKTREE_PATH`
2. File Reading Budget (from template)
3. Architectural Context (filled in from Step 1b)
4. Review rules section (from template — includes repo rules, checklist, or both with priority)
5. Review Lenses (from template)
6. Output Format (from template)

### Step 3: Parse the review output

From the subagent's response, extract:

1. **General review body** — everything in the `GENERAL REVIEW` section
2. **Inline comments JSON** — the array after `INLINE_COMMENTS_JSON:`

### Step 4: Post to GitHub

**Pre-flight: clear stale pending reviews.** Before posting, check for and delete any pending review:
```bash
gh api repos/$REPO/pulls/$PR_NUMBER/reviews --hostname $GH_HOST \
  --jq '.[] | select(.state == "PENDING") | .id'
# If an ID is returned, delete it:
gh api repos/$REPO/pulls/$PR_NUMBER/reviews/{REVIEW_ID} \
  --hostname $GH_HOST --method DELETE
```

Post the review:
```bash
gh api repos/$REPO/pulls/$PR_NUMBER/reviews \
  --hostname $GH_HOST \
  --method POST \
  --input - <<'EOF'
{
  "body": "<general review body as markdown>",
  "event": "COMMENT",
  "comments": <inline comments JSON array>,
  "commit_id": "<HEAD_SHA>"
}
EOF
```

**Event mapping:**

If a domain checklist was loaded, use the checklist score to influence the event:
- >=90% checks passed AND verdict is "Ready to merge" -> `"event": "APPROVE"`
- 75-89% checks passed OR verdict is "Needs fixes" -> `"event": "COMMENT"`
- <75% checks passed OR verdict is "Needs discussion" -> `"event": "REQUEST_CHANGES"`

If no checklist was loaded, use the reviewer's verdict directly:
- Verdict is "Ready to merge" -> `"event": "APPROVE"`
- Verdict is "Needs fixes" -> `"event": "COMMENT"`
- Verdict is "Needs discussion" -> `"event": "REQUEST_CHANGES"`

**Fallback for 422 errors:**
- "line not in diff" or "start line must precede end line" -> remove the offending comment from the array, move its content into the general body under a "## Additional Comments" section, and retry.
- "pending review exists" -> delete the pending review (see pre-flight above) and retry.

### Step 4b: Keep the worktree for re-reviews

**Do NOT delete the worktree.** It will be reused if the PR is re-reviewed. Stale worktrees are cleaned up lazily at the start of the next `/review-pr` invocation (see Step 1a).

### Step 5: Report to user

Show:
- Link to the posted review
- Summary of how many inline comments were posted
- The assessment verdict
- If repo review-rules were found: list which rule files were applied
- If a checklist was loaded: checklist score (e.g., "Frontend Compliance: 7/8 checks passed (88%)")
- If neither: note that review used architectural lenses only

## Alternate Posting Method (gh-pr-review extension)

If `gh api` is problematic, use the `gh-pr-review` extension instead:

```bash
# Start pending review
gh pr-review review --start -R $REPO $PR_NUMBER

# Add each inline comment (supports multi-line ranges)
gh pr-review review --add-comment -R $REPO $PR_NUMBER \
  --review-id {REVIEW_ID} \
  --path "src/foo.ts" \
  --start-line 10 \
  --line 25 \
  --side RIGHT \
  --body "**Important:** Comment here"

# Submit with general body
gh pr-review review --submit -R $REPO $PR_NUMBER \
  --review-id {REVIEW_ID} \
  --event COMMENT \
  --body "General review body here"
```

## Important

- Always include `commit_id` / `--commit` to pin the review to the current HEAD — prevents stale comments if the PR is force-pushed.
- Only comment on lines that appear in the diff. If unsure, move the comment to the general body.
- The general review body should be **robotic**: tables, bullets, short factual statements. No prose, no adjectives, no bolded praise. Think CI report.
- Inline comments should be **human**: conversational, direct, like a teammate. Use "you"/"we", ask questions, explain the why. Still use severity prefixes.
