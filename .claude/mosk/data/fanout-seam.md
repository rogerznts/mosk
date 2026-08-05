# Fan-out seam — `dispatch_wave(plan) → results`

Reference material for `implement.md`. Describes how a **wave** of independent
work units is dispatched, verified and joined, across the three runtimes MOSK
supports.

Decisions behind this: **ADR-0012** (what may be delegated), **ADR-0013** (the
seam and its tiers), **ADR-0014** (the actuator). This file is the operational
contract; the ADRs hold the reasoning.

---

## 1. What this seam is, and what it is not

`dispatch_wave(plan) → results` takes a **human-approved fan-out plan**, executes
its units, and returns the consolidated join.

It is the sibling of `invoke_phase_agent(role, phase, spec_dir)` (ADR-0004), not
a replacement. In Tiers 2 and 3 it is *built on* it — one call per unit. The two
stay separate because a join and a wave plan do not fit an assignment shaped
"one phase, one agent": overloading that signature would push the barrier into
every caller.

**It is not an autonomous executor.** The wave runs work whose route a human
already approved, and stops at the join. Chaining one wave into the next is a
route decision, and route decisions are never delegated (ADR-0012).

---

## 2. The invariant contract — identical in all three tiers

What follows does not vary by runtime. It is what makes the observable result the
same everywhere; only the amount of structure gained differs.

1. **Disk is the state boundary.** Units read and write files. Nothing of
   consequence lives only in a unit's context (ADR-0004 §1).
2. **A unit returns a short status, never a transcript.** Verbose output goes to
   a file. A unit that streams its reasoning back defeats the isolation it was
   given.
3. **The join closes only when every unit settles** — completed, failed, or
   suspended. A wait timeout is a checkpoint, not a failure: real work runs 15–60
   minutes.
4. **`current_phase` does not branch.** One pointer per spec. The
   `phase-history.log` gets **one entry per wave**, never one per unit — that is
   what keeps the ADR-0008 attempt counter honest (a log entry per unit would
   inflate `tentativa N/max` and declare exhaustion on the first wave).
5. **Three signals suspend a branch and return it to the human**: a `judgment`
   guard raised inside the unit, an escalation, and exhaustion of that unit's
   attempt cap. They suspend **that branch only** — the others keep running.
6. **One tier per wave.** No mixing.
7. **Every wave has a sequential equivalent.** Declining parallelism degrades
   time, never capability.

---

## 3. Deriving the plan — read `[P]`, never infer it

Units come from the `[P]` markers already present in `tasks.md`, whose contract
is *different files, no dependencies between them*. The wave honours that marker;
it does not re-derive parallelism by reasoning about the code.

Where `[P]` is absent, the unit runs sequentially. **When in doubt, sequential.**
A wrongly parallel pair writing the same file corrupts work that would have
succeeded serially — the cost is asymmetric, so the tie goes to caution.

The plan presented for approval states:

- the units and their grouping (what runs together, what depends on what);
- the acceptance criterion for each unit;
- the attempt cap in force;
- the sequential equivalent, if the human declines.

Approval happens **once**, before dispatch. After it, no per-branch confirmation
is asked (ADR-0012 §3).

---

## 4. Tier 1 — Orca orchestration

**Requires the session to be running inside the Orca IDE**, not merely the binary
installed (ADR-0014 §3.1). Confirm with `panes.sh tier`.

Model: **Run** (namespace and coordinator inbox) → **Task** (work item, `--deps`
forming the DAG) → **Dispatch** (one attempt on one terminal). Lifecycle
authority lives in the Dispatch.

```bash
panes.sh run "<wave objective>"                    # bind the Run first — always
panes.sh task-create "<unit A>"                    # → task_id
panes.sh task-create "<unit B>" --deps '["<task_a>"]'
panes.sh worker-start --task <task_id> --worktree current --agent claude
```

Then wait until every dispatch settles, acknowledging each Delivery:

```bash
panes.sh await --timeout-ms 900000                 # first window
panes.sh await --ack <delivery_id> --timeout-ms 900000   # every window after
```

Two failure modes are already encoded in the wrapper and must not be undone:

- **Without `--ack`, the same Delivery is re-served every window.** The wait never
  advances. Feed back the id from `panes.sh delivery-id`.
- **`question` must stay among the awaited types.** A worker that calls `ask`
  emits that type; drop it and the worker blocks until timeout, asking someone
  who is not listening.

`--worktree current` creates a *fresh agent terminal*, not a git worktree. Create
a real worktree only on a concrete file conflict — parallelism alone is not a
reason to.

What Tier 1 buys over Tier 2: verifiable provenance (`task-list`,
`dispatch-show`), an injected lifecycle preamble, `worker_done` authority, and
`ask`/`reply` plus decision gates for the guards.

**Guards inside a branch become `ask`.** A `judgment` guard raised by a unit is
sent with `panes.sh ask`; the coordinator surfaces it to the human and answers
with `panes.sh reply`. The coordinator **creates** decision gates and only
resolves them with the human's answer — never on its own (ADR-0006, ADR-0010 §5).

---

## 5. Tier 2 — native subagent

For runtimes with an isolated subagent primitive (Claude Code). One subagent per
unit, following the Tier 1 discipline of ADR-0004: the input is the spec dir plus
the unit, the subagent reads and writes on disk, and returns a short status.

Real context isolation; no provenance, no structured question channel. A guard or
escalation comes back as a field of the returned status, and the caller surfaces
it to the human — same outcome as Tier 1's `ask`, without the typed transport.

---

## 6. Tier 3 — sequential in-session

Where no subagent primitive exists (Codex and others). Units run one after the
other in the session, under output-suppression discipline, with verbose logs
redirected to a file — the same Tier 2 arrangement of ADR-0004.

**Be honest about what this tier is.** The parallelism here is organisational,
not temporal: the gain is isolated verification per unit, not speed. Say so in
the fan-out plan rather than implying a wall-clock benefit that will not arrive.

---

## 7. Selecting the tier

Resolved by **detected capability**, never by preference written in a prompt:

```bash
panes.sh tier --json
```

| Situation | Tier |
|---|---|
| Inside the Orca IDE, orchestration available | 1 |
| Inside the IDE, orchestration experimental disabled | 2 |
| Orca installed, session **outside** the IDE | 2 |
| No Orca, runtime with native subagent | 2 |
| No native subagent | 3 |

`panes.sh tier` reports `2+` with `runtime_decides` whenever Tier 1 does not
apply: a shell cannot know whether its caller has a subagent tool, so it does not
claim to. Choosing between 2 and 3 is the caller's, from the runtime it is in.

Degradation never errors — it drops a tier, states why, and continues.

**Do not mix tiers within a wave.** Half the branches on Orca and half on
subagents yields partial provenance, which is worse than none because it invites
claiming the wave was orchestrated when only part of it was; and it gives the
join two different meanings of "done" (`worker_done` versus a returned status).
If one unit does not fit the chosen tier, the whole wave drops a tier.

---

## 8. The join

The wave closes when every unit has settled. Report to the human:

- units that converged;
- units that failed, with the reason;
- units suspended and what they are waiting on;
- what remains open.

**No wave starts another on its own.** A result that calls for more work needs a
new plan and a new approval — the same refusal ADR-0010 §5 made to Orca's
autonomous coordinator loop, applied generally.

If the approved plan stops describing what is actually happening — a unit failed
and the work needs redistributing, a unit turned out to depend on another — the
wave does **not** self-correct. It reports and asks for a new plan.

---

## 9. Dispatch failure is not a loop turn

The actuator has its own circuit breaker: after 3 consecutive failures on a task,
the dispatch context breaks and the task is marked failed. MOSK has
`max_retries` (default 3) counting **gate loopbacks per spec**. The matching
number is a coincidence; they measure different things:

| Counter | Measures | Level |
|---|---|---|
| Actuator circuit breaker | dispatch failure — the worker produced no result | infrastructure |
| `max_retries` (ADR-0008) | non-convergence of quality — a result exists and failed the gate | product |

A unit that trips the actuator's breaker is reported at the join as a **failed
unit**, and the human decides. It does **not** consume a delivery-loop turn.
Conflating them would let terminal instability eat the spec's correction budget
(ADR-0013 §6).
