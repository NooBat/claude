---
name: workflow-refactor
description: Guide for refactoring code safely and systematically. Use when restructuring code while preserving behavior - ensures test baselines, incremental changes, and no regressions.
user-invocable: true
argument-hint: "[component-or-module-name]"
---

# Workflow: Safe Refactoring

You are guiding through safe, systematic code refactoring. The cardinal rule: **behavior stays identical**. Follow each phase in order. Use tasks to track progress.

## When to Refactor

**Do refactor when:**
- Component/module exceeds 200 lines
- Logic is duplicated across components
- Tests are difficult to write
- Component has multiple responsibilities
- Performance issues identified
- Code is hard to understand
- Patterns are inconsistent with codebase

**Don't refactor when:**
- Code works and is clear
- No tests exist (write tests first!)
- Under time pressure
- No clear improvement goal

## Refactoring Principles

- **Tests first**: Always ensure test coverage before refactoring
- **Small steps**: Make incremental changes, test after each
- **No behavior changes**: Refactoring and features are separate PRs
- **One thing at a time**: Stay focused on one refactoring goal
- **Maintain or improve tests**: Never let test coverage decrease

---

## Phase 1: Planning

### Step 1: Identify Refactoring Goal

Be specific about what you're improving:
- **Extract component/module**: Break monolith into smaller pieces
- **Extract function/hook**: Move complex logic to reusable unit
- **Performance**: Reduce unnecessary work, optimize computations
- **Simplify logic**: Reduce nesting, improve readability
- **Unify patterns**: Match rest of codebase
- **Type safety**: Add/improve types, remove `any`

### Step 2: Ensure Test Coverage

**CRITICAL**: Do not refactor without tests!

Run existing tests. If coverage is poor:
1. Write characterization tests for current behavior first
2. Ensure tests pass
3. Then proceed to refactor

### Step 3: Create Refactoring Plan

Document:
- What you're changing
- Why you're changing it
- What stays the same (public API/behavior)
- Incremental steps (each independently testable)

---

## Phase 2: Test Baseline

### Step 4: Run Full Test Suite

Run all tests. **Every test must pass.**

If any test fails: fix it first. Never refactor on a red baseline.

Save the test output as your baseline.

---

## Phase 3: Refactor

### Step 5: Make Small, Incremental Changes

**Don't** refactor everything at once. **Do** make small commits for each change.

Common refactoring moves:

**Extract component/module:**
1. Identify distinct sections
2. Create separate files
3. Move logic and rendering
4. Pass data via props/parameters
5. Update tests for each piece
6. Verify original still works

**Extract function/hook:**
1. Create new file for the function/hook
2. Move logic out of the component/caller
3. Return a clean interface
4. Update caller to use the extracted unit
5. Write tests for the extracted unit

**Simplify logic:**
1. Use early returns to reduce nesting
2. Use declarative methods (filter, map) instead of imperative loops
3. Extract complex conditions to named variables
4. Break large functions into smaller ones

**Improve type safety:**
1. Define proper interfaces for data structures
2. Add types to function parameters and returns
3. Replace `any` with specific types
4. Fix type errors that surface

### Step 6: Test After EVERY Change

Run tests after each incremental change. If tests fail:
- The change broke behavior — undo it
- Figure out what went wrong
- Try a different approach

---

## Phase 4: Verification

### Step 7: Run All Quality Checks

- [ ] All tests pass
- [ ] Type checking passes
- [ ] Linting passes

### Step 8: Manual Testing

Run the application and verify:
- [ ] All features work as before
- [ ] No visual regressions
- [ ] No console errors
- [ ] Performance same or better

### Step 9: Review the Diff

Check that:
- [ ] Changes are focused on the refactoring goal
- [ ] No unrelated changes included
- [ ] No behavior changes (unless fixing an actual bug)
- [ ] Public API unchanged (or properly updated)

---

## Phase 5: Documentation

### Step 10: Update Documentation

If the refactoring changed structure significantly:
- Update usage docs/examples
- Add architectural comments for non-obvious decisions
- Update README if public API changed

---

## Phase 6: Commit & PR

### Step 11: Commit

Use conventional commit format:
```
refactor: [description of structural change]

[Explain what was restructured and why]
No behavior changes.
```

### Step 12: Create Pull Request

Include in the PR description:
- **Motivation**: Why this refactoring improves the code
- **Changes**: What was restructured
- **Impact**: No behavior changes, all tests pass
- **Performance**: Same or better

---

## Common Pitfalls

| Pitfall | Problem | Solution |
|---------|---------|----------|
| **Over-abstraction** | Creating abstractions for code used once | Extract only when reused 2-3+ times |
| **Breaking changes** | Changing public API during refactor | Keep API stable, or version carefully |
| **Scope creep** | "While I'm here, I'll also..." | Stay focused on one goal |
| **No tests** | Refactoring without coverage | Write tests first, then refactor |
| **Big bang** | Refactoring everything at once | Incremental changes, one PR at a time |
| **Mixed concerns** | Refactoring AND adding features | Separate PRs: refactor first, feature second |

---

## Checklist Summary

**Before**
- [ ] Refactoring goal clear
- [ ] Tests exist and pass (green baseline)
- [ ] Plan documented

**During**
- [ ] Small, incremental changes
- [ ] Tests pass after each change
- [ ] Behavior unchanged
- [ ] Public API stable

**After**
- [ ] All tests pass
- [ ] Type checking passes
- [ ] Linting passes
- [ ] Manual testing completed
- [ ] No regressions
- [ ] Documentation updated

**Deployment**
- [ ] Clear PR description with motivation
- [ ] Review completed
