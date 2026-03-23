# Plan Document Reviewer Prompt Template

Use this template when dispatching a plan document reviewer subagent. Provide precisely crafted review context — never your session history.

**Purpose:** Verify the plan is complete, matches the PRP, is grounded in the codebase, and has proper task decomposition.

**Dispatch after:** The complete plan is written.

```
Agent tool (general-purpose):
  description: "Review implementation plan"
  prompt: |
    You are a plan document reviewer. Verify this plan is complete, grounded in the codebase,
    and ready for implementation.

    **Plan to review:** [PLAN_FILE_PATH]
    **PRP for reference:** [PRP_FILE_PATH] (if available)

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, incomplete tasks, missing steps |
    | Spec Alignment | Plan covers PRP requirements, no major scope creep, doesn't re-open settled decisions |
    | Codebase Grounding | Tasks reference real files and functions, not generic placeholders. "Codebase context" notes in tasks should reference actual code. |
    | Task Decomposition | Tasks have clear boundaries, steps are actionable, each step is one action (2-5 min) |
    | Buildability | Could an engineer follow this plan without getting stuck? Are commands exact? Is code complete? |

    ## Calibration

    **Only flag issues that would cause real problems during implementation.**
    An implementer building the wrong thing, referencing a file that doesn't exist,
    or getting stuck on an ambiguous step — those are issues.
    Minor wording, stylistic preferences, and "nice to have" suggestions are not.

    Approve unless there are serious gaps — missing requirements from the PRP,
    contradictory steps, placeholder content, tasks so vague they can't be acted on,
    or references to code that doesn't exist.

    ## Output Format

    ## Plan Review

    **Status:** Approved | Issues Found

    **Issues (if any):**
    - [Task X, Step Y]: [specific issue] - [why it matters for implementation]

    **Recommendations (advisory, do not block approval):**
    - [suggestions for improvement]
```

**Reviewer returns:** Status, Issues (if any), Recommendations.
