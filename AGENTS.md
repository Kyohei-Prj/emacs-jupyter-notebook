# Workflow: Plan → Implement → Feedback

This project uses a 3-stage AI-driven workflow on top of OpenCode.

## Stages
1. **Planning** — `/plan <idea>` (uses the `planner` agent). Produces `docs/<slug>/architecture.md`, `spec.md`, `implementation-plan.md`, and an empty `feedback-log.md`. Commit the docs manually before starting Implementation.
2. **Implementation** — `/implement-phase <n> <slug>` (uses the `lead` agent).
   `lead` creates and switches to `feature/<slug>-phase-<n>`, MUST delegate each task to the `task-implementer` subagent via the Task tool — one task at a time (unless tagged [parallel-with]) — rather than editing files itself, then commits the completed phase.
3. **Feedback** — `/review-phase <n> <slug>` (uses the `lead` agent).
   `lead` delegates the review to `phase-reviewer`, presents findings to the user, delegates confirmed blocking fixes to `issue-resolver` sequentially, and only on confirmation delegates doc updates to `doc-updater`, then commits all fixes and doc updates. Merging the feature branch to main is the user's responsibility.

**Automated alternative:** `/autorun <slug>` (uses the `lead` agent) runs the full Implementation → Feedback cycle for all phases without pausing for confirmation. `lead` stops only when a subagent reports FAIL and waits for user direction.

## Context hygiene rule
Any agent doing actual file edits during Implementation or Feedback must be a subagent invoked via Task, not the primary session. The primary session
holds summaries, not diffs.

## Docs
All planning docs for a unit of work live under `docs/<slug>/`. See the`planning-docs` skill for templates and task type tag rules.

# Behavioral Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Utilities

- Reference to `emacs-jupyter` API and related information can be found under `/home/kyohei/Projects/jupyter/`.
- Use skills `elisp-development` to facilitate elisp coding.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
