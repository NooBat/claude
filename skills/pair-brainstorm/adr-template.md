# ADR Template

Use this template for Architecture Decision Records. Create one ADR per significant decision where the rejected alternative was genuinely reasonable.

**Threshold:** Only create an ADR when someone six months from now would ask "why didn't you do X instead?"

**Storage:** `docs/decisions/NNN-short-title.md` (user preferences override this default)

**Numbering:** Sequential (001, 002, ...) within the project's decisions directory.

If multiple serious alternatives were rejected, repeat the "Why Not" section for each.

```markdown
# ADR-NNN: [Decision Title]
Date: YYYY-MM-DD

## Context
<!-- What situation or question prompted this decision?
     Include relevant constraints, requirements, or codebase facts. -->

## Decision
<!-- What was chosen and the core reasoning.
     Be specific: "We chose X because Y" not "We decided to go with X." -->

## Why Not [Alternative Name]
<!-- The strongest rejected alternative and why it lost.
     Be fair — explain what was good about it and what tipped the scale. -->
```
