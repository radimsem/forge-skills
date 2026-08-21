export const meta = {
  name: 'blacksmith-scout-fanout',
  description: 'Run forge Part 1 for each task in parallel and return structured proposals',
  phases: [{ title: 'Scout', detail: 'one forge Part 1 per task, stops at the gate' }],
}

const SCOUT_SCHEMA = {
  type: 'object',
  required: ['ref', 'title', 'kind', 'filesToTouch', 'symbols', 'plan',
             'passCriteria', 'difficulty', 'blastRadius', 'declaredBlockers',
             'openQuestions', 'risks'],
  properties: {
    ref: { type: 'string' },
    title: { type: 'string' },
    kind: { type: 'string', enum: ['bug', 'feature', 'chore', 'docs'] },
    filesToTouch: { type: 'array', items: { type: 'string' } },
    symbols: { type: 'array', items: { type: 'string' } },
    plan: { type: 'string' },
    passCriteria: { type: 'string' },
    difficulty: { type: 'string', enum: ['high', 'medium', 'low'] },
    blastRadius: { type: 'string', enum: ['high', 'medium', 'low'] },
    declaredBlockers: { type: 'array', items: { type: 'string' } },
    openQuestions: { type: 'array', items: { type: 'string' } },
    risks: { type: 'array', items: { type: 'string' } },
  },
}

// Wrapped in an exported function so this file is a syntactically valid ES
// module: a bare top-level `return` (as in the originating task brief) is
// illegal outside a function in both scripts and modules. `args`, `phase`,
// `parallel`, `agent` and `log` are the Workflow engine's injected call
// surface; the body below is otherwise unchanged from the brief.
export default async function run(args, { phase, parallel, agent, log }) {
  const tasks = Array.isArray(args) ? args : []

  phase('Scout')
  const proposals = await parallel(
    tasks.map((t) => () =>
      agent(
        [
          `Load the forge skill and run Part 1 only (Steps 1 through 6) for ref ${t.ref}.`,
          'Stop at the Step 6 gate. Do NOT edit any file and do NOT ask the user anything.',
          'If a Step 4 required field is missing, do not interview: record the question in',
          'openQuestions and continue with your best assumption noted in risks.',
          'Return the structured proposal only.',
          t.hint ? `Context from the caller: ${t.hint}` : '',
        ].filter(Boolean).join('\n'),
        { label: `scout:${t.ref}`, phase: 'Scout', schema: SCOUT_SCHEMA },
      ),
    ),
  )

  const ok = proposals.filter(Boolean)
  log(`scouted ${ok.length}/${tasks.length} tasks`)
  return { proposals: ok, failed: tasks.length - ok.length }
}
