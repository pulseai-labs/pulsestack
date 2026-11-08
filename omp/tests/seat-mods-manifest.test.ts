import { afterEach, describe, expect, test } from 'bun:test'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { killRule } from '../../seat-mods/hooks/rules'

// The ambient OMP entry of seat-mods (#1102). CI has no omp, so this is the contract of the manifest omp reads:
// seat-mods/package.json names the entry, the entry exists, and what it exports registers the kill rail and nothing else.
// CI has no omp, so "omp loads it once" is shown by a live load probe on omp 18.16.0, recorded in PR #1119's Evidence. Every check runs on the shipped tree and on a
// fixture with one planted defect; a check whose control stays green is broken.
const SHIPPED = resolve(import.meta.dir, '../../seat-mods')
const INCIDENT = 'kill $(ps -eo pid,args 2>/dev/null) 2>/dev/null; true'

// Closed input: our own manifest. Returns the findings, empty when the manifest is right.
function manifestFindings(root: string): string[] {
  const file = join(root, 'package.json')
  if (!existsSync(file)) return ['package.json is missing']
  let pkg: any
  try { pkg = JSON.parse(readFileSync(file, 'utf8')) } catch { return ['package.json is not JSON'] }
  const out: string[] = []
  if (pkg.name !== 'seat-mods') out.push('name must be seat-mods: it sets the runtime link name')
  if ('version' in pkg) out.push('no version field: plugin.json owns the version')
  // omp reads pkg.omp (or pkg.pi) and also loads the extensions of a default feature, and takes tools, hooks and commands:
  // any key beside `extensions` is a second way to load code in every plain session.
  if (pkg.omp === null || typeof pkg.omp !== 'object' || JSON.stringify(Object.keys(pkg.omp)) !== '["extensions"]') out.push('omp must hold exactly the extensions key')
  if ('pi' in pkg) out.push('no pi key: it is a second manifest')
  const entries = pkg.omp?.extensions
  if (!Array.isArray(entries) || entries.length !== 1) return [...out, 'omp.extensions must list exactly one entry']
  const entry = String(entries[0])
  if (resolve(root, entry) === resolve(root, 'omp/extension.ts')) out.push('the entry must not be the full guard: it loads only through omp-seat')
  if (resolve(root, entry) !== resolve(root, 'omp/kill-rail.ts')) out.push(`the entry must be omp/kill-rail.ts, not ${entry}`)
  if (!existsSync(resolve(root, entry))) out.push(`the entry ${entry} does not exist`)
  return out
}

// What omp does with the entry: import it, call its default export with the extension API. A fake pi records the handlers.
async function railFindings(entryPath: string): Promise<string[]> {
  const out: string[] = []
  const handlers: Array<[string, (e: any, c: any) => any]> = []
  const envOf = () => JSON.stringify(Object.entries(process.env).sort())
  const envBefore = envOf() // a plain session's entry writes no env, at import or in a call
  const ui: string[] = []
  const mod = await import(entryPath)
  if (typeof mod.default !== 'function') return ['the entry has no default export function']
  mod.default({ on: (name: string, fn: (e: any, c: any) => any) => { handlers.push([name, fn]) } })
  if (handlers.map(h => h[0]).join() !== 'tool_call') return [`must register exactly one tool_call handler, got ${handlers.map(h => h[0]).join() || 'none'}`]
  const call = handlers[0]![1]
  const saved = process.env.SEAT_MODS_ROLE
  try {
    for (const role of [undefined, '', 'coordinator', 'orchestrator', 'implementer', 'bogus']) {
      if (role === undefined) delete process.env.SEAT_MODS_ROLE; else process.env.SEAT_MODS_ROLE = role
      for (const agent of [{ kind: 'main' }, { kind: 'sub', name: 'implementer' }]) {
        const ctx = { cwd: '/repo/wt', agent, ui: { setStatus: (key: string) => { ui.push(key) } } }
        const tag = `role ${JSON.stringify(role)} ${agent.kind}`
        const blocked = await call({ toolName: 'bash', input: { command: INCIDENT } }, ctx)
        if (blocked?.block !== true || blocked.reason !== killRule(INCIDENT)) out.push(`${tag}: the incident string is not refused with the rail's own reason`)
        // Nothing but the rail: a literal-PID kill, a merge, a branch delete and a write outside all pass.
        for (const command of ['kill 12345', 'gh pr merge 1 --squash', 'git branch -D topic', 'git commit --no-verify -m x'])
          if (await call({ toolName: 'bash', input: { command } }, ctx) !== undefined) out.push(`${tag}: ${command} must pass`)
        if (await call({ toolName: 'write', input: { path: '/etc/x', content: INCIDENT } }, ctx) !== undefined) out.push(`${tag}: a non-shell tool must pass`)
        if (await call({ toolName: 'task', input: {} }, ctx) !== undefined) out.push(`${tag}: task must pass`)
        // eval: double- and single-quoted literals and an argv list are read; a harmless eval passes.
        for (const code of ['import os; os.system("kill -1")', 'x = "$(5"; import os; os.system("kill -1")', 'import os; os.system("kill $(pgrep x)")', "import os; os.system('kill -1')", "subprocess.run(['kill', '-1'])", `subprocess.run("sh -c-o '$(x' 'kill -1'", shell=True)`, `subprocess.run("ksh -c '$(x'; kill -1", shell=True)`, `subprocess.run("busybox sh -c '$(x'; kill -1", shell=True)`, `subprocess.run("mksh -c '$(x' && kill -1", shell=True)`, 'import os; os.system("time ! kill -1")'])
          if ((await call({ toolName: 'eval', input: { language: 'py', code } }, ctx))?.block !== true) out.push(`${tag}: eval ${code} is not refused`)
        for (const code of ['print("hello")', 'print(1 + 1)', 'print("cost: $(5")', 'x = "$("', 'console.log("a $(b")', "os.system('kill 12345')", 'import os; os.system("time ! kill 123")'])
          if (await call({ toolName: 'eval', input: { language: 'py', code } }, ctx) !== undefined) out.push(`${tag}: eval ${code} must pass`)
        const unread = await call({ toolName: 'bash', input: { command: 'echo "\u00000\u0000"' } }, ctx)
        if (unread?.block !== true || !String(unread.reason).includes('could not be read safely')) out.push(`${tag}: an unreadable text is not refused`)
      }
    }
  } finally {
    if (saved === undefined) delete process.env.SEAT_MODS_ROLE; else process.env.SEAT_MODS_ROLE = saved
  }
  if (ui.length > 0) out.push(`no status line: setStatus was called with ${ui.join()}`)
  if (envOf() !== envBefore) out.push('the entry changed process.env')
  return out
}

describe('seat-mods package.json manifest (#1102)', () => {
  const dirs: string[] = []
  afterEach(() => { for (const d of dirs.splice(0)) rmSync(d, { recursive: true, force: true }) })
  function fixture(pkg: unknown, files: Record<string, string> = {}): string {
    const root = mkdtempSync(join(tmpdir(), 'seat-mods-manifest-'))
    dirs.push(root)
    mkdirSync(join(root, 'omp'), { recursive: true })
    if (pkg !== undefined) writeFileSync(join(root, 'package.json'), typeof pkg === 'string' ? pkg : JSON.stringify(pkg))
    for (const [name, text] of Object.entries(files)) writeFileSync(join(root, name), text)
    return root
  }
  const good = { name: 'seat-mods', private: true, omp: { extensions: ['omp/kill-rail.ts'] } }

  test('the shipped manifest names the kill rail entry, and the entry exists', () => {
    expect(manifestFindings(SHIPPED)).toEqual([])
    expect(existsSync(join(SHIPPED, 'omp/kill-rail.ts'))).toBe(true)
  })
  test('control: a manifest-shaped fixture with the right entry is clean', () => {
    expect(manifestFindings(fixture(good, { 'omp/kill-rail.ts': '' }))).toEqual([])
  })
  test('control: a missing manifest is found', () => {
    expect(manifestFindings(fixture(undefined))).toEqual(['package.json is missing'])
  })
  test('control: a wrong entry path is found, and so is an entry that is not there', () => {
    const wrong = { ...good, omp: { extensions: ['omp/kill-rails.ts'] } }
    const found = manifestFindings(fixture(wrong, { 'omp/kill-rail.ts': '' }))
    expect(found.join('\n')).toContain('must be omp/kill-rail.ts')
    expect(found.join('\n')).toContain('does not exist')
    expect(manifestFindings(fixture(good)).join('\n')).toContain('does not exist')
  })
  test('control: the full guard as the entry is found', () => {
    const found = manifestFindings(fixture({ ...good, omp: { extensions: ['omp/extension.ts'] } }, { 'omp/extension.ts': '' }))
    expect(found.join('\n')).toContain('must not be the full guard')
  })
  test('control: any other omp key or a pi key is found: a features guard entry, hooks, a pi manifest (R1)', () => {
    const files = { 'omp/kill-rail.ts': '' }
    const feature = { ...good, omp: { ...good.omp, features: { guard: { default: true, extensions: ['omp/extension.ts'] } } } }
    expect(manifestFindings(fixture(feature, files)).join('\n')).toContain('exactly the extensions key')
    expect(manifestFindings(fixture({ ...good, omp: { ...good.omp, hooks: 'omp/extension.ts' } }, files)).join('\n')).toContain('exactly the extensions key')
    expect(manifestFindings(fixture({ ...good, pi: { extensions: ['omp/extension.ts'] } }, files)).join('\n')).toContain('no pi key')
  })
  test('control: a second entry, a wrong name and a version are each found', () => {
    expect(manifestFindings(fixture({ ...good, omp: { extensions: ['omp/kill-rail.ts', 'omp/extension.ts'] } })).join('\n')).toContain('exactly one entry')
    expect(manifestFindings(fixture({ ...good, name: 'other' }, { 'omp/kill-rail.ts': '' })).join('\n')).toContain('name must be seat-mods')
    expect(manifestFindings(fixture({ ...good, version: '0.15.0' }, { 'omp/kill-rail.ts': '' })).join('\n')).toContain('no version field')
  })

  test('the shipped entry registers one tool_call handler that is the kill rail and nothing else', async () => {
    expect(await railFindings(join(SHIPPED, 'omp/kill-rail.ts'))).toEqual([])
  })
  test('control: an entry that loads the full guard is found', async () => {
    const root = fixture(good, { 'omp/kill-rail.ts': `export { default } from ${JSON.stringify(join(SHIPPED, 'omp/extension.ts'))}\n` })
    const found = await railFindings(join(root, 'omp/kill-rail.ts'))
    expect(found.length).toBeGreaterThan(0)
    expect(found.join('\n')).toContain('exactly one tool_call handler')
  })
  test('control: an entry whose handler is removed is found', async () => {
    const root = fixture(good, { 'omp/kill-rail.ts': 'export default function (_pi: any) {}\n' })
    expect((await railFindings(join(root, 'omp/kill-rail.ts'))).join('\n')).toContain('none')
  })
  test('control: a rail that approves-by-omission for an unreadable text is found', async () => {
    const real = readFileSync(join(SHIPPED, 'omp/kill-rail.ts'), 'utf8').replace("'../hooks/rules'", JSON.stringify(join(SHIPPED, 'hooks/rules'))).replace("'./extension'", JSON.stringify(join(SHIPPED, 'omp/extension')))
    expect(real).toContain(": check.unread && e?.toolName === 'bash' ? { block: true, reason: KILL_UNCHECKED } : undefined")
    const root = fixture(good, { 'omp/kill-rail.ts': real.replace(": check.unread && e?.toolName === 'bash' ? { block: true, reason: KILL_UNCHECKED } : undefined", ': undefined') })
    expect((await railFindings(join(root, 'omp/kill-rail.ts'))).join('\n')).toContain('unreadable text is not refused')
  })
  test('control: an entry that sets an env var at import, sets a status, reads one literal style, or blocks every eval is found (R4)', async () => {
    let real = readFileSync(join(SHIPPED, 'omp/kill-rail.ts'), 'utf8').replace("'../hooks/rules'", JSON.stringify(join(SHIPPED, 'hooks/rules'))).replace("'./extension'", JSON.stringify(join(SHIPPED, 'omp/extension')))
    const handler = 'pi.on(\'tool_call\', (e: any, ctx: any) => {'
    real = real.replace("pi.on('tool_call', (e: any) => {", handler)
    expect(real).toContain(handler)
    const entry = (text: string) => join(fixture(good, { 'omp/kill-rail.ts': text }), 'omp/kill-rail.ts')
    expect((await railFindings(entry(`process.env.SEAT_MODS_FIXTURE_M3 = 'x'\n` + real))).join('\n')).toContain('changed process.env')
    delete process.env.SEAT_MODS_FIXTURE_M3
    expect((await railFindings(entry(real.replace(handler, handler + " ctx?.ui?.setStatus?.('seat-mods-kill', 'kill rail');")))).join('\n')).toContain('no status line')
    expect((await railFindings(entry(real.replace('return check.deny !== undefined ? { block: true, reason: check.deny }', "return check.deny !== undefined ? { block: true, reason: KILL_UNCHECKED }")))).join('\n')).toContain("rail's own reason")
    expect((await railFindings(entry(real.replace("String(e?.toolName)", "(e?.toolName === 'eval' ? 'bash' : String(e?.toolName))")))).join('\n')).toContain('is not refused')
    expect((await railFindings(entry(real.replace('const check = killCheck(', "if (e?.toolName === 'eval') return { block: true, reason: 'x' }\n    const check = killCheck(")))).join('\n')).toContain('must pass')
  })
  test('control: an entry that refuses an eval literal it cannot read is found (C1)', async () => {
    const real = readFileSync(join(SHIPPED, 'omp/kill-rail.ts'), 'utf8').replace("'../hooks/rules'", JSON.stringify(join(SHIPPED, 'hooks/rules'))).replace("'./extension'", JSON.stringify(join(SHIPPED, 'omp/extension')))
    expect(real).toContain("check.unread && e?.toolName === 'bash'")
    const root = fixture(good, { 'omp/kill-rail.ts': real.replace("check.unread && e?.toolName === 'bash'", 'check.unread') })
    expect((await railFindings(join(root, 'omp/kill-rail.ts'))).join('\n')).toContain('must pass')
  })
  test('control: a rail that ignores free roles is found', async () => {
    const root = fixture(good, { 'omp/kill-rail.ts': `import { default as g } from ${JSON.stringify(join(SHIPPED, 'omp/kill-rail.ts'))}\nexport default function (pi: any) { g({ on: (n: string, f: any) => pi.on(n, (e: any, c: any) => (process.env.SEAT_MODS_ROLE === 'coordinator' ? undefined : f(e, c))) }) }\n` })
    expect((await railFindings(join(root, 'omp/kill-rail.ts'))).join('\n')).toContain('the incident string is not refused')
  })
})
