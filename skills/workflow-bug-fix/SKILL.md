---
name: workflow-bug-fix
description: Guide for investigating and fixing bugs systematically. Use when you need to diagnose a bug, find its root cause, and implement a minimal fix with regression tests.
user-invocable: true
argument-hint: "[bug-description-or-ticket]"
---

# Workflow: Systematic Bug Fix

You are guiding through the systematic process of fixing a bug. Follow each phase in order. Use tasks to track progress.

## Debugging Principles

- **Reproduce first**: Cannot fix what you cannot reproduce
- **Minimal changes**: Smallest fix that resolves the issue
- **Root cause**: Fix the cause, not the symptom
- **Test coverage**: Add tests that would have caught the bug
- **Regression prevention**: Ensure fix doesn't break other features

---

## Phase 1: Reproduction

### Step 1: Gather Information
- Read bug report carefully
- Note steps to reproduce
- Identify affected components
- Check for error messages or stack traces
- Note environment details (browser, OS, versions)

### Step 2: Reproduce Locally

Follow the reproduction steps. Confirm:
- [ ] Bug reproduced successfully
- [ ] Error messages captured
- [ ] Console/log output noted
- [ ] Network requests checked (if applicable)

**If cannot reproduce:**
- Try different environments
- Check for data dependencies
- Request more details from reporter
- Look for race conditions or timing issues

---

## Phase 2: Diagnosis

### Step 3: Identify the Component

Use code search to find the relevant code:
- Search for error messages in the codebase
- Trace the call stack from the error
- Find the component/module where the bug manifests

### Step 4: Read and Understand

Read the component and surrounding files:
- Implementation code
- Custom hooks/utilities used
- State management (store, context, etc.)
- Parent and child components/callers
- API integrations

**Look for:**
- State management issues
- Missing error handling
- Incorrect logic or conditions
- Race conditions
- Missing null/undefined checks
- Stale closures or references

### Step 5: Check Existing Tests

Look at the test file for this component:
- [ ] Tests exist for this component
- [ ] Tests cover the buggy behavior
- [ ] Tests are passing (but shouldn't be, given the bug?)

### Step 6: Identify Root Cause

Common bug categories:

| Category | Symptoms | Common Causes |
|----------|----------|---------------|
| **State** | UI doesn't reflect changes | Stale state, missing deps, mutation instead of immutable update |
| **API** | Data not loading, wrong data | Wrong params, missing error handling, cache issues |
| **Logic** | Wrong behavior | Incorrect condition, off-by-one, type coercion |
| **Rendering** | Visual glitches, crashes | Null access, infinite loop, missing key |
| **Async** | Intermittent failures | Race condition, stale closure, missing cleanup |

---

## Phase 3: Fix

### Step 7: Write Failing Test

Before fixing, write a test that reproduces the bug:
- The test should FAIL with the current code
- The test should PASS after the fix
- The test should describe the expected behavior

Run test to confirm it fails.

### Step 8: Implement Minimal Fix

Apply the smallest change that resolves the issue:
- Fix the root cause, not a symptom
- Don't refactor surrounding code (separate concern)
- Don't add unrelated improvements

### Step 9: Verify Fix

- [ ] Failing test now passes
- [ ] No other tests broken
- [ ] Bug no longer reproduces manually
- [ ] Related features still work

---

## Phase 4: Regression Prevention

### Step 10: Add Edge Case Tests

Add tests for related edge cases:
- Empty/null/undefined inputs
- Boundary conditions
- Error states
- Concurrent operations (if applicable)

### Step 11: Check for Similar Bugs

Search for similar patterns in the codebase that might have the same bug. If found, fix them or create separate tickets.

---

## Phase 5: Review

### Step 12: Self-Review

Check:
- [ ] Fix is minimal (no unrelated changes)
- [ ] No debug artifacts left (console.log, debugger, etc.)
- [ ] Types are correct
- [ ] All tests pass
- [ ] Linting passes

### Step 13: Run Full Test Suite

Run the project's test suite, type checker, and linter. All should pass.

---

## Phase 6: Commit & PR

### Step 14: Commit

Use conventional commit format:
```
fix: [description of what was fixed]

[Explain root cause and how the fix addresses it]

Closes TICKET-ID
```

### Step 15: Create Pull Request

Include in the PR description:
- **Root cause**: Why the bug happened
- **Fix**: What was changed and why
- **Testing**: How to verify the fix
- **Regression tests**: What tests were added

---

## Checklist Summary

**Reproduction**
- [ ] Bug reproduced locally
- [ ] Steps documented

**Diagnosis**
- [ ] Root cause identified
- [ ] Similar bugs checked

**Fix**
- [ ] Failing test written first
- [ ] Minimal fix implemented
- [ ] Test now passes
- [ ] Manual testing completed
- [ ] No regressions

**Quality**
- [ ] Edge case tests added
- [ ] All tests pass
- [ ] Type checking passes
- [ ] Linting passes

**Deployment**
- [ ] Clear commit message with root cause
- [ ] PR created with explanation
