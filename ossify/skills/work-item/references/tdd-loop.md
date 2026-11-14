# The TDD loop, per AC

_Call the `oss` dispatcher by name. The plugin loader puts `bin/` on `$PATH` on Claude Code, Codex and OMP, so `oss` resolves in every Bash call; a variable set in one call is gone in the next._

Depth for SKILL.md §5. One AC at a time, in the order `oss verify_acs` printed
them, each driven RED→GREEN before the next one starts.

---

## 1. Worked walk-through

A work item on a Markdown table-of-contents generator. Its spec declares four
`auto:` ACs, and `oss verify_acs` prints them in this order:

```
AC-1  pytest tests/test_slugify.py::test_ascii_slug        exit 0
AC-2  pytest tests/test_slugify.py::test_duplicate_suffix  exit 0
AC-3  python -m tocgen sample.md                           output contains - [Install](#install)
AC-4  pytest tests/                                        exit 0
```

### RED gate first (SKILL.md §4)

```bash
oss redgate "<worktree-abs>" "pytest tests/test_slugify.py::test_ascii_slug" "exit 0"
# rc 0 — RED. tests/test_slugify.py does not exist yet, so pytest exits nonzero. Proceed.

oss redgate "<worktree-abs>" "python -m tocgen sample.md" "output contains - [Install](#install)"
# rc 0 — RED. The generator runs but emits no anchor links yet. Proceed.
```

RED for that reason on AC-1 and AC-2 is the ordinary case, not a problem: the test
file is something step 1 below is about to write. Note it in the report's
`## 8. Blockers and advisories`. Nothing here blocks.

### AC-1 — ASCII slugs

1. **Write the failing test.** The expectation is `exit 0`, so the test asserts
   the behaviour, and its failure is the assertion failing:

   ```python
   # <worktree-abs>/tests/test_slugify.py
   from tocgen.slugify import slugify

   def test_ascii_slug():
       assert slugify("Getting Started") == "getting-started"
   ```

2. **Run it, watch it fail.**

   ```bash
   cd "<worktree-abs>" && pytest tests/test_slugify.py::test_ascii_slug
   # ModuleNotFoundError: No module named 'tocgen.slugify'  → RED, as expected
   ```

   The failure is the point. It proves the test reaches the behaviour under test
   rather than passing on an accident of imports.

3. **Minimum implementation.** Lowercase, strip non-alphanumerics, join on `-`.
   Nothing about duplicates yet — that is AC-2's job, and writing it now is
   over-implementing (§3).

4. **Run it again, watch it pass.** One green test, one AC closed.

### AC-2 — duplicate headings get a numeric suffix

Same four beats. The new test fails first (`slugify` has no memory of what it
already emitted), then the minimum implementation adds a seen-set and a `-2`
suffix, then it passes.

**Do not fold this into AC-1.** Two ACs implemented before either is verified
means that when the pair goes red you cannot tell which half broke, and the
RED→GREEN evidence for both is gone.

### AC-3 — the rendered output contains the anchor

The expectation is `output contains - [Install](#install)`, matched literally, so
the test asserts on captured stdout:

```bash
cd "<worktree-abs>" && python -m tocgen sample.md | grep -F -- "- [Install](#install)"
```

The RED probe already returned 0 here, so this AC starts genuinely red. Wire the
slugger into the renderer, re-run, watch it pass.

### AC-4 — the full suite

The last AC is a whole-suite run, and it is the one most often skipped because
"the individual tests passed". Run it anyway: it is the only step that catches the
regression AC-2's seen-set introduced in an unrelated test that shared the module.

---

## 2. GREEN on the first run

Sometimes step 2 does not fail. Two cases are legitimate; both must be **noted in
the report**, and both need the same sanity check first.

1. **Cascade from a sibling AC.** AC-2's minimum implementation already satisfied
   AC-3, so AC-3's brand-new test passes immediately. Ordinary in a coherent work
   item, and good news.
2. **The RED gate read only a missing file, and the behaviour was already there.**
   The test file did not exist, so RED said nothing about the code; the newly written test
   passes on first run because the production code already handled the case (a
   library default, a framework behaviour).

**The sanity check, in both cases:** break the production code once, watch the
new test go red, restore from a copy saved outside the worktree, never from git.
A test that passes with and without the behaviour tests nothing; vacuous green
is worse than a failure — it ships as evidence.

Anything else that goes green on the first run is a third case, and it is not
legitimate — but **"the work item was already done" is usually the wrong
diagnosis**, and gaps-mode is the wrong response.

Already-done is mostly ruled out by arithmetic: if the gate probed this AC and
returned rc 0, the AC's own command **failed** at gate time, minutes ago. Two
causes actually fit:

- **The test is misaimed or tautological.** It asserts something that was always
  true — it imports the module and checks it imports, it asserts on a fixture it
  built itself, it matches a substring present in the error message too. This is
  §3's pitfall territory and it is the common case. Break the production code,
  re-run, and if the test still passes you have found it; restore from a copy saved
  outside the worktree, never from git.
- **The gate probe and the new test disagree.** The probe ran a different command,
  a different working directory, or a different fixture state than your test. Read
  both side by side; the difference is the finding.

**Do not return gaps-mode here.** It is out of bounds: gaps-mode is a gate-phase
exit (SKILL.md §3 + §4) and the loop is past it — `returns.md` §4 carries the
reasoning. Instead: stop, diagnose which of
the two it is, record the finding in `## 8. Blockers and advisories`, then proceed
or halt under the structural-surprise rule (SKILL.md §5). A first-run green you
have diagnosed and written down is an honest result; one you routed into a late
gaps-mode return is a stranded work item.

---

## 3. Pitfalls

- **Skipping RED.** Writing the implementation first and the test after produces a
  test shaped like the code instead of like the requirement. It passes on the
  first run every time, which is how you can tell.
- **Over-implementing.** The minimum that makes *this* AC pass, and no more. Code
  written ahead of an AC is code no test drove and no reviewer expected.
- **Combining ACs.** See AC-2 above. The gate goes opaque exactly when you need it
  most.
- **Forgetting the full-suite re-run.** Per-AC greens do not compose. The suite is
  the only place a cross-AC regression shows up before close.
- **Accepting a vacuous green.** A runner that collects zero tests exits 0 and
  reads as a pass:

  ```bash
  cd "<worktree-abs>" && pytest tests/ 2>&1 | oss zero_tests_guard "pytest tests/"
  # rc 0 = VACUOUS — the command is a test runner and it ran nothing
  # rc 1 = a real run
  ```

  The rc reads backwards from instinct: **0 means the guard fired.** The demo
  runner at close applies the same guard, so a vacuous green found here is one
  found two ceremonies early.
- **Editing the test to match the implementation** when they disagree. The spec
  decides which one is wrong, and if the spec is silent that belongs in the
  report's `## 7. Deviations from spec`, not in a quiet edit.
- **Relative paths.** Every path in this file is absolute or reached through
  `cd "<worktree-abs>" && …` in a single invocation. Your cwd is the caller's, and
  each Bash call starts a fresh shell.
