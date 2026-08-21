# Blacksmith — Anti-patterns

This file is the canonical home for lessons learned during an orchestration run, exactly as `references/anti-patterns.md` is forge's — a red flag belongs here the moment it generalizes beyond the run that surfaced it, not scattered into `SKILL.md`.

| Red flag | Why it is wrong |
|---|---|
| Dispatching before battle-plan approval | The gate is the wrapper's contract, exactly as Step 6 is forge's. |
| Treating any file overlap as hard | Over-serializes; the two grades exist precisely to avoid this. |
| Merging because the PR page says green | The ancestor proof, not the PR UI, releases a relay. |
| Downgrading depth on high blast radius | Floor 2. The auth-one-liner case is the reason the axes are separate. |
| Letting the implementing model be the only reviewer | Floor 4, generalized from `codex impl`. |
| Dispatching a plan-sourced task without the freshness check | Nothing else re-validated that plan against the repo. |
| Treating disjoint file sets as proof of independence | Semantic conflicts exist; the rebase-then-`/goal` rule is the defense. |
| Auto-removing worktrees | Inherited from forge's `worktree` flag: losing in-progress state on inferred completion is the wrong default. |
| Silent truncation under `budget` | Anything deferred or downgraded must be named in the close-out. |
| A check written without its failure branch | An agent hitting the failed check has no defined behavior, so two runs diverge; every check needs its branch and the reason. |
| A classification rule that routes missing data to the permissive branch | An empty list satisfies a "disjoint"-style predicate vacuously, so unknown scope silently takes the parallel-safe path; missing data must route to the conservative branch. |
