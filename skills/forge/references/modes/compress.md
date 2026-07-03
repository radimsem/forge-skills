# Forge — `compress` flag

Runs the whole forge session in a token-saving output mode by sourcing a compression skill
before Step 1. The point is to keep a long forge run (proposal, implementation, multi-pass
review) from burning context on verbose prose and over-built code, without changing what the
lifecycle does.

## Manual verification recipe

```
/forge 42 compress
```

Expected: before any Step 1 output, the agent sources `ponytail` (or `caveman` if ponytail is
absent) and announces it in one line. Every subsequent step runs under that mode. After each
re-hydrate `/compact`, the mode is re-sourced. If neither skill is installed, one line notes
the flag is ignored and the run proceeds normally.

## Skill selection

Check the runtime's available-skills list (for Claude Code, the skills offered to the Skill
tool) and pick the **first** match, in this order:

1. **`ponytail`** — preferred. It is the newer and more widely adopted of the two, and it
   compresses the bigger token sink: the code itself (minimal diffs, no unrequested
   abstractions), plus the prose around it. Accept either the bare `ponytail` name or a
   plugin-namespaced form such as `ponytail:ponytail`. Source it at its default intensity
   (`full`); do not pass a level unless the user asked for one.
2. **`caveman`** — fallback. Compresses prose only (~75% on explanation text), leaves code
   untouched.
3. **Neither installed** — the flag is inert. Say so in one line (mirroring how `codex` is
   ignored on non-Claude-Code runtimes) and run a normal session. Never try to install
   either skill or emulate their behavior from memory; an unsourced imitation drifts.

Source exactly one skill, never both. One compression discipline keeps the output shape
predictable; ponytail's own docs suggest pairing with caveman, but that is the user's call to
make explicitly, not this flag's.

## When it fires

At parameter-parse time, before Step 1 produces any output — the savings compound across the
whole session, so sourcing late forfeits most of them. Announce the choice in a single line
("compress: sourcing ponytail") and move on.

### Interaction with the re-hydrate block

The Steps 8/9 re-hydrate block runs `/compact`, which can shed the sourced skill's
persistence along with the stale reviewer transcript. After re-sourcing `/karpathy-guidelines`,
re-source the compression skill chosen at startup. The re-hydrate block becomes:

```
/compact  →  re-source /karpathy-guidelines  →  re-source <compression skill>
```

Keep the startup choice; do not re-run selection (the installed-skill set does not change
mid-session).

## What compression must never eat

The flag compresses style, not contract. These stay complete regardless of mode:

- The Step 5 proposal block — every field of the proposal template, in full.
- Step 4 interview question blocks and their proposed answers.
- The Step 12 `/goal` verification — exact commands and their real output, shown.
- Safety-relevant text: destructive-action confirmations, security findings, the Step 6 gate
  question. (Caveman's own auto-clarity exception already carves these out; the same rule
  binds under ponytail.)
- Code correctness: ponytail's "when NOT to be lazy" list (trust-boundary validation, error
  handling, security, accessibility, anything explicitly requested) binds — and the repo's
  own code standards and reviewer agents always outrank the compression skill. A Step 8
  reviewer finding is never waved off as "ponytail said less code".

If compression and a forge gate ever pull in opposite directions, the gate wins.

## Composition

| Combination | Effect |
|---|---|
| `compress` + `automode` | Orthogonal; both simply apply. The autonomous run's assumption notes and the Step 12 plan-only output stay complete per the list above. |
| `compress` + `docs` | `CONTEXT.md` gets the full proposal template — the file is the plan source for Part 2, so it is contract, not prose. |
| `compress` + `tdd` | Composes; ponytail's one-runnable-check instinct yields to `/tdd`'s explicit red-green discipline, which the user opted into. |
| `compress` + reviewer flags (`codex`, `coderabbit`) | Composes; reviewer subagents run in their own context and are unaffected. Rework prompts stay fully specified. |
| `/forge pr <N>` + `compress` | Applies — it shapes output, not lifecycle, so PR-entry mode honors it (review summaries and comments get terser without dropping findings). |

## Scope

The mode governs this forge session's output. It does not persist beyond the session, and
"stop ponytail" / "stop caveman" / "normal mode" from the user lifts it immediately without
touching the rest of the forge run.
