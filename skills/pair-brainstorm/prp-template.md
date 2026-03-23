# PRP Template

Use this template when writing the Product Requirements Prompt. Fill in each section based on the research and design conversation. Remove placeholder comments.

```markdown
# PRP: [Feature Name]
Date: YYYY-MM-DD
Status: Draft | Approved

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
- **In scope:** [what this PRP covers]
- **Out of scope:** [what this PRP explicitly does NOT cover]
- **Technical constraints:** [platform limits, performance requirements, compatibility needs]
- **Assumptions that must hold:** [conditions that, if false, invalidate this design]

## Solution Design

### Architecture
<!-- High-level structure: what are the main components and how do they relate? -->

### Components
<!-- For each component: what it does, how you use it, what it depends on -->

### Data Flow
<!-- How data moves through the system — inputs, transformations, outputs -->

### Error Handling
<!-- What can go wrong and how the system responds -->

### Testing Strategy
<!-- What to test, how to test it, what coverage looks like -->

## Decisions Log
<!-- Key forks in the road — link to ADR files for full reasoning -->
| Decision | Chosen | Rejected | ADR |
|----------|--------|----------|-----|
| [decision description] | [chosen approach] | [rejected approach] | [docs/decisions/NNN-short-title.md] |

## Story Breakdown
<!-- FEATURE-LEVEL ONLY — omit for story-level PRPs.
     Each story should be independently plannable via /pair-brainstorm → /plan. -->

| # | Story | Depends On | Risk | Description |
|---|-------|-----------|------|-------------|
| 1 | [story name] | — | [H/M/L] | [what this story delivers] |
| 2 | [story name] | 1 | [H/M/L] | [what this story delivers] |

### Dependency Graph
<!-- Which stories can run in parallel vs. must be sequenced -->

### Recommended Order
<!-- Start with: highest-risk or most foundational story first -->

## Success Criteria
<!-- How do we know this is done and working? Measurable where possible. -->

## Open Questions
<!-- Anything unresolved that the planner needs to address -->
```
