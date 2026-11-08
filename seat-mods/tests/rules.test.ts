import { describe, test, expect } from 'claude-code/testing'
import { parseRole, parseAllow, scratchDirs, scratchAllow, bashRules, commitMessageFiles, rmTargets, removalOf, UNREAD, placeOf, decide, invalidText, statusText, substitutionsOf, SUBSTITUTION_TOO_DEEP } from '../hooks/rules'

describe('parseRole', () => {
  test('unset and empty default to the guarded implementer', () => {
    expect(parseRole(undefined)).toEqual({ kind: 'default', role: 'implementer' })
    expect(parseRole('')).toEqual({ kind: 'default', role: 'implementer' })
  })
  test('the three guarded roles are on', () => {
    for (const role of ['implementer', 'verifier', 'reviewer']) expect(parseRole(role)).toEqual({ kind: 'on', role })
  })
  test('orchestrator and coordinator are free; near misses stay invalid', () => {
    for (const role of ['orchestrator', 'coordinator']) expect(parseRole(role)).toEqual({ kind: 'free', role })
    for (const value of ['Implementer', 'Orchestrator', 'orchestrator ', 'orchestrater', 'Coordinator', 'co-ordinator'])
      expect(parseRole(value)).toEqual({ kind: 'invalid', value })
  })
})

describe('statusText', () => {
  test('every state reads distinctly', () => {
    expect(statusText({ kind: 'on', role: 'implementer' })).toBe('seat: implementer')
    expect(statusText({ kind: 'default', role: 'implementer' })).toBe('seat: implementer (default: SEAT_MODS_ROLE unset or empty)')
    expect(statusText({ kind: 'free', role: 'orchestrator' })).toBe('seat: orchestrator')
    expect(statusText({ kind: 'invalid', value: 'impl' })).toBe('seat: INVALID ROLE "impl"')
  })
})

describe('parseAllow', () => {
  test('splits on colons and drops a trailing slash', () => {
    expect(parseAllow('/a/reports/:/b/scratch')).toEqual(['/a/reports', '/b/scratch'])
  })
  test('ignores relative entries and the root', () => {
    expect(parseAllow('rel/dir:/:/ok')).toEqual(['/ok'])
  })
  test('unset is empty', () => {
    expect(parseAllow(undefined)).toEqual([])
  })
})

describe('bashRules', () => {
  test('merges', () => {
    expect(bashRules('git merge main')).toContain('merge')
    expect(bashRules('git -C /w merge main')).toContain('merge')
    expect(bashRules('gh pr merge 12 --merge')).toContain('merge')
  })
  test('force-push spellings', () => {
    for (const c of ['git push --force', 'git push -f origin b', 'git push --force-with-lease', 'git push origin +b'])
      expect(bashRules(c)).toContain('force-push')
    expect(bashRules('git push origin b')).not.toContain('force-push')
  })
  test('branch deletion', () => {
    for (const c of ['git branch -D b', 'git push --delete origin b', 'git push -d origin b', 'git push origin :b'])
      expect(bashRules(c)).toContain('branch-delete')
    expect(bashRules('git branch -d b')).not.toContain('branch-delete')
  })
  test('no-verify', () => {
    expect(bashRules('git commit --no-verify -F m')).toContain('no-verify')
    expect(bashRules('git commit -n -F m')).toContain('no-verify')
    expect(bashRules('git push --no-verify')).toContain('no-verify')
  })
  test('trailers on the command line, in a heredoc, or in the message file', () => {
    expect(bashRules('git commit -m "x\n\nCo-Authored-By: a <b>"')).toContain('ai-trailer')
    expect(bashRules("git commit -F - <<'EOF'\nfix\n\n🤖 Generated with x\nEOF")).toContain('ai-trailer')
    expect(bashRules('git commit -F msg.txt', 'fix\n\nco-authored-by: a')).toContain('ai-trailer')
    expect(bashRules('git commit -F msg.txt', 'fix')).not.toContain('ai-trailer')
  })
  test('commit, push and pr create', () => {
    expect(bashRules('git commit -F m && git push origin b')).toEqual(expect.arrayContaining(['commit', 'push']))
    expect(bashRules('gh pr create --fill')).toContain('pr-create')
  })
  test('commit message text is not read as commands (final review #2)', () => {
    const heredoc = "git commit -F - <<'EOF'\nfeat: guards\n\nDenies git merge and git push --force on seats.\nEOF"
    expect(bashRules(heredoc)).toEqual(['commit'])
    const substituted = 'git commit -m "$(cat <<\'EOF\'\nfeat: guards\n\ngh pr merge is denied.\nEOF\n)"'
    expect(bashRules(substituted)).toEqual(['commit'])
    expect(bashRules('git commit -m "add the -n flag"')).toEqual(['commit'])
    expect(bashRules('git commit -m "mention --no-verify | git merge"')).toEqual(['commit'])
  })
  test('a heredoc trailer is still found, and real commands after the message still count', () => {
    expect(bashRules("git commit -F - <<'EOF'\nfix\n\nCo-Authored-By: a\nEOF")).toContain('ai-trailer')
    expect(bashRules("git commit -F - <<'EOF'\nfix\nEOF\ngit push --force")).toContain('force-push')
  })
  test('only the command word counts: echo or grep naming git is not git (merge-bar condition 1)', () => {
    expect(bashRules('echo git merge')).toEqual([])
    expect(bashRules('echo merge')).toEqual([])
    expect(bashRules('grep -rn "git push --force" docs')).toEqual([])
  })
  test('control: wrappers and assignments before git are still git', () => {
    expect(bashRules('GIT_TRACE=1 git merge main')).toContain('merge')
    expect(bashRules('sudo git push --force')).toContain('force-push')
    expect(bashRules('env A=1 /usr/bin/git branch -D b')).toContain('branch-delete')
    expect(bashRules('(cd sub && git push -f)')).toContain('force-push')
  })
  test('the trailer check reads only the commit segment (merge-bar condition 1)', () => {
    expect(bashRules('git commit -m x && grep -rn "Co-Authored-By:" hooks/')).toEqual(['commit'])
    expect(bashRules('git commit -m "x\n\nCo-Authored-By: a" && echo done')).toContain('ai-trailer')
  })
  test('separate force and delete flags count', () => {
    expect(bashRules('git branch --delete --force x')).toContain('branch-delete')
    expect(bashRules('git push -d origin b')).toContain('branch-delete')
  })
  test('an attached option value is not a flag bundle (PR #644 round 5)', () => {
    expect(bashRules('git commit -mfixing')).toEqual(['commit'])
    expect(bashRules('git push -ofoo origin b')).toEqual(['push'])
  })
  test('a comment is not a command (PR #644 round 5)', () => {
    expect(bashRules('echo ok # ; git push --force')).toEqual([])
  })
  test('a comment right after an operator is a comment (PR #644 round 6)', () => {
    expect(bashRules('echo ok;# x; git push --force')).toEqual([])
  })
  test('flags stop at -- (PR #644 round 6)', () => {
    expect(bashRules('git add -- --no-verify')).toEqual([])
    expect(bashRules('git commit -m x -- -n')).toEqual(['commit'])
  })
  test('control: flags before -- still count', () => {
    expect(bashRules('git commit --no-verify -m x -- a.ts')).toContain('no-verify')
  })
  test('control: a command before a comment still counts', () => {
    expect(bashRules('echo ok; git push --force # note')).toContain('force-push')
    expect(bashRules('git push origin b#tag')).toEqual(['push'])
  })
  test('control: bundles without the letter do not count', () => {
    expect(bashRules('git push -qu origin b')).toEqual(['push'])
    expect(bashRules('git branch -d x')).toEqual([])
    expect(bashRules('git commit -am x')).toEqual(['commit'])
  })
  test('any heredoc delimiter is message text (PR #644 review)', () => {
    expect(bashRules("git commit -F - <<'COMMIT-MSG'\nfix\n\ngit merge main\nCOMMIT-MSG")).toEqual(['commit'])
    expect(bashRules('git commit -F - <<"END MSG"\nfix\ngit push -f\nEND MSG')).toEqual(['commit'])
    expect(bashRules('git commit -F - <<-EOF.1\n\tfix\n\tgit merge x\n\tEOF.1')).toEqual(['commit'])
    expect(bashRules('git commit -F - <<-EOF.1\n\tfix\n\tEOF.1\ngit push --force')).toContain('force-push')
  })
  test('control: a body line that only starts with the delimiter does not end the heredoc', () => {
    expect(bashRules("git commit -F - <<'MSG'\nfix\nMSG-not-the-end\ngit merge x\nMSG\ngit push --force")).toEqual(['commit', 'push', 'force-push'])
  })
  test('PR #644 round 2: spellings that slipped past', () => {
    expect(bashRules('git push \\\n  --force origin b')).toContain('force-push')
    expect(bashRules('git branch -d -f victim')).toContain('branch-delete')
    expect(bashRules('git branch -d --force victim')).toContain('branch-delete')
    expect(bashRules('git push --mirror origin')).toContain('force-push')
    expect(bashRules('git push --prune origin')).toContain('branch-delete')
    expect(bashRules('gh pr --repo o/r merge 12')).toContain('merge')
    expect(bashRules('gh pr -R o/r create --fill')).toContain('pr-create')
  })
  test('control: a backslash-newline joins lines, a plain newline still splits', () => {
    expect(bashRules('git push origin b\ngit status')).toEqual(['push'])
    expect(bashRules('gh pr --repo o/r view 12')).toEqual([])
  })
  test('an escaped operator is text, not a boundary (PR #644 round 3)', () => {
    expect(bashRules("printf '<%s>\\n' foo\\|git merge")).toEqual([])
    expect(bashRules('echo a\\;git push --force')).toEqual([])
  })
  test('control: an unescaped operator still splits', () => {
    expect(bashRules('echo a;git push --force')).toContain('force-push')
  })
  test('a trailer counts only at a line start, as the repo hook reads it (PR #644 round 4)', () => {
    expect(bashRules('git commit -m "docs: explain Co-Authored-By: trailers"')).toEqual(['commit'])
    expect(bashRules('git commit -m "chore: 🤖 Generated with marker stays mid-line"')).toEqual(['commit'])
    expect(bashRules('git commit -F m', 'docs: noting that Co-Authored-By: trailers exist mid-line\n')).toEqual(['commit'])
  })
  test('control: a line-start trailer still counts, in any case', () => {
    expect(bashRules('git commit -F m', 'fix\n\nco-authored-by: a <b>\n')).toContain('ai-trailer')
    expect(bashRules('git commit -F m', 'fix\n\n🤖 Generated with x\n')).toContain('ai-trailer')
  })
  test('a quoted -C path does not hide the subcommand', () => {
    expect(bashRules('git -C "/a b" push --force')).toContain('force-push')
  })
  test('quoted words are not subcommands (Review Focus 2)', () => {
    expect(bashRules('git commit -m "merge the fix"')).not.toContain('merge')
    expect(bashRules('git log --merges')).toEqual([])
  })
})

describe('commitMessageFiles', () => {
  test('finds -F, --file and --file=', () => {
    expect(commitMessageFiles('git commit -F /m/a')).toEqual(['/m/a'])
    expect(commitMessageFiles('git commit --file "/m/b"')).toEqual(['/m/b'])
    expect(commitMessageFiles('git add . && git commit --file=/m/c')).toEqual(['/m/c'])
  })
  test('a quoted path with spaces stays whole (PR #644 review)', () => {
    expect(commitMessageFiles('git commit -F "/r/scratch/seat x/msg"')).toEqual(['/r/scratch/seat x/msg'])
  })
  test('every commit in the call, not only the first (PR #644 review)', () => {
    expect(commitMessageFiles('git commit -F /m/clean && git commit -F /m/other')).toEqual(['/m/clean', '/m/other'])
  })
  test('the attached -F form names the file (PR #644 round 2)', () => {
    expect(commitMessageFiles('git commit -F/tmp/msg')).toEqual(['/tmp/msg'])
    expect(commitMessageFiles('git commit -F"/r/scratch/msg"')).toEqual(['/r/scratch/msg'])
  })
  test('stdin and no file are empty', () => {
    expect(commitMessageFiles('git commit -F -')).toEqual([])
    expect(commitMessageFiles('git commit -m x')).toEqual([])
  })
})

describe('placeOf', () => {
  test('allow wins over the worktree, then the worktree, then outside', () => {
    expect(placeOf('/w/r/report.md', '/w', ['/w/r'])).toBe('allow')
    expect(placeOf('/w/src/a.ts', '/w', [])).toBe('worktree')
    expect(placeOf('/w', '/w', [])).toBe('worktree')
    expect(placeOf('/elsewhere/a', '/w', ['/s'])).toBe('outside')
  })
  test('a sibling that shares the prefix is outside', () => {
    expect(placeOf('/w2/a', '/w', [])).toBe('outside')
  })
})

describe('decide', () => {
  test('implementer: common rules deny, commit and push allow', () => {
    expect(decide('implementer', { kind: 'bash', rules: ['merge'] })).toStartWith('seat-mods (implementer): no merges')
    expect(decide('implementer', { kind: 'bash', rules: ['commit', 'push', 'pr-create'] })).toBeUndefined()
  })
  test('every role: each common rule denies', () => {
    for (const role of ['implementer', 'verifier', 'reviewer'] as const)
      for (const rule of ['merge', 'force-push', 'branch-delete', 'no-verify', 'ai-trailer'] as const)
        expect(decide(role, { kind: 'bash', rules: [rule] })).toBeDefined()
  })
  test('verifier and reviewer: commit, push and pr create deny', () => {
    for (const role of ['verifier', 'reviewer'] as const)
      for (const rule of ['commit', 'push', 'pr-create'] as const)
        expect(decide(role, { kind: 'bash', rules: [rule] })).toBeDefined()
  })
  test('writes per role', () => {
    expect(decide('implementer', { kind: 'write', place: 'worktree' })).toBeUndefined()
    expect(decide('verifier', { kind: 'write', place: 'worktree' })).toBeUndefined()
    expect(decide('reviewer', { kind: 'write', place: 'worktree' })).toContain('no edits in the worktree')
    for (const role of ['implementer', 'verifier', 'reviewer'] as const) {
      expect(decide(role, { kind: 'write', place: 'allow' })).toBeUndefined()
      expect(decide(role, { kind: 'write', place: 'outside' })).toContain('SEAT_MODS_ALLOW')
    }
  })
  // #844: each deny says where a seat can go instead, so a scratch write or cleanup costs one turn, not several.
  test('an outside write names the SEAT_MODS_ALLOW folders when it has them', () => {
    const deny = decide('implementer', { kind: 'write', place: 'outside', allow: ['/s/a', '/s/b'] })
    expect(deny).toContain('no writes outside')
    expect(deny).toContain('go in /s/a, /s/b.')
    expect(decide('implementer', { kind: 'write', place: 'outside' })).not.toContain('go in')
    expect(decide('implementer', { kind: 'write', place: 'allow', allow: ['/s/a'] })).toBeUndefined()
  })
  // Batch 5: /tmp and $TMPDIR are writable places for every guarded role, so the texts that say where a write or an rm may go name them.
  test('the outside-write and outside-rm texts name the scratch places beside the worktree and SEAT_MODS_ALLOW', () => {
    for (const role of ['implementer', 'verifier', 'reviewer'] as const) {
      const write = decide(role, { kind: 'write', place: 'outside' })
      for (const place of ['the worktree', '/tmp', '$TMPDIR', 'the SEAT_MODS_ALLOW directories']) expect(write).toContain(place)
      const rm = decide(role, { kind: 'bash', rules: [], removals: [removalOf('/etc/x', '/w', ['/s'], false)] })
      for (const place of ['the worktree unless this seat reviews', '/tmp', '$TMPDIR', 'the SEAT_MODS_ALLOW directories', 'roots or ancestors']) expect(rm).toContain(place)
    }
  })
  test('the unread-operand advice says what the guard reads: a plain NAME=value just before, a cd it can follow', () => {
    const unread = decide('implementer', { kind: 'bash', rules: [], removals: [UNREAD] })
    expect(unread).toContain('a $VAR no plain NAME=value just before gave')
    expect(unread).toContain('a relative path after a cd it cannot follow')
    expect(unread).not.toContain('the guard does not read $VAR')
  })
  test('an rm operand the guard cannot read says to spell it out; a placed one outside keeps its text', () => {
    const unread = decide('verifier', { kind: 'bash', rules: [], removals: [UNREAD] })
    expect(unread).toContain('no rm with an operand the guard cannot resolve')
    expect(unread).toContain('spell its path out literally')
    const outside = decide('verifier', { kind: 'bash', rules: [], removals: [removalOf('/etc/x', '/w', ['/s'], false)] })
    expect(outside).toContain('no rm outside writable places')
    expect(outside).not.toContain('literally')
    expect(decide('verifier', { kind: 'bash', rules: [], removals: [removalOf('/s/x', '/w', ['/s'], false)] })).toBeUndefined()
    // a target the glue could not place (a link's `..`, an omp URL cwd) is outside, not unread
    expect(removalOf(undefined, '/w', ['/s'], false).unresolved).toBeUndefined()
  })
  test('the deny text has the spec shape', () => {
    expect(decide('verifier', { kind: 'bash', rules: ['push'] }))
      .toBe('seat-mods (verifier): no git push — this seat may not run this command; report it instead.')
  })
  test('invalidText names the value and the roles', () => {
    expect(invalidText('impl')).toContain('"impl"')
    expect(invalidText('impl')).toContain('implementer, verifier, reviewer')
    expect(invalidText('impl')).toContain('orchestrator, coordinator')
  })
})

// Literal expectations distinguish quote handling and prefix placement from the
// resolver: these are inputs to the rail, not a second shell implementation.
describe('rm operand parsing', () => {
  test('only rm command segments produce targets', async () => {
    expect(rmTargets('echo "rm /var/x"; rm /w/x')).toEqual([{ path: '/w/x', glob: false }])
    expect(rmTargets("cat <<'EOF'\nrm /var/x\nEOF")).toEqual([])
    expect(rmTargets('git commit -m "rm -rf /var"')).toEqual([])
    expect(rmTargets('A=1 sudo env command /bin/rm -rf /w/build')).toEqual([{ path: '/w/build', glob: false }])
  })
  test('single quotes and escaped expansions are literal; active expansions are unknown', async () => {
    expect(rmTargets("rm '/w/$X' /w/\\$X")).toEqual([
      { path: '/w/$X', glob: false }, { path: '/w/$X', glob: false },
    ])
    for (const command of ['rm "$OLDPWD"', 'rm /w/"${X}"', 'rm "$(pwd)"', 'rm ~someone/x'])
      expect(rmTargets(command)).toEqual([{ path: undefined, glob: false }])
    expect(rmTargets("rm '~/x'")).toEqual([{ path: './~/x', glob: false }])
    expect(rmTargets('rm ~/x')).toEqual([{ path: '~/x', glob: false }])
  })
  test('glob directory is the directory of the literal prefix; quoted patterns stay literal', async () => {
    expect(rmTargets('rm /tmp/tmp.* build/*.o b*/x *.log /a? /[ab]')).toEqual([
      { path: '/tmp', glob: true }, { path: 'build', glob: true },
      { path: '.', glob: true }, { path: '.', glob: true },
      { path: '/', glob: true }, { path: '/', glob: true },
    ])
    expect(rmTargets("rm '/w/*.o' /w/\\*.o")).toEqual([
      { path: '/w/*.o', glob: false }, { path: '/w/*.o', glob: false },
    ])
  })
  test('options stop at --, even for a quoted delimiter', async () => {
    expect(rmTargets('rm -rf -- -file -')).toEqual([
      { path: '-file', glob: false }, { path: '-', glob: false },
    ])
    expect(rmTargets('rm "--" -file')).toEqual([{ path: '-file', glob: false }])
    expect(rmTargets('rm -rf')).toEqual([])
  })
  test('earlier directory changes poison only relative operands, including after --', async () => {
    for (const change of ['cd -', 'cd "$D"', 'pushd /var', 'popd', 'builtin cd /var'])
      expect(rmTargets(`${change}; rm -- -file /w/x ~/x`)).toEqual([
        { path: undefined, glob: false }, { path: '/w/x', glob: false }, { path: '~/x', glob: false },
      ])
    // batch 5: a literal cd resolves the relative operand instead, beside its failed-cd reading (Ruling 21)
    expect(rmTargets('cd /var; rm -- -file /w/x ~/x')).toEqual([
      { path: '-file', glob: false }, { path: '/var/-file', glob: false }, { path: '/w/x', glob: false }, { path: '~/x', glob: false },
    ])
    expect(rmTargets('rm x; cd /var')).toEqual([{ path: 'x', glob: false }])
  })
  test('malformed words fail closed beside valid quoted words', async () => {
    for (const command of ['rm "unterminated', 'rm dangling\\'])
      expect(rmTargets(command)).toEqual([{ path: undefined, glob: false }])
    expect(rmTargets('rm "a b"')).toEqual([{ path: 'a b', glob: false }])
  })
})

describe('fix1 expansion guard', () => {
  test('F6 self-reference fails explicitly, ordinary markers still expand', () => {
    expect(() => rmTargets('rm "\u00000\u0000"')).toThrow('unresolvable shell marker')
    expect(rmTargets('rm "/reports/x"')).toEqual([{ path: '/reports/x', glob: false }])
  })
})

describe('fix2 shared shell reader and root placement', () => {
  test('G2 herestring leaves following git commands visible beside a real heredoc body', () => {
    expect(bashRules('cat <<< x\ngit push --force')).toContain('force-push')
    expect(bashRules("cat <<'EOF'\ngit push --force\nEOF")).toEqual([])
  })
  test('G3 path-qualified wrapper uses the same command matching as a bare wrapper', () => {
    expect(bashRules('/usr/bin/sudo git push --force')).toContain('force-push')
    expect(bashRules('sudo git push --force')).toContain('force-push')
    expect(bashRules('/usr/bin/env git status')).toEqual([])
  })
  test('G4 root contains absolute descendants, not relative paths', () => {
    expect(placeOf('/tmp/x', '/', [])).toBe('worktree')
    expect(placeOf('/tmp/x', '/w', [])).toBe('outside')
    expect(placeOf('tmp/x', '/', [])).toBe('outside')
    expect(placeOf('/tmp/x', '/w', ['/'])).toBe('allow')
  })
})

// 0.3.1: the existing rails share rm's head-word walk, with safe commands beside them.
describe('reserved heads across Bash rails (#701)', () => {
  const cases: Array<[string, string, string]> = [
    ['if git push --force; then :; fi', 'force-push', 'if git status; then :; fi'],
    ['! git push --force', 'force-push', '! git diff --quiet'],
    ['{ git push --force; }', 'force-push', '{ git log -1; }'],
    ['if true; then git push -f; fi', 'force-push', 'if true; then git status; fi'],
    ['while true; do git merge x; done', 'merge', 'while read l; do echo "$l"; done'],
    ['! gh pr merge 1', 'merge', '! gh pr view 1'],
  ]
  for (const [command, rule, control] of cases) {
    test(`${command}: rail beside allowed control`, () => {
      expect(bashRules(command)).toContain(rule)
      expect(bashRules(control)).toEqual([])
    })
  }
  for (const prefix of ['if', 'then', 'elif', 'else', 'do', 'while', 'until', '!', '{', '(', 'time', 'builtin']) {
    // Some fragments are not complete Bash programs. time and ( are existing
    // wrapper/splitter controls; those rows do not prove HEAD_WORDS coverage.
    for (const [command, expected, control] of [
      ['git branch -D b', ['branch-delete'], 'git branch -d b'],
      ['git status --no-verify', ['no-verify'], 'git status'],
      ['gh pr create', ['pr-create'], 'gh pr view 1'],
      ['git commit -m x', ['commit'], 'git log -1'],
      ['git push', ['push'], 'git status'],
      ['git merge x', ['merge'], 'git diff --quiet'],
      ['git push -f', ['push', 'force-push'], 'git status'],
    ] as const) {
      test(`${prefix} ${command}: ${['time', '('].includes(prefix) ? 'wrapper/splitter control' : 'head recognition'} beside allowed control`, () => {
        expect(bashRules(`${prefix} ${command}`)).toEqual([...expected])
        expect(bashRules(`${prefix} ${control}`)).toEqual([])
      })
    }
  }
  test('plain push counts only as push; mentions remain text', () => {
    expect(bashRules('if git push; then :; fi')).toEqual(['push'])
    expect(bashRules('echo if git push --force')).toEqual([])
  })
  test('commit files follow the head walk; a non-commit mention has no file', () => {
    expect(commitMessageFiles('if git commit -F /w/msg-trailer.txt; then :; fi')).toEqual(['/w/msg-trailer.txt'])
    expect(commitMessageFiles('echo if git commit -F /w/msg-trailer.txt')).toEqual([])
  })
})

describe('rm heredoc input (#702 item 1)', () => {
  for (const input of ['<<EOF\ny\nEOF', '<<-EOF\n\ty\n\tEOF', "<<'EOF'\ny\nEOF"]) {
    test(`${input.split('\n')[0]} leaves only the operand, including when attached`, () => {
      expect(rmTargets(`rm -i /reports/x ${input}`)).toEqual([{ path: '/reports/x', glob: false }])
      expect(rmTargets(`rm -i /var/x ${input}`)).toEqual([{ path: '/var/x', glob: false }])
      expect(rmTargets(`rm -i /reports/x${input}`)).toEqual([{ path: '/reports/x', glob: false }])
      expect(rmTargets(`rm -i /var/x${input}`)).toEqual([{ path: '/var/x', glob: false }])
    })
  }
  test('quoted and escaped << words stay operands beside a real heredoc', () => {
    expect(rmTargets("rm '/reports/<<EOF'")).toEqual([{ path: '/reports/<<EOF', glob: false }])
    expect(rmTargets('rm /reports/\\<\\<EOF')).toEqual([{ path: '/reports/<<EOF', glob: false }])
    expect(rmTargets("rm /reports/x '<<EOF'")).toEqual([
      { path: '/reports/x', glob: false }, { path: '<<EOF', glob: false },
    ])
    expect(rmTargets('rm /reports/x <<EOF\ny\nEOF')).toEqual([{ path: '/reports/x', glob: false }])
  })
})

// Fix task 1: Bash syntax belongs to raw heads, not basenames or program argv.
describe('ordinary programs named like head words', () => {
  for (const prefix of ['/fixtures/if', '/fixtures/do', 'A=1 if', 'A=1 do', 'env if', '/usr/bin/env do', 'command if', 'exec if', 'nohup if', 'A=1 time if', 'time env if', 'if A=1 if', 'if env if', '"if"', '\\if', 'builtin if', 'A=1 builtin if']) {
    for (const [payload, rule] of [
      ['git push --force', 'force-push'], ['git merge x', 'merge'],
      ['git branch -D b', 'branch-delete'], ['git status --no-verify', 'no-verify'],
      ['gh pr create', 'pr-create'], ['git commit -m x', 'commit'], ['git push', 'push'],
    ]) {
      test(`${prefix} ${payload}: program argv allowed beside bare head rail`, () => {
        const bare = prefix.endsWith('do') ? `while true; do ${payload}; break; done` : `if ${payload}; then :; fi`
        expect(bashRules(bare)).toContain(rule)
        expect(bashRules(`${prefix} ${payload}`)).toEqual([])
      })
    }
    test(`${prefix}: commit file and rm argv stay text beside bare heads`, () => {
      const commit = prefix.endsWith('do') ? 'while true; do git commit -F /w/msg-trailer.txt; break; done' : 'if git commit -F /w/msg-trailer.txt; then :; fi'
      const remove = prefix.endsWith('do') ? 'while true; do rm /var/x; break; done' : 'if rm /var/x; then :; fi'
      expect(commitMessageFiles(commit)).toEqual(['/w/msg-trailer.txt'])
      expect(commitMessageFiles(`${prefix} git commit -F /w/msg-trailer.txt`)).toEqual([])
      expect(rmTargets(remove)).toEqual([{ path: '/var/x', glob: false }])
      expect(rmTargets(`${prefix} rm /var/x`)).toEqual([])
    })
  }
  test('builtin still invokes cd through assignments and the command builtin', () => {
    for (const prefix of ['builtin', 'A=1 builtin', 'command builtin', 'builtin builtin', 'time builtin']) {
      expect(rmTargets(`${prefix} cd /var; rm x`)).toEqual([{ path: undefined, glob: false }])
      expect(rmTargets(`${prefix} cd /var; rm /reports/x`)).toEqual([{ path: '/reports/x', glob: false }])
    }
  })
})

describe('rm heredoc fd and opener provenance', () => {
  test('fd 2 is shell input; an operand ending in 2 stays an operand', () => {
    expect(rmTargets('rm -i /reports/x 2<<EOF\ny\nEOF')).toEqual([{ path: '/reports/x', glob: false }])
    expect(rmTargets('rm -i /var/x 2<<EOF\ny\nEOF')).toEqual([{ path: '/var/x', glob: false }])
    expect(rmTargets('rm -i /reports/x2<<EOF\ny\nEOF')).toEqual([{ path: '/reports/x2', glob: false }])
    expect(rmTargets("rm -i /reports/x '2'<<EOF\ny\nEOF")).toEqual([{ path: '/reports/x', glob: false }, { path: '2', glob: false }])
  })
})

// #723: a lone `&` is Bash's background list separator. Without it the whole line
// read as one command with the first head, so every rail after the `&` was
// invisible — fail-open. `&&` and the redirections that carry `&` are not
// boundaries; the `&` of a `|&` pipe is.
describe('a lone & is a command boundary (#723)', () => {
  test('a command behind a lone & meets its rails, spaced or glued', () => {
    expect(bashRules('true & git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
    expect(bashRules('true &git push origin main')).toContain('push')
    expect(bashRules('true& git push origin main')).toContain('push')
    expect(bashRules('true & gh pr merge 12')).toContain('merge')
  })
  test('control: && keeps its meaning beside the split', () => {
    expect(bashRules('git add f && git push origin b')).toContain('push')
    expect(bashRules('git log --oneline && git status')).toEqual([])
  })
  test('the trailer check reads the commit behind a lone &, not the line before it', () => {
    expect(bashRules('echo & git commit -m "x\n\nCo-Authored-By: a"')).toContain('ai-trailer')
    expect(bashRules('echo & git commit -m "x"')).toEqual(['commit'])
  })
  test('the commit-file reader sees the commit behind a lone &', () => {
    expect(commitMessageFiles('true & git status')).toEqual([])
    expect(commitMessageFiles('true & git commit -F /w/msg-trailer.txt')).toEqual(['/w/msg-trailer.txt'])
  })
  test('the & of a |& pipe splits too, and the piping command keeps its rules', () => {
    expect(bashRules('git push origin main |& cat')).toEqual(['push'])
    expect(bashRules('echo a |& git push --force')).toContain('force-push')
  })
  test('control: redirections carry & without splitting it', () => {
    expect(bashRules('git commit -m m 2>&1')).toEqual(['commit'])
    expect(bashRules('git push origin main >&2')).toEqual(['push'])
    expect(bashRules('git push origin main &>/dev/null')).toEqual(['push'])
    expect(bashRules('git push origin main &>>/dev/null')).toEqual(['push'])
    expect(bashRules('git push origin main <&0')).toEqual(['push'])
    expect(bashRules('git push origin main >&-')).toEqual(['push'])
    // The flag after the redirection stays with its command: this row dies if a
    // lookaround is dropped (review R4).
    expect(bashRules('git push origin main 2>&1 --force')).toContain('force-push')
  })
  test('control: a trailing & leaves the line to its one command', () => {
    expect(bashRules('git commit -m m &')).toEqual(['commit'])
    expect(bashRules('git push origin main &')).toEqual(['push'])
  })
})

// #723 review R1/C1/C2, round 3: an `&` inside an unquoted `${…}` or `$[…]` is
// literal in Bash — the word carries it — so only that `&` stops being a boundary;
// every other character (`(`, `)`, `;`, `|`, newline) keeps its COMMANDS meaning,
// and the `&` of a `$(…)` nested in an expansion is a real separator and keeps
// splitting. seat-mods-local; molt's gate keeps the raw split by ruling.
describe('an & inside an unquoted expansion is not a boundary (#723 review R1)', () => {
  test('an assignment-prefixed expansion leaves the command behind it reachable', () => {
    expect(bashRules('X=${x/a&b/c} git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
    expect(bashRules('X=$[2&3] git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
    expect(bashRules('X=${x/a&b/c} gh pr merge 12')).toContain('merge')
  })
  test('a nested expansion is one word, including a & after its close', () => {
    expect(bashRules('X=${a:-${b/&/c}} git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
    // The nesting pin (review RR1): with the nested `${` untracked, the first `}`
    // closes the outer word and this `&` splits, junk-heading the follower.
    expect(bashRules('X=${a:-${b/&/c}&d} git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
  })
  test('a nested command substitution stays executable (review C1)', () => {
    expect(bashRules('echo ${x:-$(git push --force)}')).toEqual(expect.arrayContaining(['push', 'force-push']))
    expect(bashRules('echo ${x:-$(git status)}')).toEqual([])
  })
  test('the & of a nested substitution still splits (review C1/P6)', () => {
    expect(bashRules('echo ${x:-$(true & git push --force)}')).toEqual(expect.arrayContaining(['push', 'force-push']))
    expect(bashRules('echo ${x:-$(true & git status)}')).toEqual([])
  })
  test('$$ is a complete token: ${ after it opens, the { after a bare $$ stays literal (review C2)', () => {
    expect(bashRules('X=$$${x/a&b/c} git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
    expect(bashRules('X=$${x} git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
    // The 0.3.1 reading of the third row splits at the expansion's `&` and reads no rule,
    // while its raw separator reads the rules; the union keeps the tag's reading, the only
    // denies it adds being the 0.3.1 reading's own (round 4, the structural fix).
    expect(bashRules('X=$${x/a&b/c} git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
  })
  test('the union reads the 0.3.1 spelling too: a backtick } cannot sever the tail (review RR3-1)', () => {
    expect(bashRules('git push ${x:-`echo }` & echo hi} --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
    expect(bashRules('git push origin ${x:-`echo }` & hi} :refs/heads/main')).toEqual(expect.arrayContaining(['push', 'branch-delete']))
  })
  test('the zone-level && and redirection guards stay pinned (review RR3-3)', () => {
    expect(bashRules('X=${x/a&&b/c} git push --force')).toEqual([])
    expect(bashRules('X=${x/a>&b/c} git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
  })
  test('an escaped $ is text, and the & behind it splits as Bash splits it', () => {
    expect(bashRules('\\${x/a&b/c} git push --force')).toEqual([])
  })
  test('an unterminated expansion masks nothing: the split stays (fail closed)', () => {
    expect(bashRules('echo ${x & git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
  })
  test('a flag and a message file beside the expansion stay with their command', () => {
    expect(bashRules('git push ${x/a&b/c} --force')).toContain('force-push')
    expect(commitMessageFiles('git commit -F ${x/a&b/c}')).toEqual(['${x/a&b/c}'])
  })
  test('control: an expansion without a boundary & reads as before', () => {
    expect(bashRules('git push ${x/a&b/c} origin main')).toEqual(['push'])
    expect(bashRules('echo ${x//&/y}')).toEqual([])
    expect(bashRules('printf x ${x/a/& git push --force }')).toEqual([])
  })
  test('control: the & beside an expansion still splits', () => {
    expect(bashRules('echo ${x//&/y} & git push --force')).toEqual(expect.arrayContaining(['push', 'force-push']))
  })
})


// RR3/round 4 structural pin: the union guarantee, row by row, over the round-3
// verifier's own matrix exports (scratch/s2-verifier-3, tag side; their msgFileText
// travels with each row). The rows below are every matrix row whose seat-mods-v0.3.1
// reading found a rule or a -F file; the other 311 rows read nothing
// there, which every head reading contains trivially. Every rule and file the 0.3.1
// reading found must appear in the head's reading of that row — the rails can miss
// nothing the tag caught (#723 round 4).
const TAG_SUPERSET_ROWS = [
  '["true &\\ngit push origin main","",["push"],[]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true &\\ngit push --force origin main","",["push","force-push"],[]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true &\\ngit merge feature","",["merge"],[]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true &\\ngh pr merge 12","",["merge"],[]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true &\\ngit commit -m \\"x\\n\\nCo-Authored-By: a\\"","",["commit","ai-trailer"],[]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true &\\ngit commit -F /w/msg-trailer.txt","fix\\n\\nCo-Authored-By: someone <x@y>\\n",["commit","ai-trailer"],["/w/msg-trailer.txt"]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true &\\ngit commit --no-verify -m m","",["no-verify","commit"],[]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true &\\ngit branch -D feature","",["branch-delete"],[]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true &\\ngit push --delete origin b","",["push","branch-delete"],[]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true &\\ngit commit -m m","",["commit"],[]]',
  '["true &\\ngit commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["true & ( git push origin main )","",["push"],[]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["true & ( git push --force origin main )","",["push","force-push"],[]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["true & ( git merge feature )","",["merge"],[]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["true & ( gh pr merge 12 )","",["merge"],[]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["true & ( git commit -m \\"x\\n\\nCo-Authored-By: a\\" )","",["commit","ai-trailer"],[]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["true & ( git commit -F /w/msg-trailer.txt )","fix\\n\\nCo-Authored-By: someone <x@y>\\n",["commit","ai-trailer"],["/w/msg-trailer.txt"]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["true & ( git commit --no-verify -m m )","",["no-verify","commit"],[]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["true & ( git branch -D feature )","",["branch-delete"],[]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["true & ( git push --delete origin b )","",["push","branch-delete"],[]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["true & ( git commit -m m )","",["commit"],[]]',
  '["true & ( git commit -F /w/msg.txt )","",["commit"],["/w/msg.txt"]]',
  '["git push origin main & git merge x","",["push"],[]]',
  '["git status & git commit --no-verify -m m","",["no-verify"],[]]',
  '["git commit -m m 2>&1","",["commit"],[]]',
  '["git push origin main >&2","",["push"],[]]',
  '["git push origin main >& 2","",["push"],[]]',
  '["git push origin main &>","",["push"],[]]',
  '["git push origin main &>>","",["push"],[]]',
  '["git push origin main &>/dev/null","",["push"],[]]',
  '["git push origin main &> /dev/null","",["push"],[]]',
  '["git push origin main &>>/dev/null","",["push"],[]]',
  '["git push origin main <&0","",["push"],[]]',
  '["git push origin main >&-","",["push"],[]]',
  '["git push origin main 2>&-","",["push"],[]]',
  '["git commit -m \\"x\\n\\nCo-Authored-By: a\\" 2>&1","",["commit","ai-trailer"],[]]',
  '["git push origin main 2 >&1","",["push"],[]]',
  '["git push origin main > /dev/null 2>&1","",["push"],[]]',
  '["git commit -m m 2>&1 &","",["commit"],[]]',
  '["git commit -m m 2>&1 && git push origin main","",["commit","push"],[]]',
  '["git push origin main 2>&1 | tail -1","",["push"],[]]',
  '["git add f && git push --force","",["push","force-push"],[]]',
  '["git add f&&git push origin main","",["push"],[]]',
  '["git commit -m m &","",["commit"],[]]',
  '["git push origin main &","",["push"],[]]',
  '["git commit -m \\"a & b\\"","",["commit"],[]]',
  '["git commit -m \'a & b\'","",["commit"],[]]',
  '["git commit -m \'x & git push --force\'","",["commit"],[]]',
  '["git commit -m \\"x && y\\"","",["commit"],[]]',
  '["git commit -m m <<\'EOF\'\\nbody & more\\nEOF","",["commit"],[]]',
  '["git push origin main # & push & force","",["push"],[]]',
  '["git push origin main |& cat","",["push"],[]]',
  '["git add f\\ngit push origin main","",["push"],[]]',
  '["FOO=1 git push origin main &","",["push"],[]]',
  '["env git push origin main","",["push"],[]]',
  '["git push origin main","",["push"],[]]',
  '["git merge x 2>&1","",["merge"],[]]',
  '["gh pr merge 12 2>&1","",["merge"],[]]',
  '["git branch -D x 2>&1","",["branch-delete"],[]]',
  '["git commit -F /w/msg.txt 2>&1","",["commit"],["/w/msg.txt"]]',
  '["git commit -F /w/msg.txt &","",["commit"],["/w/msg.txt"]]',
  '["git commit -m m -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["git commit --file=/w/msg2.txt","",["commit"],["/w/msg2.txt"]]',
  '["git commit -F/w/msg3.txt","",["commit"],["/w/msg3.txt"]]',
  '["X=${x/a&b/c} git push --force","",["push","force-push"],[]]',
  '["X=$[2&3] git push --force","",["push","force-push"],[]]',
  '["X=${x/a&b/c} gh pr merge 12","",["merge"],[]]',
  '["X=${a:-${b/&/c}} git push --force","",["push","force-push"],[]]',
  '["git push ${x/a&b/c} --force","",["push","force-push"],[]]',
  '["git push origin main ${x/a&b/c}","",["push"],[]]',
  '["git push origin main $[2&3]","",["push"],[]]',
  '["X=${x/[a&b]/c} git push --force","",["push","force-push"],[]]',
  '["X=$[a[1]&2] git push --force","",["push","force-push"],[]]',
  '["X=${x/a&b/c} git commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["X=${x/a&b/c} git commit -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["git commit -F ${x/a&b/c}","",["commit"],["${x/a&b/c}"]]',
  '["git commit -F ${d}/msg.txt","",["commit"],["${d}/msg.txt"]]',
  '["git commit ${x/a&b/c} -F /w/msg.txt","",["commit"],["/w/msg.txt"]]',
  '["git commit -m ${x:-a\\nCo-Authored-By: b}","",["commit"],[]]',
  '["X=${x/a&b/c} git commit -m \\"x\\n\\nCo-Authored-By: a\\"","",["commit","ai-trailer"],[]]',
  '["git push ${x/a&b/c} origin main","",["push"],[]]',
  '["git commit -m ${x/a&b/c}","",["commit"],[]]',
  '["git commit -m \'${x&y}\'","",["commit"],[]]',
  '["git commit -m \\"a & ${x&y}\\"","",["commit"],[]]',
  '["git push origin main ${x} 2>&1","",["push"],[]]',
  '["${x} && git push --force","",["push","force-push"],[]]',
  '["X=${x/a&b/c git push --force","",["push","force-push"],[]]',
  '["X=$[2&3 git push --force","",["push","force-push"],[]]',
  '["X=${x/a}b&c/d} git push --force","",["push","force-push"],[]]',
  '["X=$[a]b&c]d git push --force","",["push","force-push"],[]]',
  '["echo ${x:-$(git push --force)}","",["push","force-push"],[]]',
  '["X=${x:-$(git push --force)}","",["push","force-push"],[]]',
  '["echo ${x:-$(git push --force>&2)}","",["push"],[]]',
  '["echo ${x:-$(true&&git push --force)}","",["push","force-push"],[]]',
  '["echo ${x:-$(git push --force) & git status}","",["push","force-push"],[]]',
  '["echo ${x:-$(X=${y/a&b/c} git push --force)}","",["push","force-push"],[]]',
  '["echo $(X=${y/a&b/c} git push --force)","",["push","force-push"],[]]',
  '["X=${x:-$[2&3]} git push --force","",["push","force-push"],[]]',
  '["X=$[${x:-2}&3] git push --force","",["push","force-push"],[]]',
  '["X=$[$[2&3]&1] git push --force","",["push","force-push"],[]]',
  '["X=$[arr[1]&2] git push --force","",["push","force-push"],[]]',
  '["X=$$${x/a&b/c} git push --force","",["push","force-push"],[]]',
  '["X=$$$(git push --force)","",["push","force-push"],[]]',
  '["X=$$$[2&3] git push --force","",["push","force-push"],[]]',
  '["X=$$& git push --force","",["push","force-push"],[]]',
  '["X=$${x} git push --force","",["push","force-push"],[]]',
  '["X=$${x/a&b/c} git push --force","",["push","force-push"],[]]',
  '["X=$$$${x&y} git push --force","",["push","force-push"],[]]',
  '["X=\\\\$${x/a&b/c} git push --force","",["push","force-push"],[]]',
  '["X=${x:-\'a&b\'} git push --force","",["push","force-push"],[]]',
  '["X=${x:-\\"a&b\\"} git push --force","",["push","force-push"],[]]',
  '["X=${x/a\\"b&c\\"d/e} git push --force","",["push","force-push"],[]]',
  '["X=${x:-\\"a&b} git push --force","",["push","force-push"],[]]',
  '["X=${x:-\'a&b} git push --force","",["push","force-push"],[]]',
  '["X=\\"${x/a&b/c}\\" git push --force","",["push","force-push"],[]]',
  '["git push --force ${x/a&b/c","",["push","force-push"],[]]',
  '["git push --force $[2&3","",["push","force-push"],[]]',
  '["X=${a:-${b/&/c git push --force","",["push","force-push"],[]]',
  '["X=${x/[}a]&b/c} git push --force","",["push","force-push"],[]]',
  '["X=${x/a]b&c/d} git push --force","",["push","force-push"],[]]',
  '["X=$[a]&2] git push --force","",["push","force-push"],[]]',
  '["X=${x/a&>b/c} git push --force","",["push","force-push"],[]]',
  '["X=${x/a&}&b git push --force","",["push","force-push"],[]]',
  '["echo ${x/a&b/c}\\ngit push --force","",["push","force-push"],[]]',
  '["X=$(echo a\\ngit push --force)","",["push","force-push"],[]]',
  '["git commit -m ${x:-a&b\\n\\nCo-Authored-By: c}","",["commit"],[]]',
  '["git commit -F ${x/a&b/c}/msg.txt","",["commit"],["${x/a&b/c}/msg.txt"]]',
  '["git commit -F ${x/a&b/c}","",["commit"],["${x/a&b/c}"]]',
  '["X=${x/a&b/c} git commit -m \\"x\\n\\nCo-Authored-By: a\\"","",["commit","ai-trailer"],[]]',
  '["git push origin main 2>&1 --force","",["push","force-push"],[]]',
  '["git push origin main >&2","",["push"],[]]',
  '["git push origin main &>/dev/null","",["push"],[]]',
  '["git push origin main <&0","",["push"],[]]',
  '["a && git push --force","",["push","force-push"],[]]',
  '["git commit -m m &","",["commit"],[]]',
  '["X=$((2&3)) git push --force","",["push","force-push"],[]]',
  '["git push $((2&3)) --force","",["push"],[]]',
].map(row => JSON.parse(row) as [string, string, string[], string[]])
const TAG_SUPERSET_VACUOUS = 311

test('head rules and -F files are a superset of the 0.3.1 reading, over the verifier matrix', () => {
  expect(TAG_SUPERSET_ROWS.length + TAG_SUPERSET_VACUOUS).toBe(466)
  const missing: string[] = []
  for (const [command, messageFileText, rules, files] of TAG_SUPERSET_ROWS) {
    for (const rule of rules)
      if (!(bashRules(command, messageFileText) as string[]).includes(rule)) missing.push(`rule ${rule} :: ${command}`)
    for (const file of files)
      if (!commitMessageFiles(command).includes(file)) missing.push(`file ${file} :: ${command}`)
  }
  expect(missing).toEqual([])
})

// Batch 5, C3 and C4 (#702 B2/B8, #724 A10): the command word is read as Bash reads it
// after quote removal, and a redirection never hides the word it touches.
describe('batch 5: command word', () => {
  test('an escaped command word runs the command it spells', () => {
    expect(bashRules('\\git push --force origin main')).toContain('force-push')
    expect(rmTargets('\\rm -rf /etc/x')).toEqual([{ path: '/etc/x', glob: false }])
    expect(bashRules('git push \\--force origin main')).toContain('force-push')
  })
  test('an escaped path character is the character Bash passes on', () => {
    // Every member of the dropped class, and a word that starts like a reserved word (`\do`).
    expect(commitMessageFiles('git commit -F \\/w\\/m\\_\\1\\.\\-\\a\\Z')).toEqual(['/w/m_1.-aZ'])
    expect(commitMessageFiles('git commit -F /w/\\dos\\fi.txt')).toEqual(['/w/dosfi.txt'])
    // A reserved word at the very end of the command is still not unescaped (the value keeps
    // its backslash, as every kept escape does; it shows the word was not read as syntax).
    expect(commitMessageFiles('git commit -F \\do')).toEqual(['\\do'])
    // control: a character outside the class keeps its escape, which the path then carries
    expect(commitMessageFiles('git commit -F /w/m\\*')).toEqual(['/w/m\\*'])
  })
  test('control: an escaped backslash is not an escaped command word', () => {
    expect(bashRules('\\\\git push --force origin main')).toEqual([])
    expect(bashRules('\\git status')).toEqual([])
  })
  test('control: an escaped reserved word is a program, not a head word', () => {
    for (const word of ['if', 'then', 'elif', 'else', 'do', 'while', 'until']) {
      expect(bashRules(`\\${word} git push --force`)).toEqual([])
      expect(bashRules(`${word} git push --force`)).toContain('force-push')
    }
  })
  test('an fd-variable redirection before the command does not hide it', () => {
    expect(rmTargets('{log}>/w/f rm -rf /etc/x')).toEqual([{ path: '/etc/x', glob: false }])
    expect(bashRules('{log}>/w/f git push --force')).toContain('force-push')
    expect(bashRules('2>/w/f git push --force')).toContain('force-push')
    expect(bashRules('&>/w/f git push --force')).toContain('force-push')
  })
  test('control: a brace word that is not an fd variable stays an ordinary word', () => {
    expect(bashRules('{log,x}>/w/f git push --force')).toEqual([])
  })
  test('a lone redirection operator takes the next word as its target, not as the command', () => {
    expect(bashRules('> /w/f git push --force')).toContain('force-push')
    expect(bashRules('2> /w/f git push --force')).toContain('force-push')
    expect(bashRules('git push origin main > --force')).toEqual(['push'])
    expect(bashRules('git push origin main >& --force')).toEqual(['push'])
    // control: only the target is dropped; the flag after it is still the push's
    expect(bashRules('git push origin main > /w/f --force')).toContain('force-push')
  })
  test('a redirection glued to a flag is cut off it', () => {
    for (const c of ['git push --force>&2', 'git push --force&>f', 'git push -f>/dev/null',
      'git push --force</dev/null', 'git push --force<&0', 'git push --force>>f', 'git push --force>a>b'])
      expect(bashRules(c)).toContain('force-push')
    expect(bashRules('git push --force> /w/f')).toContain('force-push')
    expect(bashRules('git push origin main --x> --force')).toEqual(['push'])
    expect(bashRules('git push origin main --force2>/dev/null')).toEqual(['push'])
  })
  test('control: the redirection words are not the command\'s arguments', () => {
    expect(bashRules('git push origin main 2>&1')).toEqual(['push'])
    expect(bashRules('git push origin main 2>&1 --force')).toContain('force-push')
    expect(bashRules('git commit -m "a\\b" 2>/dev/null')).toEqual(['commit'])
  })
  test('a path-qualified wrapper is skipped as its bare name', () => {
    expect(bashRules('./env git push --force origin main')).toContain('force-push')
    expect(bashRules('./env git status')).toEqual([])
  })
})

// Batch 5, C2 (#724 A3/A9/A11, #702 B3/B10/B10b/B11): heredocs read as Bash reads them —
// the opener line runs, a `<<` in arithmetic or a comment opens nothing, and the
// delimiter is its word after quote removal, found before any line is folded.
describe('batch 5: heredocs', () => {
  const RULED = 'git push --force origin main'
  // The 11 closing spellings of evidence row 702-B10: each closes at a line `EOF`.
  const CLOSES = ['\\EOF', 'E\\OF', '\\E\\O\\F', "E'OF'", 'E"OF"', "'E'OF", '"E"OF', 'E\\O"F"', "\\E'OF'"]
  test('C2a: the opener line after the delimiter word runs', () => {
    expect(bashRules(`cat <<EOF; ${RULED}\nbody\nEOF`)).toContain('force-push')
    expect(bashRules(`cat <<EOF & ${RULED}\nbody\nEOF`)).toContain('force-push')
    expect(bashRules(`cat <<EOF \\\n; ${RULED}\nbody\nEOF`)).toContain('force-push')
    // an escaped backslash ends the opener line, and its text joins nothing after the body
    expect(bashRules(`echo <<EOF x\\\\\nbody\nEOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`echo a\\\\\n${RULED}`)).toContain('force-push')
    // control: the body is still text
    expect(bashRules(`cat <<EOF; echo x\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`cat <<EOF \\\n> out\n${RULED}\nEOF`)).toEqual([])
  })
  test('C2a: the body marker stays in the opener\'s own segment for the trailer check', () => {
    expect(bashRules("git commit -F - <<'EOF' && echo done\nfix\n\nCo-Authored-By: a\nEOF")).toContain('ai-trailer')
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nfix\n\nCo-Authored-By: a\nEOF\n)\"")).toContain('ai-trailer')
    // control: a trailer-shaped body fed to another command is not the commit's message
    expect(bashRules("git commit -m x && cat <<'EOF'\nCo-Authored-By: a\nEOF")).toEqual(['commit'])
  })
  test('C2b: a << in arithmetic or in a comment opens no heredoc', () => {
    expect(bashRules(`echo $((1<<c))\n${RULED}`)).toContain('force-push')
    expect(bashRules(`echo "$((1<<c))"\n${RULED}`)).toContain('force-push')
    expect(bashRules(`(( a << b ))\n${RULED}`)).toContain('force-push')
    expect(bashRules(`# <<EOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`echo ok # <<EOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`cat <<EOF # <<X\nbody\nEOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`echo $(( (1) + (2) << c ))\n${RULED}`)).toContain('force-push')
    // a comment starts after an operator, a closed quote and a continued line; a body's quote is text
    expect(bashRules(`echo ok;# <<EOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`echo "a" # <<EOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`echo 'a' # <<EOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`echo ok \\\n# <<EOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`cat <<EOF\nit's\nEOF\n# <<X\n${RULED}`)).toContain('force-push')
    expect(rmTargets('# <<EOF\nrm -rf /etc/x')).toEqual([{ path: '/etc/x', glob: false }])
    expect(rmTargets('echo $((1<<c))\nrm -rf /etc/x')).toEqual([{ path: '/etc/x', glob: false }])
  })
  test('control: a heredoc after arithmetic, or after a # that starts no comment, still opens', () => {
    expect(bashRules(`(( a )) && cat <<EOF\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`echo $((1)) <<EOF\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`echo "#" <<EOF\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`echo "x #" <<EOF\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`echo 'x #' <<EOF\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`echo a#b <<EOF\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`echo \\ #b <<EOF\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`cat <<EOF # note\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`# note\ncat <<EOF\n${RULED}\nEOF`)).toEqual([])
    // `$((` in single quotes is text, and `((` inside a word starts no arithmetic
    expect(bashRules(`echo '$((' <<EOF\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`cat <((cat <<EOF\n${RULED}\nEOF\n))`)).toEqual([])
  })
  test('C2c: the delimiter is its word after quote removal', () => {
    for (const d of CLOSES) {
      expect(bashRules(`cat <<${d}\nbody\nEOF\n${RULED}`)).toContain('force-push')
      expect(rmTargets(`cat <<${d}\nbody\nEOF\nrm -f /etc/x`)).toEqual([{ path: '/etc/x', glob: false }])
      // control: what comes before the closing line is still body text
      expect(bashRules(`cat <<${d}\n${RULED}\nEOF`)).toEqual([])
    }
    expect(bashRules(`cat <<-\\EOF\n\tbody\n\tEOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`cat 2<<\\EOF\nbody\nEOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`cat <<E''OF\nbody\nEOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`cat <<"E\\$OF"\nbody\nE$OF\n${RULED}`)).toContain('force-push')
    // `<<-` strips the tabs of the joined line: this one closes at its second line
    expect(bashRules(`cat <<-EOF\n\t\\\n\tEOF\n${RULED}\nEOF`)).toContain('force-push')
    // An empty quoted delimiter closes at the first empty line.
    expect(bashRules(`cat <<''\nbody\n\n${RULED}`)).toContain('force-push')
    expect(bashRules(`cat <<''\n${RULED}\n\necho done`)).toEqual([])
  })
  test('C2c: E"O\\F" never closes at EOF; Bash\'s delimiter is EO\\F', () => {
    expect(bashRules(`cat <<E"O\\F"\nbody\nEOF\n${RULED}`)).not.toContain('force-push')
    // control: its own delimiter closes it
    expect(bashRules(`cat <<E"O\\F"\nbody\nEO\\F\n${RULED}`)).toContain('force-push')
  })
  test('B10b: a body line E does not close <<E\'OF\' early', () => {
    expect(bashRules(`cat <<E'OF'\nE\n${RULED}\nEOF`)).not.toContain('force-push')
  })
  test('B11: a quoted body line ending in a backslash is not folded into the closing line', () => {
    expect(rmTargets("cat <<'EOF'\ny\\\nEOF\nrm -f /var/x")).toEqual([{ path: '/var/x', glob: false }])
    expect(bashRules(`cat <<'EOF'\ny\\\nEOF\n${RULED}`)).toContain('force-push')
    // a quoted body keeps its lines, so git reads this trailer on a line of its own
    expect(bashRules("git commit -F - <<'EOF'\nfix\\\nCo-Authored-By: a\nEOF")).toContain('ai-trailer')
  })
  test('control: an unquoted body line ending in a backslash joins the next, as in Bash', () => {
    expect(bashRules(`cat <<EOF\ny\\\nEOF\n${RULED}`)).toEqual([])
    expect(bashRules(`cat <<EOF\ny\\\nEOF\nEOF\n${RULED}`)).toContain('force-push')
    expect(bashRules(`cat <<EOF\ny\\\\\nEOF\n${RULED}`)).toContain('force-push')
    expect(bashRules("git commit -F - <<EOF\nfix\\\nCo-Authored-By: a\nEOF")).toEqual(['commit'])
  })
  test('Review Focus 5: two heredocs on one line close in order', () => {
    expect(bashRules(`cat <<A <<'B'\na\nA\nb\nB\n${RULED}`)).toContain('force-push')
    expect(rmTargets("rm -i /reports/x <<A <<'B'\na\nA\nb\nB\nrm -rf /etc/x")).toEqual([
      { path: '/reports/x', glob: false }, { path: '/etc/x', glob: false },
    ])
    // control: the second body is text, and it starts after the first one's closing line
    expect(bashRules(`cat <<A <<'B'\na\nA\n${RULED}\nB`)).toEqual([])
    expect(bashRules(`cat <<A <<B\nB\nA\n${RULED}\nB`)).toEqual([])
  })
  test('control: the standard commit form stays a commit', () => {
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nfix: x\n\ngit merge and git push --force are words here\nEOF\n)\"")).toEqual(['commit'])
  })
})

// Task 2 review R1: the text after an unquoted opener is command text, so its quotes, and
// a comment's, must pair as Bash pairs them. A quote left unpaired there would pair across
// the body with a later one and hide the lines between.
describe('batch 5: quotes in a heredoc tail or a comment pair as in Bash', () => {
  const RULED = 'git push --force origin main'
  test('a quote in a # comment pairs with nothing', () => {
    expect(bashRules(`cat > notes.md <<'EOF' # don't expand\ntext\nEOF\ngit commit -m 'notes' && ${RULED}`)).toContain('force-push')
    expect(bashRules(`cat <<'EOF' # say "hi\ntext\nEOF\n${RULED} "x"`)).toContain('force-push')
    expect(bashRules(`echo hi # don't\n${RULED} 'x'`)).toContain('force-push')
    expect(bashRules(`git commit -m "$(cat <<EOF | grep "it's"\nit's\nEOF\n)" # don't\n${RULED} 'x'`)).toContain('force-push')
    expect(rmTargets("cat <<'EOF' # don't\ntext\nEOF\nrm -rf /etc/x '/etc/y'")).toEqual([
      { path: '/etc/x', glob: false }, { path: '/etc/y', glob: false },
    ])
    // control: the body is text, and the comment still runs nothing
    expect(bashRules(`cat > notes.md <<'EOF' # don't expand\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`cat <<'EOF' # say "hi\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`echo hi # don't ${RULED}`)).toEqual([])
  })
  test('a comment ends at its newline, even after a backslash', () => {
    expect(bashRules(`# x \\\n${RULED}`)).toContain('force-push')
    // control: outside a comment the backslash-newline still joins the lines
    expect(bashRules(`echo x \\\n${RULED}`)).toEqual([])
  })
  test('a quoted string in the tail that spans lines ends the opener line after it', () => {
    expect(bashRules(`cat <<EOF 'a\nb'\nbody\nEOF\n${RULED} 'x'`)).toContain('force-push')
    expect(bashRules(`cat <<EOF "a\nb"\nbody\nEOF\n${RULED} "x"`)).toContain('force-push')
    // so does a newline inside arithmetic
    expect(bashRules(`cat <<EOF $((1 +\n2)); ${RULED}\nbody\nEOF`)).toContain('force-push')
    expect(rmTargets("cat <<EOF 'a\nb'\nbody\nEOF\nrm -rf /etc/x '/etc/y'")).toEqual([
      { path: '/etc/x', glob: false }, { path: '/etc/y', glob: false },
    ])
    // control: the body starts after that line
    expect(bashRules(`cat <<EOF 'a\nb'\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`cat <<EOF "a\nb"\n${RULED}\nEOF`)).toEqual([])
  })
  test('an escaped quote or a $\'…\' string in the tail opens nothing past the line', () => {
    expect(bashRules(`cat <<EOF it\\'s\nbody\nEOF\n${RULED} 'x'`)).toContain('force-push')
    expect(bashRules(`cat <<EOF a\\"b\nbody\nEOF\n${RULED} "x"`)).toContain('force-push')
    expect(bashRules(`cat <<EOF $'it\\'s'\nbody\nEOF\n${RULED} 'x'`)).toContain('force-push')
    expect(bashRules(`echo it\\'s\n${RULED} 'x'`)).toContain('force-push')
    // control: the body is text, and a real string after an escape, or a $'…' string, still masks
    expect(bashRules(`cat <<EOF it\\'s\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules(`cat <<EOF $'it\\'s'\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules("echo \\' 'a ; git push --force'")).toEqual([])
    expect(bashRules("echo $'a\\' ; git push --force'")).toEqual([])
  })
  test('a quoted << after an unquoted opener is text', () => {
    expect(bashRules(`cat <<A "x <<B"\na\nA\nb\nB\n${RULED} "y"`)).toContain('force-push')
    expect(bashRules(`cat <<A "x <<B"\na\nA\n${RULED}\nB`)).toContain('force-push')
    // control: the first opener's body is text
    expect(bashRules(`cat <<A "x <<B"\n${RULED}\nA`)).toEqual([])
  })
  test('an opener inside "$(…)" keeps its line in the piece', () => {
    expect(bashRules(`git commit -m "$(cat <<EOF | grep "it's"\nit's\nEOF\n)" && ${RULED} 'x'`)).toContain('force-push')
    // control: the commit form with that line is still a commit
    expect(bashRules(`git commit -m "$(cat <<EOF | grep "it's"\nit's git merge\nEOF\n)"`)).toEqual(['commit'])
  })
})

// Task 2 review R2 (Rulings 13, 14): quotes nest inside `$(…)`, backticks and `${…}`, which
// the scan does not model, so an opener line holding one after the delimiter word keeps the
// 0.9.0 reading; `$$` is the PID, not the start of `$'…'`; a quoted `<<` with no such
// construct before it on its line is text.
describe('batch 5: an opener line holding a substitution reads as in 0.9.0', () => {
  const RULED = 'git push --force origin main'
  test('a substitution with an odd inner quote in the tail no longer hides the line after the body', () => {
    expect(bashRules(`cat <<EOF "$(echo "it's")"\nbody\nEOF\n${RULED} 'x'`)).toContain('force-push')
    expect(bashRules(`git commit -F - <<EOF --author="$(echo "it's")"\nmsg\nEOF\n${RULED} 'x'`)).toContain('force-push')
    expect(bashRules(`git commit -F - <<EOF -m "$(echo 'say "hi')"\nmsg\nEOF\n${RULED} 'x'`)).toContain('force-push')
    expect(bashRules(`cat <<EOF "\`echo "it's"\`"\nbody\nEOF\n${RULED} 'x'`)).toContain('force-push')
    expect(bashRules(`cat <<EOF "\${x:-"it's"}"\nbody\nEOF\n${RULED} 'x'`)).toContain('force-push')
    // control: the body is text
    expect(bashRules(`cat <<EOF "$(echo "it's")"\n${RULED}\nEOF`)).toEqual([])
  })
  test('a quoted body after such a tail is not read as commands', () => {
    expect(bashRules(`git commit -F - <<'EOF' --author="$(echo "Bob O'Neil")"\nfix: x\n\ngit push --force words\nEOF`)).toEqual(['commit'])
  })
  test('a heredoc opened inside a substitution in the tail does not take the first one\'s place', () => {
    expect(bashRules(`cat <<A $(cat <<B\nb\nB\n)\na\nA\n${RULED}`)).toContain('force-push')
    // control: the first heredoc's body is text
    expect(bashRules(`cat <<A $(cat <<B\nb\nB\n)\n${RULED}\nA`)).toEqual([])
  })
  test('control: a tail without a substitution is still command text', () => {
    expect(bashRules(`cat <<EOF; ${RULED}\nbody\nEOF`)).toContain('force-push')
    expect(bashRules(`cat <<EOF > "$out"; ${RULED}\nbody\nEOF`)).toContain('force-push')
    // a substitution before the opener is not in its tail
    expect(bashRules(`echo $(date); cat <<EOF; ${RULED}\nbody\nEOF`)).toContain('force-push')
  })
  test('$$ is the PID: the quote after it is a single quote, not $\'…\'', () => {
    expect(bashRules(`echo $$'a\\' ; ${RULED} ; echo 'b'`)).toContain('force-push')
    expect(bashRules(`cat <<EOF $$'a\\'\nbody\nEOF\n${RULED} 'x'`)).toContain('force-push')
    // control: the body is text, and a real $'…' string still masks
    expect(bashRules(`cat <<EOF $$'a\\'\n${RULED}\nEOF`)).toEqual([])
    expect(bashRules("echo $'a\\' ; git push --force'")).toEqual([])
  })
  test('a quoted << with no substitution before it on its line is text', () => {
    expect(bashRules(`grep -n "<<EOF" a.sh && ${RULED}\necho done`)).toContain('force-push')
    expect(bashRules(`echo "x <<EOF y"\n${RULED}\nEOF`)).toContain('force-push')
    expect(bashRules(`echo 'x <<EOF'\n${RULED}\nEOF`)).toContain('force-push')
    // a `$(` on an earlier line, closed before a newline outside quotes, does not count
    expect(bashRules(`echo $(date)\necho "x <<EOF y"\n${RULED}\nEOF`)).toContain('force-push')
    // control: after a `$(` on its line, even one opened on an earlier line, it opens a heredoc
    expect(bashRules("git commit -m \"$(\ncat <<'EOF'\nsay \"hi\ngit merge words\nEOF\n)\"")).toEqual(['commit'])
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nfix: x\n\ngit merge words\nEOF\n)\"")).toEqual(['commit'])
    // the commit form keeps its line in the piece, whatever quotes that line holds
    expect(bashRules("git commit -m \"$(cat <<'EOF' | tr -d '\"'\nfix: x\n\ngit merge words\nEOF\n)\"")).toEqual(['commit'])
  })
})

// Batch 5, C1 (#724 A1, A2): a `$(…)` or backtick span is a command of its own, read wherever
// Bash runs it (unquoted, in double quotes, in an unquoted heredoc body) and nowhere else.
describe('batch 5: substitutions', () => {
  const RULED = 'git push --force origin main'
  const nest = (n: number, inner: string) => 'echo ' + '$('.repeat(n) + inner + ')'.repeat(n)
  test('substitutionsOf: the command text of each span Bash runs', () => {
    expect(substitutionsOf('git commit -m "$(git push --force)"')).toEqual(['git push --force'])
    expect(substitutionsOf('git commit -m `git push --force`')).toEqual(['git push --force'])
    expect(substitutionsOf("echo '$(rm -rf /)'")).toEqual([])
    expect(substitutionsOf("cat <<'EOF'\n$(rm -rf /)\nEOF")).toEqual([])
    expect(substitutionsOf('cat <<EOF\n$(git push --force)\nEOF')).toEqual(['git push --force'])
    // a heredoc before a span on the same level is read too
    expect(substitutionsOf('cat <<EOF\n$(git push --force)\nEOF\necho $(date)')).toEqual(['git push --force', 'date'])
  })
  test('a nested span is listed after the span it sits in', () => {
    expect(substitutionsOf('echo "$(echo $(git push --force))"')).toEqual(['echo $(git push --force)', 'git push --force'])
    // inside backticks an escaped backtick opens the nested span
    expect(substitutionsOf('echo `echo \\`git push --force\\``')).toEqual(['echo `git push --force`', 'git push --force'])
  })
  test('control: a $\'…\' string, an escaped opener and a quoted body run nothing', () => {
    expect(substitutionsOf("echo $'$(git push --force)'")).toEqual([])
    expect(substitutionsOf("echo $'a\\' $(git push --force)'")).toEqual([])
    expect(substitutionsOf('echo \\$\\(git push\\) "\\$(git push)" \\`git push\\`')).toEqual([])
    expect(substitutionsOf("cat <<'EOF'\n`git push --force`\nEOF")).toEqual([])
    expect(substitutionsOf('cat <<EOF\n\\$(git push --force)\nEOF')).toEqual([])
    // the unquoted body's backtick runs, and a quote in the body is text
    expect(substitutionsOf('cat <<EOF\n`git push --force`\nEOF')).toEqual(['git push --force'])
    expect(substitutionsOf("cat <<EOF\nit's $(git push --force)\nEOF")).toEqual(['git push --force'])
    // `$$` is the PID: the quote after it is a single quote, closed by the next one
    expect(substitutionsOf("echo $$'a\\' $(git push --force)")).toEqual(['git push --force'])
  })
  test('a span ends at its own closing parenthesis, and # starts a comment only at a word start', () => {
    expect(substitutionsOf('echo "$( (true); git push --force )"')).toEqual([' (true); git push --force '])
    expect(substitutionsOf('echo "$(echo ${#x} a#b "c"#d)"')).toEqual(['echo ${#x} a#b "c"#d'])
    // `$((…); …)` read as arithmetic first: the spans found on that try are not kept
    expect(substitutionsOf('echo $(($(date)); git push --force)')).toEqual(['($(date)); git push --force', 'date'])
  })
  test('$((…)) is arithmetic, walked for the spans in it; $( (…) …) is a substitution', () => {
    expect(substitutionsOf('echo $((1 + 2))')).toEqual([])
    expect(substitutionsOf('echo $(( $(git push --force) + 1 ))')).toEqual(['git push --force'])
    expect(substitutionsOf('echo $((echo a); git push --force)')).toEqual(['(echo a); git push --force'])
    expect(bashRules('echo "$((echo a); git push --force)"')).toContain('force-push')
  })
  test('a # comment inside a double-quoted $(…) ends at its newline, quotes and all', () => {
    expect(substitutionsOf('git commit -m "$(echo a # it\'s )\n)"')).toEqual(['echo a # it\'s )\n'])
    // control: a comment outside any span runs nothing
    expect(substitutionsOf('echo ok # $(git push --force)')).toEqual([])
  })
  test('a ruled command in a substitution is refused', () => {
    expect(bashRules('git commit -m "$(git push --force origin main)"')).toContain('force-push')
    expect(bashRules('git commit -m `git push --force origin main`')).toContain('force-push')
    expect(rmTargets('git commit -m "$(rm -rf /etc/x)"')).toEqual([{ path: '/etc/x', glob: false }])
    expect(bashRules('cat <<EOF\n$(git push --force origin main)\nEOF')).toContain('force-push')
    expect(commitMessageFiles('echo "`git commit -F /w/msg`"')).toEqual(['/w/msg'])
    // control
    expect(commitMessageFiles("echo '$(git commit -F /w/msg)'")).toEqual([])
  })
  test('a substitution nested more than 8 deep is refused (Ruling 3)', () => {
    const deep = 'echo ' + '$('.repeat(9) + 'true' + ')'.repeat(9)
    expect(substitutionsOf(deep)).toContain(SUBSTITUTION_TOO_DEEP)
    expect(bashRules(deep)).toContain('force-push')
    expect(rmTargets(deep)).toContainEqual({ path: undefined, glob: false })
    // control: 8 deep is read level by level
    expect(substitutionsOf(nest(8, 'true'))).toHaveLength(8)
    expect(substitutionsOf(nest(8, 'true'))).not.toContain(SUBSTITUTION_TOO_DEEP)
    expect(bashRules(nest(8, 'true'))).toEqual([])
    expect(rmTargets(nest(8, 'true'))).toEqual([])
    expect(bashRules(nest(8, RULED))).toContain('force-push')
    // far deeper than the walk follows: still read as too deep, with no stack overflow. 10,000 levels
    // overflow any reader that spends five or more frames a level (bun's stack holds about 45,000
    // simple frames); 20,000 took up to 5.2 s on a CI runner, past the kit's fixed 5 s test timeout.
    const deeper = 'echo "' + '$('.repeat(10000) + 'true' + ')'.repeat(10000) + '"'
    expect(bashRules(deeper)).toContain('force-push')
  })
  test('Ruling 2: a relative rm operand in a substitution is unread when the command changes directory', () => {
    expect(rmTargets('cd /etc && git commit -m "$(rm -rf x)"')).toEqual([{ path: undefined, glob: false }])
    // controls: with no cd it reads as a top-level rm would; an absolute operand stays read
    expect(rmTargets('git commit -m "$(rm -rf x)"')).toEqual([{ path: 'x', glob: false }])
    expect(rmTargets('cd /etc && git commit -m "$(rm -rf /tmp/x)"')).toEqual([{ path: '/tmp/x', glob: false }])
    // the list keeps no nesting, so a cd in any substitution counts: here the rm runs in /etc
    expect(rmTargets('echo "$(cd /etc; echo "$(rm -rf x)")"')).toEqual([{ path: undefined, glob: false }])
  })
  test('a span the outer reading already splits is not listed twice', () => {
    expect(rmTargets('echo $(rm -rf /etc/x)')).toEqual([{ path: '/etc/x', glob: false }])
  })
  test('control: plain body text, an honest substitution and the commit form stay allowed', () => {
    expect(bashRules('cat <<EOF\nplease git merge later\nEOF')).toEqual([])
    expect(bashRules('git commit -m "release $(date +%F)"')).toEqual(['commit'])
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nfix\nEOF\n)\"")).toEqual(['commit'])
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nfix: it's (done)\n\ngit push --force words\nEOF\n)\"")).toEqual(['commit'])
    expect(bashRules("gh pr create --title t --body \"$(cat <<'EOF'\n## Summary\n- git merge words\nEOF\n)\"")).toEqual(['pr-create'])
    expect(rmTargets("git commit -m \"$(cat <<'EOF'\nrm -rf /etc/x\nEOF\n)\"")).toEqual([])
  })
  test('a heredoc opened after an opener in quotes keeps its own quoting inside the substitution', () => {
    // Bash opens both heredocs inside the substitution: B's body runs only when B is unquoted
    expect(bashRules(`git commit -m "$(cat <<'A' <<'B'\na\nA\n$(${RULED})\nB\n)"`)).toEqual(['commit'])
    expect(bashRules(`git commit -m "$(cat <<'A' <<B\na\nA\n$(${RULED})\nB\n)"`)).toContain('force-push')
  })
  test('an opener line holding a substitution (Ruling 13): the line is command text, the body is body', () => {
    expect(bashRules(`cat <<'EOF' "$(${RULED})"\nbody\nEOF`)).toContain('force-push')
    expect(bashRules(`cat <<EOF "$(date)"\n$(${RULED})\nEOF`)).toContain('force-push')
    // control: the quoted body is text, and so is a comment on the line
    expect(bashRules(`cat <<'EOF' "$(date)"\n$(${RULED})\nEOF`)).toEqual([])
    expect(substitutionsOf(`cat <<EOF "$(date)" # $(${RULED})\nbody\nEOF`)).toEqual(['date'])
  })
  test('a later opener after a heredoc that never closes has no body of its own', () => {
    expect(substitutionsOf('cat <<A <<B\n$(git push --force)')).toEqual(['git push --force'])
    // control: the first body is quoted, so nothing runs; a backtick in the later delimiter is a word
    expect(substitutionsOf("cat <<'A' <<B\n$(git push --force)")).toEqual([])
    expect(substitutionsOf('cat <<A <<`x`\nbody')).toEqual([])
  })
  test('inner quotes in a double-quoted $(…) pair inside it, as in Bash', () => {
    expect(bashRules(`git commit -m "$(echo "it's")" && ${RULED} 'x'`)).toContain('force-push')
    expect(bashRules(`git commit -m \`echo "\` && ${RULED} "x"`)).toContain('force-push')
    // a backtick span ends at the next unescaped backtick, whatever quotes it holds
    expect(substitutionsOf(`git commit -m \`echo "\` && ${RULED} "x"`)).toEqual(['echo "'])
    // a comment inside the span takes its quotes with it
    expect(bashRules(`git commit -m "$(echo "a" # it"s )\n)" && ${RULED} "x"`)).toContain('force-push')
    // control: the substitution alone is a commit message
    expect(bashRules('git commit -m "$(echo "it\'s")"')).toEqual(['commit'])
    expect(bashRules('git commit -m "$(echo "a;b")"')).toEqual(['commit'])
    // an inner string is text, as in Bash; a command beside it in the span is still read
    expect(bashRules(`git commit -m "$(echo "a; ${RULED}")"`)).toEqual(['commit'])
    expect(bashRules(`git commit -m "$(echo "a"; ${RULED})"`)).toContain('force-push')
  })
  test('a span holding a heredoc is sliced from the command in Bash\'s order (Task 3 review C1)', () => {
    // the opener line's text stays before the body, so the next reading still runs it
    expect(substitutionsOf(`echo \`cat <<'EOF' ; ${RULED}\nbody\nEOF\n\``)).toEqual([`cat <<'EOF' ; ${RULED}\nbody\nEOF\n`])
    for (const open of ['echo `', 'x=`', 'echo $(echo `']) {
      const close = open.endsWith('`') ? (open.includes('$(') ? '`)' : '`') : ')'
      expect(bashRules(`${open}cat <<'EOF' ; ${RULED}\nbody\nEOF\n${close}`)).toContain('force-push')
      expect(bashRules(`${open}cat <<EOF | ${RULED}\nbody\nEOF\n${close}`)).toContain('force-push')
      // control: the body is text
      expect(bashRules(`${open}cat <<'EOF'\n${RULED}\nEOF\n${close}`)).toEqual([])
    }
    expect(rmTargets('x=`cat <<EOF && rm -rf /etc/x\nbody\nEOF\n`')).toEqual([{ path: '/etc/x', glob: false }])
    expect(bashRules('echo `cat <<EOF ; git commit -n -m x\nbody\nEOF\n`')).toContain('no-verify')
    // two openers on the line: both bodies follow it, in order
    expect(substitutionsOf(`echo \`cat <<A <<'B' ; ${RULED}\na\nA\nb\nB\n\``)).toEqual([`cat <<A <<'B' ; ${RULED}\na\nA\nb\nB\n`])
    expect(bashRules(`echo \`cat <<A <<'B' ; ${RULED}\na\nA\nb\nB\n\``)).toContain('force-push')
    // control
    expect(rmTargets("x=`cat <<'EOF'\nrm -rf /etc/x\nEOF\n`")).toEqual([])
    // a heredoc inside a span is read with the span, once, at the next level
    expect(substitutionsOf('echo "$(cat <<EOF\n$(date)\nEOF\n)"')).toEqual(['cat <<EOF\n$(date)\nEOF\n', 'date'])
    // the delimiter word is not command text, even on a line read in the 0.9.0 layout
    expect(bashRules(`cat <<"$(${RULED})" "$(date)"\nbody\n$(${RULED})`)).toEqual([])
    // every shell's grammar runs the command after the second `;` here; Bash 5.3.9 alone drops
    // that `;` (zsh, dash and busybox sh run it), and a rail that adds stops reads it
    expect(bashRules(`echo "$(cat <<EOF ; echo x ; ${RULED}\nbody\nEOF\n)"`)).toContain('force-push')
  })
  test('C5 row 724-A12: a backtick inside ${…} no longer ends the expansion early (Ruling 15)', () => {
    // Bash: the `}` in the backticks does not close `${`, so the & is in the word and no git runs
    expect(bashRules('printf x ${x:-`echo }` & git push --force }')).toEqual([])
    // control: a lone & outside the expansion still splits
    expect(bashRules('printf x ${x:-`echo }`} & git push --force')).toContain('force-push')
  })
})

describe('batch 5: scratch directories', () => {
  test('scratchDirs: /tmp, plus an absolute TMPDIR below the root, without its trailing slashes', () => {
    expect(scratchDirs(undefined)).toEqual(['/tmp'])
    expect(scratchDirs('/var/tmp/x/')).toEqual(['/tmp', '/var/tmp/x'])
    expect(scratchDirs('/var/tmp/x')).toEqual(['/tmp', '/var/tmp/x'])
    expect(scratchDirs('/var/tmp/x//')).toEqual(['/tmp', '/var/tmp/x'])
    // controls: a TMPDIR that names no directory below the root adds nothing (`/` would put every path inside)
    for (const tmpdir of ['relative', 'rel/dir', '', '/', '//', '///']) expect(scratchDirs(tmpdir)).toEqual(['/tmp'])
    // /tmp named twice is one place
    expect(scratchDirs('/tmp')).toEqual(['/tmp'])
    expect(scratchDirs('/tmp/')).toEqual(['/tmp'])
  })
  test('scratchAllow: each scratch directory as given and as resolved, once; one that does not resolve adds nothing', () => {
    expect(scratchAllow(['/tmp'], ['/tmp'], '/w')).toEqual(['/tmp'])
    expect(scratchAllow(['/tmp'], ['/private/tmp'], '/w')).toEqual(['/tmp', '/private/tmp']) // macOS (Review Focus 4)
    expect(scratchAllow(['/tmp', '/var/tmp/x'], ['/tmp', '/var/tmp/x'], '/w')).toEqual(['/tmp', '/var/tmp/x'])
    expect(scratchAllow(['/tmp', '/dangling'], ['/tmp', undefined], '/w')).toEqual(['/tmp'])
    expect(scratchAllow(['/tmp'], [undefined], '/w')).toEqual([])
    expect(scratchAllow(['/tmp'], ['/tmp'], undefined)).toEqual(['/tmp'])
  })
  // placeOf lets an allow directory outrank the worktree, so a scratch directory that holds the worktree would hand a
  // reviewer its edits: it is left out, as given and as resolved. The worktree beside it, above it or elsewhere keeps it.
  test('scratchAllow: a scratch directory that holds the worktree is left out', () => {
    for (const root of ['/tmp/wt', '/tmp', '/tmp/a/b/wt']) expect(scratchAllow(['/tmp'], ['/tmp'], root)).toEqual([])
    expect(scratchAllow(['/tmp'], ['/private/tmp'], '/private/tmp/wt')).toEqual([])
    expect(scratchAllow(['/tmp'], ['/private/tmp'], '/private/tmp')).toEqual([])
    // a resolved '/' (a TMPDIR such as /tmp/.. ) holds every worktree: it can never put everything inside
    expect(scratchAllow(['/tmp/..'], ['/'], '/w')).toEqual([])
    // controls: a sibling sharing the prefix, the worktree above the scratch directory, the worktree elsewhere
    expect(scratchAllow(['/tmp'], ['/tmp'], '/tmpfoo/wt')).toEqual(['/tmp'])
    expect(scratchAllow(['/tmp'], ['/tmp'], '/')).toEqual(['/tmp'])
    expect(scratchAllow(['/tmp'], ['/tmp'], '/w')).toEqual(['/tmp'])
    expect(scratchAllow(['/w/tmp'], ['/w/tmp'], '/w')).toEqual(['/w/tmp'])
    // one directory leaving does not take the other with it
    expect(scratchAllow(['/tmp', '/home/u/t'], ['/tmp', '/home/u/t'], '/tmp/wt')).toEqual(['/home/u/t'])
  })
  // Review Focus 3: the scratch directory is a writable place whose own path and ancestors rm still protects.
  test('over scratchDirs: descendants are inside; the directory itself, its ancestors and everything else are not', () => {
    const allow = scratchDirs(undefined)
    expect(placeOf('/tmp/x', '/w', allow)).toBe('allow')
    expect(placeOf('/tmp/a/b', '/w', allow)).toBe('allow')
    expect(placeOf('/etc/x', '/w', allow)).toBe('outside')
    expect(placeOf('/tmpfoo/x', '/w', allow)).toBe('outside')
    expect(removalOf('/tmp/x', '/w', allow, false)).toEqual({ place: 'allow', protected: false })
    expect(removalOf('/tmp', '/w', allow, true)).toEqual({ place: 'allow', protected: false }) // rm /tmp/*: the accepted cost
    expect(removalOf('/tmp', '/w', allow, false).protected).toBe(true) // rm -rf /tmp
    expect(removalOf('/', '/w', allow, false).protected).toBe(true) // rm -rf /
    expect(removalOf('/', '/w', allow, true).protected).toBe(true) // rm -rf /*
    expect(removalOf('/etc/x', '/w', allow, false)).toEqual({ place: 'outside', protected: false })
    expect(decide('implementer', { kind: 'bash', rules: [], removals: [removalOf('/tmp', '/w', allow, false)] })).toContain('roots or ancestors')
    expect(decide('implementer', { kind: 'bash', rules: [], removals: [removalOf('/tmp/x', '/w', allow, false)] })).toBeUndefined()
  })
})

// Task 5: a relative rm operand after a literal cd, and a "$NAME" after a literal NAME=value, resolve to an
// absolute path, but only along a plain `;`, `&&` or newline sequence from the command's start (spec §7).
describe('batch 5: rm after cd', () => {
  const t = (path: string | undefined, glob = false) => ({ path, glob })
  // What both glues decide for an implementer whose worktree and session directory are `root`, with the scratch
  // directories allowed. The glues walk each `..` (through links) before placing; with no links that is lexical.
  const lexical = (path: string) => {
    const parts: string[] = []
    for (const part of path.split('/')) if (part === '..') parts.pop(); else if (part !== '' && part !== '.') parts.push(part)
    return '/' + parts.join('/')
  }
  const verdict = (command: string, root = '/w/wt', role: 'implementer' | 'reviewer' = 'implementer') => decide(role, {
    kind: 'bash', rules: bashRules(command),
    removals: rmTargets(command).map(target => target.path === undefined ? UNREAD
      : removalOf(lexical(target.path.startsWith('/') ? target.path : `${root}/${target.path}`), root, scratchDirs(undefined), target.glob)),
  })
  test('the plan: a literal cd or assignment resolves; anything else stays unresolved', () => {
    expect(rmTargets('cd "/w/wt" && rm -rf pf/__pycache__ tests/__pycache__'))
      .toEqual([{ path: '/w/wt/pf/__pycache__', glob: false }, { path: '/w/wt/tests/__pycache__', glob: false }])
    // Ruling 21 amends the plan's value: the cd may fail before the newline, so the bare operand (the session's
    // directory) is a target too, and both must be allowed.
    expect(rmTargets('WT="/w/wt"; cd "$WT"\nrm -f pf/__pycache__/o.pyc'))
      .toEqual([{ path: 'pf/__pycache__/o.pyc', glob: false }, { path: '/w/wt/pf/__pycache__/o.pyc', glob: false }])
    expect(rmTargets('WT=/w/wt; rm -f "$WT/x"')).toEqual([{ path: '/w/wt/x', glob: false }])
    // stays unresolved (refused as today)
    for (const c of ['cd /w/wt || true; rm x', '(cd /w/wt); rm x', 'if true; then cd /w/wt; fi; rm x',
      'cd -; rm x', 'cd "$UNSET"; rm x', 'WT=$(pwd); rm "$WT/x"', 'cd /w/wt | cat; rm x', 'rm "$UNSET/x"'])
      expect(rmTargets(c)).toEqual([{ path: undefined, glob: false }])
    // a relative cd after a known absolute one. Ruling 21 amends the plan's value: `cd /w` may fail before the `;`,
    // so `cd wt` joins onto the session's directory too, beside `/w/wt/x`. Fix round 1 (finding 3) writes that join
    // `./wt`, so no glue reads a leading `~`, `@` or `:` in it: the same place as the bare `wt/x`.
    expect(rmTargets('cd /w; cd wt && rm x')).toEqual([{ path: './wt/x', glob: false }, { path: '/w/wt/x', glob: false }])
  })
  test('adjacent controls: the same shapes with a ruled directory resolve to it and are refused', () => {
    expect(rmTargets('cd /etc && rm -rf x')).toEqual([t('/etc/x')])
    expect(rmTargets('WT=/etc; rm -rf "$WT/x"')).toEqual([t('/etc/x')])
    // Ruling 21: the failed-cd reading is a target beside the cd's own
    expect(rmTargets('WT="/etc"; cd "$WT"\nrm -f pf/__pycache__/o.pyc')).toEqual([t('pf/__pycache__/o.pyc'), t('/etc/pf/__pycache__/o.pyc')])
    expect(rmTargets('cd /; cd etc && rm x')).toEqual([t('./etc/x'), t('/etc/x')]) // `./`: fix round 1 (finding 3)
    for (const command of ['cd /etc && rm -rf x', 'WT=/etc; rm -rf "$WT/x"', 'WT="/etc"; cd "$WT"\nrm -f pf/__pycache__/o.pyc',
      'cd /; cd etc && rm x', 'cd "/etc" && rm -rf pf/__pycache__ tests/__pycache__'])
      expect(verdict(command)).toContain('no rm outside writable places')
    for (const command of ['cd "/w/wt" && rm -rf pf/__pycache__ tests/__pycache__', 'WT="/w/wt"; cd "$WT"\nrm -f pf/__pycache__/o.pyc',
      'WT=/w/wt; rm -f "$WT/x"', 'cd /w; cd wt && rm x'])
      expect(verdict(command)).toBeUndefined()
    // the session directory is the worktree here, so an unresolved operand is refused by its own text
    expect(verdict('cd /w/wt || true; rm x')).toContain('cannot resolve')
  })
  test('Review Focus 2: a cd in a subshell, a block, a pipeline, or after || or & does not move the directory', () => {
    for (const c of ['{ cd /w/wt; }; rm x', 'cd /w/wt & rm x', 'true || cd /w/wt; rm x', 'true | cd /w/wt; rm x',
      'while true; do cd /w/wt; break; done; rm x', 'for d in /w/wt; do cd "$d"; done; rm x', 'case a in a) cd /w/wt;; esac; rm x',
      '! cd /w/wt; rm x', 'time cd /w/wt; rm x', 'echo $(cd /w/wt); rm x', 'f() { cd /etc; }; cd /w && f && rm x',
      'if false; then\ncd /w/wt\nelse\nrm x\nfi', 'if true; then\ncd /w/wt\nfi\nrm x',
      'function f { cd /etc; }; cd /w && f && rm x', 'cd /w; (cd wt); rm x', '(cd /w/wt && rm x)', 'X=$(cd /w/wt && rm y)', 'cd /w/wt && ls | head; rm x', 'cd /w/wt || exit; rm x'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    // the rm inside the plain sequence reads before the || or | that follows it
    expect(rmTargets('cd /w/wt && rm x || true')).toEqual([t('/w/wt/x')])
    expect(rmTargets('cd /w/wt && rm x | cat')).toEqual([t('/w/wt/x')])
    // no cd: a pipeline, subshell or block keeps the session directory, as today
    for (const c of ['ls | wc -l; rm x', '(true); rm x', 'if true; then :; fi; rm x', 'true || false; rm x'])
      expect(rmTargets(c)).toEqual([t('x')])
  })
  // Ruling 21 (spec §4): a cd may fail, and one behind `&&` may be skipped, so after `;` or a newline the walk keeps
  // every directory the shell may be in, and a relative operand is one target in each; the rest of a `cd X &&`
  // list runs in X only.
  test('Ruling 21: a cd that may fail or be skipped leaves every directory the next command may run in', () => {
    expect(rmTargets('false && cd /w/wt; rm x')).toEqual([t('x'), t('/w/wt/x')])
    expect(rmTargets('test -d /w/wt && cd /w/wt\nrm x')).toEqual([t('x'), t('/w/wt/x')])
    expect(rmTargets('test -d /w/wt && cd /w/wt && rm x')).toEqual([t('/w/wt/x')])
    expect(rmTargets('cd /w && rm a && cd wt; rm x')).toEqual([t('/w/a'), t('x'), t('/w/x'), t('/w/wt/x')])
    expect(rmTargets('WT=/w/wt && cd "$WT" && rm a; rm b')).toEqual([t('/w/wt/a'), t('b'), t('/w/wt/b')])
    expect(rmTargets('cd /w && cd wt; rm x')).toEqual([t('x'), t('/w/x'), t('/w/wt/x')])
    expect(rmTargets('git status; WT=/w && cd "$WT"; rm x')).toEqual([t('x'), t('/w/x')])
    expect(rmTargets('cd /a; cd b; rm x')).toEqual([t('x'), t('/a/x'), t('./b/x'), t('/a/b/x')]) // `./`: fix round 1 (finding 3)
    // the cap: four directories are read, a fifth makes the operand unresolved; an absolute cd && starts again
    expect(rmTargets('cd /a; cd /b; cd /c; rm x')).toEqual([t('x'), t('/a/x'), t('/b/x'), t('/c/x')])
    expect(rmTargets('cd /a; cd /b; cd /c; cd /d; rm x')).toEqual([t(undefined)])
    expect(rmTargets('cd /a; cd /b; cd /c; cd /d; cd /w && rm x')).toEqual([t('/w/x')])
    // an assignment a failed command may skip is forgotten when its list ends (a failed cd leaves WT unset)
    for (const c of ['true && WT=/w/wt; rm "$WT/x"', 'cd /w && WT=/w/wt; rm "$WT/x"'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    // Ruling 24: an assignment behind a cd may be skipped, so it never becomes known; one before the cd holds
    expect(rmTargets('cd /w && WT=/w/wt && rm "$WT/x"')).toEqual([t(undefined)])
    expect(rmTargets('WT=/w/wt && cd /w && rm "$WT/x"')).toEqual([t('/w/wt/x')])
    expect(rmTargets('WT=/w/wt X=/w && rm "$WT/x" "$X/y"')).toEqual([t('/w/wt/x'), t('/w/y')])
    expect(rmTargets('true; WT=/w && X=/x; rm "$X/y"')).toEqual([t('/x/y')])
    // an unread change inside a list, a directory named twice, a relative cd after an unknown one
    expect(rmTargets('cd /w && builtin cd /etc && rm x')).toEqual([t(undefined)])
    expect(rmTargets('cd /w; cd /w; rm x')).toEqual([t('x'), t('/w/x')])
    expect(rmTargets('cd - && cd wt && rm x')).toEqual([t(undefined)])
  })
  test('Ruling 21: the failed-cd hide is refused; the same removal behind && is allowed', () => {
    // a reviewer whose session directory is the worktree: a failed cd removes the worktree's build
    expect(verdict('cd /tmp/typo; rm -rf build', '/w/wt', 'reviewer')).toContain('no rm outside writable places')
    expect(verdict('cd /tmp/typo && rm -rf build', '/w/wt', 'reviewer')).toBeUndefined()
    expect(verdict('cd /tmp/x; rm -rf *', '/w/wt', 'reviewer')).toContain('no rm outside writable places')
    expect(verdict('cd /tmp/x && rm -rf *', '/w/wt', 'reviewer')).toBeUndefined()
    // the implementer's own worktree holds both readings
    expect(verdict('cd /w/wt/pf; rm -rf build')).toBeUndefined()
    expect(verdict('cd /etc; rm -rf build')).toContain('no rm outside writable places')
  })
  test('Ruling 21: both baton records stay allowed with cwd = root = their worktree; their /etc/x siblings are refused', () => {
    for (const [command, root] of [['cd "/home/dev/projects/pilot-fourseat/.worktrees/r0.s6.w1" && rm -rf pf/__pycache__ tests/__pycache__ && grep -n \'value:\\.1f\' pf/sizes.py && python3 -m unittest tests.test_sizes; echo "rc=$?"; diff /tmp/sizes.py.orig pf/sizes.py && echo "identical to pre-mutation copy"', '/home/dev/projects/pilot-fourseat/.worktrees/r0.s6.w1'],
      ['WT="/home/dev/projects/pilot-fourseat/.worktrees/r0.s7.w1"; cd "$WT"\nrm -f pf/__pycache__/ordinal.*.pyc tests/__pycache__/test_ordinal.*.pyc\npython3 -m unittest tests.test_ordinal; echo "post-cache-clear rc=$?"', '/home/dev/projects/pilot-fourseat/.worktrees/r0.s7.w1']] as const) {
      expect(rmTargets(command).every(target => target.path !== undefined)).toBe(true)
      expect(verdict(command, root)).toBeUndefined()
      expect(verdict(command.split(root).join('/etc/x'), root)).toContain('no rm outside writable places')
    }
  })
  test('the variable spellings that resolve, and the ones that do not', () => {
    expect(rmTargets('WT=/w/wt; rm -f "${WT}/x" ${WT}/y $WT/z "$WT"/q "$WT" ${WT}x')).toEqual([
      t('/w/wt/x'), t('/w/wt/y'), t('/w/wt/z'), t('/w/wt/q'), t('/w/wt'), t('/w/wtx')])
    expect(rmTargets("WT=/w/wt; rm -f '$WT/x' \\$WT/y")).toEqual([t('$WT/x'), t('$WT/y')])
    expect(rmTargets('WT=x; rm "it\'s/$WT"')).toEqual([t("./it's/x")]) // Ruling 24: a bare operand built from a variable is ./
    expect(rmTargets("WT='/w/wt' X=/w/x; rm -f \"$WT/a\" \"$X/b\"")).toEqual([t('/w/wt/a'), t('/w/x/b')])
    expect(rmTargets('WT=/w/wt; cd $WT && rm -f a "$WT/b"')).toEqual([t('/w/wt/a'), t('/w/wt/b')])
    for (const c of ['WT=/w/wt; rm "$WTx"', 'WT=/w/wt; rm "${WT:-/w}/x"', 'WT=/w/wt; rm "$$WT"', 'WT=/w/wt; rm ~$WT',
      'WT=/w/wt; rm "${#WT}"', 'WT=/w/wt; rm "$1"'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    // a relative value is a relative operand: it joins a known directory, or the session's, like any other
    // Ruling 21: after `cd /w;` the session's directory is a target beside /w; a relative cd joins onto each directory
    // Ruling 24: and a bare one built from a variable is written ./
    expect(rmTargets('cd /w; WT=wt; rm -rf "$WT/x"')).toEqual([t('./wt/x'), t('/w/wt/x')])
    expect(rmTargets('WT=wt; rm -rf "$WT/x"')).toEqual([t('./wt/x')])
    expect(rmTargets('WT=wt; cd "$WT" && rm x')).toEqual([t('./wt/x')]) // `./`: fix round 1 (finding 3)
    // a glob after a substituted value is placed by its literal prefix
    expect(rmTargets('WT=/w/wt; rm -f "$WT"/pf/*.pyc')).toEqual([t('/w/wt/pf', true)])
  })
  test('a value with an expansion, or one Bash reads differently, never becomes known', () => {
    for (const c of ['WT=$(pwd); rm "$WT/x"', 'WT="$HOME/x"; rm "$WT/y"', 'WT=`pwd`; rm "$WT/x"', 'WT=~/x; rm "$WT"',
      "WT='/w/a b'; rm $WT/x", "WT='/w/*'; rm $WT", "WT='~/x'; rm $WT", 'WT=; rm "$WT/x"', 'WT=/w/wt true; rm "$WT/x"',
      'export WT=/w/wt; rm "$WT/x"', 'local WT=/w/wt; rm "$WT/x"', 'declare WT=/w/wt; rm "$WT/x"', 'readonly WT=/w/wt; rm "$WT/x"',
      'RANDOM=/w/wt; rm "$RANDOM/x"', 'SECONDS=/w; rm "$SECONDS/x"', 'PWD=/w/wt; rm "$PWD/x"', 'UID=/w; rm "$UID/x"',
      'WT[0]=/w/wt; rm "$WT/x"', 'WT+=/w/wt; rm "$WT/x"'])
      expect(rmTargets(c)).toEqual([t(undefined)])
  })
  test('a later command that may change a known variable makes it unknown again', () => {
    for (const c of ['WT=/w; WT=$(pwd); rm "$WT/x"', 'WT=/w; WT+=/x; rm "$WT/y"', 'WT=/w; WT[0]=/etc; rm "$WT/y"',
      'WT=/w; unset WT; rm "$WT/y"', 'WT=/w; read WT </dev/null; rm "$WT/y"', 'WT=/w; printf -v WT /etc; rm "$WT/y"',
      'WT=/w; N=WT; printf -v "$N" /etc; rm "$WT/y"', 'WT=/w; echo ${WT:=/etc}; rm "$WT/y"', 'WT=/w; export WT=/etc; rm "$WT/y"',
      'WT=/w; eval "WT=/etc"; rm "$WT/y"', 'WT=/w; source ./env.sh; rm "$WT/y"', 'WT=/w; . ./env.sh; rm "$WT/y"',
      'WT=/w; for WT in /etc; do :; done; rm "$WT/y"', 'WT=/w; let WT=1; rm "$WT/y"', 'WT=/w; mapfile WT </dev/null; rm "$WT/y"',
      'WT=/w; $CMD; rm "$WT/y"', 'WT=/w; WT=/etc true; rm "$WT/y"', 'WT=/w; echo $((WT=1)); rm "$WT/y"',
      'WT=/w; WT=`pwd`; rm "$WT/y"', 'WT=/w; WT="$HOME/x"; rm "$WT/y"'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    // Ruling 24: any other command forgets every variable, even one that only reads it
    for (const c of ['WT=/w; git -C "$WT" status; rm "$WT/y"', 'WT=/w; echo "$WT" ${WT}; rm "$WT/y"', 'WT=/w; set -euo pipefail; rm "$WT/y"'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    // controls: a literal assignment, a literal cd and an rm keep it
    for (const c of ['WT=/w; X=1; rm "$WT/y"', 'WT=/w; WT=/w; rm "$WT/y"', 'WT=/w; cd /etc; rm "$WT/y"'])
      expect(rmTargets(c)).toEqual([t('/w/y')])
    expect(rmTargets('WT=/w; rm -f a; rm "$WT/y"')).toEqual([t('a'), t('/w/y')])
  })
  test('cd spellings: the builtin itself resolves; a wrapper, an option or an unread word does not', () => {
    for (const c of ['\\cd /w && rm x', '"cd" /w && rm x', "c'd' /w && rm x", 'cd /w/ && rm x', 'cd /w 2>/dev/null && rm x'])
      expect(rmTargets(c)).toEqual([t('/w/x')])
    // Ruling 21: after a newline the failed-cd reading is a target too
    for (const c of ['cd /w # go\nrm x', 'cd "/w"\nrm x']) expect(rmTargets(c)).toEqual([t('x'), t('/w/x')])
    expect(rmTargets('cd / && rm x')).toEqual([t('/x')])
    for (const c of ['builtin cd /w; rm x', 'command cd /w; rm x', '/usr/bin/cd /w; rm x', 'A=1 cd /w; rm x', 'cd -- /w; rm x',
      'cd -P /w; rm x', 'cd /w /etc; rm x', 'cd; rm x', 'cd ~; rm x', 'cd ~/w; rm x', 'cd /w*; rm x', 'cd /w/{a,b}; rm x',
      'cd ""; rm x', 'cd /w/wt/..; rm x', 'cd /w/wt && cd .. && rm x', 'pushd /w; rm x', 'cd /w; popd; rm x',
      'cd /w; "pushd" /etc; rm x', 'cd /w; builtin cd /etc; rm x', 'cd /w; "command" cd /etc; rm x', 'cd /w; command cd /etc; rm x',
      'cd /w; eval "cd /etc"; rm x', 'cd /w; source ./go.sh; rm x', 'cd /w; . ./go.sh; rm x', 'cd /w; C=cd; $C /etc; rm x',
      'cd /w; `echo cd` /etc; rm x', 'cd /w; trap "cd /etc" DEBUG; rm x', 'cd /w; shopt -s cdable_vars; rm x',
      'CDPATH=/etc; cd /w; cd ssl && rm x', 'cd /w; export CDPATH=/etc; cd ssl && rm x', 'IFS=/; cd /w && rm x',
      'cd /w; command -p cd /etc; rm x', 'cd /w; command -- cd /etc; rm x', 'cd /w; builtin -- cd /etc; rm x',
      'cd /w; command -p $C /etc; rm x', 'cd /w; env -i cd /etc; rm x', 'cd /w; cd - && rm x', 'cd /w; cd ~/x && rm y',
      'cd /w; coproc { cd /etc; rm x; }', 'cd /w; A=1 $C /etc; rm x', 'if true; then "cd" /etc; fi; rm x', 'cd /w; c[d] /etc; rm x'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    // as before batch 5, any word named cd counts, even through an unread folder
    expect(rmTargets('$D/cd /etc; rm x')).toEqual([t(undefined)])
    // controls: a command that only runs a program keeps the directories (Ruling 21: the session's, and /w)
    for (const c of ['cd /w; echo cd /etc; rm x', 'cd /w; git status; rm x', 'cd /w; echo "cd /etc"; rm x', 'cd /w; command rm x',
      'cd /w; command -p git status; rm x', 'cd /w && cat <<EOF\ncd /etc\nEOF\nrm x', '>/dev/null cd /w; rm x', '""cd /w; rm x'])
      expect(rmTargets(c)).toEqual([t('x'), t('/w/x')])
    // no cd before it: a builtin that can change the directory leaves the session's, as today
    for (const c of ['source venv/bin/activate && rm -rf x', 'eval true; rm x', '$EDITOR f; rm x', 'export A=1; rm x'])
      expect(rmTargets(c)).toEqual([t('x')])
  })
  test('operands keep their kind; a .. is left to placement, which follows links before it', () => {
    expect(rmTargets("cd /w && rm -rf -- -x ~/x '~/y' /abs ..")).toEqual([t('/w/-x'), t('~/x'), t('/w/~/y'), t('/abs'), t('/w/..')])
    expect(rmTargets('cd /w/wt && rm -rf ../x')).toEqual([t('/w/wt/../x')])
    expect(rmTargets('cd /w/wt && rm -f *.pyc pf/__pycache__/o.*.pyc')).toEqual([t('/w/wt/.', true), t('/w/wt/pf/__pycache__', true)])
    expect(rmTargets('cd /w/wt && rm -f ../*.pyc .*.pyc')).toEqual([t('/w/wt/..', true), t(undefined)])
    // the real record: globs under a cd through a variable (Task 6 replays it)
    expect(rmTargets('WT="/w/wt"; cd "$WT"\nrm -f pf/__pycache__/ordinal.*.pyc tests/__pycache__/test_ordinal.*.pyc\npython3 -m unittest tests.test_ordinal; echo "rc=$?"'))
      .toEqual([t('pf/__pycache__', true), t('/w/wt/pf/__pycache__', true), t('tests/__pycache__', true), t('/w/wt/tests/__pycache__', true)]) // Ruling 21
    // a `..` out of the worktree is outside; one that stays inside is inside
    expect(verdict('cd /w/wt && rm -rf ../x')).toContain('no rm outside writable places')
    expect(verdict('cd /w/wt && rm -rf ..')).toContain('roots or ancestors')
    expect(verdict('cd /w/wt/pf && rm -rf ../tests/x')).toBeUndefined()
  })
  test('Ruling 2: a substitution inherits neither the directory nor the variables', () => {
    for (const c of ['cd /w && echo "$(rm x)"', 'WT=/w; echo "$(rm "$WT/x")"', 'echo "$(cd /w && rm x)"', 'echo "$(WT=/w; rm "$WT/x")"',
      'cd /w; X=$(cd /etc); rm y', 'WT=/w; echo `rm "$WT/x"`'])
      expect(rmTargets(c)).toEqual([t(undefined)])
  })
})

// Task 5 fix round 1: four ways the walk approved a removal Bash makes elsewhere (base 0572a24c refused each).
describe('batch 5: rm after cd, fix round 1', () => {
  const t = (path: string | undefined, glob = false) => ({ path, glob })
  const lexical = (path: string) => {
    const parts: string[] = []
    for (const part of path.split('/')) if (part === '..') parts.pop(); else if (part !== '' && part !== '.') parts.push(part)
    return '/' + parts.join('/')
  }
  const verdict = (command: string, role: 'implementer' | 'reviewer' = 'implementer', root = '/w/wt') => decide(role, {
    kind: 'bash', rules: bashRules(command),
    removals: rmTargets(command).map(target => target.path === undefined ? UNREAD
      : removalOf(lexical(target.path.startsWith('/') ? target.path : `${root}/${target.path}`), root, scratchDirs(undefined), target.glob)),
  })
  test('finding 1: a newline after &&, || or | continues the list; a command alone on its line ends it', () => {
    // Bash skips the assignment with the list, and the rm on the next line removes /x
    for (const c of ['false &&\nWT=/w/wt\nrm -rf "$WT/x"', 'cd /w/missing &&\nWT=/w/wt\nrm -rf "$WT/x"', 'true &&\n\n  WT=/w/wt\nrm "$WT/x"',
      'true && # why\nWT=/w/wt\nrm "$WT/x"', 'cd /w ||\nrm x', 'cd /w |\ncat; rm x'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    expect(verdict('false &&\nS=/tmp/x\nrm -rf "$S/y"')).toContain('cannot resolve')
    // controls: the rest of a `cd X &&` list runs in X only, across the newline; a list ends at a newline after a command
    expect(rmTargets('cd /w/wt &&\nrm -rf build')).toEqual([t('/w/wt/build')])
    expect(rmTargets('cd /w/wt &&   \n  rm -rf build')).toEqual([t('/w/wt/build')])
    expect(rmTargets('true\nWT=/w/wt\nrm "$WT/x"')).toEqual([t('/w/wt/x')])
    expect(verdict('cd /tmp/x &&\nrm -rf build', 'reviewer')).toBeUndefined()
    expect(verdict('cd /tmp/x\nrm -rf build', 'reviewer')).toContain('no rm outside writable places')
    // the `&` or `|` of a redirection operator separates nothing
    for (const c of ['cd /w && echo hi >|/tmp/f && rm y', 'cd /w && echo hi 2>&1 && rm y', 'cd /w && echo hi &>/dev/null && rm y',
      'cd /w && echo hi <&0 && rm y'])
      expect(rmTargets(c)).toEqual([t('/w/y')])
    // a command made of a redirection or a heredoc alone is a command: the newline after it ends the list
    expect(rmTargets('cd /w && >/dev/null\nrm x')).toEqual([t('x'), t('/w/x')])
    expect(rmTargets('cd /w/missing && <<EOF\nb\nEOF\nrm x')).toEqual([t('x'), t('/w/missing/x')])
  })
  test('finding 2: an assignment-only command may fail, so an assignment after its && may be skipped', () => {
    for (const c of ['A="$(false)" && WT=/w/wt; rm -rf "$WT/x"', 'A=`false` && WT=/w/wt; rm -rf "$WT/x"',
      'A=1 </nonexistent && WT=/w/wt; rm -rf "$WT/x"', 'A="$(git rev-parse --show-toplevel)" && WT=/w/wt; rm -rf "$WT/x"',
      'A="$HOME" && WT=/w/wt; rm -rf "$WT/x"'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    expect(verdict('A="$(git rev-parse --show-toplevel)" && S=/tmp/x; rm -rf "$S/y"')).toContain('cannot resolve')
    // controls: a literal assignment cannot fail, and within the list the assignment holds
    expect(rmTargets('A=1 && WT=/w/wt; rm -rf "$WT/x"')).toEqual([t('/w/wt/x')])
    expect(rmTargets('A=/w X=1 && WT=/w/wt; rm -rf "$WT/x"')).toEqual([t('/w/wt/x')])
    // Ruling 24: behind a command that may fail, the assignment never becomes known, in its own list too
    expect(rmTargets('A="$(false)" && WT=/w/wt && rm -rf "$WT/x"')).toEqual([t(undefined)])
    expect(verdict('A=1 && S=/tmp/x; rm -rf "$S/y"', 'reviewer')).toBeUndefined()
  })
  test('finding 3: a relative cd from the session directory is written ./ so no glue reads a leading ~, @ or :', () => {
    expect(rmTargets('cd "~" && rm -rf scratch/x')).toEqual([t('./~/scratch/x')])
    expect(rmTargets('cd "~/scratch" && rm -rf x')).toEqual([t('./~/scratch/x')])
    expect(rmTargets('cd \\~ && rm -rf x')).toEqual([t('./~/x')])
    expect(rmTargets('cd "~"; rm -rf x')).toEqual([t('x'), t('./~/x')])
    expect(rmTargets('cd @ && rm -rf tmp/x')).toEqual([t('./@/tmp/x')])
    expect(rmTargets('cd ":~" && rm -rf x')).toEqual([t('./:~/x')])
    expect(rmTargets('cd file:///tmp && rm -rf x')).toEqual([t('./file:///tmp/x')])
    expect(rmTargets('cd ./sub && cd ~x && rm y')).toEqual([t(undefined)])
    expect(rmTargets('cd ./sub && rm y')).toEqual([t('./sub/y')])
    // controls: an active tilde is HOME, so a cd to it is unknown; a quoted one in an operand stays literal, as before
    expect(rmTargets('cd ~ && rm -rf scratch/x')).toEqual([t(undefined)])
    expect(rmTargets('rm -rf "~/scratch/x" ~/scratch/y')).toEqual([t('./~/scratch/x'), t('~/scratch/y')])
  })
  test('finding 4: every write to a known variable is read, wherever the segment holds it', () => {
    for (const c of ['S=/w/wt; X="$((S=5))"; rm -rf "$S/x"', 'S=/w/wt; X=$[S=5]; rm -rf "$S/x"', 'S=/w/wt; A[S=5]=1; rm -rf "$S/x"',
      'S=/w/wt; cd $[S=5]; rm -rf "$S/x"', 'S=/w/wt; cd "$((S=5))"; rm -rf "$S/x"', 'S=/w/wt; : >"$((S=5))"; rm -rf "$S/x"',
      'S=/w/wt; true > $[S=5]; rm -rf "$S/x"', 'S=/w/wt; : <<<"$((S=5))"; rm -rf "$S/x"', 'S=/w/wt; true {S}>/dev/null; rm -rf "$S/x"',
      'S=/w/wt; exec {S}>/dev/null; rm -rf "$S/x"', 'S=/w/wt; : <<EOF\n$((S=5))\nEOF\nrm -rf "$S/x"', 'S=/w/wt; [[ 1 -eq S=5 ]]; rm -rf "$S/x"',
      'S=/w/wt; echo ${A[S=5]}; rm -rf "$S/x"', 'S=/w/wt X=$((S=5)); rm -rf "$S/x"', 'S=/w/wt; X="${ S=/etc; }"; rm -rf "$S/x"']) {
      const found = rmTargets(c)
      expect(found.length > 0 && found.every(target => target.path === undefined)).toBe(true)
    }
    // the operand before the write reads S as Bash does, and the write's own operand is unread: still refused
    expect(rmTargets('S=/w/wt; rm -rf "$S/x" "$[S=5]"')).toEqual([t('/w/wt/x'), t(undefined)])
    // a Bash 5.3 `${ …; }` runs in the current shell, and a heredoc line read in the 0.9.0 layout hides its tail
    for (const c of ['cd /w; X="${ cd /etc; }"; rm y', 'cd /w; echo "${| cd /etc; }"; rm y', 'cd /w; cat <<EOF "$(true)"; cd /etc\nbody\nEOF\nrm y'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    expect(verdict('S=/tmp/x; X="$((S=5))"; rm -rf "$S/y"', 'reviewer')).toContain('cannot resolve')
    // Ruling 24: a command that only reads it, a heredoc, an assignment with an expansion forget it too
    for (const c of ['S=/w/wt; X="$((1+1))"; : >"$S.log"; exec 3>/dev/null; rm -rf "$S/x"', 'S=/w/wt; cat <<EOF\n$S\nEOF\nrm -rf "$S/x"',
      'X="$((S=5))" S=/w/wt; rm -rf "$S/x"', "S=/w/wt; cat <<'EOF'\nS is $((S=5))\nEOF\nrm -rf \"$S/x\"",
      'S=/w/wt X="$((S=5))"; rm -rf "$S/x"', 'S=/w/wt A[S=5]=1; rm -rf "$S/x"', 'S=/w/wt S="$HOME/x"; rm -rf "$S/y"'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    // controls: only literal assignments, a literal cd and rm between the assignment and its use
    expect(rmTargets('S=/w/wt; X=1; cd /w; rm -f a; rm -rf "$S/x"')).toEqual([t('a'), t('/w/a'), t('/w/wt/x')])
    expect(rmTargets('cd /w/wt && git commit -m "$(cat <<\'EOF\'\nmsg\nEOF\n)" && rm -rf build')).toEqual([t('/w/wt/build')])
    expect(verdict('S=/tmp/x; rm -rf "$S/y"', 'reviewer')).toBeUndefined()
  })
})

// Task 5 fix round 2 (Ruling 24): a variable stays known only across literal assignments, a literal cd and rm.
describe('batch 5: rm after cd, fix round 2', () => {
  const t = (path: string | undefined, glob = false) => ({ path, glob })
  const verdict = (command: string, role: 'implementer' | 'reviewer' = 'implementer', root = '/w/wt') => decide(role, {
    kind: 'bash', rules: bashRules(command),
    removals: rmTargets(command).map(target => target.path === undefined ? UNREAD
      : removalOf(target.path.startsWith('/') ? target.path : `${root}/${target.path.replace(/^\.\//, '')}`, root, scratchDirs(undefined), target.glob)),
  })
  test('open 2: a command made of redirections alone may fail, so the assignment after its && never becomes known', () => {
    for (const c of ['</nonexistent && S=/tmp/x; rm -rf "$S/y"', '>/nonexistent/d/f && S=/tmp/x; rm -rf "$S/y"',
      '</nonexistent &&\nS=/tmp/x\nrm -rf "$S/y"', '<"$(false)" && S=/tmp/x; rm -rf "$S/y"'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    for (const role of ['implementer', 'reviewer'] as const)
      expect(verdict('</nonexistent && S=/tmp/x; rm -rf "$S/y"', role)).toContain('cannot resolve')
    // a heredoc or here-string is a redirection too, so the command is not a literal assignment (Bash: this one succeeds)
    for (const c of ['A=1 <<EOF && S=/tmp/x; rm -rf "$S/y"\nbody\nEOF', 'A=1 <<<x && S=/tmp/x; rm -rf "$S/y"'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    // control: the same assignment at the start of its list
    expect(rmTargets('S=/tmp/x && rm -rf "$S/y"')).toEqual([t('/tmp/x/y')])
    expect(verdict('S=/tmp/x && rm -rf "$S/y"', 'reviewer')).toBeUndefined()
  })
  test('open 4: a write through an indirect name is never seen, so any other command forgets every variable', () => {
    for (const c of ['Z=S=5; S=/tmp/x; : "$((Z))"; rm -rf "$S/y"', 'Z=S=5; S=/tmp/x; : $[Z]; rm -rf "$S/y"',
      'Z=S=5; S=/tmp/x; X=abcdef; : "${X:Z}"; rm -rf "$S/y"', 'Z=S; S=/tmp/x; : "$(($Z=5))"; rm -rf "$S/y"',
      'Z=W; WT=/tmp/x; : "$((${Z}T=5))"; rm -rf "$WT/y"', "Z='$((S=5))'; S=/tmp/x; : \"${Z@P}\"; rm -rf \"$S/y\"",
      'Z=S; S=/tmp/x; compgen -V "$Z" -W /etc >/dev/null; rm -rf "$S/y"', 'WT=/w/wt; echo "$WT"; rm -rf "$WT/x"',
      'WT=/w/wt; true; rm -rf "$WT/x"', 'WT=/w/wt; : ; rm -rf "$WT/x"', 'WT=/w/wt; >/tmp/log; rm -rf "$WT/x"',
      'WT=/w/wt; f; rm -rf "$WT/x"', 'WT=/w/wt; cd /w 2>/dev/null; rm -rf "$WT/x"', 'WT=/w/wt; rm -f a 2>/dev/null; rm -rf "$WT/x"',
      'WT=/w/wt; cd "$UNSET"; rm -rf "$WT/x"'])
      expect(rmTargets(c).at(-1)).toEqual(t(undefined))
    expect(verdict('Z=S; S=/tmp/x; compgen -V "$Z" -W /etc >/dev/null; rm -rf "$S/y"', 'reviewer')).toContain('cannot resolve')
    // an assignment before `&` or `|` runs in a subshell, so the rm after it reads the shell's own, unset variable
    for (const c of ['WT=/w/wt & rm -rf "$WT/x"', 'WT=/w/wt | rm -rf "$WT/x"']) expect(rmTargets(c)).toEqual([t(undefined)])
    // control: a pipe after the variable is set leaves it set for an rm in the pipeline
    expect(rmTargets('WT=/w/wt; rm -rf "$WT/x" | cat')).toEqual([t('/w/wt/x')])
    // controls: only literal assignments, a literal cd and rm stand between the assignment and its use
    expect(rmTargets('Z=1; S=/tmp/x; cd /w; rm -f a; rm -rf "$S/y"')).toEqual([t('a'), t('/w/a'), t('/tmp/x/y')])
    expect(verdict('Z=1; S=/tmp/x; rm -rf "$S/y"', 'reviewer')).toBeUndefined()
  })
  test('introduced by 2b6ee7ba: a bare operand built from a variable is written ./ whatever its first character', () => {
    expect(rmTargets('S=@; rm -rf "$S/tmp/allow/x"')).toEqual([t('./@/tmp/allow/x')])
    expect(rmTargets('S=:; rm -rf "$S~/scratch/x"')).toEqual([t('./:~/scratch/x')])
    expect(rmTargets('S=x; rm -rf "$S" "$S"/*.o')).toEqual([t('./x'), t('./x', true)])
    expect(rmTargets('S=./sub; rm -rf "$S/x"')).toEqual([t('./sub/x')])
    // controls: an absolute value is placed as is; a literal operand keeps its old reading
    expect(rmTargets('S=/tmp/allow; rm -rf "$S/x" sub/y')).toEqual([t('/tmp/allow/x'), t('sub/y')])
  })
  test('pre-existing: a ${ …; } funsub runs in the current shell and may cd; it ends the walk', () => {
    // after a cd the directory is unknown, as 0.9.0 left it after every cd
    for (const c of ['cd /w && echo "${ cd /etc; }" && rm y', 'cd /w; X="${ cd /etc; }"; rm y', 'cd /w; X="\\${ x; }"; rm y'])
      expect(rmTargets(c)).toEqual([t(undefined)])
    expect(verdict('cd /w; X="${ cd /etc; }"; rm -rf y')).toContain('cannot resolve')
    // known limit (README Limits, #925): with no cd before it, the rm stays in the session directory, as in 0.9.0,
    // though Bash runs it where the funsub's cd went
    for (const c of ['X="${ cd /etc; }"; rm -rf y', 'echo "${| cd /etc; }"; rm -rf y', 'X="${ true; }" && rm -rf y'])
      expect(rmTargets(c)).toEqual([t('y')])
    // control: a $( … ) runs in a subshell, so its cd stays there
    expect(rmTargets('X="$(cd /etc)"; rm -rf y')).toEqual([t('y')])
  })
  test('minor: the heredoc sentinel holds a NUL, so a word Bash can pass is an operand', () => {
    expect(rmTargets('rm -rf \u0001')).toEqual([t('\u0001')])
    expect(rmTargets('rm -rf x \u0001')).toEqual([t('x'), t('\u0001')])
    expect(rmTargets('rm -i /reports/x <<EOF\ny\nEOF')).toEqual([t('/reports/x')])
  })
})

// Task 5 fix round 3 (Ruling 24, type c completed): an rm keeps the variables only as the bare word `rm` after literal
// assignments, since Bash expands an rm's prefix values and a wrapper's operands in the current shell.
describe('batch 5: rm after cd, fix round 3', () => {
  const t = (path: string | undefined, glob = false) => ({ path, glob })
  const verdict = (command: string, role: 'implementer' | 'reviewer' = 'implementer', root = '/w/wt') => decide(role, {
    kind: 'bash', rules: bashRules(command),
    removals: rmTargets(command).map(target => target.path === undefined ? UNREAD
      : removalOf(target.path.startsWith('/') ? target.path : `${root}/${target.path.replace(/^\.\//, '')}`, root, scratchDirs(undefined), target.glob)),
  })
  test('an rm whose prefix or wrapper writes a variable forgets them all (the opposite of mutant N04)', () => {
    // Bash leaves S=5 and removes 5/y (or /etc/5/y after the cd)
    for (const c of ['S=/tmp/x; X="$[S=5]" rm -f /tmp/x/a; rm -rf "$S/y"', 'S=/tmp/x; X=$[S=5] rm -f /tmp/x/a; rm -rf "$S/y"',
      'S=/tmp/x; X="$((S=5))" rm -f /tmp/x/a; rm -rf "$S/y"', 'S=/tmp/x; env X="$((S=5))" rm -f /tmp/x/a; rm -rf "$S/y"',
      'S=/tmp/x; command env X="$[S=5]" rm -f /tmp/x/a; rm -rf "$S/y"', 'Z=S=5; S=/tmp/x; X="$((Z))" rm -f /tmp/x/a; rm -rf "$S/y"',
      'Z=S=5; S=/tmp/x; X="$[Z]" rm -f /tmp/x/a; rm -rf "$S/y"', 'S=/tmp/x; X="$[S=5]" rm -f /tmp/x/a; cd /etc; rm -rf "$S/y"'])
      expect(rmTargets(c)).toEqual([t('/tmp/x/a'), t(undefined)])
    expect(verdict('S=/tmp/x; X="$[S=5]" rm -f /tmp/x/a; rm -rf "$S/y"', 'reviewer')).toContain('cannot resolve')
    expect(verdict('S=/tmp/x; X="$[S=5]" rm -f /tmp/x/a; cd /etc; rm -rf "$S/y"')).toContain('cannot resolve')
    // a wrapper or a path-qualified rm forgets them too, whatever it writes
    for (const c of ['S=/w/wt; env rm -f /w/wt/a; rm -rf "$S/x"', 'S=/w/wt; command rm -f /w/wt/a; rm -rf "$S/x"',
      'S=/w/wt; sudo rm -f /w/wt/a; rm -rf "$S/x"', 'S=/w/wt; /bin/rm -f /w/wt/a; rm -rf "$S/x"', 'S=/w/wt; X="$S" rm -f /w/wt/a; rm -rf "$S/x"'])
      expect(rmTargets(c)).toEqual([t('/w/wt/a'), t(undefined)])
    // controls: literal assignments before the bare rm keep them, and an escaped rm is the bare word
    for (const c of ['S=/w/wt; X=1 rm -f /w/wt/a; rm -rf "$S/x"', 'S=/w/wt; X=1 Y=/w rm -f /w/wt/a; rm -rf "$S/x"',
      'S=/w/wt; \\rm -f /w/wt/a; rm -rf "$S/x"', 'S=/w/wt; rm -f /w/wt/a; rm -rf "$S/x"'])
      expect(rmTargets(c)).toEqual([t('/w/wt/a'), t('/w/wt/x')])
    expect(verdict('S=/tmp/x; X=1 rm -f /tmp/x/a; rm -rf "$S/y"', 'reviewer')).toBeUndefined()
  })
})


// Final fix wave, I1 (ledger 117): inside a `$(…)` Bash 5.3 also ends a heredoc at a body line that starts with the
// delimiter and holds a `)` after it, with a warning, and reads the rest of that line as command text. A top-level
// heredoc, and one in a backtick span, close only at a line that is exactly the delimiter (probed under Bash 5.3.9).
describe('batch 5 fix wave: a heredoc in a $(…) closes at a line that starts with its delimiter and holds a `)`', () => {
  const t = (path: string | undefined, glob = false) => ({ path, glob })
  test('the `EOF)` commit form: a force-push or an rm after it is read', () => {
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nmsg\nEOF)\" && git push --force")).toEqual(['commit', 'push', 'force-push'])
    expect(bashRules("git commit --amend -m \"$(cat <<'EOF'\nmsg\nEOF)\" && git push --force-with-lease")).toEqual(['commit', 'push', 'force-push'])
    expect(rmTargets("git commit -m \"$(cat <<'EOF'\nmsg\nEOF)\" && rm -rf /etc/x")).toEqual([t('/etc/x')])
    expect(substitutionsOf("git commit -m \"$(cat <<'EOF'\nmsg\nEOF)\" && git push --force")).toEqual(["cat <<'EOF'\nmsg\nEOF"])
  })
  test('unquoted, after <<-, nested, and with a command between the delimiter and the `)`', () => {
    expect(bashRules('x=$(cat <<EOF\nmsg\nEOF) && git push --force')).toEqual(['push', 'force-push'])
    expect(bashRules('x=$(cat <<-EOF\nmsg\n\tEOF) && git push --force')).toEqual(['push', 'force-push'])
    expect(bashRules('x=$(echo $(cat <<EOF\nmsg\nEOF) && git push --force)')).toEqual(['push', 'force-push'])
    // Bash reads the rest of the closing line as the next line of the substitution, so it runs the push
    expect(bashRules('x=$(cat <<EOF\nmsg\nEOF git push --force)')).toEqual(['push', 'force-push'])
    expect(substitutionsOf('x=$(cat <<EOF\nmsg\nEOF git push --force)')).toEqual(['cat <<EOF\nmsg\nEOF\n git push --force'])
    expect(rmTargets('x=$(cat <<EOF\nmsg\nEOF rm -rf /etc/x)')).toEqual([t('/etc/x')])
  })
  test('control: the standard commit form and a body line that only starts with the delimiter stay allowed', () => {
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nmsg\nEOF\n)\"")).toEqual(['commit'])
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nfeat: x\n\ngit push --force is denied.\nEOF\n)\"")).toEqual(['commit'])
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nmsg\nEOF)\"")).toEqual(['commit'])
    expect(rmTargets("git commit -m \"$(cat <<'EOF'\nmsg\nEOF)\"")).toEqual([])
    // no `)` after the delimiter: Bash does not close there
    expect(bashRules("git commit -m \"$(cat <<'EOF'\nEOFs are fine; git push --force\nEOF\n)\"")).toEqual(['commit'])
  })
  test('control: a top-level heredoc and one in a backtick span close only at the exact line', () => {
    expect(bashRules('cat <<EOF\nEOFs are fine\nEOF\n')).toEqual([])
    expect(bashRules('cat <<EOF\nEOFs are fine (really) && git push --force\nEOF\n')).toEqual([])
    expect(rmTargets('cat <<EOF\nEOF) && rm -rf /etc/x\nEOF\n')).toEqual([])
    expect(bashRules('x=`cat <<EOF\nmsg\nEOF) git push --force\n`')).toEqual([])
  })
  // Known-limit pins (README Limits): the rule is read only for a `$(` opened on the opener's line, only for the last
  // opener on that line, and not on a line a backslash joined. Bash runs the push in all three.
  test('known limit: a $( on an earlier line, an earlier opener on the line, or a joined line is not seen closing', () => {
    expect(bashRules('x=$(\ncat <<EOF\nmsg\nEOF) && git push --force')).toEqual([])
    expect(bashRules('x=$(cat <<EOF\nmsg\nEO\\\nF) && git push --force')).toEqual([])
    expect(bashRules("x=$(cat <<'EOF' <<B\nb\nB\nmsg\nEOF) && git push --force")).toEqual([])
  })
  // Ruling 33: the `$(` check reads the opener's logical line, from the last newline outside quotes, not its physical
  // line, so a quoted string that spans lines neither opens a `$(` that is text nor hides one that is real (probed under
  // Bash 5.3.9: the first two run no rm and no push, the third runs the push).
  test('a quoted string spanning lines: a `$(` inside it is text, and one after it is read', () => {
    expect(rmTargets("printf '%s\\n' 'x\n$(' >/dev/null; git commit -F - <<'EOF'\nmsg\nEOF) ; rm -rf /etc/x\nEOF")).toEqual([])
    expect(bashRules("printf '%s\\n' 'x\n$(' >/dev/null; git commit -F - <<'EOF'\nmsg\nEOF) ; rm -rf /etc/x\nEOF")).toEqual(['commit'])
    expect(bashRules("echo '\n$(' ; cat <<EOF\nEOF) && git push --force\nEOF")).toEqual([])
    expect(bashRules('echo "\n\\$(" ; cat <<EOF\nEOF) && git push --force\nEOF')).toEqual([])
    expect(bashRules("echo 'a\nb' ; x=$(cat <<EOF\nmsg\nEOF) ; git push --force")).toEqual(['push', 'force-push'])
    expect(bashRules('echo "a\nb" ; x=$(cat <<EOF\nmsg\nEOF) ; git push --force')).toEqual(['push', 'force-push'])
    expect(bashRules("git add 'a\nb' && git commit -m \"$(cat <<'EOF'\nmsg\nEOF)\"")).toEqual(['commit'])
    // a heredoc body on the logical line is not read as its text: here a `'(` in an earlier body would open a `$(`
    expect(bashRules("y=$(cat <<A\n'(\nA) ; cat <<B\nB) ; git push --force\nB")).toEqual([])
    // after a heredoc body the line resumes in the opener's quote: here inside the `"…"`, which `)"` closes, so `'$('` is text
    expect(bashRules("git commit -m \"$(cat <<'A'\na\nA\n)\" ; echo '$(' ; cat <<B\nB) ; git push --force\nB\n")).toEqual(['commit'])
    // a `$(` before a newline in quotes, or before a backslash-newline, is on the opener's logical line: Bash runs the push
    expect(bashRules("git commit -m \"$(\ncat <<'EOF'\nmsg\nEOF)\" && git push --force")).toEqual(['commit', 'push', 'force-push'])
    expect(bashRules("git commit -m \"$(\ncat <<'EOF'\nmsg\nEOF)\"")).toEqual(['commit'])
    expect(bashRules('x=$( \\\ncat <<EOF\nmsg\nEOF) && git push --force')).toEqual(['push', 'force-push'])
  })
  // Ruling 34: the scan's own quote reading does not nest quotes inside `$(…)`, so after `"$(echo "it's")"` it sits in a `'`
  // that Bash never opened. A heredoc body resumed in that quote must not flip the next line's quotes: a seeded reading
  // closes a heredoc early only when the unseeded one agrees (probed under Bash 5.3.9: no push, no rm).
  test('a quote the scan misreads inside "$(…)" is not carried past a heredoc body into an early close', () => {
    expect(bashRules("git commit -m \"$(echo \"it's done\")\" --allow-empty && cat <<'EOF'\nnotes\nEOF\necho 'call $(' ; cat <<EOF\nEOF) ; git push --force\nEOF")).toEqual(['commit'])
    expect(rmTargets("echo \"$(echo \"'\")\" ; cat <<'X'\nx\nX\necho a' $(' ; cat <<EOF\nEOF) ; rm -rf /etc/x\nEOF")).toEqual([])
    // controls: the resume after a real `"$(…)"` body still reads a `$(` opened after it
    expect(bashRules("x=\"$(cat <<A\na\nA\n)\" ; y=$(cat <<B\nB) ; git push --force\nB")).toEqual(['push', 'force-push'])
  })
  // Known limit (README Limits): the logical line restarts where the scan resumes after a heredoc body, so a `$(` before
  // an earlier heredoc's body is not seen. Bash runs the push.
  test('known limit: a $( before an earlier heredoc body on the line is not seen', () => {
    expect(bashRules("git commit -m \"$(cat <<'A'\na\nA\ncat <<'EOF'\nmsg\nEOF)\" && git push --force")).toEqual(['commit'])
  })
  // Known limit (README Limits, since 85fe6564): after `"$(echo "'")"` and a heredoc body the scan resumes in a `'` Bash never
  // opened, so the seeded and unseeded readings of the next line disagree and the close is not read. Bash runs the push;
  // af88a29e's physical-line reading caught it.
  test('known limit: a quote the scan misreads inside "$(…)" before a heredoc body hides a later close', () => {
    expect(bashRules("echo \"$(echo \"'\")\" ; cat <<'X'\nx\nX\nx=$(cat <<EOF\nmsg\nEOF) ; git push --force\nEOF\n)\n")).toEqual([])
  })
})

describe('PR 923 round 1: an opener line read in the 0.9.0 layout keeps its tail for the rm walk', () => {
  // The tail after the delimiter word goes into the heredoc piece when it holds a `$(`, a backtick or a `${`. 0.9.0 put
  // that tail back for rm; the walk must still see an rm there (Bash runs it).
  test('an rm in a $(…), backtick or ${…} opener tail is seen', () => {
    for (const x of ['$(x)', '`x`', '${x}']) {
      expect(rmTargets(`cat <<EOF; rm -rf /boot; echo ${x}\nbody\nEOF`)).toEqual([{ path: '/boot', glob: false }])
    }
  })
  // controls: the body stays input, and the new-layout and quoted-delimiter tails read as before
  test('the body stays input and other tails still read', () => {
    expect(rmTargets('cat <<EOF; echo $(x)\nrm -rf /boot\nEOF')).toEqual([])
    expect(rmTargets('cat <<EOF && rm -rf /boot\nbody\nEOF')).toEqual([{ path: '/boot', glob: false }])
    expect(rmTargets("cat <<'EOF'; rm -rf /boot\nbody\nEOF")).toEqual([{ path: '/boot', glob: false }])
  })
})

describe('PR 923 round 2: a funsub spelling in text Bash does not expand leaves the directory known', () => {
  // `${ ` or `${|` inside single quotes, after an escape, in a comment or in a heredoc body runs nothing; 0.9.0 placed
  // the rm in the session directory, and so does this.
  test('quoted, escaped, commented and heredoc-body spellings do not unknow the directory', () => {
    for (const c of ["echo '${ x}'; rm scratch.txt", 'echo \\${ x}; rm scratch.txt', 'rm scratch.txt # note ${ x} form',
      "cat <<'E'\n${ x}\nE\nrm scratch.txt", "echo $'${| x}'; rm scratch.txt"]) {
      expect(rmTargets(c)).toEqual([{ path: 'scratch.txt', glob: false }])
    }
  })
  // controls: after a cd, a real funsub, unquoted or in double quotes, still makes the directory unknown
  test('after a cd a real funsub still makes the directory unknown', () => {
    for (const c of ['cd /w; X="${ cd /etc; }"; rm -rf y', 'cd /w; echo "${| cd /etc; }"; rm -rf y', 'cd /w; X=${ cd /etc; }; rm -rf y']) {
      expect(rmTargets(c)).toEqual([{ glob: false }])
    }
  })
})
