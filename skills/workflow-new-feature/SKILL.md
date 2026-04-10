---
name: workflow-new-feature
description: Guide for implementing a new feature from planning to deployment. Use for features with established patterns that don't need a full /plan design phase.
user-invocable: true
argument-hint: "[feature-name]"
---

# Workflow: New Feature Development

You are guiding through the complete workflow for implementing a new feature. Follow each phase in order. Use tasks to track progress.

## Prerequisites

- [ ] Requirements understood
- [ ] Design mockups available (if applicable)
- [ ] API endpoints documented or planned

---

## Phase 1: Planning

### Step 1: Understand Requirements
- Read feature requirements carefully
- Identify user stories and acceptance criteria
- List all UI components / modules needed
- Determine data requirements
- Clarify validation rules

### Step 2: Review Similar Features
- Find similar features in the codebase
- Study existing patterns and conventions
- Identify reusable components/utilities
- Check for shared infrastructure

### Step 3: Architect the Design
- Design component/module hierarchy
- Plan state management approach
- Map data flow
- Plan file structure
- Identify integration points

---

## Phase 2: Setup

### Step 4: Create Project Structure

Create directories and files per the project's conventions:
- Follow existing package/module structure
- Set up configuration files
- Add dependencies if needed

### Step 5: Define Types/Interfaces

Create type definitions for:
- Data models (API responses, internal state)
- Component props / function parameters
- Configuration objects
- Event handlers

### Step 6: Create API Layer (if applicable)

Set up API integration:
- Define endpoints and parameters
- Set up data fetching (hooks, services, etc.)
- Configure caching/invalidation
- Handle request/response transformations

---

## Phase 3: Implementation

### Step 7: Create Custom Hooks/Utilities

Extract complex logic into reusable units:
- Data fetching and transformation
- State management logic
- Business rule implementations
- Helper functions

### Step 8: Build Components/Modules

Build in order of dependency (leaf nodes first):
- Use the project's component library (not raw HTML)
- Follow existing conventions for structure and naming
- Ensure proper error and loading states

### Step 9: Implement Forms (if applicable)

Build forms with:
- Proper validation rules
- Error message display
- Submit handling
- Dirty state tracking

---

## Phase 4: Testing

### Step 10: Write Unit Tests

Cover:
- Component rendering
- User interactions
- Business logic
- Edge cases (empty, null, error states)
- Accessibility

### Step 11: Run Tests and Checks

Run the project's full quality suite:
- [ ] Unit tests pass
- [ ] Type checking passes
- [ ] Linting passes

---

## Phase 5: Review

### Step 12: Self-Review

Check:
- [ ] Project's component library used consistently
- [ ] Strings localized (if applicable)
- [ ] Types defined properly
- [ ] API integration correct
- [ ] Form validation complete
- [ ] Tests written
- [ ] Accessibility compliant

### Step 13: Manual Testing

Run the application and test:
- [ ] All features work as expected
- [ ] Forms validate correctly
- [ ] API calls succeed
- [ ] Loading states display properly
- [ ] Error handling works
- [ ] Keyboard navigation works

---

## Phase 6: Documentation

### Step 14: Add Documentation

As needed:
- Localization keys
- Component usage docs
- API documentation
- README updates

---

## Phase 7: Commit & PR

### Step 15: Commit

Use conventional commit format:
```
feat: [description of feature]

- [key change 1]
- [key change 2]
- [key change 3]
```

### Step 16: Create Pull Request

Include in the PR description:
- Summary of the feature
- List of changes by file
- Test plan
- Screenshots (if visual changes)
- Risk assessment

---

## Phase 8: Address Feedback

### Step 17: Respond to Review Comments
- Make requested changes
- Update tests if needed
- Re-run quality checks

---

## Checklist Summary

**Planning**
- [ ] Requirements understood
- [ ] Similar features reviewed
- [ ] Architecture planned

**Implementation**
- [ ] Types defined
- [ ] API layer set up
- [ ] Hooks/utilities created
- [ ] Components built
- [ ] Forms with validation (if applicable)

**Quality**
- [ ] Tests written and passing
- [ ] Type checking passes
- [ ] Linting passes
- [ ] Manual testing completed
- [ ] Accessibility verified

**Documentation**
- [ ] Localization keys added (if applicable)
- [ ] Component docs updated (if needed)

**Deployment**
- [ ] Code committed
- [ ] PR created with full description
- [ ] Review feedback addressed
