---
name: review-pr
description: Use when reviewing a GitHub pull request - dispatches code-reviewer subagent, reads changed files, and posts structured review with inline line-range comments to GitHub
---
# Review PR

Dispatch the `superpowers:code-reviewer` subagent to review a GitHub PR, then post the review to GitHub with inline file comments (with line ranges) and a general review body.

**Announce at start:** "Reviewing PR #$0 — fetching data, running code review, and posting to GitHub."

## Process

### Step 1: Gather PR context

```bash
# Get repo identifier
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# Get PR metadata
gh pr view $0 --json title,body,baseRefName,headRefName,baseRefOid,headRefOid,files,author

# Get the diff (this is what the reviewer needs)
gh pr diff $0
```

Save `BASE_SHA`, `HEAD_SHA`, `REPO`, PR title, and PR body for later steps.

### Step 1a: Create a temporary worktree at the PR's HEAD

**Never check out a different branch in the main worktree** — other agents may be reading files concurrently. Create a temporary worktree instead:

```bash
git fetch origin pull/$0/head
git worktree add /tmp/pr-review-$0 HEAD_SHA --detach
```

Use `/tmp/pr-review-$0` as the base path for **all file reads** from here on — both your own reads in Step 1b and the subagent's reads in Step 2. Pass this path (`WORKTREE_PATH`) to the subagent prompt so it reads from the correct location.

### Step 1b: Gather architectural context (what makes reviews insightful)

The diff alone only shows what changed. Insightful reviews need to understand **where the code is going** and **what patterns already exist**. Gather:

1. **Related specs/plans** — search for spec/plan docs related to the PR's feature area:

   ```bash
   # Check for specs, plans, or design docs mentioned in PR body or related to changed paths
   find specs/ docs/plans/ -name "*.md" 2>/dev/null | head -20
   ```

   Read any specs that relate to the PR's feature. These reveal the **destination** — what's planned next, how many more files will follow this pattern, what the full scope looks like.
2. **Sibling files** — read files adjacent to the changed ones that follow (or should follow) the same patterns. This reveals whether the PR is consistent with existing conventions or diverging.
3. **Consumers/callers** — for new APIs, helpers, or exports: who will use them? How many call sites will exist? This reveals whether an abstraction is warranted.

Include all of this in the subagent prompt as `## Architectural Context`.

### Step 2: Dispatch code-reviewer subagent

Use the Agent tool with `subagent_type: "superpowers:code-reviewer"` and `model: "sonnet"` (no  `isolation` — the worktree from Step 1a is shared).

Include `WORKTREE_PATH` in the subagent prompt and instruct it to read all files from that path (e.g., `{WORKTREE_PATH}/src/foo.ts` instead of `src/foo.ts`). The subagent must read the actual changed files (not just the diff) to understand full context.

**Critical instruction for the subagent prompt — append this to the standard code-reviewer template:**

```
## Architectural Context

{PASTE specs, sibling file summaries, and caller info gathered in Step 1b}
```

Then append the review lenses and output format below:

```
## Review Lenses

Go beyond correctness. Apply each lens to the changed code:

### 1. Pattern Recognition
Look at the SHAPE of the code, not just whether it works:
- Is this a known pattern done partially? (e.g., helpers without encapsulation = proto-POM)
- Is there an established pattern (design pattern, architecture pattern) that would fit here?
- Are there repeated structures that signal a missing abstraction?

### 2. Projection — Where Is This Going?
Use the architectural context (specs, plans) to evaluate the current code against its future:
- If 5 more files will follow this pattern, does the current approach scale?
- Will selectors/constants/configs scatter across files without a central source?
- Are there extension points that should exist now to avoid painful retrofits?

### 3. Consistency with Existing Codebase
Compare against sibling files and existing conventions:
- Does it follow the patterns established elsewhere in the codebase?
- If it deviates, is the deviation justified or accidental?
- Are there existing utilities/helpers that could be reused instead of reinvented?

### 4. Abstraction Fitness
Evaluate whether the level of abstraction is right:
- Too abstract: premature generalization for a single use case
- Too concrete: duplicated logic that should be shared (only if 3+ repetitions exist or are planned)
- Just right: matches the current and near-term needs

### 5. Integration Surface
How does this code connect to the rest of the system?
- Are the boundaries clean? (clear inputs/outputs, no hidden dependencies)
- Will changes here force changes elsewhere?
- Is the coupling appropriate for the relationship between components?

For each lens, if you find something noteworthy, include it as an insight in the review.
Prefix insightful observations with **Insight:** (separate from bug/issue severity).
Not every lens will produce findings — only include substantive observations.

## Output Format for GitHub Posting

Structure your review output in TWO clearly separated sections:

### GENERAL REVIEW
Put strengths, recommendations, assessment, and any feedback NOT tied to specific
lines here. This becomes the top-level review body on GitHub.

**Tone: robotic/structured.** Write like a CI report, not a human. Use tables, bullet lists,
short factual statements. No adjectives, no prose, no bolded praise phrases like "Clean design"
or "Well-implemented". Just state what happened and whether it's correct.

Example structure:
```

## Summary

| Area               | Status                                |
| ------------------ | ------------------------------------- |
| Credential routing | ✅ Provider setting now controls path |
| Dead code removal  | ✅ 3 deprecated settings removed      |
| Test coverage      | ✅ New routing paths covered          |

## Notes

- `apiBaseUrl` override only applies to GFP path — intentional per PR description
- Tests still reference `ANTHROPIC_API_KEY` env var (vestigial, non-blocking)

## Verdict

Ready to merge / Needs fixes / Needs discussion

```

### INLINE COMMENTS
For every issue tied to specific code, output a JSON array. Each entry:

{
  "path": "relative/file/path",
  "body": "Your comment (markdown OK)",
  "start_line": <first line of range, or same as line for single-line>,
  "line": <last line of range>,
  "side": "RIGHT"
}

Rules:
- Lines MUST fall within the PR diff (changed/added lines or diff context lines)
- Use start_line < line for multi-line ranges, start_line == line for single-line
- side: "RIGHT" for new/changed code, "LEFT" for deleted code
- Prefix the body with: **Critical:**, **Important:**, **Minor:**, or **Insight:**

**Tone: human/conversational.** Write inline comments like a teammate, not a linter.
Be direct but friendly. Use "you" and "we". Ask questions. Explain the *why*.
Don't write formal topic sentences — just say what you see and what you'd suggest.

Good: "This'll break if `provider` is ever `undefined` — the `else` branch assumes it's always `\"anthropic\"`. Worth a guard?"
Bad: "**Important:** The else branch assumes the provider is always 'anthropic'. Consider adding a guard clause for undefined values."

Good: "Nice catch exporting this — kills the duplicate string problem."
Bad: "**Insight:** Exporting SECRET_KEY eliminates duplicate string literals across modules."

Still use the severity prefix (**Critical:**/**Important:**/**Minor:**/**Insight:**) but write the rest conversationally.

Output ONLY valid JSON for the array. Example:

INLINE_COMMENTS_JSON:
[
  {
    "path": "src/foo.ts",
    "body": "**Important:** This variable stopped being used after your refactor — safe to remove?",
    "start_line": 42,
    "line": 42,
    "side": "RIGHT"
  },
  {
    "path": "src/bar.ts",
    "body": "**Minor:** This is basically the same logic as `validate()` — might be worth pulling into a shared helper so they don't drift apart.",
    "start_line": 10,
    "line": 25,
    "side": "RIGHT"
  }
]
```

### Step 3: Parse the review output

From the subagent's response, extract:

1. **General review body** — everything in the `GENERAL REVIEW` section
2. **Inline comments JSON** — the array after `INLINE_COMMENTS_JSON:`

### Step 4: Post to GitHub

Use `gh api` to post the review in a single API call:

```bash
gh api repos/{REPO}/pulls/$0/reviews \
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

- Reviewer says "Ready to merge? Yes" → `"event": "APPROVE"`
- Reviewer says "Ready to merge? With fixes" → `"event": "COMMENT"`
- Reviewer says "Ready to merge? No" → `"event": "REQUEST_CHANGES"`

**Fallback:** If `gh api` fails with a 422 (line not in diff), remove the offending comment from the array and move it into the general body instead. Retry.

### Step 4b: Clean up the worktree

```bash
git worktree remove /tmp/pr-review-$0
```

### Step 5: Report to user

Show:

- Link to the posted review
- Summary of how many inline comments were posted
- The assessment verdict

## Alternate Posting Method (gh-pr-review extension)

If `gh api` is problematic, use the `gh-pr-review` extension instead:

```bash
# Start pending review
gh pr-review review --start -R {REPO} $0

# Add each inline comment (supports multi-line ranges)
gh pr-review review --add-comment -R {REPO} $0 \
  --review-id {REVIEW_ID} \
  --path "src/foo.ts" \
  --start-line 10 \
  --line 25 \
  --side RIGHT \
  --body "**Important:** Comment here"

# Submit with general body
gh pr-review review --submit -R {REPO} $0 \
  --review-id {REVIEW_ID} \
  --event COMMENT \
  --body "General review body here"
```

## Important

- Always include `commit_id` / `--commit` to pin the review to the current HEAD — prevents stale comments if the PR is force-pushed.
- Only comment on lines that appear in the diff. If unsure, move the comment to the general body.
- The general review body should be **robotic**: tables, bullets, short factual statements. No prose, no adjectives, no bolded praise. Think CI report.
- Inline comments should be **human**: conversational, direct, like a teammate. Use "you"/"we", ask questions, explain the why. Still use severity prefixes.
