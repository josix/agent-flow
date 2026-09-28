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

async function run(script, args) {
  // script: { Loid: [...], Lawliet: [...], Alphonse: [...], Codex: [...], Jev: [...] } consumed in order
  const calls = []
  const next = who => {
    const q = script[who] || []
    if (!q.length) throw new Error(`no scripted response left for ${who}`)
    return q.shift()
  }
  const agent = async (prompt, opts = {}) => {
    const who = opts.agentType ? opts.agentType.split(':')[1] : (opts.label && opts.label.startsWith('Jev') ? 'Jev' : 'Codex')
    calls.push({ who, prompt })
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
  })

  const JEV_HI = { jev_ran: true, model: 'jev-1.13.0', threshold: 0.8, truncated: false, scores: { addresses_task: 0.9, unrelated_changes: 0.95, needs_clarification: 0.9, security_surface: 0.1 }, over_threshold: ['unrelated_changes', 'needs_clarification'], surfaced: ['unrelated_changes'] }

  await test('J1: jev falsy → 0 Jev calls, result.jev is null', async () => {
    const { result, calls } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK] }, { profile: 'standard' })
    eq(calls.filter(c => c.who === 'Jev').length, 0, 'jev calls')
    if (result.jev !== null) throw new Error('result.jev should be null when jev is falsy')
  })

  await test('J2: jev on, shadow, JEV_HI → complete, one INFO advisory (unrelated_changes only)', async () => {
    const { result } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK], Jev: [JEV_HI] }, { profile: 'standard', jev: true })
    eq(result.status, 'complete', 'status'); eq(result.rounds, 0, 'rounds')
    const jevAdv = result.advisory.filter(a => a.source === 'jev')
    eq(jevAdv.length, 1, 'jev advisory count')
    if (!jevAdv[0].issue.includes('unrelated_changes')) throw new Error('advisory should cite unrelated_changes')
    if (result.advisory.some(a => a.source === 'jev' && a.issue.includes('needs_clarification'))) throw new Error('needs_clarification is record-only and must not surface')
    eq(result.open_findings, undefined, 'jev must never reach open findings')
  })

  await test('J3: Jev dispatch fails (parallel catches null) → complete, history shows dispatch_failed', async () => {
    const { result } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK], Jev: [] }, { profile: 'standard', jev: true })
    eq(result.status, 'complete', 'status')
    eq(result.history[0].jev, 'skipped:dispatch_failed', 'history jev field')
  })

  await test('J4: codex false, jev true — name-keyed results regression check', async () => {
    const bad = { verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 3), { severity: 'WARNING', file: 'tests/', line: 1, issue: 'add tests' }], summary: '' }
    const { result, calls } = await run({
      Loid: [LOID_OK, LOID_OK],
      Lawliet: [bad, LAW_OK],
      Alphonse: [{ ...ALPH_OK, overall: 'FAILED', failures: ['t'] }, ALPH_OK],
      Jev: [JEV_HI, JEV_HI],
    }, { profile: 'standard', codex: false, jev: true })
    eq(result.status, 'complete', 'status'); eq(result.rounds, 1, 'rounds')
    const fix = calls.filter(c => c.who === 'Loid')[1].prompt
    if (!fix.includes('a.ts:3') || !fix.includes('tests/')) throw new Error('fix prompt missing findings — name-keyed result mapping regressed')
  })

  await test('J5: jev_ran false with skip_reason timeout → history shows the skip', async () => {
    const { result } = await run({ Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK], Jev: [{ jev_ran: false, skip_reason: 'timeout' }] }, { profile: 'standard', jev: true })
    eq(result.history[0].jev, 'skipped:timeout', 'history jev field')
  })

  await test('J6: codex true, jev true — truth table and divergence cap unchanged', async () => {
    const codexBad = { codex_ran: true, verdict: 'NEEDS_CHANGES', raw: 'NEEDS_CHANGES\nWARNING: src/x.ts:9: style' }
    const { result: divResult } = await run({
      Loid: [LOID_OK, LOID_OK, LOID_OK],
      Lawliet: [LAW_OK, LAW_OK, LAW_OK],
      Alphonse: [ALPH_OK, ALPH_OK, ALPH_OK],
      Codex: [codexBad, { ...codexBad }, { ...codexBad }],
      Jev: [JEV_HI, JEV_HI, JEV_HI],
    }, { profile: 'thorough', codex: true, jev: true })
    eq(divResult.status, 'divergence', 'status with jev on')

    const codexOnlyBlocked = { codex_ran: true, verdict: 'BLOCKED', raw: 'BLOCKED\nERROR: src/x.ts:9: null deref' }
    const { result: citedResult } = await run({
      Loid: [LOID_OK, LOID_OK],
      Lawliet: [LAW_OK, LAW_OK],
      Alphonse: [ALPH_OK, ALPH_OK],
      Codex: [codexOnlyBlocked, { codex_ran: true, verdict: 'APPROVED', raw: 'APPROVED' }],
      Jev: [JEV_HI, JEV_HI],
    }, { profile: 'standard', codex: true, jev: true })
    eq(citedResult.status, 'complete', 'status'); eq(citedResult.rounds, 1, 'rounds')
  })

  await test('J7: surfaced ids outside the code-side allowlist never become an advisory', async () => {
    const { result } = await run({
      Loid: [LOID_OK], Lawliet: [LAW_OK], Alphonse: [ALPH_OK],
      Jev: [{ ...JEV_HI, surfaced: ['security_surface'] }],
    }, { profile: 'standard', jev: true })
    eq(result.advisory.filter(a => a.source === 'jev').length, 0, 'jev advisory count')
  })

  await test('J8: JEV never reaches the Loid fix prompt or Lawliet prompt', async () => {
    const bad = { verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 3)], summary: '' }
    const { calls } = await run({
      Loid: [LOID_OK, LOID_OK], Lawliet: [bad, LAW_OK], Alphonse: [ALPH_OK, ALPH_OK], Jev: [JEV_HI, JEV_HI],
    }, { profile: 'standard', jev: true })
    const loidFix = calls.filter(c => c.who === 'Loid')[1].prompt
    const lawRereview = calls.filter(c => c.who === 'Lawliet')[1].prompt
    if (loidFix.includes('JEV') || lawRereview.includes('JEV')) throw new Error('JEV leaked into a Loid or Lawliet prompt')
  })

  await test('J9: lawliet.intent_mismatch is recorded in history', async () => {
    const { result } = await run({
      Loid: [LOID_OK, LOID_OK],
      Lawliet: [{ verdict: 'NEEDS_CHANGES', findings: [], intent_mismatch: 'wrong endpoint', summary: '' }, LAW_OK],
      Alphonse: [ALPH_OK, ALPH_OK],
    }, { profile: 'standard' })
    eq(result.history[0].intent_mismatch, true, 'intent_mismatch recorded')
  })

  await test('J10: round-1 Jev prompt uses --round 1 and never --diff-base', async () => {
    const bad = { verdict: 'NEEDS_CHANGES', findings: [err('a.ts', 3)], summary: '' }
    const { calls } = await run({
      Loid: [LOID_OK, { ...LOID_OK, review_base: 'r1base' }],
      Lawliet: [bad, LAW_OK], Alphonse: [ALPH_OK, ALPH_OK],
      Jev: [JEV_HI, JEV_HI],
    }, { profile: 'standard', jev: true })
    const jevCalls = calls.filter(c => c.who === 'Jev')
    eq(jevCalls.length, 2, 'jev calls across both rounds')
    if (!jevCalls[1].prompt.includes('--round 1')) throw new Error('missing --round 1')
    if (jevCalls[1].prompt.includes('--diff-base')) throw new Error('Jev prompt must never use --diff-base')
  })

  console.log(failed ? `✗ ${failed} test(s) failed` : '✓ All tests passed')
  process.exit(failed ? 1 : 0)
})()
