# Forge — Codex reviewer reference

Loaded on demand by SKILL.md Step 8 **only when the `codex` or `codex challenge` flag is set**. Default (no flag) runs never read this file.

**Claude Code only** — the `codex` plugin is CC-exclusive. Non-CC runtime: ignore the flag, warn once, use `superpowers:requesting-code-review`, do not read further. The rest of forge stays runtime-generic.

## Step 8a — Codex generic reviewer

`/codex:review` / `/codex:adversarial-review` are `disable-model-invocation: true` — unreachable via the Skill/command tool inside an autonomous loop. Drive the companion script over Bash:

1. **Resolve + pre-flight** (once/run) via the bundled helper. Run it by its absolute path — `<forge-skill-dir>/scripts/resolve-codex.py`, where `<forge-skill-dir>` is the base directory announced when this skill loaded (the dir containing `SKILL.md`):
   ```bash
   python3 <forge-skill-dir>/scripts/resolve-codex.py
   ```
   It `JSON.parse`s `codex-companion.mjs setup --json` and prints the newest companion's absolute path **iff** `ready && codex.available && auth.loggedIn`; otherwise prints `UNAVAILABLE` and exits non-zero (covers: plugin/node/Codex missing or not authenticated). Capture stdout as `<script>`.
2. Output `UNAVAILABLE` (plugin absent, Codex missing, or unauthenticated) → **degrade gracefully**: warn the Codex reviewer is unavailable, fall back to `superpowers:requesting-code-review` this run, continue the loop. Never stall.
3. **Run foreground/synchronous** (the loop needs findings now) with the resolved `<script>`:
   - `codex` → `node <script> review --wait`
   - `codex challenge` → `node <script> adversarial-review --wait` (challenges approach/design/assumptions). Implies `codex`; **never both passes**.
4. Verbatim Codex output = this pass's generic-reviewer findings; merge with the project reviewer agents' findings; same must-fix/should-fix termination as Step 8.

## Step 8b — Optional: delegate rework to Codex (agent discretion)

Codex-suited findings (mechanical refactors, a self-contained fix Codex itself proposed) → forge **may** hand rework to the `codex:codex-rescue` subagent instead of fixing inline. Judgment call; small fixes stay inline. `automode`: auto-decide — delegate only if net-positive + clearly Codex-suited.

Delegation **follows the re-hydration**:

1. **Re-hydrate** (`/compact` → re-source `/karpathy-guidelines`) Claude-side first — forge still reviews Codex's returned diff with fresh discipline.
2. Dispatch via the **Agent tool**, `subagent_type: "codex:codex-rescue"` (subagent, *not* a skill — never `Skill(codex:rescue)`; re-enters the command, hangs). Codex is a different runtime, **cannot source the `/karpathy-guidelines` skill** — inline its substance as task-prompt constraints:
   ```
   Constraints (follow strictly before touching code):
   <karpathy-guidelines principles — surgical/minimal changes,
    no overcomplication, surface assumptions, verifiable success criteria>

   Task: <specific rework, scoped to the finding>
   ```
3. **Foreground (`--wait`)** — loop blocks until rework returns, then re-enter Step 8 on the new diff. Background + lifecycle polling (`node <script> status|result|cancel`, or `/codex:status|result|cancel` for the user) only for a rare long rescue.
4. The subagent only *forwards* to Codex; doesn't poll/cancel itself. Returns nothing (Codex failed) → fix inline, continue — never stall the loop on a failed delegation.
