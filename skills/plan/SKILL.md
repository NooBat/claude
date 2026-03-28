---
name: plan
description: "Use when you have a spec or requirements and need to create a codebase-aware implementation plan with technical design and phased tasks. Scans the codebase to find reusable code and existing patterns before planning."
---

# Plan: Codebase-Aware Implementation Planning

Write implementation plans that are grounded in what actually exists. Before writing a single task, scan the codebase to find reusable code, understand established patterns, and avoid reinventing what's already built.

**Announce at start:** "I'm using the plan skill to create a codebase-aware implementation plan."

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md` (user preferences override this default)

## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Ingest spec** (or gather requirements ad-hoc)
2. **Codebase scan** — broad architecture scan + targeted deep dives
3. **Reconcile** — cross-check spec assumptions against codebase reality
4. **Write plan** — technical design + phased implementation tasks with concrete code
5. **Review & handoff** — plan review loop, user approval, execution handoff

## Process Flow

```mermaid
flowchart TD
    A{Spec exists?}
    A -->|yes| B[Read spec, extract\nscope & context]
    A -->|no| C[Ad-hoc: ask 2-3\nrequirements questions]
    B --> D[Broad architecture scan\nproject structure, shared utils,\ntest infra, build system]
    C --> D
    D --> E[Targeted deep dives\nfiles to modify, functions to reuse,\ntest patterns, integration points]
    E --> F[Reconcile spec vs\ncodebase reality]
    F --> G{Significant\nmismatches?}
    G -->|yes| H[Report to user,\nresolve conflicts]
    G -->|no| I[Write technical design\n+ phased tasks]
    H --> I
    I --> J[Plan review loop]
    J --> K{Review passed?}
    K -->|issues found, fix and re-dispatch| J
    K -->|approved| L[User reviews plan]
    L --> M{User approves?}
    M -->|changes requested| I
    M -->|approved| N((Execution handoff))
```

---

## Phase 1: INGEST SPEC

### If spec exists:
- Read the spec file
- Extract the **Codebase Context** section (research findings from pair-brainstorm)
- Identify which **User Story** this plan covers — **each plan is scoped to ONE user story**. If the spec has multiple stories, run `/plan` separately for each.
- Extract scope, constraints, boundaries, and success criteria
- Note the **Decisions Log** — these decisions are settled; do not re-open them
- Note **Open Questions** — these need to be resolved during planning

### If no spec (ad-hoc mode):
- Ask 2-3 focused requirements questions:
  - What are you building? (scope)
  - What constraints exist? (technical limits, patterns to follow)
  - What does "done" look like? (success criteria)
- Then proceed to Phase 2

### Scope Check
Each plan covers **one user story**. If the spec has multiple user stories, run `/plan` for each one separately. If the user tries to plan multiple stories at once, suggest breaking into separate plans.

---

## Phase 2: CODEBASE SCAN

Two-pass scan. Dispatch parallel subagents for different areas.

### Pass 1: Broad Architecture Scan
Understand the project landscape:
- **Project structure:** directory layout, module organization, key config files
- **Shared utilities:** common modules, helper functions, base classes
- **Test infrastructure:** test runner, fixtures, mocks, test patterns
- **Build system:** build tools, dependency management, CI/CD
- **Code conventions:** naming, file organization, error handling patterns

### Pass 2: Targeted Deep Dives
Zoom into areas the spec touches:
- **Files to modify or extend:** read them, understand their structure
- **Functions to reuse:** identify specific functions/classes that can be leveraged
- **Existing test patterns:** how are tests written for similar functionality?
- **Integration points:** where does this feature connect to existing code?

**Dispatch subagents freely.** Examples:
- One agent scans shared utilities and common patterns
- Another explores the specific modules the spec targets
- A third reviews test infrastructure and conventions

---

## Phase 3: RECONCILE

Cross-check the spec's assumptions against what you actually found. This phase catches the "plans in a vacuum" problem.

### Validate Assumptions
- Does the spec's Codebase Context match reality?
- Are the "established patterns" it references still current?
- Are the "reusable components" it lists still available and appropriate?

### Identify Reuse Opportunities
- Functions/modules the spec missed that could reduce implementation work
- Existing test utilities that can be leveraged
- Patterns in adjacent code that should be followed

### Flag Conflicts
- Proposed architecture conflicting with existing patterns
- Data flow assumptions that don't match actual interfaces
- Dependencies that have changed since the spec was written

### Report
- **If no significant mismatches:** proceed silently to Phase 4
- **If significant mismatches found:** report to the user with specifics:
  > "The spec says X, but the codebase actually does Y. This affects the design because Z. How should we proceed?"

  Wait for the user to resolve the conflict before proceeding.

---

## Phase 4: WRITE PLAN

### Plan Document Header
Every plan MUST start with:

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Tech Stack:** [Key technologies/libraries]

**Spec Reference:** [path to spec if one exists]

---
```

### Technical Design

**This section is the HOW** — architecture, data models, API contracts, error handling. It contains concrete types, routes, and error behavior that executing agents implement against. The contract is rigid; the implementation is flexible.

```markdown
## Technical Design

### Architecture
<!-- High-level component structure: what are the main pieces and how do they relate?
     2-3 sentences + a list of components with one-line descriptions. -->

### Data Model
<!-- Concrete types/interfaces — agents use these exactly.
     Include field names, types, relationships. -->

### API Contracts (if applicable)
<!-- Exact routes, request/response shapes, error codes.
     Agents don't invent these — they implement what's here. -->

### Error Handling
<!-- Specific error scenarios and exact responses.
     "Timeout after 30s → set status='failed'" not "handle timeouts appropriately" -->

### Testing Strategy
<!-- What to test at each level: unit, integration, e2e.
     Reference specific functions/components. -->
```

**Detail level guidance:** Include concrete types with field names, exact API routes with request/response shapes, specific error scenarios with exact responses. Do NOT prescribe function bodies — that's what the task steps are for.

### File Structure
Before defining tasks, map out which files will be created or modified:
- Design units with clear boundaries and well-defined interfaces
- Each file should have one clear responsibility
- Follow established codebase patterns
- Reference specific existing files discovered in the codebase scan

### Task Structure

Each plan covers one user story (or one refactoring goal). Use the task templates in `skills/plan/task-templates.md` — pick the right variant:
- **Feature** — adding new behavior. Unit tests first → implementation → integration tests.
- **Refactoring** — changing structure, behavior stays identical. Green baseline → characterization tests → structural changes.

### Carrying Forward Decisions
- The plan inherits the spec's Decisions Log
- Do NOT re-open settled decisions
- If the codebase scan reveals new information that challenges a decision, flag it in Phase 3 (RECONCILE), don't silently override

---

## Phase 5: REVIEW & HANDOFF

### Plan Review Loop
1. Dispatch plan-reviewer subagent (see `skills/plan/plan-reviewer-prompt.md`) with precisely crafted context
2. If Issues Found: fix, re-dispatch, repeat until Approved
3. Max 3 iterations, then surface to human for guidance

### User Review
Present the plan:

> "Plan written and committed to `<path>`. Please review and let me know if you want changes before we start implementation."

Wait for user response. If changes requested, make them and re-run review loop.

### Execution Handoff
After user approves:

> "Plan approved. Two execution options:
>
> **1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration
>
> **2. Inline Execution** — Execute tasks in this session with checkpoints for review
>
> Which approach?"

**If Subagent-Driven:** Use superpowers:subagent-driven-development
**If Inline Execution:** Use superpowers:executing-plans

---

## Key Principles

- **Always scan the codebase before planning** — even if the spec has a Codebase Context section, verify it
- **Technical Design before tasks** — concrete types, API contracts, and error handling BEFORE implementation steps
- **One plan per user story** — if spec has multiple stories, run `/plan` separately for each
- **Reference specific files and functions** in every task — no generic "implement the component" steps
- **Carry forward decision rationale** — don't re-open settled decisions from the spec
- **Dispatch subagents freely** — for parallel codebase exploration
- **Reconcile before writing** — catch spec/codebase mismatches early
- **DRY, YAGNI, TDD** — same engineering principles, now grounded in real code
- **Exact file paths, complete code, exact commands** — the engineer following this plan should never have to guess
