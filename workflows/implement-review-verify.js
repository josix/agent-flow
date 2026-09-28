export const meta = {
  name: 'implement-review-verify',
  description: 'agent-flow Phases 3-5: Loid implements, then Lawliet + Codex + Alphonse review/verify in parallel, with capped batched fix rounds',
  whenToUse: 'Called by /agent-flow:orchestrate after planning. Not meant to be run directly.',
  phases: [
    { title: 'Implement', detail: 'Loid implements the plan (or locates the target from the intent)' },
    { title: 'Review & Verify', detail: 'Lawliet, Codex (optional) and Alphonse in parallel' },
    { title: 'Fix', detail: 'Loid fixes all blocking findings in one batch' },
  ],
}

// args (from commands/orchestrate.md):
//   intent:          verbatim intent block (Goal/Description/Actions/Constraints/Assumptions)
//   plan:            Senku's checklist, or a path under .claude/agent-reports/, or '' when Phases 1-2 were skipped
//   profile:         'fast' | 'standard' | 'thorough'
//   codex:           true when Codex co-review should run (profile allows it AND codex.available: true)
//   state_file:      path to .claude/orchestration.local.md
//   plugin_root:     ${CLAUDE_PLUGIN_ROOT}
//   prior_findings:  optional — findings to fix first when relaunched after an escalation
//   start_round:     optional — rounds already used before an escalation relaunch (keeps the cap)
//   preambles:       optional — graph / personal-KB / AgentsView preamble lines for Lawliet
//
// Returns one of:
//   { status: 'complete', ... }     all gates passed (or ENVIRONMENT_BLOCKED caveat)
//   { status: 'capped', ... }       round cap reached with open findings — report them
//   { status: 'escalation', ... }   Loid hit a contradicted load-bearing assumption — ask the user, relaunch
//   { status: 'divergence', ... }   Codex-only finding repeated on the same file:line — ask the user
//   { status: 'blocked', ... }      Loid could not proceed (error it couldn't fix)

const A = args || {}
const PROFILE = A.profile || 'standard'
const MAX_ROUNDS = { fast: 1, standard: 2, thorough: 3 }[PROFILE] || 2
const START_ROUND = Number.isInteger(A.start_round) && A.start_round > 0 ? A.start_round : 0
const ROOT = A.plugin_root || '${CLAUDE_PLUGIN_ROOT}'
const REPORT_RULE = 'If your report exceeds ~3000 characters, write the full report under .claude/agent-reports/ and put its path in report_path.'

const FINDING = {
  type: 'object',
  required: ['severity', 'file', 'line', 'issue'],
  properties: {
    severity: { type: 'string', enum: ['ERROR', 'WARNING', 'INFO'] },
    file: { type: 'string' },
    line: { type: 'integer' },
    issue: { type: 'string' },
  },
}

const LOID_SCHEMA = {
  type: 'object',
  required: ['status', 'review_base', 'items', 'verification', 'summary'],
  properties: {
    status: { type: 'string', enum: ['done', 'partial', 'blocked', 'escalation'] },
    review_base: { type: 'string', description: 'Output of the snapshot command you ran BEFORE editing' },
    items: {
      type: 'array',
      items: {
        type: 'object',
        required: ['item', 'status'],
        properties: { item: { type: 'string' }, status: { type: 'string', enum: ['done', 'skipped'] }, reason: { type: 'string' } },
      },
    },
    verification: { type: 'string', description: 'The verification block with the commands you ran and their results' },
    escalation: { type: 'string', description: 'The full <escalation> block when status is escalation' },
    blocker: { type: 'string', description: 'Failed command, error output, and what you tried when status is blocked' },
    summary: { type: 'string' },
    report_path: { type: 'string' },
  },
}

const LAWLIET_SCHEMA = {
  type: 'object',
  required: ['verdict', 'findings', 'summary'],
  properties: {
    verdict: { type: 'string', enum: ['APPROVED', 'NEEDS_CHANGES'] },
    findings: { type: 'array', items: FINDING },
    intent_mismatch: { type: 'string', description: 'Set when the patch does not do what the Goal/Constraints asked' },
    summary: { type: 'string' },
    report_path: { type: 'string' },
  },
}

const ALPHONSE_SCHEMA = {
  type: 'object',
  required: ['overall', 'tests', 'types', 'lint', 'build'],
  properties: {
    overall: { type: 'string', enum: ['VERIFIED', 'FAILED', 'ENVIRONMENT_BLOCKED'] },
    tests: { type: 'string' },
    types: { type: 'string' },
    lint: { type: 'string' },
    build: { type: 'string' },
    failures: { type: 'array', items: { type: 'string' }, description: 'One entry per failing test/gate with file:line when known' },
    environment_blocker: { type: 'string', description: 'Exact error signature when overall is ENVIRONMENT_BLOCKED' },
    report_path: { type: 'string' },
  },
}

const CODEX_SCHEMA = {
  type: 'object',
  required: ['codex_ran', 'verdict', 'raw'],
  properties: {
    codex_ran: { type: 'boolean' },
    verdict: { type: 'string', description: 'codex_verdict line from the helper output' },
    raw: { type: 'string', description: 'Full contents of the codex_raw_path file (empty if none)' },
    skip_reason: { type: 'string' },
  },
}

const key = f => `${f.file}:${f.line}`
const blocking = fs => fs.filter(f => f.severity === 'ERROR' || f.severity === 'WARNING')
const errors = fs => fs.filter(f => f.severity === 'ERROR')

function parseCodex(raw) {
  const out = []
  for (const line of (raw || '').split('\n')) {
    const m = line.match(/^\s*(ERROR|WARNING|INFO):\s*(.+?):(\d+):\s*(.+)$/)
    if (m) out.push({ severity: m[1], file: m[2], line: Number(m[3]), issue: m[4], source: 'codex' })
  }
  return out
}

function loidPrompt(round, findings) {
  const snapshot = 'Before editing anything, run `git stash create 2>/dev/null || true` and, if that printed nothing, `git rev-parse HEAD`; return that value as review_base.'
  if (round === 0) {
    return [
      'Implement this task. You run targeted checks only (changed files + their tests); Alphonse runs the full suite afterwards.',
      snapshot,
      '## Intent (verbatim)', A.intent || '(none provided)',
      '## Plan', A.plan ? String(A.plan) : 'No plan was produced (Phases 1-2 skipped for this profile). Locate the target from the intent yourself.',
      A.prior_findings ? `## Fix these first\n${A.prior_findings}` : '',
      'Report status "escalation" with the full <escalation> block if a load-bearing intent assumption is contradicted; "blocked" with the failing command and output if you cannot proceed.',
      REPORT_RULE,
    ].filter(Boolean).join('\n\n')
  }
  return [
    `Review-fix round ${round}. Fix ALL of these blocking findings in one pass, then re-run targeted checks.`,
    snapshot,
    '## Intent (verbatim)', A.intent || '(none provided)',
    '## Findings to fix',
    findings.map(f => `- ${f.severity} ${key(f)} [${f.source}] ${f.issue}`).join('\n'),
    'List every finding as an item with done/skipped (+ reason).',
    REPORT_RULE,
  ].join('\n\n')
}

function reviewPrompt(reviewBase, round, previous) {
  const scope = round === 0
    ? 'Review the full change for this task (branch diff + working tree + new untracked files).'
    : `Review ONLY the fix: \`git diff ${reviewBase}\` plus new untracked files. Confirm each previous finding is resolved:\n${previous.map(f => `- ${key(f)} ${f.issue}`).join('\n')}`
  return [
    A.preambles || '',
    'Phase 4 review. Codex and Alphonse run in parallel with you — you own static analysis (type check, lint, semgrep, complexipy) and intent fidelity.',
    scope,
    '## Intent (verbatim)', A.intent || '(none provided)',
    'Only ERROR/WARNING findings with file:line are blocking; keep nits as INFO.',
    REPORT_RULE,
  ].filter(Boolean).join('\n\n')
}

function alphonsePrompt() {
  return [
    'Phase 5 verification. Lawliet is reviewing in parallel and runs type check + lint, so run the FULL test suite and the build only, and report types/lint as "COVERED (Lawliet)".',
    'Classify failures caused solely by an environment mismatch the change did not introduce as ENVIRONMENT_BLOCKED with the exact error signature.',
    REPORT_RULE,
  ].join('\n\n')
}

function codexPrompt(reviewBase, round) {
  const base = round === 0 ? '' : ` --diff-base ${reviewBase}`
  return [
    'Run this command with the Bash tool (set the Bash timeout to 600000 ms — it can take up to 8 minutes):',
    '```bash',
    `mkdir -p .claude/codex && bash "${ROOT}/scripts/dispatch-codex-review.sh" --state-file "${A.state_file || '.claude/orchestration.local.md'}"${base}`,
    '```',
    'Parse its key: value output. If codex_raw_path is set, read that file, return its full contents as raw, then delete the file. Return codex_ran, verdict (the codex_verdict value), raw, and skip_reason if present. Do not review anything yourself.',
  ].join('\n')
}

const history = []
let loid = null
let roundsUsed = 0
let extraRoundUsed = false
let lastCodexOnly = ''
let toFix = []
let lastReview = null

for (let round = START_ROUND; ; round++) {
  phase(round === 0 ? 'Implement' : 'Fix')
  loid = await agent(loidPrompt(round === START_ROUND ? 0 : round, toFix), {
    agentType: 'agent-flow:Loid',
    schema: LOID_SCHEMA,
    phase: round === 0 ? 'Implement' : 'Fix',
    label: round === 0 ? 'Loid: implement' : `Loid: fix round ${round}`,
  })
  if (!loid) return { status: 'blocked', reason: 'Loid dispatch failed or was stopped', history }
  if (loid.status === 'escalation') return { status: 'escalation', escalation: loid.escalation, open_findings: toFix, rounds_used: round, loid, history }
  if (loid.status === 'blocked') return { status: 'blocked', reason: loid.blocker, loid, history }

  phase('Review & Verify')
  const tasks = [
    () => agent(reviewPrompt(loid.review_base, round === START_ROUND ? 0 : round, toFix), { agentType: 'agent-flow:Lawliet', schema: LAWLIET_SCHEMA, phase: 'Review & Verify', label: `Lawliet r${round}` }),
    () => agent(alphonsePrompt(), { agentType: 'agent-flow:Alphonse', schema: ALPHONSE_SCHEMA, phase: 'Review & Verify', label: `Alphonse r${round}` }),
  ]
  if (A.codex) {
    tasks.push(() => agent(codexPrompt(loid.review_base, round === START_ROUND ? 0 : round), { schema: CODEX_SCHEMA, phase: 'Review & Verify', label: `Codex r${round}`, effort: 'low' }))
  }
  const [lawliet, alphonse, codex] = await parallel(tasks)

  if (!lawliet || !alphonse) {
    return { status: 'blocked', reason: `${!lawliet ? 'Lawliet' : 'Alphonse'} dispatch failed or was stopped`, loid, history }
  }

  // Phase 4 truth table (skills/verification-gates/references/codex-co-review.md)
  const lawFindings = lawliet.findings.map(f => ({ ...f, source: 'lawliet' }))
  const codexFindings = codex && codex.codex_ran && ['NEEDS_CHANGES', 'BLOCKED'].includes(codex.verdict) ? parseCodex(codex.raw) : []
  if (codex && codex.codex_ran && !['APPROVED', 'NEEDS_CHANGES', 'BLOCKED'].includes(codex.verdict)) {
    log(`Codex verdict ${codex.verdict || 'missing'} — treating as advisory`)
  }
  const lawKeys = new Set(blocking(lawFindings).map(key))
  const codexOnly = blocking(codexFindings).filter(f => !lawKeys.has(key(f)))
  // A NEEDS_CHANGES verdict must never pass silently: when Lawliet gives no
  // cited ERROR/WARNING (e.g. an intent mismatch), carry its reason as a finding.
  const lawBlocking = blocking(lawFindings)
  if (lawliet.verdict === 'NEEDS_CHANGES' && lawBlocking.length === 0) {
    lawBlocking.push({ severity: 'ERROR', file: 'intent', line: 0, issue: lawliet.intent_mismatch || lawliet.summary || 'Lawliet returned NEEDS_CHANGES without a cited finding', source: 'lawliet' })
  }
  const reviewBlocking = lawliet.verdict === 'NEEDS_CHANGES'
    ? lawBlocking.concat(codexOnly)
    : codexOnly

  const verifyBlocking = alphonse.overall === 'FAILED'
    ? (alphonse.failures && alphonse.failures.length ? alphonse.failures : ['Verification failed — see Alphonse report'])
        .map(d => ({ severity: 'ERROR', file: 'verification', line: 0, issue: d, source: 'alphonse' }))
    : []
  // Divergence cap: Lawliet APPROVED but the same Codex-only citations repeat.
  const codexOnlySig = codexOnly.map(key).sort().join('|')
  if (lawliet.verdict === 'APPROVED' && verifyBlocking.length === 0 && codexOnlySig && codexOnlySig === lastCodexOnly) {
    return { status: 'divergence', codex_findings: codexOnly, lawliet, alphonse, loid, history }
  }
  lastCodexOnly = lawliet.verdict === 'APPROVED' ? codexOnlySig : ''

  const open = reviewBlocking.concat(verifyBlocking)
  const advisory = lawFindings.filter(f => f.severity === 'INFO').concat(codexFindings.filter(f => f.severity === 'INFO'))

  history.push({ round, lawliet: lawliet.verdict, codex: codex ? codex.verdict : 'skipped', alphonse: alphonse.overall, open: open.length, errors: errors(open).length })
  lastReview = { lawliet, alphonse, codex, advisory }

  if (open.length === 0) {
    return {
      status: 'complete',
      rounds: round,
      environment_blocker: alphonse.overall === 'ENVIRONMENT_BLOCKED' ? alphonse.environment_blocker : null,
      loid, lawliet, alphonse,
      codex: codex ? { verdict: codex.verdict, skip_reason: codex.skip_reason || null } : null,
      advisory, history,
    }
  }

  roundsUsed = round
  const prev = history.length > 1 ? history[history.length - 2] : null
  const madeProgress = prev && errors(open).length > 0 && errors(open).length < prev.errors
  if (roundsUsed >= MAX_ROUNDS) {
    if (!extraRoundUsed && madeProgress) {
      extraRoundUsed = true
      log(`Round cap ${MAX_ROUNDS} reached but ERRORs dropped ${prev.errors} → ${errors(open).length}; allowing one extra round`)
    } else {
      log(`Round cap reached with ${open.length} open finding(s); stopping`)
      return { status: 'capped', rounds: roundsUsed, open_findings: open, advisory, loid, ...lastReview, history }
    }
  }
  toFix = open
}
