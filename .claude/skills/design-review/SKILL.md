---
name: design-review
description: Review the changed code for clean software design — SOLID, dependency injection, testability, and DRY-vs-coupling balance — using a fresh, unbiased subagent, then apply the fixes. Complements /simplify (dedup/simplicity/perf) and /code-review (correctness/security). Invoke after finishing an implementation, or on demand with a target (a file, a PR number, a branch).
argument-hint: "[<target>]"
---

`/design-review → design-reviewer subagent (blind) → apply fixes → /simplify cleanup pass`

You are checking the changed code's structural design — not hunting for bugs
(`/code-review`) and not doing dedup/style/perf cleanup (`/simplify`). The point of
this skill is a judgment call only a reviewer with no stake in the implementation can
make well: is this wired for dependency injection and testability, does it hold up
against SOLID, and is DRY being applied sensibly rather than used to justify coupling
things that don't belong together.

## Phase 0 — Gather the diff scope

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1` if
there's no upstream) to see what's in scope. If there are uncommitted changes, or the
range diff is empty, also run `git diff HEAD` and fold the working-tree changes into
scope — this review often runs before a commit. If the user passed a target
(`$ARGUMENTS`: a PR number, branch name, or file path), review that instead.

Don't review the diff yourself here — you're about to hand it to a subagent that
must judge it fresh. The only thing this phase produces is *what to point that
agent at* (a diff, a target description), not an opinion about it.

## Phase 1 — Launch the design-reviewer subagent (blind, foreground)

Launch the `design-reviewer` subagent via the Agent tool, with `run_in_background:
false` — Phase 2 needs its findings before continuing.

Brief it with **only**:
- the diff itself (or the target you resolved in Phase 0)
- file paths / project layout it may need to read surrounding context

Do **not** include:
- why the implementation session made the choices it did
- your own read on whether the code is fine
- any framing that nudges it toward or away from a particular verdict

This is deliberate, not an oversight — the whole value of this skill is a verdict
uncontaminated by the rationalizations that accumulate while writing code. If you
catch yourself explaining the reasoning behind a change in the agent's prompt,
cut it; let the diff speak for itself.

For a diff that touches genuinely separate concerns (e.g. a data layer change and an
unrelated UI change), you may launch more than one `design-reviewer` agent in
parallel — one per concern — so each stays focused, the same way `/simplify` fans
out across angles. For an ordinary single-purpose diff, one agent is enough.

## Phase 2 — Apply the fixes

Read the findings the subagent reported. For each:
- Apply it if it's a real, scoped improvement.
- Skip it if the fix would change intended behavior, ripple well outside the
  reviewed diff, amount to speculative future-proofing, or you judge it a false
  positive — note the skip rather than arguing with it.

Dedup findings that point at the same underlying issue before applying.

## Phase 3 — Clean up with simplify

If Phase 2 changed anything, invoke the `simplify` skill on the resulting diff —
applying design fixes (e.g. introducing a new seam or splitting a class) can itself
leave behind the kind of duplication or awkwardness `/simplify` is built to catch.
Skip this phase if Phase 2 made no changes.

## Phase 4 — Summary

Close with a short summary: what design issues were found, what was fixed, what was
skipped and why, and confirm existing tests/analyzer still pass after the changes.
