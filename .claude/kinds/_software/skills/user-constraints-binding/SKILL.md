---
name: user-constraints-binding
description: Every constraint the owner states is binding. Use whenever a plan, design or brief touches a numbered constraint in docs/design/constraints.md, or the owner says something will not work.
---

# User constraints are binding

The failure this prevents: building a feature the owner said would not work.

## Rules

1. Read `docs/design/constraints.md` before you plan, design or build.
2. Every `C<n>` is binding. It is not a preference and not a starting point.
3. If your work conflicts with a `C<n>`, stop. Report to the owner:
   `Conflict with C<n>: "<quote>". My plan needed: <what>.` Then wait.
4. Do not argue the constraint. Do not build around it. Do not build it
   "just to show it works". Do not continue with the rest and leave it for later.
5. Only the owner can withdraw a constraint. A reviewer, planner or your own
   judgement cannot.
6. If the owner states a new constraint mid-session, the requirements-owner
   records it as the next `C<n>` before any more work.
