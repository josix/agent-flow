#!/usr/bin/env node
// Behavioral tests for workflows/implement-review-verify.js.
// Mocks the workflow runtime (agent/parallel/phase/log/args) and replays
// scripted agent responses to check round caps, the truth table, the
// divergence cap, and early returns. Run: node scripts/test-implement-review-verify.js
'use strict'
const fs = require('fs')
const path = require('path')

const SRC = fs.readFileSync(path.join(__dirname, '..', 'workflows', 'implement-review-verify.js'), 'utf8')
  .replace(/^export const meta/m, 'const meta')
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor

const LOID_OK = { status: 'done', review_base: 'abc123', items: [], verification: 'Tests: PASS', summary: 'ok' }
const LAW_OK = { verdict: 'APPROVED', findings: [], summary: 'ok' }
const ALPH_OK = { overall: 'VERIFIED', tests: 'PASS', types: 'COVERED (Lawliet)', lint: 'COVERED (Lawliet)', build: 'PASS' }
const err = (file, line) => ({ severity: 'ERROR', file, line, issue: `bug at ${file}` })
const warn = (file, line) => ({ severity: 'WARNING', file, line, issue: `risk at ${file}` })

async function run(script, args) {
  // script: { Loid: [...], Lawliet: [...], Alphonse: [...], Codex: [...] } consumed in order
  const calls = []
  const next = who => {
    const q = script[who] || []
    if (!q.length) throw new Error(`no scripted response left for ${who}`)
    return q.shift()
  }
  const agent = async (prompt, opts = {}) => {
    const who = opts.agentType ? opts.agentType.split(':')[1] : ((opts.label || '').startsWith('Snapshot') ? 'Snapshot' : 'Codex')
    calls.push({ who, prompt })
    if (who === 'Snapshot' && !(script.Snapshot || []).length) return { ok: true, output: 'baseline_status: written' }
    return next(who)
  }
  const parallel = async thunks => Promise.all(thunks.map(t => t().catch(() => null)))
  const fn = new AsyncFunction('agent', 'parallel', 'phase', 'log', 'args', SRC)
  const result = await fn(agent, parallel, () => {}, () => {}, args === null ? null : { intent: 'Goal: test task', ...args })
  return { result, calls }
}

let failed = 0
async function test(name, fn) {
  try { await fn(); console.log(`  ✓ ${name}`) } catch (e) { failed++; console.log(`  ✗ ${name}: ${e.message}`) }
}
const eq = (a, b, m) => { if (a !== b) throw new Error(`${m}: expected ${b}, got ${a}`) }

;(async () => {
  console.log('implement-review-verify workflow')

  await test('all gates pass on first review → complete, 0 fix rounds', async () => {
    const { result, calls } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK] }, { profile: 'standard' })
    eq(result.status, 'complete', 'status'); eq(result.rounds, 0, 'rounds')
    eq(calls.filter(c => c.who === 'Codex').length, 0, 'codex skipped when args.codex falsy')
  })

  await test('codex run snapshots untracked files before Loid', async () => {
    const { calls } = await run({
      Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK],
      Codex: [{ codex_ran: true, verdict: 'APPROVED', raw: '' }],
    }, { profile: 'standard', codex: true })
    eq(calls[0].who, 'Snapshot', 'first call is the snapshot task')
    eq(calls[1].who, 'Loid', 'second call is Loid')
    if (!calls[0].prompt.includes('snapshot-untracked.sh') || !calls[0].prompt.includes('--state-file')) {
      throw new Error('snapshot prompt missing script invocation')
    }
    if (calls[0].prompt.includes('--keep-only')) throw new Error('first launch must be allowed to write the baseline')
  })

  await test('no snapshot when Codex is off', async () => {
    const { result, calls } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK] }, { profile: 'standard' })
    eq(result.status, 'complete', 'status')
    eq(calls.filter(c => c.who === 'Snapshot').length, 0, 'no snapshot dispatched')
  })

  await test('snapshot failure is non-blocking', async () => {
    const { result } = await run({
      Snapshot: [null],
      Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK],
      Codex: [{ codex_ran: true, verdict: 'APPROVED', raw: '' }],
    }, { profile: 'standard', codex: true })
    eq(result.status, 'complete', 'status')
  })

  await test('relaunch runs the idempotent snapshot before Loid (script keeps the first baseline)', async () => {
    const { calls } = await run({
      Snapshot: [{ ok: true, output: 'baseline_status: kept' }],
      Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK],
      Codex: [{ codex_ran: true, verdict: 'APPROVED', raw: '' }],
    }, { profile: 'standard', codex: true, start_round: 1 })
    eq(calls[0].who, 'Snapshot', 'snapshot runs first, before any Loid edit in this launch')
    eq(calls.filter(c => c.who === 'Snapshot').length, 1, 'one snapshot dispatch')
    if (!calls[0].prompt.includes('--keep-only')) throw new Error('relaunch snapshot must not write a fresh baseline')
  })

  await test('round-0 escalation relaunch (prior_findings: []) also snapshots with --keep-only', async () => {
    const { calls } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK], Codex: [{ codex_ran: true, verdict: 'APPROVED', raw: '' }] },
      { profile: 'standard', codex: true, start_round: 0, prior_findings: [] })
    if (!calls[0].prompt.includes('--keep-only')) throw new Error('round-0 relaunch snapshot missing --keep-only')
  })

  await test('fast launch with Codex available takes the baseline even though Codex is off', async () => {
    const { calls } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK] },
      { profile: 'fast', codex: false, codex_available: true })
    eq(calls[0].who, 'Snapshot', 'baseline taken before Loid so a standard relaunch has it')
    eq(calls.filter(c => c.who === 'Codex').length, 0, 'Codex still not dispatched')
  })

  await test('Lawliet NEEDS_CHANGES then fixed → complete after 1 round, fix scoped to diff', async () => {
    const { result, calls } = await run({
      Loid: [LOID_OK, { ...LOID_OK, review_base: 'fixbase' }],
      Lawliet: [{ verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 3), { severity: 'INFO', file: 'b.ts', line: 1, issue: 'nit' }], summary: '' }, LAW_OK],
      Alphonse: [ALPH_OK, ALPH_OK],
    }, { profile: 'standard' })
    eq(result.status, 'complete', 'status'); eq(result.rounds, 1, 'rounds')
    const fix = calls.filter(c => c.who === 'Loid')[1].prompt
    if (!fix.includes('a.ts:3') || fix.includes('b.ts:1')) throw new Error('fix prompt should batch ERROR/WARNING only, not INFO')
    const rereview = calls.filter(c => c.who === 'Lawliet')[1].prompt
    if (!rereview.includes('git diff fixbase')) throw new Error('re-review not scoped to the fix base')
  })

  await test('fast profile stops after 1 fix round with open findings → capped', async () => {
    const bad = { verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 3)], summary: '' }
    const { result, calls } = await run({ Loid: [LOID_OK, LOID_OK], Lawliet: [bad, bad], Alphonse: [ALPH_OK, ALPH_OK] }, { profile: 'fast' })
    eq(result.status, 'capped', 'status'); eq(calls.filter(c => c.who === 'Loid').length, 2, 'Loid dispatches')
  })

  await test('ERROR count dropping at the cap grants exactly one extra round', async () => {
    const two = { verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 1), err('b.ts', 2)], summary: '' }
    const one = { verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 1)], summary: '' }
    const { result, calls } = await run({
      Loid: [LOID_OK, LOID_OK, LOID_OK],
      Lawliet: [two, one, one],
      Alphonse: [ALPH_OK, ALPH_OK, ALPH_OK],
    }, { profile: 'fast' })
    eq(result.status, 'capped', 'status'); eq(calls.filter(c => c.who === 'Loid').length, 3, 'Loid dispatches (1 impl + 1 cap + 1 extra)')
  })

  await test('Alphonse FAILED is blocking even when Lawliet approves', async () => {
    const { result } = await run({
      Loid: [LOID_OK, LOID_OK],
      Lawliet: [LAW_OK, LAW_OK],
      Alphonse: [{ ...ALPH_OK, overall: 'FAILED', failures: ['tests/test_x.py::test_y'] }, ALPH_OK],
    }, { profile: 'standard' })
    eq(result.status, 'complete', 'status'); eq(result.rounds, 1, 'rounds')
  })

  await test('ENVIRONMENT_BLOCKED is not blocking and carries the caveat', async () => {
    const { result } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [{ ...ALPH_OK, overall: 'ENVIRONMENT_BLOCKED', environment_blocker: 'requires-python >=3.10' }] }, {})
    eq(result.status, 'complete', 'status'); eq(result.environment_blocker, 'requires-python >=3.10', 'caveat')
  })

  await test('Codex-only cited finding blocks when Lawliet approves (truth table)', async () => {
    const codexBad = { codex_ran: true, verdict: 'BLOCKED', raw: 'BLOCKED\nERROR: src/x.ts:9: null deref' }
    const { result } = await run({
      Loid: [LOID_OK, LOID_OK],
      Lawliet: [LAW_OK, LAW_OK],
      Alphonse: [ALPH_OK, ALPH_OK],
      Codex: [codexBad, { codex_ran: true, verdict: 'APPROVED', raw: 'APPROVED' }],
    }, { profile: 'standard', codex: true })
    eq(result.status, 'complete', 'status'); eq(result.rounds, 1, 'rounds')
  })

  await test('Codex uncited verdict is advisory only', async () => {
    const { result } = await run({
      Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK],
      Codex: [{ codex_ran: true, verdict: 'NEEDS_CHANGES', raw: 'NEEDS_CHANGES\nconsider renaming things' }],
    }, { codex: true })
    eq(result.status, 'complete', 'status')
  })

  await test('same Codex-only citation twice while Lawliet approves → divergence', async () => {
    const codexBad = { codex_ran: true, verdict: 'NEEDS_CHANGES', raw: 'NEEDS_CHANGES\nWARNING: src/x.ts:9: style' }
    const { result } = await run({
      Loid: [LOID_OK, LOID_OK, LOID_OK],
      Lawliet: [LAW_OK, LAW_OK, LAW_OK],
      Alphonse: [ALPH_OK, ALPH_OK, ALPH_OK],
      Codex: [codexBad, { ...codexBad }, { ...codexBad }],
    }, { profile: 'thorough', codex: true })
    eq(result.status, 'divergence', 'status')
  })

  await test('NEEDS_CHANGES with no cited finding (intent mismatch) is not silently approved', async () => {
    const { result, calls } = await run({
      Loid: [LOID_OK, LOID_OK],
      Lawliet: [{ verdict: 'NEEDS_CHANGES', findings: [], intent_mismatch: 'does not add the endpoint the Goal asks for', summary: '' }, LAW_OK],
      Alphonse: [ALPH_OK, ALPH_OK],
    }, { profile: 'standard' })
    eq(result.status, 'complete', 'status'); eq(result.rounds, 1, 'a fix round ran')
    if (!calls.filter(c => c.who === 'Loid')[1].prompt.includes('does not add the endpoint')) throw new Error('intent mismatch not passed to Loid')
  })

  await test('divergence is not returned while Alphonse is failing', async () => {
    const codexBad = { codex_ran: true, verdict: 'NEEDS_CHANGES', raw: 'WARNING: src/x.ts:9: style' }
    const failing = { ...ALPH_OK, overall: 'FAILED', failures: ['tests/t.py::test_a'] }
    const { result } = await run({
      Loid: [LOID_OK, LOID_OK, LOID_OK],
      Lawliet: [LAW_OK, LAW_OK, LAW_OK],
      Alphonse: [failing, failing, failing],
      Codex: [codexBad, { ...codexBad }, { ...codexBad }],
    }, { profile: 'standard', codex: true })
    if (result.status === 'divergence') throw new Error('returned divergence with failing tests')
    eq(result.status, 'capped', 'status')
    if (!result.open_findings.some(f => f.source === 'alphonse')) throw new Error('alphonse failure missing from open findings')
  })

  await test('Codex ERROR on the same line as a Lawliet INFO is not deduplicated away', async () => {
    const lawInfo = { verdict: 'APPROVED', findings: [{ severity: 'INFO', file: 'src/x.ts', line: 9, issue: 'nit' }], summary: '' }
    const { result } = await run({
      Loid: [LOID_OK, LOID_OK],
      Lawliet: [lawInfo, LAW_OK], Alphonse: [ALPH_OK, ALPH_OK],
      Codex: [{ codex_ran: true, verdict: 'BLOCKED', raw: 'ERROR: src/x.ts:9: null deref' }, { codex_ran: true, verdict: 'APPROVED', raw: '' }],
    }, { codex: true })
    eq(result.rounds, 1, 'the Codex ERROR triggered a fix round')
  })

  await test('Lawliet APPROVED with a cited WARNING still triggers a fix round', async () => {
    const lawWarn = { verdict: 'APPROVED', findings: [warn('a.ts', 3)], summary: '' }
    const { result, calls } = await run({
      Loid: [LOID_OK, LOID_OK], Lawliet: [lawWarn, LAW_OK], Alphonse: [ALPH_OK, ALPH_OK],
    }, { profile: 'standard' })
    eq(result.status, 'complete', 'status')
    eq(result.rounds, 1, 'rounds')
    const second = calls.filter(c => c.who === 'Loid')[1]
    if (!second || !String(second.prompt).includes('a.ts:3') || !String(second.prompt).includes('[lawliet]')) throw new Error('fix prompt missing the Lawliet WARNING')
  })

  await test('Lawliet APPROVED with its own cited finding is not a Codex divergence', async () => {
    const lawWarn = () => ({ verdict: 'APPROVED', findings: [warn('a.ts', 3)], summary: '' })
    const cx = () => ({ codex_ran: true, verdict: 'NEEDS_CHANGES', raw: 'NEEDS_CHANGES\nWARNING: src/x.ts:9: style' })
    const { result } = await run({
      Loid: [LOID_OK, LOID_OK, LOID_OK], Lawliet: [lawWarn(), lawWarn(), lawWarn()],
      Alphonse: [ALPH_OK, ALPH_OK, ALPH_OK], Codex: [cx(), cx(), cx()],
    }, { profile: 'standard', codex: true })
    eq(result.status, 'capped', 'status')
    if (!result.open_findings.some(f => f.source === 'lawliet' && f.file === 'a.ts' && f.line === 3)) throw new Error('Lawliet finding missing from open findings')
  })

  await test('Codex NEEDS_CHANGES citing only INFO is advisory, not blocking', async () => {
    const { result } = await run({
      Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK],
      Codex: [{ codex_ran: true, verdict: 'NEEDS_CHANGES', raw: 'NEEDS_CHANGES\nINFO: src/x.ts:9: naming' }],
    }, { codex: true })
    eq(result.status, 'complete', 'status')
    eq(result.rounds, 0, 'rounds')
    if (!result.advisory.some(f => f.source === 'codex' && f.line === 9)) throw new Error('Codex INFO missing from advisory')
  })

  await test('relaunch after escalation keeps the used round budget', async () => {
    const bad = { verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 3)], summary: '' }
    const { result, calls } = await run({ Loid: [LOID_OK], Lawliet: [bad], Alphonse: [ALPH_OK] },
      { profile: 'standard', start_round: 2, prior_findings: '- ERROR a.ts:3 bug' })
    eq(result.status, 'capped', 'status (cap 2 already used)')
    const first = calls.find(c => c.who === 'Loid').prompt
    if (!first.includes('Fix these first')) throw new Error('prior findings not passed on relaunch')
  })

  await test('escalation return carries open findings and rounds used', async () => {
    const bad = { verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 3)], summary: '' }
    const { result } = await run({
      Loid: [LOID_OK, { ...LOID_OK, status: 'escalation', escalation: '<escalation/>' }],
      Lawliet: [bad], Alphonse: [ALPH_OK],
    }, { profile: 'standard' })
    eq(result.status, 'escalation', 'status'); eq(result.rounds_used, 1, 'rounds_used')
    eq(result.open_findings.length, 1, 'open findings carried')
  })

  await test('skipped plan items and partial status come back as loid_incomplete', async () => {
    const loid = { ...LOID_OK, status: 'partial', items: [{ item: 'add docs', status: 'skipped', reason: 'out of scope' }, { item: 'fix bug', status: 'done' }] }
    const { result } = await run({ Loid: [loid], Lawliet: [LAW_OK], Alphonse: [ALPH_OK] }, { profile: 'standard' })
    eq(result.status, 'complete', 'status')
    eq(result.loid_incomplete.length, 1, 'one incomplete item')
    eq(result.loid_incomplete[0], 'add docs — out of scope', 'item text')
    const clean = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK] }, { profile: 'standard' })
    eq(clean.result.loid_incomplete.length, 0, 'none when all done')
  })

  await test('an item skipped then finished drops out of loid_incomplete; relaunch keeps prior ones', async () => {
    const r0 = { ...LOID_OK, items: [{ item: 'add docs', status: 'skipped', reason: 'later' }] }
    const r1 = { ...LOID_OK, items: [{ item: 'add docs', status: 'done' }] }
    const { result } = await run({
      Loid: [r0, r1], Lawliet: [{ verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 1)], summary: 'x' }, LAW_OK], Alphonse: [ALPH_OK, ALPH_OK],
    }, { profile: 'standard' })
    eq(result.status, 'complete', 'status'); eq(result.loid_incomplete.length, 0, 'finished item removed')
    const esc = { ...LOID_OK, status: 'escalation', escalation: '<escalation/>' }
    const rel = await run({ Loid: [esc] }, { profile: 'standard', start_round: 1, prior_findings: [], prior_incomplete: ['write migration — blocked on schema'] })
    eq(rel.result.loid_incomplete.length, 1, 'prior incomplete carried through a repeat escalation')
    const partialRelaunch = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK] },
      { profile: 'standard', start_round: 1, prior_findings: [], prior_incomplete: ['Loid reported partial: ran out of time'] })
    eq(partialRelaunch.result.loid_incomplete.length, 0, 'a carried partial note clears once Loid finishes')
    const partialEsc = await run({ Loid: [esc] },
      { profile: 'standard', start_round: 1, prior_findings: [], prior_incomplete: ['Loid reported partial: ran out of time'] })
    eq(partialEsc.result.loid_incomplete[0], 'Loid reported partial: ran out of time', 'carried partial note survives a repeat escalation')
  })

  await test('repeat escalation on a relaunch hands the prior findings back', async () => {
    const prior = [{ ...err('a.ts', 3), source: 'lawliet' }]
    const esc = { ...LOID_OK, status: 'escalation', escalation: '<escalation/>' }
    const { result } = await run({ Loid: [esc] }, { profile: 'standard', start_round: 1, prior_findings: prior })
    eq(result.status, 'escalation', 'status'); eq(result.rounds_used, 1, 'rounds_used')
    eq(Array.isArray(result.open_findings) && result.open_findings.length, 1, 'open_findings kept')
    eq(result.open_findings[0].file, 'a.ts', 'finding file')
    const text = await run({ Loid: [esc] }, { profile: 'standard', start_round: 1, prior_findings: '- ERROR a.ts:3 bug' })
    eq(text.result.open_findings, '- ERROR a.ts:3 bug', 'text prior_findings returned as-is')
  })

  await test('prior_findings passed as the open_findings array is formatted, not [object Object]', async () => {
    const { calls } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK] },
      { profile: 'standard', start_round: 1, prior_findings: [{ ...err('a.ts', 3), source: 'lawliet' }] })
    const first = calls.find(c => c.who === 'Loid').prompt
    if (first.includes('[object Object]')) throw new Error('array findings stringified as [object Object]')
    if (!first.includes('ERROR a.ts:3 [lawliet] bug at a.ts')) throw new Error('formatted finding missing from Loid prompt')
  })

  await test('Codex APPROVED with a cited WARNING still blocks (severity wins)', async () => {
    const { result, calls } = await run({
      Loid: [LOID_OK, LOID_OK], Lawliet: [LAW_OK, LAW_OK], Alphonse: [ALPH_OK, ALPH_OK],
      Codex: [{ codex_ran: true, verdict: 'APPROVED', raw: 'APPROVED\nWARNING: src/x.ts:9: race' }, { codex_ran: true, verdict: 'APPROVED', raw: 'APPROVED' }],
    }, { profile: 'standard', codex: true })
    eq(result.status, 'complete', 'status'); eq(result.rounds, 1, 'the Codex WARNING triggered a fix round')
    if (!calls.filter(c => c.who === 'Loid')[1].prompt.includes('src/x.ts:9 [codex]')) throw new Error('Codex WARNING not sent to Loid')
  })

  await test('unparseable Codex verdict keeps its cited findings as advisory', async () => {
    const { result } = await run({
      Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK],
      Codex: [{ codex_ran: true, verdict: 'MAYBE', raw: 'MAYBE\nERROR: src/x.ts:9: bug' }],
    }, { codex: true })
    eq(result.status, 'complete', 'status'); eq(result.rounds, 0, 'rounds')
    if (!result.advisory.some(f => f.source === 'codex' && f.line === 9)) throw new Error('unparseable Codex finding missing from advisory')
  })

  await test('divergence carries open_findings and rounds_used; Accept-Codex relaunch keeps the cap', async () => {
    const cx = () => ({ codex_ran: true, verdict: 'NEEDS_CHANGES', raw: 'NEEDS_CHANGES\nWARNING: src/x.ts:9: style' })
    const { result } = await run({
      Loid: [LOID_OK, LOID_OK], Lawliet: [LAW_OK, LAW_OK], Alphonse: [ALPH_OK, ALPH_OK], Codex: [cx(), cx()],
    }, { profile: 'standard', codex: true })
    eq(result.status, 'divergence', 'status'); eq(result.rounds_used, 2, 'rounds_used is the next fix round')
    eq(result.open_findings.length, 1, 'open findings carried')
    // Relaunch as the orchestrator would on Accept Codex: Codex still disagrees → capped, no fresh rounds.
    const re = await run({
      Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK], Codex: [cx()],
    }, { profile: 'standard', codex: true, start_round: result.rounds_used, prior_findings: result.open_findings })
    eq(re.result.status, 'capped', 'relaunch at the cap stops instead of starting over')
    eq(re.calls.filter(c => c.who === 'Loid').length, 1, 'exactly one Loid dispatch on the relaunch')
    if (!re.calls.find(c => c.who === 'Loid').prompt.includes('src/x.ts:9 [codex]')) throw new Error('Codex finding not passed to Loid on relaunch')
  })

  await test('divergence at the round cap falls through to capped (A,B,B under standard)', async () => {
    const cx = f => ({ codex_ran: true, verdict: 'NEEDS_CHANGES', raw: `NEEDS_CHANGES\nWARNING: src/${f}.ts:9: style` })
    const { result, calls } = await run({
      Loid: [LOID_OK, LOID_OK, LOID_OK], Lawliet: [LAW_OK, LAW_OK, LAW_OK], Alphonse: [ALPH_OK, ALPH_OK, ALPH_OK],
      Codex: [cx('a'), cx('b'), cx('b')],
    }, { profile: 'standard', codex: true })
    eq(result.status, 'capped', 'status')
    eq(result.open_findings.length, 1, 'open findings carried')
    eq(calls.filter(c => c.who === 'Loid').length, 3, 'initial pass + 2 fix rounds, no 3rd fix')
  })

  await test('prior_findings null or blank is not a relaunch (no --keep-only)', async () => {
    for (const pf of [null, '', '  ']) {
      const { calls } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK], Codex: [{ codex_ran: true, verdict: 'APPROVED', raw: '' }] },
        { profile: 'standard', codex: true, prior_findings: pf })
      if (calls[0].prompt.includes('--keep-only')) throw new Error(`prior_findings=${JSON.stringify(pf)} treated as relaunch`)
    }
  })

  await test('bare launch without intent is refused before any agent runs', async () => {
    const { result, calls } = await run({}, null)
    eq(result.status, 'blocked', 'status'); eq(calls.length, 0, 'no agents spawned')
    const blank = await run({}, { intent: '   ' })
    eq(blank.result.status, 'blocked', 'blank intent')
  })

  await test('Loid escalation returns immediately without review', async () => {
    const { result, calls } = await run({ Loid: [{ ...LOID_OK, status: 'escalation', escalation: '<escalation/>' }] }, {})
    eq(result.status, 'escalation', 'status'); eq(calls.length, 1, 'only Loid ran')
  })

  await test('Codex re-review in round 2 passes --diff-base', async () => {
    const codexBad = { codex_ran: true, verdict: 'BLOCKED', raw: 'ERROR: src/x.ts:9: bug' }
    const { calls } = await run({
      Loid: [LOID_OK, { ...LOID_OK, review_base: 'r1base' }],
      Lawliet: [LAW_OK, LAW_OK], Alphonse: [ALPH_OK, ALPH_OK],
      Codex: [codexBad, { codex_ran: true, verdict: 'APPROVED', raw: '' }],
    }, { codex: true })
    const second = calls.filter(c => c.who === 'Codex')[1].prompt
    if (!second.includes('--diff-base r1base')) throw new Error('missing --diff-base on re-review')
    if (!second.includes('AGENT_FLOW_CODEX_TIMEOUT')) throw new Error('codex prompt missing timeout guidance')
    if (!second.includes('BASH_MAX_TIMEOUT_MS')) throw new Error('codex prompt missing the Bash timeout cap')
    // The override must sit directly before `bash`, not before `mkdir` (which would not reach the helper).
    if (!second.includes('&& AGENT_FLOW_CODEX_TIMEOUT=<n> bash')) throw new Error('timeout override not placed immediately before bash')
    if (/AGENT_FLOW_CODEX_TIMEOUT=<[^>]*>\s+mkdir/.test(second)) throw new Error('timeout override prefixes mkdir only')
  })

  console.log(failed ? `✗ ${failed} test(s) failed` : '✓ All tests passed')
  process.exit(failed ? 1 : 0)
})()
