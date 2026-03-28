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
Each task references which test(s) it makes green by task ID. **Every task must include complete, reviewable code** — a reviewer should understand exactly what happens without guessing.

- [ ] T007 Implement `export_csv` in `src/dashboard/export.py` → T003, T004 pass

**Files:** Create `src/dashboard/export.py`
**Codebase context:** Follow existing pattern in `src/dashboard/query.py` which uses similar filter logic

\`\`\`python
import csv
import io

UTF8_BOM = b"\xef\xbb\xbf"

def export_csv(dataset: list[dict], filters: dict) -> bytes:
    filtered = [
        row for row in dataset
        if all(row.get(k) == v for k, v in filters.items())
    ]
    if not filtered:
        return UTF8_BOM  # headers-only handled by T008

    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=filtered[0].keys())
    writer.writeheader()
    writer.writerows(filtered)
    return UTF8_BOM + buf.getvalue().encode("utf-8")
\`\`\`

- [ ] T008 Implement `parse_csv` in `src/dashboard/export.py` → T003, T004, T005 use this

\`\`\`python
def parse_csv(data: bytes) -> list[dict]:
    text = data.decode("utf-8-sig")  # strips BOM
    if not text.strip():
        return []
    reader = csv.DictReader(io.StringIO(text))
    return list(reader)
\`\`\`

- [ ] T009 Handle empty-after-filter edge case in `export_csv` → T005 passes

Add headers-only output when filter produces zero rows:

\`\`\`python
# Replace the early return in export_csv:
if not filtered and dataset:
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=dataset[0].keys())
    writer.writeheader()
    return UTF8_BOM + buf.getvalue().encode("utf-8")
if not dataset:
    return b""
\`\`\`

- [ ] T010 Run unit suite — verify ALL green + no regressions

Run: `pytest tests/unit/test_export.py -v`
Expected: ALL PASS

- [ ] T011 Refactor while green (clean up, extract helpers, improve names)
- [ ] T012 Run unit suite — verify still ALL green after refactor

## Integration Tests (post-implementation verification)
Verify components work together with real server/API. Written after implementation, not part of TDD cycle.

- [ ] T013 Integration test: full export round-trip through API in `tests/integration/test_export_api.py`

\`\`\`python
def test_export_endpoint_returns_csv_file(test_client, seed_data):
    # seed_data fixture creates 10 rows, 5 active
    response = test_client.post("/api/export", json={
        "format": "csv",
        "filters": {"status": "active"},
    })
    assert response.status_code == 200
    assert response.headers["content-type"] == "text/csv; charset=utf-8"

    rows = parse_csv(response.content)
    assert len(rows) == 5
    assert all(r["status"] == "active" for r in rows)
\`\`\`

- [ ] T014 Run integration suite — verify PASS
- [ ] T015 Commit
```

### Feature Rules
- **Complete code in every task** — tests AND implementation. A reviewer reads the plan and knows exactly what will be built. No placeholders, no "handle X" without showing how.
- **Unit tests first** — write ALL before implementation, they're the executable specification
- **One behavior per test task** — each test task has one test function with complete code
- **Edge case discovery** — actively discover edge cases while writing tests
- **Implementation references tests** — says which test(s) it makes green (e.g., "→ T003, T004 pass")
- **Refactor step** — after all unit tests green, refactor while staying green
- **Integration tests after implementation** — verify components work together with real dependencies
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
Small, safe changes. Run tests after EVERY change. **Every task must include the actual code change** — a reviewer should see exactly what moves where.

- [ ] T005 Extract `_apply_filters` helper from `export_csv` in `src/dashboard/export.py`

\`\`\`python
# Extract filtering logic into reusable helper:
def _apply_filters(dataset: list[dict], filters: dict) -> list[dict]:
    return [
        row for row in dataset
        if all(row.get(k) == v for k, v in filters.items())
    ]

def export_csv(dataset: list[dict], filters: dict) -> bytes:
    filtered = _apply_filters(dataset, filters)  # was inline list comp
    # ... rest unchanged
\`\`\`

- [ ] T006 Run suite — still ALL green
- [ ] T007 Move `parse_csv` to `src/dashboard/parsers.py`, update imports

\`\`\`python
# src/dashboard/parsers.py (new file)
import csv
import io

def parse_csv(data: bytes) -> list[dict]:
    text = data.decode("utf-8-sig")
    if not text.strip():
        return []
    reader = csv.DictReader(io.StringIO(text))
    return list(reader)

# src/dashboard/export.py — update import:
# - from .export import parse_csv  (remove)
# + from .parsers import parse_csv (add)
\`\`\`

- [ ] T008 Run suite — still ALL green
- [ ] T009 Commit
```

### Refactoring Rules
- **Complete code in every task** — show exactly what moves where, what gets renamed, what gets extracted. A reviewer sees the before/after without guessing.
- **Green baseline first** — never refactor on red. Fix failures before starting.
- **Characterization tests** — capture current behavior where coverage gaps exist
- **Run tests after every change** — not just at the end. If red, undo last change.
- **No failing tests** — if a test fails during refactoring, you broke behavior. Undo.

---

## Both Variants
- Complete code in plan (not "add validation" — show the validation code)
- Exact commands with expected output
