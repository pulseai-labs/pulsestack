import { beforeEach, describe, expect, test } from 'bun:test'
import { spawnSync } from 'node:child_process'
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { MARKETPLACE } from '../../omp-roles/omp/bin-path'
import { checkExtensions, expandRole, pinWarning, planLaunch, versionWarning } from '../../omp-roles/omp/seat'

let root: string, ompRecord: string, claudeRecord: string

function install(name: string, withExt = true, version = ({ 'seat-mods': '0.14.0', molt: '0.3.0' } as Record<string, string>)[name] ?? '0.2.0'): string {
  const p = join(root, 'cache', name)
  mkdirSync(join(p, 'omp'), { recursive: true })
  mkdirSync(join(p, '.claude-plugin'), { recursive: true })
  writeFileSync(join(p, '.claude-plugin', 'plugin.json'), JSON.stringify({ name, version }))
  if (withExt) writeFileSync(join(p, 'omp', 'extension.ts'), 'export default function () {}')
  return p
}
// seat-mods' second OMP entry, which the orchestrator loads last (0.8.0).
function statusEntry(p: string): string {
  writeFileSync(join(p, 'omp', 'status-extension.ts'), 'export default function () {}')
  return p
}
function record(path: string, paths: Record<string, string>) {
  mkdirSync(join(path, '..'), { recursive: true })
  const plugins: Record<string, unknown[]> = {}
  for (const [n, p] of Object.entries(paths)) plugins[`${n}@${MARKETPLACE}`] = [{ scope: 'user', installPath: p }]
  writeFileSync(path, JSON.stringify({ version: 2, plugins }))
}
const launch = (role = 'worker', args: string[] = ['--x']) =>
  planLaunch({ role, via: 'omp-glm', args, ompRecord, claudeRecord })

beforeEach(() => {
  root = mkdtempSync(join(tmpdir(), 'seat-'))
  ompRecord = join(root, 'omp', 'plugins', 'installed_plugins.json')
  claudeRecord = join(root, 'claude', 'plugins', 'installed_plugins.json')
})

describe('planLaunch', () => {
  test('worker pins the two extensions in order, then the caller args, with no system prompt', () => {
    const [s, m] = ['seat-mods', 'molt'].map((n) => install(n))
    record(ompRecord, { 'seat-mods': s, molt: m, 'omp-roles': install('omp-roles', false) })
    expect(launch()).toMatchObject({
      argv: ['omp-glm', '-e', join(s, 'omp/extension.ts'), '-e', join(m, 'omp/extension.ts'), '--x'],
      warnings: [],
    })
  })
  // Only user-scope entries count (omp-roles README): a mod installed only at another scope, for this or another
  // project, is not installed, so an unguarded seat never launches on it.
  for (const scope of ['project', 'local', 'managed']) {
    test(`seat-mods and molt recorded only at Claude ${scope} scope count as not installed`, () => {
      const plugins: Record<string, unknown[]> = {}
      for (const n of ['seat-mods', 'molt'])
        plugins[`${n}@${MARKETPLACE}`] = [{ scope, installPath: install(n), ...(scope === 'managed' ? {} : { projectPath: '/some/other/project' }) }]
      mkdirSync(join(claudeRecord, '..'), { recursive: true })
      writeFileSync(claudeRecord, JSON.stringify({ version: 2, plugins }))
      expect(launch()).toEqual({ error: `omp-seat: seat-mods is not installed (looked in ${ompRecord} and ${claudeRecord})` })
    })
  }
  test('a worker launches with seat-mods and molt only', () => {
    const [s, m] = [install('seat-mods'), install('molt')]
    record(ompRecord, { 'seat-mods': s, molt: m })
    const r = launch() as { argv: string[]; extensions: string[] }
    expect(r.argv).toEqual(['omp-glm', '-e', join(s, 'omp/extension.ts'), '-e', join(m, 'omp/extension.ts'), '--x'])
    expect(r.argv.filter(a => a === '-e')).toHaveLength(2)
    expect(r.extensions).toHaveLength(2)
  })
  test('the orchestrator launches with seat-mods, molt and crew only; the status entry is the last -e', () => {
    const [s, m] = [statusEntry(install('seat-mods', true, '0.14.0')), install('molt')]
    record(ompRecord, { 'seat-mods': s, molt: m, crew: install('crew', false, '0.3.0') })
    const rolesDir = join(import.meta.dir, '../../omp-roles/roles')
    const r = planLaunch({ role: 'orchestrator', via: 'omp-glm', args: [], ompRecord, claudeRecord, roleEnv: 'orchestrator', rolesDir }) as { argv: string[] }
    expect(r).not.toHaveProperty('error')
    expect(r.argv.filter(a => a === '-e')).toHaveLength(3)
    expect(r.argv[r.argv.lastIndexOf('-e') + 1]).toBe(join(s, 'omp/status-extension.ts'))
  })
  test('leftover authority variables are ignored: no preflight export, and bin/omp-seat names none', async () => {
    const seatModule = await import('../../omp-roles/omp/seat')
    expect('authorityPreflight' in seatModule).toBe(false)
    const bin = readFileSync(join(import.meta.dir, '..', '..', 'omp-roles', 'bin', 'omp-seat'), 'utf8')
    expect(bin).not.toContain('AUTO' + 'NOMIC_')
  })
  test('a name from the prototype chain is not a role', () => {
    expect(launch('toString')).toEqual({ error: expect.stringContaining('unknown role "toString"') })
    expect(launch('__proto__')).toHaveProperty('error')
  })
  test('an unknown role is an error', () => {
    expect(launch('x')).toEqual({ error: 'omp-seat: unknown role "x" (known: worker, spine-driver, close, work-pr, orchestrator, crew-spine, crew-work-pr)' })
  })
  test("orchestrator appends its role file and loads seat-mods' status entry last (seat-mods 0.8.0, crew 0.3.0)", () => {
    const [s, m] = [statusEntry(install('seat-mods', true, '0.14.0')), install('molt')]
    record(ompRecord, { 'seat-mods': s, molt: m, 'crew': install('crew', false, '0.3.0') })
    const rolesDir = join(import.meta.dir, '../../omp-roles/roles')
    expect(planLaunch({ role: 'orchestrator', via: 'omp-glm', args: [], ompRecord, claudeRecord, roleEnv: 'orchestrator', rolesDir })).toMatchObject({
      argv: ['omp-glm', '-e', join(s, 'omp/extension.ts'), '-e', join(m, 'omp/extension.ts'),
        '-e', join(s, 'omp/status-extension.ts'), '--append-system-prompt', join(rolesDir, 'orchestrator.md')],
    })
  })
  test('orchestrator refuses seat-mods 0.7.0 (no status check, no kill rail), naming the 0.14.0 floor', () => {
    record(ompRecord, { 'seat-mods': statusEntry(install('seat-mods', true, '0.7.0')), molt: install('molt'), 'crew': install('crew', false, '0.3.0') })
    const r = planLaunch({ role: 'orchestrator', via: 'omp-glm', args: [], ompRecord, claudeRecord, roleEnv: 'orchestrator', rolesDir: join(import.meta.dir, '../../omp-roles/roles') })
    expect(r).toEqual({ error: expect.stringContaining('seat-mods 0.7.0') })
    expect((r as { error: string }).error).toContain('0.14.0')
  })
  test('the orchestrator is held to the kill rail floor too: seat-mods 0.13.0 has the status entry and no rail, so it is refused (#1099)', () => {
    record(ompRecord, { 'seat-mods': statusEntry(install('seat-mods', true, '0.13.0')), molt: install('molt'), 'crew': install('crew', false, '0.3.0') })
    const r = planLaunch({ role: 'orchestrator', via: 'omp-glm', args: [], ompRecord, claudeRecord, roleEnv: 'orchestrator', rolesDir: join(import.meta.dir, '../../omp-roles/roles') })
    expect(r).toEqual({ error: expect.stringContaining('seat-mods 0.13.0') })
    expect((r as { error: string }).error).toContain('0.14.0')
  })
  test('orchestrator refuses a seat-mods install with no omp/status-extension.ts', () => {
    record(ompRecord, { 'seat-mods': install('seat-mods', true, '0.14.0'), molt: install('molt'), 'crew': install('crew', false, '0.3.0') })
    const r = planLaunch({ role: 'orchestrator', via: 'omp-glm', args: [], ompRecord, claudeRecord, roleEnv: 'orchestrator', rolesDir: join(import.meta.dir, '../../omp-roles/roles') })
    expect((r as { error: string }).error).toContain('status-extension.ts')
  })
  const orch = () => planLaunch({ role: 'orchestrator', via: 'omp-glm', args: [], ompRecord, claudeRecord, roleEnv: 'orchestrator', rolesDir: join(import.meta.dir, '../../omp-roles/roles') })
  const orchMods = () => ({ 'seat-mods': statusEntry(install('seat-mods', true, '0.14.0')), molt: install('molt') })
  test('orchestrator refuses a host with no crew, naming the plugin, the install command and the omp record', () => {
    record(ompRecord, orchMods())
    const r = orch() as { error: string }
    expect(r.error).toContain('orchestrator needs crew 0.3.0 or later installed for omp')
    expect(r.error).toContain('omp plugin install crew@pulsestack')
    expect(r.error).toContain(ompRecord)
  })
  // crew's first release is 0.3.0, so no below-minimum `crew` version can exist: the value
  // here is synthetic on purpose, and exists only to exercise the compare and its message.
  test('orchestrator refuses a crew record below 0.3.0 (no "Host: OMP")', () => {
    record(ompRecord, { ...orchMods(), 'crew': install('crew', false, '0.0.1') })
    expect((orch() as { error: string }).error).toContain('crew 0.0.1 is unsupported for orchestrator')
  })
  test("orchestrator refuses crew installed only for Claude Code (omp would not discover it)", () => {
    record(ompRecord, orchMods())
    record(claudeRecord, { 'crew': install('crew', false, '0.3.0') })
    expect((orch() as { error: string }).error).toContain('needs crew 0.3.0 or later installed for omp')
  })
  for (const env of [undefined, '', 'coordinator', 'implementer', ' orchestrator', 'orchestrator ']) {
    test(`orchestrator refuses SEAT_MODS_ROLE=${JSON.stringify(env)}: the #798 rail keys on "orchestrator"`, () => {
      record(ompRecord, { ...orchMods(), 'crew': install('crew', false, '0.3.0') })
      const r = planLaunch({ role: 'orchestrator', via: 'omp-glm', args: [], ompRecord, claudeRecord, rolesDir: join(import.meta.dir, '../../omp-roles/roles'), roleEnv: env })
      expect((r as { error: string }).error).toContain('needs SEAT_MODS_ROLE=orchestrator')
    })
  }
  test('control: worker launches with SEAT_MODS_ROLE unset', () => {
    record(ompRecord, { 'seat-mods': install('seat-mods'), molt: install('molt') })
    expect(launch('worker')).toHaveProperty('argv')
  })
  test('control: a worker does not load the status entry, even when seat-mods ships it', () => {
    record(ompRecord, { 'seat-mods': statusEntry(install('seat-mods', true, '0.14.0')), molt: install('molt') })
    const r = launch('worker') as { argv: string[] }
    expect(r.argv.filter(a => a === '-e')).toHaveLength(2)
    expect(r.argv.some(a => a.endsWith('status-extension.ts'))).toBe(false)
  })
  test('control: worker needs no crew', () => {
    record(ompRecord, { 'seat-mods': install('seat-mods'), molt: install('molt') })
    expect(launch('worker')).toHaveProperty('argv')
  })
  test('control: worker accepts seat-mods 0.14.0, the kill rail floor (#1099)', () => {
    record(ompRecord, { 'seat-mods': install('seat-mods', true, '0.14.0'), molt: install('molt') })
    expect(launch('worker')).toHaveProperty('argv')
  })
  for (const role of ['spine-driver', 'close', 'work-pr', 'crew-spine', 'crew-work-pr']) {
    test(`${role} appends its shipped role file after the extensions and before passthrough args`, () => {
      const [s, m] = ['seat-mods', 'molt'].map((n) => install(n))
      record(ompRecord, { 'seat-mods': s, molt: m })
      const rolesDir = join(import.meta.dir, '../../omp-roles/roles')
      expect(planLaunch({ role, via: 'omp-glm', args: ['--model', 'test model', 'Begin.'], ompRecord, claudeRecord, rolesDir })).toMatchObject({
        argv: ['omp-glm', '-e', join(s, 'omp/extension.ts'), '-e', join(m, 'omp/extension.ts'),
          '--append-system-prompt', join(rolesDir, `${role}.md`), '--model', 'test model', 'Begin.'],
        warnings: [],
      })
    })
    test(`${role} refuses a missing role file instead of launching without its procedure`, () => {
      record(ompRecord, { 'seat-mods': install('seat-mods'), molt: install('molt') })
      const rolesDir = join(root, 'missing roles')
      expect(planLaunch({ role, via: 'omp-glm', args: [], ompRecord, claudeRecord, rolesDir })).toEqual({
        error: `omp-seat: role file ${join(rolesDir, `${role}.md`)} is missing`,
      })
    })
  }
  test('a mod missing from both records names the mod and both records', () => {
    record(ompRecord, { 'seat-mods': install('seat-mods') })
    const r = launch()
    expect(r).toHaveProperty('error')
    const e = (r as { error: string }).error
    expect(e).toContain('molt')
    expect(e).toContain(ompRecord)
    expect(e).toContain(claudeRecord)
  })
  test('with no record at all every mod is missing, and that is an error', () => {
    expect(launch()).toHaveProperty('error')
  })
  test("a mod present only in Claude Code's record uses that install path", () => {
    const [s, m] = ['seat-mods', 'molt'].map((n) => install(n))
    record(ompRecord, { 'seat-mods': s })
    record(claudeRecord, { molt: m })
    expect(launch()).toMatchObject({
      argv: ['omp-glm', '-e', join(s, 'omp/extension.ts'), '-e', join(m, 'omp/extension.ts'), '--x'],
      warnings: [],
    })
  })
  test('an install without omp/extension.ts is an error naming the file', () => {
    const old = install('seat-mods', false)
    record(ompRecord, { 'seat-mods': old, molt: install('molt') })
    const r = launch() as { error: string }
    expect(r.error).toContain(join(old, 'omp', 'extension.ts'))
    expect(r.error).toContain('0.14.0')
  })
  test('seat-mods 0.13.0 (no kill rail) with an OMP extension is refused, naming the 0.14.0 minimum (#1099)', () => {
    record(ompRecord, { 'seat-mods': install('seat-mods', true, '0.13.0'), molt: install('molt') })
    expect(launch()).toEqual({ error: expect.stringContaining('seat-mods 0.13.0') })
    expect((launch() as { error: string }).error).toContain('0.14.0')
  })
  test('seat-mods 0.14.0 with an OMP extension is accepted', () => {
    record(ompRecord, { 'seat-mods': install('seat-mods', true, '0.14.0'), molt: install('molt') })
    expect(launch()).toHaveProperty('argv')
    expect(launch()).not.toHaveProperty('error')
  })
  test('newer seat-mods is accepted without a lexicographic version comparison', () => {
    record(ompRecord, { 'seat-mods': install('seat-mods', true, '0.100.0'), molt: install('molt') })
    expect(launch()).toHaveProperty('argv')
  })
  test('a mod with an unreadable or invalid version refuses instead of launching unguarded', () => {
    const s = install('seat-mods')
    record(ompRecord, { 'seat-mods': s, molt: install('molt') })
    for (const content of ['{not json', JSON.stringify({ version: 'bad' }), JSON.stringify({})]) {
      writeFileSync(join(s, '.claude-plugin', 'plugin.json'), content)
      expect(launch()).toEqual({ error: expect.stringContaining('0.14.0') })
    }
  })
  test('an unreadable record fails loud, naming the record, and execs nothing', () => {
    mkdirSync(join(ompRecord, '..'), { recursive: true })
    writeFileSync(ompRecord, '{not json')
    const r = launch() as { error: string }
    expect(r.error).toContain(ompRecord)
    expect(r.error).toContain('unreadable')
  })
  test('an unreadable Claude record fails loud too', () => {
    record(ompRecord, { 'seat-mods': install('seat-mods'), molt: install('molt') })
    mkdirSync(join(claudeRecord, '..'), { recursive: true })
    writeFileSync(claudeRecord, '{not json')
    expect((launch() as { error: string }).error).toContain(claudeRecord)
  })
})

describe('pinWarning', () => {
  test('a different omp version warns', () => {
    expect(pinWarning('omp/18.9.0', '18.8.9')).toBe(
      'omp-seat: omp 18.9.0 is not the tested 18.8.9; running anyway — an upgrade is a PR (omp-roles README)',
    )
  })
  test('the tested version, with trailing newline, does not', () => {
    expect(pinWarning('omp/18.8.9\n', '18.8.9')).toBeUndefined()
  })
})

describe('versionWarning', () => {
  test('a via that cannot run says nothing about the version', () => {
    expect(versionWarning({ error: new Error('ENOENT'), status: null, stdout: null }, '18.8.9')).toBeUndefined()
    expect(versionWarning({ status: 1, stdout: '' }, '18.8.9')).toBeUndefined()
  })
  test('a via that runs is held to the tested version', () => {
    expect(versionWarning({ status: 0, stdout: 'omp/18.9.0\n' }, '18.8.9')).toContain('18.9.0')
    expect(versionWarning({ status: 0, stdout: 'omp/18.8.9\n' }, '18.8.9')).toBeUndefined()
  })
})

describe('seat config overlay (#843)', () => {
  const shipped = join(import.meta.dir, '..', '..', 'omp-roles', 'seat-config.yml')
  test('the shipped overlay turns off omp\'s todo reminders and nothing else', () => {
    expect(Bun.YAML.parse(readFileSync(shipped, 'utf8'))).toEqual({ todo: { reminders: false } })
  })
  test('planLaunch passes the overlay right after the extensions, before the role file', () => {
    const [s, m] = ['seat-mods', 'molt'].map((n) => install(n))
    record(ompRecord, { 'seat-mods': s, molt: m })
    const rolesDir = join(import.meta.dir, '../../omp-roles/roles')
    expect(planLaunch({ role: 'close', via: 'omp-glm', args: ['Begin.'], ompRecord, claudeRecord, rolesDir, seatConfig: shipped })).toMatchObject({
      argv: ['omp-glm', '-e', join(s, 'omp/extension.ts'), '-e', join(m, 'omp/extension.ts'),
        `--config=${shipped}`, '--append-system-prompt', join(rolesDir, 'close.md'), 'Begin.'],
    })
  })
  test('a missing overlay stops the launch instead of starting a seat whose todo reminders block molt', () => {
    const [s, m] = ['seat-mods', 'molt'].map((n) => install(n))
    record(ompRecord, { 'seat-mods': s, molt: m })
    const gone = join(root, 'missing', 'seat-config.yml')
    expect(planLaunch({ role: 'worker', via: 'omp-glm', args: [], ompRecord, claudeRecord, seatConfig: gone })).toEqual({
      error: `omp-seat: seat config ${gone} is missing`,
    })
  })
  test('bin/omp-seat passes the shipped overlay to every launch', () => {
    const seat = join(import.meta.dir, '..', '..', 'omp-roles', 'bin', 'omp-seat')
    const home = mkdtempSync(join(tmpdir(), 'seat-home-'))
    const [s, m] = ['seat-mods', 'molt'].map((n) => install(n))
    record(join(home, '.omp', 'plugins', 'installed_plugins.json'), { 'seat-mods': s, molt: m })
    const out = join(home, 'argv.txt')
    const via = join(home, 'via.sh')
    writeFileSync(via, `#!/bin/sh\n[ "$1" = --version ] && exit 0\nprintf '%s\\n' "$@" > '${out}'\n`)
    chmodSync(via, 0o755)
    const r = spawnSync('bun', [seat, 'worker', '--via', via], { env: { ...process.env, HOME: home }, encoding: 'utf8', timeout: 30_000 })
    expect(r.status).toBe(0)
    expect(readFileSync(out, 'utf8').split('\n')).toContain(`--config=${shipped}`)
  })
})

describe('bin/omp-seat with a via that cannot run', () => {
  const seat = join(import.meta.dir, '..', '..', 'omp-roles', 'bin', 'omp-seat')
  function run(via: string) {
    const home = mkdtempSync(join(tmpdir(), 'seat-home-'))
    const [s, m] = ['seat-mods', 'molt'].map((n) => install(n))
    record(join(home, '.omp', 'plugins', 'installed_plugins.json'), { 'seat-mods': s, molt: m })
    return spawnSync('bun', [seat, 'worker', '--via', via], { env: { ...process.env, HOME: home }, encoding: 'utf8', timeout: 30_000 })
  }
  for (const set of [['PATH'], ['PATH', 'SHA256', 'ASSIGNMENT_ID', 'ASSIGNMENT_GENERATION', 'LAUNCH_ID']]) {
    test(`leftover authority variables (${set.length} of 5) neither refuse nor are read: the via runs and exits 0`, () => {
      const home = join(root, 'home')
      const receipt = join(root, 'executed')
      const via = join(root, 'harmless-via')
      writeFileSync(via, `#!/bin/sh\n[ "$1" = --version ] && exit 0\nprintf executed >> '${receipt}'\n`)
      chmodSync(via, 0o700)
      const [s, m] = ['seat-mods', 'molt'].map(n => install(n))
      record(join(home, '.omp/plugins/installed_plugins.json'), { 'seat-mods': s, molt: m })
      const leftover = Object.fromEntries(set.map(n => ['AUTO' + 'NOMIC_' + (n === 'PATH' ? 'AUTHORITY_PATH' : n === 'SHA256' ? 'AUTHORITY_SHA256' : n), join(root, 'missing-snapshot')]))
      const r = spawnSync('bun', [seat, 'worker', '--via', via], { env: { ...process.env, HOME: home, ...leftover }, encoding: 'utf8', timeout: 30_000 })
      expect({ status: r.status, executed: existsSync(receipt) }).toEqual({ status: 0, executed: true })
    })
  }
  test('an extension that fails to load stops the launch before any omp starts', () => {
    const home = mkdtempSync(join(tmpdir(), 'seat-home-'))
    const [s, m] = ['seat-mods', 'molt'].map((n) => install(n))
    writeFileSync(join(m, 'omp', 'extension.ts'), 'throw new Error("boom")')
    record(join(home, '.omp', 'plugins', 'installed_plugins.json'), { 'seat-mods': s, molt: m })
    const r = spawnSync('bun', [seat, 'worker', '--via', 'true'], { env: { ...process.env, HOME: home }, encoding: 'utf8', timeout: 30_000 })
    expect(r.status).toBe(2)
    expect(r.stderr).toContain(`omp-seat: ${join(m, 'omp', 'extension.ts')} did not load: boom`)
  })
  test('a missing command is named and exits 2, with no pin warning', () => {
    const r = run('/nonexistent/omp-via')
    expect(r.status).toBe(2)
    expect(r.stderr).toContain('omp-seat: cannot run /nonexistent/omp-via:')
    expect(r.stderr).not.toContain('not the tested')
  })
  test('a command that exits non-zero on --version gets no pin warning and keeps its own status', () => {
    const r = run('false')
    expect(r.status).toBe(1)
    expect(r.stderr).not.toContain('not the tested')
  })
})

describe('checkExtensions (fix wave 4)', () => {
  const mod = (name: string, src: string) => { const f = join(root, name); writeFileSync(f, src); return f }
  test('modules whose default export is a function load', async () => {
    expect(await checkExtensions([mod('a.ts', 'export default function () {}'), mod('b.ts', 'export default () => {}')])).toBeUndefined()
  })
  test('a module that throws on import is named with its error', async () => {
    const bad = mod('bad.ts', 'throw new Error("boom")')
    expect(await checkExtensions([bad])).toBe(`omp-seat: ${bad} did not load: boom`)
  })
  test('a syntax error, a missing file and a default export that is not a function all fail', async () => {
    for (const f of [mod('syn.ts', 'export default function ('), join(root, 'missing.ts'), mod('obj.ts', 'export default {}')]) {
      const e = await checkExtensions([join(root, 'ok.ts') && mod('ok.ts', 'export default () => {}'), f])
      expect(e).toContain(`omp-seat: ${f} did not load:`)
    }
  })
  test('planLaunch lists the two extension paths it pinned', () => {
    const [s, m] = ['seat-mods', 'molt'].map((n) => install(n))
    record(ompRecord, { 'seat-mods': s, molt: m })
    expect((launch() as { extensions: string[] }).extensions).toEqual([s, m].map((p) => join(p, 'omp/extension.ts')))
  })
})

describe('expandRole', () => {
  test('orc is the orchestrator on omp-glm, marked for the rail when SEAT_MODS_ROLE is unset or empty', () => {
    expect(expandRole('orc', undefined, undefined)).toEqual({ role: 'orchestrator', via: 'omp-glm', roleEnv: 'orchestrator' })
    expect(expandRole('orc', undefined, '')).toEqual({ role: 'orchestrator', via: 'omp-glm', roleEnv: 'orchestrator' })
  })
  test('orc keeps an explicit --via', () => {
    expect(expandRole('orc', 'omp-sol', undefined)).toEqual({ role: 'orchestrator', via: 'omp-sol', roleEnv: 'orchestrator' })
  })
  test('orc never overrides another SEAT_MODS_ROLE, so planLaunch still refuses it', () => {
    const e = expandRole('orc', undefined, 'coordinator')
    expect(e).toEqual({ role: 'orchestrator', via: 'omp-glm', roleEnv: 'coordinator' })
    expect(planLaunch({ ...e, args: [], ompRecord, claudeRecord })).toEqual({
      error: 'omp-seat: the orchestrator role needs SEAT_MODS_ROLE=orchestrator (got "coordinator"); seat-mods\' no-subagent rail keys on it' })
  })
  test('every other role is unchanged and defaults to plain omp', () => {
    expect(expandRole('orchestrator', undefined, undefined)).toEqual({ role: 'orchestrator', via: 'omp', roleEnv: undefined })
    expect(expandRole('worker', 'omp-glm', 'implementer')).toEqual({ role: 'worker', via: 'omp-glm', roleEnv: 'implementer' })
  })
})

describe('the orchestrator role states the status block (#867)', () => {
  // The role file is prose, wrapped: read as one logical line so a phrase broken
  // by a wrap still counts.
  const role = readFileSync(join(import.meta.dir, '..', '..', 'omp-roles', 'roles', 'orchestrator.md'), 'utf8').replace(/\s+/g, ' ')
  const labels = ['**What I ruled:**', '**What the PR(s) will carry:**', '**Next steps:**', '**Waiting on (seats live):**', '**Waiting on operator:**']

  test('carries the five labels, once each, in order', () => {
    let prev = -1
    for (const label of labels) {
      const first = role.indexOf(label)
      expect(first).toBeGreaterThan(prev)
      expect(role.indexOf(label, first + 1)).toBe(-1)
      prev = first
    }
  })
  test('states the rule with crew SKILL.md wording', () => {
    expect(role).toContain('your reply is only the status block')
    expect(role).toContain('is not a turn end: do the next step first')
    expect(role).toContain('five labels in this order, each at the start of a line')
    expect(role).toContain('(`none` is content)')
    expect(role).toContain('A turn the operator typed is free and takes any shape.')
    // crew SKILL.md §8's molt-handoff exception, same wording (#867 fix round).
    expect(role).toContain('ends with that line instead of the block')
  })
})
