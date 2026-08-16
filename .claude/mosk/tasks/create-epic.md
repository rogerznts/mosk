# create-epic

Create one focused epic for an existing project.

## When to use

Use for a bounded enhancement that fits one to three stories, follows existing
architecture and has manageable integration risk. Use the full spec/PRD and
architecture flow when scope, boundaries or technical direction need decisions.

## Workflow

1. Read project rules, relevant product/spec context and existing behavior.
2. Establish the enhancement goal, user value, boundaries, dependencies,
   compatibility constraints and measurable success. Ask one grouped question
   only for gaps that materially change the epic.
3. Write the epic with:
   - title, goal and current-system context;
   - in-scope/out-of-scope behavior;
   - one to three independently valuable stories;
   - integration and backward-compatibility requirements;
   - risks, mitigations, test strategy and rollback;
   - definition of done.
4. Check that no hidden architecture decision is required, each story has a
   verifiable outcome and dependencies are explicit.
5. Save under the canonical PRD/spec location and report the next story to
   prepare.

Do not manufacture implementation details. Reference verified project paths and
decisions; route unresolved product/architecture choices through the normal
human handoff.
