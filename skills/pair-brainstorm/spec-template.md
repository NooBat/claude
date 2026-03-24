# Spec Template

Use this template when writing the feature specification. Fill in each section based on the research and design conversation. Remove placeholder comments.

**Rules:**
- **WHAT only, never HOW** — no tech stack, no code, no API routes, no architecture. Those belong in `/plan`.
- **Max 3 `NEEDS CLARIFICATION` markers** — guess the rest and document in Assumptions.
- **Each user story is an MVP slice** — independently testable and valuable on its own.
- Use Given/When/Then for complex behavior, simple checklist for obvious behavior.

```markdown
# Spec: [Feature Name]
Date: YYYY-MM-DD
Status: Draft | Approved
Ticket: [PROJ-1234 or N/A]

## Codebase Context
<!-- Populated from Phase 1 research — real findings, not placeholders -->
- **Relevant existing code:** [specific files, modules, utilities that touch this area]
- **Established patterns:** [conventions the implementation should follow]
- **Reusable components:** [existing code that can be leveraged or extended]
- **External research:** [how similar problems are solved elsewhere, relevant libraries]

## Problem Statement
<!-- What problem are we solving and WHY. Frame the problem, not the solution.
     Include: who is affected, what's the impact, what triggered this work. -->

## Constraints & Boundaries
- **In scope:** [what this spec covers]
- **Out of scope:** [what this spec explicitly does NOT cover]
- **Technical constraints:** [platform limits, performance requirements, compatibility needs]
- **Assumptions:** [conditions that, if false, invalidate this spec — include any informed guesses here]

## User Stories
<!-- Each story is an independent MVP slice — testable and valuable on its own.
     P1 = you can ship JUST this. P2 = next increment. P3 = nice-to-have. -->

### US1: [Story Title] (P1 — MVP)
As a [user type], I want [capability] so that [benefit].

**Why this priority:** [value explanation]

**Acceptance Criteria:**
- Given [precondition], when [action], then [expected result]
- Given [precondition], when [action], then [expected result]

### US2: [Story Title] (P2)
As a [user type], I want [capability] so that [benefit].

**Acceptance Criteria:**
- Given [precondition], when [action], then [expected result]

### Edge Cases
- What happens when [boundary condition]?
- How does the system handle [error scenario]?

## Functional Requirements
<!-- Numbered, testable. WHAT the system must do, not HOW.
     Use NEEDS CLARIFICATION for genuine unknowns (max 3 total). -->
- **FR-001:** [requirement statement]
- **FR-002:** [requirement statement]
- **FR-003:** [NEEDS CLARIFICATION: specific question]

## Key Entities
<!-- Core data concepts this feature touches — WHAT they represent, not HOW they're stored -->
- **[Entity]:** [what it represents, key attributes, relationships]

## Decisions Log
<!-- Key forks in the road — link to ADR files for full reasoning -->
| Decision | Chosen | Rejected | ADR |
|----------|--------|----------|-----|
| [decision description] | [chosen approach] | [rejected approach] | [docs/decisions/NNN-short-title.md] |

## Story Breakdown
<!-- FEATURE-LEVEL ONLY — omit entirely for story-level specs.
     Each story should be independently plannable via /plan. -->

| # | Story | Depends On | Risk | Description |
|---|-------|-----------|------|-------------|
| 1 | [story name] | — | [H/M/L] | [what this story delivers] |
| 2 | [story name] | 1 | [H/M/L] | [what this story delivers] |

### Dependency Graph
<!-- Which stories can run in parallel vs. must be sequenced -->

### Recommended Order
<!-- Start with: highest-risk or most foundational story first -->

## Success Criteria
<!-- How do we know this is done? Measurable where possible. -->
- **SC-001:** [measurable outcome]
- **SC-002:** [measurable outcome]

## Open Questions
<!-- Anything unresolved that the planner needs to address -->
```
