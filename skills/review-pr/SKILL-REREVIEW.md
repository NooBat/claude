# Re-review Process

This file is read by the main SKILL.md when a prior review baseline is detected. It handles incremental reviews — only reviewing what changed since the last review, respecting thread resolution and author replies.

**Prerequisite variables** (set by SKILL.md Step 0):
- `PR_NUMBER`, `REPO`, `GH_HOST`, `CURRENT_USER`, `PR_AUTHOR`
- `OLD_HEAD` — commit SHA of the last reviewed version
- `HEAD_SHA` — current PR head
- `V1_REVIEW_ID` — ID of the previous review
- `V1_REVIEW_TIME` — when the previous review was submitted

---

## Step R0: Determine what changed since last review

Get the incremental diff (only changes since last review):
```bash
git fetch origin pull/$PR_NUMBER/head
git diff $OLD_HEAD..$HEAD_SHA
```

Also get the full list of files changed since last review:
```bash
git diff --name-only $OLD_HEAD..$HEAD_SHA
```

Save as `DELTA_DIFF` and `DELTA_FILES`.

If `DELTA_DIFF` is empty (no code changes since last review), report: "No code changes since your last review at {V1_REVIEW_TIME}. The PR head is still at the same state." and stop.

## Step R1: Read author replies and thread resolution

Use `gh-pr-review` extension (preferred) or `gh api` to get thread context:

```bash
gh pr-review review view -R $REPO --pr $PR_NUMBER \
  --reviewer $CURRENT_USER \
  --not_outdated \
  --tail 3
```

If the extension is not available, fall back to:
```bash
gh api repos/$REPO/pulls/$PR_NUMBER/comments --hostname $GH_HOST --paginate \
  --jq '[.[] | {id, path, body, user: .user.login, in_reply_to_id, created_at}]'
```

Classify each thread from the previous review:

| Status | Meaning | Action in Re-review |
|--------|---------|---------------------|
| **Resolved** | Thread marked as resolved on GitHub | Skip — do not re-flag |
| **Author replied** | PR author acknowledged or explained | Read reply; only re-flag if the explanation is incorrect or the issue persists in new code |
| **No response** | No reply and not resolved | Check if the code was changed; if unchanged, carry forward as a brief reminder |
| **Outdated** | Code at that location was changed | Re-evaluate in context of new code |

Save the classification as `THREAD_CONTEXT`.

## Step R2: Create or reuse worktree

Follow SKILL.md Step 1a (worktree creation/reuse). The worktree from the first review may still exist — reuse it by checking out `HEAD_SHA`.

## Step R3: Gather fresh architectural context

Follow SKILL.md Step 1b but **only for files in `DELTA_FILES`**. No need to re-gather context for unchanged files.

## Step R4: Dispatch subagent with delta-focused prompt

Dispatch a subagent with `model: "sonnet"`. The prompt should include:

1. **The delta diff** (not the full PR diff) — only changes since last review
2. **Thread context** — the classified threads from Step R1, so the reviewer knows what was already discussed
3. **Architectural context** — from Step R3
4. **The full PR diff** — for reference, but instruct the reviewer to focus on the delta
5. **WORKTREE_PATH** — for reading full file context

**Critical instructions for the subagent:**
- Focus on new/changed code since `OLD_HEAD`
- Do NOT re-flag issues that are resolved or acknowledged by the author
- For unresolved threads with no author response: briefly note "Previously flagged, still open" if the code is unchanged
- For outdated threads (code changed at that location): re-evaluate fresh
- Apply the same review lenses and output format as PROMPT-TEMPLATE.md

## Step R5: Post incremental review

Follow SKILL.md Step 4 (posting to GitHub) with these adjustments:

- The general review body should start with: "Re-review of changes since {V1_REVIEW_TIME} ({OLD_HEAD}..{HEAD_SHA})"
- Include a delta summary: "N files changed, M new comments"
- If there are unresolved threads from the previous review that are still relevant, mention them briefly in the general body

## Step R6: Report to user

Show:
- Link to the posted review
- Delta summary (files changed since last review, new comments posted)
- Threads carried forward vs resolved
- Assessment verdict
