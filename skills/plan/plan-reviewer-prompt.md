# Plan Document Reviewer Prompt Template

Use this template when dispatching a plan document reviewer subagent. Provide precisely crafted review context — never your session history.

**Purpose:** Verify the plan is complete, grounded in codebase reality, and actionable by an engineer with zero codebase context.

**Dispatch after:** Plan document is written.

```
Agent tool (general-purpose):
  description: "Review plan document"
  prompt: |
    You are a plan reviewer. Verify this plan is complete, grounded in real code,
    and actionable by an engineer who knows nothing about this codebase.

    **Plan to review:** [PLAN_FILE_PATH]
    **Spec (if exists):** [SPEC_FILE_PATH]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, incomplete tasks, missing sections |
    | Spec Alignment | Does every spec requirement have a task? Any scope creep (tasks not in spec)? |
    | Codebase Grounding | Do file paths exist? Do referenced functions/types exist? Are imports correct? |
    | Stack Context Loaded | Did the planner announce which rules and reference docs they read? Does the Technical Design reflect conventions from those docs? |
    | Task Decomposition | Clear boundaries between tasks? Each task independently actionable? |
    | Buildability | Could an engineer follow this without getting stuck? Any step missing context? |
    | TDD Compliance | Does each feature phase follow: failing test -> verify fail -> implement -> verify pass -> commit? |
    | Type Consistency | Do types, method signatures, property names used in later tasks match what's defined in earlier tasks? |

    ## Calibration

    **Only flag issues that would cause real problems during implementation.**
    An implementer building the wrong thing, referencing a file that doesn't exist,
    or getting stuck on an ambiguous step — those are issues.
    Minor wording, stylistic preferences, and "nice to have" suggestions are not.

    Approve unless there are serious gaps — missing requirements from the spec,
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
