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
  // script: { Loid: [...], Lawliet: [...], Alphonse: [...], Codex: [...] } consumed in order
  const calls = []
  const next = who => {
    const q = script[who] || []
    if (!q.length) throw new Error(`no scripted response left for ${who}`)
    return q.shift()
  }
  const agent = async (prompt, opts = {}) => {
    const who = opts.agentType ? opts.agentType.split(':')[1] : 'Codex'
    calls.push({ who, prompt })
    return next(who)
  }
  const parallel = async thunks => Promise.all(thunks.map(t => t().catch(() => null)))
  const fn = new AsyncFunction('agent', 'parallel', 'phase', 'log', 'args', SRC)
  const result = await fn(agent, parallel, () => {}, () => {}, args)
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

  console.log(failed ? `✗ ${failed} test(s) failed` : '✓ All tests passed')
  process.exit(failed ? 1 : 0)
})()
