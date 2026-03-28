# Plan Task Templates

Pick the right variant based on the work type:
- **Feature** — adding new behavior. Tests-first, then implementation.
- **Refactoring** — changing structure, behavior stays identical. Green baseline, then structural changes.

**Task format:** `- [ ] T001 [P?] Description with exact file path`
- `[P]` = parallelizable (different files, no dependencies — can dispatch to parallel subagents)

---

## Feature Variant (adding behavior)

```markdown
## Setup (if needed)
- [ ] T001 Create project structure per technical design
- [ ] T002 [P] Configure dependencies

## Tests (unit — TDD cycle, write ALL first)
One behavior per test. Complete, executable test code against the Technical Design's interfaces. Actively discover edge cases beyond the spec.

- [ ] T003 Test: [spec acceptance criterion 1]

\`\`\`python
def test_filtered_export_includes_only_matching_rows():
    ...
\`\`\`

- [ ] T004 Test: [spec acceptance criterion 2]

\`\`\`python
def test_user_can_choose_filename_and_destination():
    ...
\`\`\`

- [ ] T005 Test: [edge case discovered while writing tests]

\`\`\`python
def test_empty_dataset_after_filter_exports_headers_only():
    ...
\`\`\`

- [ ] T006 Run unit test suite — verify all FAIL (not error)

Run: `pytest tests/unit/test_story.py -v`
Expected: All FAIL (missing implementation). If any ERROR, fix the test — errors mean broken test code, not missing behavior.

## Implementation (make unit tests green)
Each task references which test(s) it makes green by task ID.

- [ ] T007 Implement [core component] in `path/to/file` → T003, T004 pass

\`\`\`python
def function(input):
    return expected
\`\`\`

- [ ] T008 Handle [edge case] in `path/to/file` → T005 passes
- [ ] T009 Run unit suite — verify ALL green + no regressions
- [ ] T010 Refactor while green (clean up, extract helpers, improve names)
- [ ] T011 Run unit suite — verify still ALL green after refactor

## Integration Tests (post-implementation verification)
Verify components work together. Written after implementation, not part of TDD cycle.

- [ ] T012 Integration test: [end-to-end scenario from spec acceptance criteria]

\`\`\`python
def test_full_export_roundtrip():
    ...
\`\`\`

- [ ] T013 Run integration suite — verify PASS
- [ ] T014 Commit
```

### Feature Rules
- **Unit tests first** — write ALL before implementation, they're the executable specification
- **One behavior per test task** — each test task has one test function with complete code
- **Edge case discovery** — actively discover edge cases while writing tests
- **Implementation references tests** — says which test(s) it makes green (e.g., "→ T003, T004 pass")
- **Refactor step** — after all unit tests green, refactor while staying green
- **Integration tests after implementation** — verify components work together
- **FAIL vs ERROR** — unit tests should FAIL (missing behavior), not ERROR (broken test code)

---

## Refactoring Variant (changing structure, not behavior)

```markdown
## Green Baseline
- [ ] T001 Run existing test suite — verify ALL green

Run: `pytest -v`
Expected: ALL PASS. If any fail, fix them first — never refactor on a red baseline.

## Characterization Tests (fill coverage gaps)
Capture current behavior before changing structure. Only needed where existing tests don't cover the code you're about to change.

- [ ] T002 Test: [existing behavior that refactoring could break]

\`\`\`python
def test_current_export_format_preserved():
    # captures CURRENT behavior, not desired behavior
    ...
\`\`\`

- [ ] T003 Test: [another coverage gap]
- [ ] T004 Run suite — verify still ALL green (characterization tests pass immediately)

## Structural Changes (behavior stays identical)
Small, safe changes. Run tests after EVERY change — not just at the end.

- [ ] T005 [structural change description] in `path/to/file`
- [ ] T006 Run suite — still ALL green
- [ ] T007 [next structural change]
- [ ] T008 Run suite — still ALL green
- [ ] T009 Commit
```

### Refactoring Rules
- **Green baseline first** — never refactor on red. Fix failures before starting.
- **Characterization tests** — capture current behavior where coverage gaps exist
- **Run tests after every change** — not just at the end. If red, undo last change.
- **No failing tests** — if a test fails during refactoring, you broke behavior. Undo.

---

## Both Variants
- Complete code in plan (not "add validation" — show the validation code)
- Exact commands with expected output
