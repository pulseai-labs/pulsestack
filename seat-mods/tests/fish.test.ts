import { describe, test, expect } from 'claude-code/testing'
import { killRule } from '../hooks/rules'

// fish's own option grammar and command prefixes. Strings only: every row is text handed to killRule, and nothing here
// runs a command. Each refused form below is one fish 4.2.1 runs its string for (probed with harmless strings), and
// each control beside it is the same form with a harmless string.

// fish's options: -c and -C take the rest of the cluster or the next word, every value runs, long names take any
// unique prefix with =value or the next word, and p, d, f, D and o take a value.
const REFUSE: ReadonlyArray<readonly [string, string]> = [
  ["fish -c 'kill -1'", "fish -c 'kill 123'"],
  ["fish -c'kill -1'", "fish -c'kill 123'"],
  ['fish -c "kill -1"', 'fish -c "kill 123"'],
  ["fish --command='kill -1'", "fish --command='kill 123'"],
  ["fish --command 'kill -1'", "fish --command 'kill 123'"],
  ["fish --comm 'kill -1'", "fish --comm 'kill 123'"],
  ["fish --c='kill -1'", "fish --c='kill 123'"],
  ["fish --co 'pkill -u dev'", "fish --co 'pkill node'"],
  ["fish -C 'kill -1'", "fish -C 'kill 123'"],
  ["fish -C'kill -1'", "fish -C'kill 123'"],
  ["fish --init 'kill -1'", "fish --init 'kill 123'"],
  ["fish --init-command='kill -1'", "fish --init-command='kill 123'"],
  ["fish --init-command 'kill 0'", "fish --init-command 'kill 10'"],
  ["fish -c 'echo ok' -c 'kill -1'", "fish -c 'echo ok' -c 'kill 123'"],
  ["fish -c 'echo ok' --command 'kill -1'", "fish -c 'echo ok' --command 'kill 123'"],
  ["fish -c 'echo ok' -c 'echo ok' -c 'kill -1'", "fish -c 'echo ok' -c 'echo ok' -c 'kill 123'"],
  ["fish -c 'echo ok' -C 'kill -1'", "fish -c 'echo ok' -C 'kill 123'"],
  ["fish -C 'echo ok' -C 'kill -1'", "fish -C 'echo ok' -C 'kill 123'"],
  ["fish -ic 'pkill -u dev'", "fish -ic 'pkill node'"],
  ["fish -l -N -c 'kill -9 -1'", "fish -l -N -c 'kill -9 123'"],
  ["fish --no-config --login -c 'kill -1'", "fish --no-config --login -c 'kill 123'"],
  ["fish -p prof -c 'kill -1'", "fish -p prof -c 'kill 123'"],
  ["fish -D 2 -c 'kill -1'", "fish -D 2 -c 'kill 123'"],
  ["fish --debug x -c 'kill -1'", "fish --debug x -c 'kill 123'"],
  ["fish -o /dev/null -c 'kill -1'", "fish -o /dev/null -c 'kill 123'"],
  ["fish -f x -c 'kill -1'", "fish -f x -c 'kill 123'"],
  ["fish --debug-output x -c 'kill -1'", "fish --debug-output x -c 'kill 123'"],
  ["fish --profile-startup x -c 'kill -1'", "fish --profile-startup x -c 'kill 123'"],
  ["fish --features x -c 'kill -1'", "fish --features x -c 'kill 123'"],
  ["fish -c -- -c 'kill -1'", "fish -c -- -c 'kill 123'"],
  ["env fish -c 'ps; kill 1'", "env fish -c 'ps; echo 1'"],
  ["/usr/bin/fish -c 'kill 0'", "/usr/bin/fish -c 'kill 10'"],
  ["sudo fish -c 'killall -u dev'", "sudo fish -c 'killall node'"],
  ["echo ok; fish -c 'kill -1'", "echo ok; fish -c 'kill 123'"],
]
// fish runs no string here (options end at --, a bare -, or the first operand; a value-taking letter eats the next
// word), and the reading takes none.
const ALLOW: readonly string[] = [
  "fish -p -c 'kill -1'", "fish -dc 'kill -1'", "fish -cC 'kill -1'", "fish x -c 'kill -1'", "fish -- -c 'kill -1'",
  "fish - -c 'kill -1'", "fish +c 'kill -1'", "fish 'kill -1'", "fish -c 'echo ok' 'kill -1'", "fish -c 'echo ok' -- 'kill -1'",
  "fish -c 'echo ok' x -c 'kill -1'", "fish -c -- 'kill -1' -c 'kill -1'", "fish -C 'echo ok' 'kill -1'", "fish -c 'echo ok'",
  "fish --no-config -c 'echo ok'", "fish script.fish --command 'kill -1'", "fish -i x -C 'kill -1'", "fish --debug -c 'kill -1'",
]
describe('killRule: fish option grammar', () => {
  for (const [command, control] of REFUSE) {
    test(`refuses ${JSON.stringify(command)}`, () => { expect(killRule(command)).toContain('kill rail') })
    test(`control: allows ${JSON.stringify(control)}`, () => { expect(killRule(control)).toBeUndefined() })
  }
  for (const command of ALLOW) test(`allows ${JSON.stringify(command)}`, () => { expect(killRule(command)).toBeUndefined() })
})

// Deliberate false stops: a -c or -C value is read even where fish then runs nothing (-n, -v, an unknown option, an
// ambiguous prefix, a value-taking option with no value left). Each has a harmless control.
const FALSE_STOPS: ReadonlyArray<readonly [string, string]> = [
  ["fish -n -c 'kill -1'", "fish -n -c 'kill 123'"],
  ["fish --no-execute -c 'kill -1'", "fish --no-execute -c 'kill 123'"],
  ["fish -c 'kill -1' -v", "fish -c 'kill 123' -v"],
  ["fish -e -c 'kill -1'", "fish -e -c 'kill 123'"],
  ["fish --i 'kill -1'", "fish --i 'kill 123'"],
  ["fish -c 'kill -1' -p", "fish -c 'kill 123' -p"],
]
describe('killRule: fish deliberate false stops', () => {
  for (const [command, control] of FALSE_STOPS) {
    test(`refuses ${JSON.stringify(command)} though fish runs nothing`, () => { expect(killRule(command)).toContain('kill rail') })
    test(`control: allows ${JSON.stringify(control)}`, () => { expect(killRule(control)).toBeUndefined() })
  }
})

// A fish string the reading cannot finish (an unclosed `$(`) is unread, as under sh, and never hides a refusal
// elsewhere in the call, before or after it.
describe('killRule: an unreadable fish string', () => {
  test('alone, it is unread: it throws', () => {
    expect(() => killRule("fish -c '$(x'")).toThrow()
    expect(() => killRule("fish -C '$(x' -c 'echo ok'")).toThrow()
  })
  for (const command of [
    "fish -c '$(x'; kill -1", "fish -c '$(x' && pkill -u dev", "fish -c '$(x' -c 'kill -1'", "fish -C '$(x' -c 'kill -1'",
    "fish -c 'kill -1' -c '$(x'", "fish --command='$(x' --init 'ps; kill 1'", "kill -1; fish -c '$(x'",
  ])
    test(`refuses ${JSON.stringify(command)} with the kill reason, not a throw`, () => { expect(killRule(command)).toContain('kill rail') })
})

// fish's command prefixes, read beside the plain string: and, or, not and begin at the head of a command (quoted or
// not, as fish reads them), and a `{` that opens a block, at the head of a command, after a prefix or keyword, and at the
// head of a substitution. fish 4.2.1 runs the kill text in each form.
const REFUSE_HEADS: ReadonlyArray<readonly [string, string]> = [
  ["fish -c 'true; and kill -1'", "fish -c 'true; and kill 123'"],
  ["fish -c 'and kill -1'", "fish -c 'and kill 123'"],
  ["fish -c 'false; or kill -1'", "fish -c 'false; or kill 123'"],
  ["fish -c 'false || or pkill -u dev'", "fish -c 'false || or pkill node'"],
  ["fish -c 'not kill -1'", "fish -c 'not kill 123'"],
  ["fish -c 'not not kill -1'", "fish -c 'not not kill 123'"],
  ["fish -c 'if not pkill -u dev; end'", "fish -c 'if not pkill node; end'"],
  ["fish -c 'while not kill -1; end'", "fish -c 'while not kill 123; end'"],
  ["fish -c 'begin kill -1; end'", "fish -c 'begin kill 123; end'"],
  ["fish -c 'begin; and kill -1; end'", "fish -c 'begin; and kill 123; end'"],
  ["fish -c '{kill -1}'", "fish -c '{kill 123}'"],
  ["fish -c '{ not kill -1; }'", "fish -c '{ not kill 123; }'"],
  ["fish -c 'echo ok; {and killall -u dev}'", "fish -c 'echo ok; {and killall node}'"],
  ["fish -c 'cd /tmp\nand killall -u dev'", "fish -c 'cd /tmp\nand killall node'"],
  ["fish -C 'true; and kill 0'", "fish -C 'true; and kill 10'"],
  // the heads before a prefix: &&, a tab, time, else and !
  ["fish -c 'true && not kill -1'", "fish -c 'true && not kill 123'"],
  ["fish -c 'true;\tand kill -1'", "fish -c 'true;\tand kill 123'"],
  ["fish -c 'time not kill -1'", "fish -c 'time not kill 123'"],
  ["fish -c 'if false; else not kill -1; end'", "fish -c 'if false; else not kill 123; end'"],
  ["fish -c '! not kill -1'", "fish -c '! not kill 123'"],
  // a prefix at the head of a substitution, bare, as $( or inside double quotes
  ["fish -c 'echo $(not kill -1)'", "fish -c 'echo $(not kill 123)'"],
  ["fish -c 'echo (not kill -1)'", "fish -c 'echo (not kill 123)'"],
  ["fish -c 'echo (and kill -1)'", "fish -c 'echo (and kill 123)'"],
  ["fish -c 'echo $(begin kill -1; end)'", "fish -c 'echo $(begin kill 123; end)'"],
  ["fish -c 'echo \"$(begin kill -1; end)\"'", "fish -c 'echo \"$(begin kill 123; end)\"'"],
  ["fish -c 'set pids (not pkill -u dev)'", "fish -c 'set pids (not pkill node)'"],
  ["fish -c 'echo (if not kill -1; end)'", "fish -c 'echo (if not kill 123; end)'"],
  // a block's { glued after a prefix, a keyword, && or a substitution's (
  ["fish -c 'not {kill -1}'", "fish -c 'not {kill 123}'"],
  ["fish -c 'and {kill -1}'", "fish -c 'and {kill 123}'"],
  ["fish -c 'if {kill -1}; end'", "fish -c 'if {kill 123}; end'"],
  ["fish -c 'if not {kill -1}; end'", "fish -c 'if not {kill 123}; end'"],
  ["fish -c 'while {kill -1; break}; end'", "fish -c 'while {kill 123; break}; end'"],
  ["fish -c 'time {kill -1}'", "fish -c 'time {kill 123}'"],
  ["fish -c '! {kill -1}'", "fish -c '! {kill 123}'"],
  ["fish -c 'echo ({kill -1})'", "fish -c 'echo ({kill 123})'"],
  ["fish -c 'not {pkill -u dev}'", "fish -c 'not {pkill node}'"],
  ["fish -c 'true && {kill -1}'", "fish -c 'true && {kill 123}'"],
  // a quoted prefix word is still a prefix
  ["fish -c \"'not' kill -1\"", "fish -c \"'not' kill 123\""],
  ["fish -c 'n\"\"ot kill -1'", "fish -c 'n\"\"ot kill 123'"],
  ["fish -c '\"and\" kill -1'", "fish -c '\"and\" kill 123'"],
  ["fish -c \"true; 'and' kill -1\"", "fish -c \"true; 'and' kill 123\""],
  ["fish -c \"'begin' kill -1; end\"", "fish -c \"'begin' kill 123; end\""],
  ["fish -c 'false; \"or\" kill -1'", "fish -c 'false; \"or\" kill 123'"],
  ["fish -c \"true; a'nd' kill -1\"", "fish -c \"true; a'nd' kill 123\""],
]
describe('killRule: fish command prefixes', () => {
  for (const [command, control] of REFUSE_HEADS) {
    test(`refuses ${JSON.stringify(command)}`, () => { expect(killRule(command)).toContain('kill rail') })
    test(`control: allows ${JSON.stringify(control)}`, () => { expect(killRule(control)).toBeUndefined() })
  }
  // A prefix word that is an argument (quoted or not), sits inside a quoted string, or is part of a longer word is not a prefix.
  for (const command of ["fish -c 'echo and kill -1'", "fish -c 'echo \"and kill -1\"'", "fish -c \"echo 'not' kill -1\"", "fish -c 'echo $(echo not kill -1)'",
    "fish -c 'band kill -1'", "fish -c 'echo ok; ornot kill -1'", "fish -c 'notify kill -1'", "fish -c \"'and kill -1'\"", "fish -c 'echo {not,x} kill -1'"])
    test(`allows ${JSON.stringify(command)}`, () => { expect(killRule(command)).toBeUndefined() })
  // The prefixes are fish's only: a POSIX shell's string keeps its verdict.
  test('control: sh -c with a fish prefix keeps the verdict it had', () => {
    expect(killRule("sh -c 'true; and kill -1'")).toBeUndefined()
    expect(killRule("bash -c 'not kill -1'")).toBeUndefined()
  })
})

// The frozen set: a grid of fish option forms, runner spellings, kill placements, unreadable strings (an unclosed
// `$(`) on either side of a kill, and a command after the call. `fishy`, a name the rail does not read, is read here as
// fish was read before fish had a reading of its own, so `fishy`'s refused set is that earlier set (its count and digest
// are frozen below). Every form it refuses must be refused under fish, and a throw counts as unread, never as a refusal.
// The forms fish adds are frozen too, so a refusal added or dropped shows. Other names keep their frozen verdicts.
// cyrb53: a 53-bit string hash (the hooks module may import nothing but its own files).
function cyrb53(str: string): number {
  let h1 = 0xdeadbeef, h2 = 0x41c6ce57
  for (let i = 0; i < str.length; i++) {
    const ch = str.charCodeAt(i)
    h1 = Math.imul(h1 ^ ch, 2654435761)
    h2 = Math.imul(h2 ^ ch, 1597334677)
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909)
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909)
  return 4294967296 * (2097151 & h2) + (h1 >>> 0)
}
const FISH_GRID_WORDS = ['-c', '-C', '--command', '--comm', '--init', '--c', '-i', '-n', '-p', '-ic', '-cC', '--', '-', 'x', '+c', '-v', '--i', '-e']
const FISH_PLACEMENTS: ReadonlyArray<readonly [string, string]> = [
  ["'kill -1'", "'echo S2'"], ["'echo S1'", "'kill -1'"], ["'kill -1'", "'kill -1'"], ["'$(x'", "'kill -1'"], ["'kill -1'", "'$(x'"],
]
const FISH_TAILS = ['; kill -1', ' && pkill -u dev', '; echo ok']
// Each command without its runner name; the name goes in front, as `fish`, `env fish` or `/usr/bin/fish`.
function fishGrid(): string[] {
  const forms: string[][] = []
  const grow = (prefix: string[]): void => {
    if (prefix.length > 0) forms.push(prefix)
    if (prefix.length < 2) for (const w of FISH_GRID_WORDS) grow([...prefix, w])
  }
  grow([])
  const commands: string[] = []
  for (const form of forms) {
    for (const [s1, s2] of FISH_PLACEMENTS) commands.push([...form, s1, s2].join(' '))
    for (const s1 of ["'$(x'", "'echo S1'"]) for (const tail of FISH_TAILS) commands.push(`${[...form, s1].join(' ')}${tail}`)
  }
  return commands
}
const verdictOf = (command: string): 'refused' | 'allowed' | 'thrown' => {
  try { return killRule(command) !== undefined ? 'refused' : 'allowed' } catch { return 'thrown' }
}
// The forms fish's reading adds to the earlier set, under each spelling.
const FISH_ADDED = { count: 144, hash: 2005709973301108 }
const SPELLINGS: ReadonlyArray<readonly [string, string]> = [['fish', 'fishy'], ['env fish', 'env fishy'], ['/usr/bin/fish', '/usr/bin/fishy']]
describe('killRule: the fish grid never loosens, and other names keep their verdicts', () => {
  const grid = fishGrid()
  test('the grid holds 3762 forms', () => { expect(grid.length).toBe(3762) })
  for (const [fish, unread] of SPELLINGS) {
    const before = grid.filter(c => verdictOf(`${unread} ${c}`) === 'refused')
    test(`${unread}: the refused set before fish was read is frozen (count and digest)`, () => {
      expect({ count: before.length, hash: cyrb53(before.join('\n')) }).toEqual({ count: 1368, hash: 4024114021318640 })
    })
    test(`${fish}: every form refused before is still refused, not thrown`, () => {
      const lost = before.filter(c => verdictOf(`${fish} ${c}`) !== 'refused').map(c => `${fish} ${c}`)
      expect({ lost: lost.length, first: lost.slice(0, 3) }).toEqual({ lost: 0, first: [] })
    })
    test(`${fish}: the forms its reading adds are frozen (count and digest)`, () => {
      const added = grid.filter(c => verdictOf(`${unread} ${c}`) !== 'refused' && verdictOf(`${fish} ${c}`) === 'refused')
      expect({ count: added.length, hash: cyrb53(added.join('\n')) }).toEqual(FISH_ADDED)
    })
  }
  // The verdicts of every other runner name on the same grid, frozen before fish was read; a name the rail does not
  // read refuses only what its tail refuses. A change to any of them shows here.
  // [refused, digest of the refused forms, thrown]
  const OTHER: Readonly<Record<string, readonly [number, number, number]>> = {
    fish2: [1368, 4024114021318640, 0], rfish: [1368, 4024114021318640, 0], 'fish.sh': [1368, 4024114021318640, 0],
    sh: [1728, 4946657913147325, 240], bash: [1728, 4946657913147325, 240], zsh: [1728, 4946657913147325, 240],
    dash: [1728, 4946657913147325, 240], 'busybox sh': [1728, 4946657913147325, 240], ksh: [2196, 2847645446119219, 552],
    mksh: [1926, 1008651996436649, 372], yash: [1800, 3279893687628280, 288], eval: [1370, 725721267385697, 1026],
    rbash: [1728, 4946657913147325, 240], ash: [1728, 4946657913147325, 240], 'static-sh': [1728, 4946657913147325, 240],
    ksh93: [2196, 2847645446119219, 552], lksh: [1926, 1008651996436649, 372], 'mksh-static': [1926, 1008651996436649, 372],
  }
  for (const name of Object.keys(OTHER))
    test(`${name} keeps its frozen verdicts on the fish grid`, () => {
      const refused = grid.filter(c => verdictOf(`${name} ${c}`) === 'refused')
      const thrown = grid.filter(c => verdictOf(`${name} ${c}`) === 'thrown')
      expect([refused.length, cyrb53(refused.join('\n')), thrown.length]).toEqual(OTHER[name]!)
    })
})
