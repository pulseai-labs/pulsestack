// The example ossify-spine recipe, end to end: baton's real engine drives it against the fake
// host, a forge that lands real merge commits, a fake `oss` over a real state file, and real
// temp git repos. The seats are callbacks (`effects`): each makes, when its thread completes,
// the file and state changes a real seat makes through `oss`. Nothing here runs a model.

import { afterEach, beforeEach, expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, realpathSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { main } from "../src/cli.ts";
import { tick } from "../src/engine.ts";
import type { PrView } from "../src/forge.ts";
import type { LaunchRequest } from "../src/host.ts";
import { notifyOnce } from "../src/notify.ts";
import { openStore, type RunState } from "../src/state.ts";
import { commit, FakeForge, git } from "./fake-forge.ts";
import { type Behaviour, FakeHost } from "./fake-host.ts";
import { loadRecipe, raw, RECIPE_PATH } from "./ossify-recipe-helpers.ts";

const FAKE_OSS = join(import.meta.dir, "fixtures", "fake-oss");
const BRIEFS = join(import.meta.dir, "..", "examples", "ossify-spine", "briefs");
const SPINE = "r0.s6";
const BRANCH = "spine/r0.s6-demo";
const W1 = "r0.s6.w1";
const W2 = "r0.s6.w2";
const SPINE_UNIT = "spine-pr";
const T0 = Date.parse("2026-10-22T10:00:00.000Z");
/** Each tick moves the clock 5 minutes: a quiet session settles (10 minutes) after two. */
const STEP_MS = 5 * 60_000;

const saved = { state: process.env.BATON_STATE_DIR, config: process.env.BATON_CONFIG, home: process.env.HOME };
let root: string, state: string, aiRoot: string, stateFile: string, spineDir: string;
let repo: string, origin: string, other: string, runDir: string, clock: number, aiOrigin: string;

beforeEach(() => {
  root = realpathSync(mkdtempSync(join(tmpdir(), "baton-ossify-e2e-")));
  state = join(root, "state");
  mkdirSync(join(root, "home"));
  process.env.BATON_STATE_DIR = state;
  process.env.BATON_CONFIG = join(root, "config.json");
  process.env.HOME = join(root, "home");
  aiRoot = join(root, "ai");
  stateFile = join(aiRoot, ".ossify", "project-state.json");
  spineDir = join(aiRoot, "docs", "spines", SPINE);
  mkdirSync(dirname(stateFile), { recursive: true });
  mkdirSync(spineDir, { recursive: true });
  for (const wi of [W1, W2]) mkdirSync(join(root, "wt", wi), { recursive: true });
  // The canonical: a bare origin, the canonical root on the spine branch, and a second clone
  // the forge lands merges from.
  origin = join(root, "origin.git");
  repo = join(root, "canon");
  other = join(root, "other");
  git(root, "init", "--bare", "-b", "main", origin);
  git(root, "clone", origin, repo);
  git(root, "clone", origin, other);
  for (const d of [repo, other]) {
    git(d, "config", "user.email", "t@example.com");
    git(d, "config", "user.name", "t");
    git(d, "config", "commit.gpgsign", "false");
  }
  commit(repo, "init");
  git(repo, "push", "origin", "main");
  git(repo, "checkout", "-b", BRANCH);
  git(repo, "push", "-u", "origin", BRANCH);
  git(other, "fetch", "origin");
  runDir = join(state, "runs", "r1");
  clock = T0;
  setState({ [W1]: 0, [W2]: 0 });
  // The AI workspace: a git repo whose origin holds the state file, as spine_finish reads it (#1095).
  aiOrigin = join(root, "ai-origin.git");
  git(root, "init", "--bare", "-b", "main", aiOrigin);
  git(aiRoot, "init", "-b", "main");
  git(aiRoot, "remote", "add", "origin", aiOrigin);
  for (const [k, v] of [["user.email", "t@example.com"], ["user.name", "t"], ["commit.gpgsign", "false"]]) git(aiRoot, "config", k, v);
  git(aiRoot, "add", ".ossify/project-state.json");
  git(aiRoot, "commit", "-m", "state");
  git(aiRoot, "push", "origin", "main");
});
afterEach(() => {
  for (const [k, v] of [["BATON_STATE_DIR", saved.state], ["BATON_CONFIG", saved.config], ["HOME", saved.home]] as const) {
    if (v === undefined) delete process.env[k];
    else process.env[k] = v;
  }
  rmSync(root, { recursive: true, force: true });
});

// ---- ossify's state, through the fake `oss` -------------------------------------------------

type Item = { id: string; status: string; dispatches: number; pr_url?: string };
function setState(dispatches: Record<string, number>): void {
  const work_items = Object.entries(dispatches).map(([id, d]) => ({ id, status: "active", dispatches: d }));
  writeFileSync(stateFile, JSON.stringify({ spines: [{ id: SPINE, status: "active" }], work_items }, null, 2));
}
const readState = () => JSON.parse(readFileSync(stateFile, "utf8")) as { spines: { id: string; status: string }[]; work_items: Item[] };
const item = (wi: string): Item => readState().work_items.find((w) => w.id === wi)!;
function oss(...args: string[]): void {
  const p = Bun.spawnSync([FAKE_OSS, ...args], { cwd: aiRoot, stdout: "pipe", stderr: "pipe" });
  if (p.exitCode !== 0) throw new Error(`fake-oss ${args.join(" ")}: rc ${p.exitCode} ${p.stderr.toString()}`);
}

// ---- the forge -------------------------------------------------------------------------------

const PR_NO: Record<string, number> = { [W1]: 1, [W2]: 2, [SPINE_UNIT]: 9 };
const prUrl = (unit: string) => `https://github.com/o/canon/pull/${PR_NO[unit]}`;
const HEAD0 = "d".repeat(40);
const openPr = (base: string): PrView => ({ state: "OPEN", head: HEAD0, base, mergeable: "MERGEABLE", checks: "green" });

/** e2e.test.ts's LandingForge on the spine branch: a merge lands a real merge commit on origin. */
class SpineForge extends FakeForge {
  /** origin's spine tip right after each PR's merge commit was pushed, by URL. */
  landedTip = new Map<string, string>();
  constructor() {
    super();
    for (const wi of [W1, W2]) this.views.set(prUrl(wi), openPr(BRANCH));
    this.views.set(prUrl(SPINE_UNIT), openPr("main"));
  }
  override async merge(url: string, head: string): Promise<void> {
    await super.merge(url, head);
    const name = Object.keys(PR_NO).find((u) => prUrl(u) === url)!;
    git(other, "fetch", "origin");
    git(other, "checkout", "-B", BRANCH, `origin/${BRANCH}`);
    git(other, "checkout", "-b", `pr-${name}`);
    const branchHead = commit(other, `pr-${name}`);
    git(other, "checkout", BRANCH);
    git(other, "merge", "--no-ff", "-m", `merge ${name}`, `pr-${name}`);
    git(other, "push", "origin", BRANCH);
    this.landedTip.set(url, git(other, "rev-parse", "HEAD"));
    this.views.set(url, { ...this.views.get(url)!, state: "MERGED", head: branchHead });
  }
}
const originTip = () => git(origin, "rev-parse", BRANCH);
const repoTip = () => git(repo, "rev-parse", BRANCH);
const mergeCommits = () => git(origin, "log", "--merges", "--reverse", "--format=%s", BRANCH).split("\n").filter(Boolean);

// ---- the host and its seats --------------------------------------------------------------------

/** `[baton <run>/<unit>/<stage>/<seq>]` in a launch title. */
function nonceParts(r: LaunchRequest): { unit: string; stage: string } {
  const m = /\[baton ([^\]]*)\]\s*$/.exec(r.title)!;
  const [, unit, stage] = m[1].split("/");
  return { unit, stage };
}

type Effect = (unit: string, n: number) => void;

/** FakeHost plus seats: when a thread completes, `effects[stage](unit, n)` runs, n its nth completion. */
class SeatHost extends FakeHost {
  advances = 0;
  effects: Record<string, Effect> = {};
  private born: number[] = [];
  private completions = new Map<string, number>();
  override async launch(r: LaunchRequest): Promise<{ threadId: string }> {
    const res = await super.launch(r);
    this.born.push(this.advances);
    return res;
  }
  override advance(): void {
    super.advance();
    this.advances++;
    this.launches.forEach((l, i) => {
      if (this.advances - this.born[i] !== l.behaviour.ticks) return;
      const { unit, stage } = nonceParts(l.request);
      const key = `${unit}/${stage}`;
      const n = (this.completions.get(key) ?? 0) + 1;
      this.completions.set(key, n);
      this.effects[stage]?.(unit, n);
    });
  }
  of(unit: string, stage: string) {
    return this.launches.filter((l) => {
      const p = nonceParts(l.request);
      return p.unit === unit && p.stage === stage;
    });
  }
}

/** A closed item's way to the merge when its review passes at once: record the PR, review, wait, land. */
const TO_LAND = ["close>item_ready", "item_ready>item_review", "item_review>item_wait", "item_wait>land"];
const SESSION_STAGES = ["lane", "implement", "regap", "verify", "close", "correct", "item_review", "item_fix", "spine_open", "spine_review", "spine_work", "spine_finish"];
const oneTick = (): Behaviour => ({ ticks: 1, end: "completed" });

const out = (unit: string, name: string) => join(runDir, "out", unit, name);
const workFile = (wi: string, name: string) => join(spineDir, `work-${wi}`, name);
function put(path: string, content: string): void {
  mkdirSync(dirname(path), { recursive: true });
  // temp name without .json, then rename: baton parks the whole run on a half-written record
  writeFileSync(path + ".tmp", content);
  renameSync(path + ".tmp", path);
}

/** ossify's §3 request record, flat (ruling T2-1), plus round, order and issued_at. */
function queue(wi: string, round: number, order: number, issuedAt = new Date(clock).toISOString()): void {
  put(join(runDir, "queue", `${wi}.json`), JSON.stringify({
    work_item_id: wi,
    target_repo: "canonical",
    handoff_path: workFile(wi, "handoff.md"),
    spec_path: workFile(wi, "spec.md"),
    worktree_path: join(root, "wt", wi),
    branch: `work/${wi}`,
    base_sha: "a".repeat(40),
    round, order, issued_at: issuedAt,
  }));
}

/** What a seat that does its job writes, per stage. Tests replace entries. */
function seats(): Record<string, Effect> {
  return {
    implement: (u) => put(workFile(u, "report.md"), "report"),
    verify: (u) => put(out(u, "verdict.json"), verdict(u, [])),
    // close on the verdict: a halting one (a stayed-green mutation) is a red gate, so the packet
    close: (u) => {
      const v = JSON.parse(readFileSync(out(u, "verdict.json"), "utf8")) as { mutation: { result: string }[] };
      if (v.mutation.some((m) => m.result === "stayed-green")) put(out(u, "correction.txt"), packet(u, "[mutation] t1 stayed green"));
      else oss("work_item_pr", u, prUrl(u));
    },
    correct: (u) => put(out(u, "corrected"), "x"),
    regap: (u) => {
      const rec = JSON.parse(readFileSync(join(runDir, "queue", `${u}.json`), "utf8"));
      queue(u, rec.round, rec.order, new Date(clock + 1000).toISOString());
    },
    spine_open: () => put(join(runDir, "spine", `${SPINE_UNIT}.json`),
      JSON.stringify({ id: SPINE_UNIT, group: 0, order: 0, pr_url: prUrl(SPINE_UNIT) })),
    // an item reviewer reviews the head its PR has now
    item_review: (u) => put(out(u, "review.md"), `verdict: pass\nhead: ${theForge.views.get(prUrl(u))!.head}\nno findings\n`),
    item_fix: (u) => put(out(u, "round-done"), "x"),
    // the spine reviewer, like the item reviewer, reviews the head the PR has now
    spine_review: (u) => put(out(u, "review.md"), `verdict: pass\nhead: ${theForge.views.get(prUrl(u))!.head}\nno findings\n`),
    spine_work: (u) => put(out(u, "round-done"), "x"),
    // a workspace that pushes to main: the second pass closes the spine and lands the record at origin/main
    spine_finish: () => {
      closeLocally();
      git(aiRoot, "commit", "-am", "close");
      git(aiRoot, "push", "origin", "main");
    },
  };
}
function closeLocally(): void {
  const s = readState();
  s.spines.find((x) => x.id === SPINE)!.status = "closed";
  writeFileSync(stateFile, JSON.stringify(s, null, 2));
}
const CLOSE_PR = "https://github.com/o/ai/pull/30";
/** A workspace that lands records only through PRs: the close goes on a branch, its PR is recorded, the root goes back to main. */
function closeOnBranch(prLine = CLOSE_PR): void {
  git(aiRoot, "switch", "-c", "docs/close");
  closeLocally();
  git(aiRoot, "commit", "-am", "close");
  git(aiRoot, "push", "origin", "docs/close");
  put(out(SPINE_UNIT, "close-pr.txt"), prLine + "\n");
  git(aiRoot, "switch", "main");
}

/** The verify seat's verdict file: Task 1's shape, one JSON object. */
function verdict(wi: string, mutation: { test: string; mutation: string; result: string; evidence: string }[]): string {
  return JSON.stringify({ mode: "verified", model: "m-1", agent: "verifier-agent-x", work_item_id: wi, identity: "c".repeat(40),
    rule: [], lenses: [], mutation });
}
const STAYED_GREEN = [{ test: "t1", mutation: "x -> y", result: "stayed-green", evidence: "pass" }];

/** What close writes on a red gate: ossify's correction packet (correction-continuation.md §2). */
function packet(wi: string, failure: string): string {
  return ["OSSIFY CORRECTION CONTINUATION v1", `handoff_path: ${workFile(wi, "handoff.md")}`, `work_item_id: ${wi}`,
    `expected_branch: work/${wi}`, `expected_head_sha: ${"a".repeat(40)}`, `expected_tree_oid: ${"b".repeat(40)}`,
    "failures:", `- ${failure}`, ""].join("\n");
}
/** A Layer 4 red: close writes the `[fidelity]` finding to verify.md and the packet. */
const fidelityRed = (u: string) => {
  put(workFile(u, "verify.md"), "## Findings\n- [fidelity] AC2 is not what the spec says\n");
  put(out(u, "correction.txt"), packet(u, "[fidelity] AC2 is not what the spec says"));
};

function newHost(lane: Effect, extra: Record<string, Effect> = {}): SeatHost {
  const host = new SeatHost(Object.fromEntries(SESSION_STAGES.map((s) => [s, oneTick()])));
  host.effects = { ...seats(), lane, ...extra };
  return host;
}

/** The run's role table: one agent per D2 role, as `running-a-spine-on-baton` writes it. */
const SEATS = Object.fromEntries(
  ["spine session", "implementer", "verifier", "close session", "reviewer", "item reviewer", "work-PR session", "driver"].map((role) => [role, {
    agent: `${role.replaceAll(" ", "-").toLowerCase()}-agent`, argv: ["seat-bin", role], brief_delivery: "inject",
    expected_model: `${role}-model`, effort: "high", env: {}, ...(role === "reviewer" || role === "item reviewer" ? { review: "/review" } : {}),
  }]),
);

async function arm(recipePath: string = RECIPE_PATH): Promise<void> {
  loadRecipe(); // throws with baton's errors if the example does not validate
  const params: Record<string, string> = {
    spine: SPINE, spine_branch: BRANCH, spine_dir: spineDir, ai_root: aiRoot, ai_project: "demo-ai",
    repo, project: "demo", state_file: stateFile, oss: FAKE_OSS, briefs: BRIEFS,
  };
  const seatsFile = join(root, "seats.json");
  writeFileSync(seatsFile, JSON.stringify(SEATS));
  const args = ["arm", recipePath, "--run", "r1", "--seats", seatsFile, "--no-timer"];
  for (const [k, v] of Object.entries(params)) args.push("--param", `${k}=${v}`);
  expect(await main(args)).toBe(0);
}

const readRun = (): RunState => openStore(state).readRun("r1");
const unit = (id: string) => readRun().units[id];
type Ev = Record<string, string>;
const events = (): Ev[] =>
  readFileSync(join(runDir, "events.jsonl"), "utf8").trim().split("\n").map((l) => JSON.parse(l) as Ev);
const moves = (u: string) => events().filter((e) => e.kind === "transition" && e.unit === u).map((e) => `${e.from}>${e.to}`);
/** Index in events.jsonl of the first event matching `f`; -1 when none. */
const at = (f: (e: Ev) => boolean) => events().findIndex(f);
const moved = (u: string, from: string, to: string) => at((e) => e.kind === "transition" && e.unit === u && e.from === from && e.to === to);
const launchedEv = (u: string, stage: string, seq = 1) => at((e) => e.kind === "launched" && e.nonce === `r1/${u}/${stage}/${seq}`);

type Rig = { host: SeatHost; forge: SpineForge; notes: string[] };
let theForge: SpineForge;
function rig(host: SeatHost, forge = new SpineForge()): Rig {
  theForge = forge;
  return { host, forge, notes: [] };
}

/** tick, advance (seats run), `between(i)`, clock +5 min; stops when `until` holds. Returns ticks run. */
async function drive(r: Rig, max: number, until: () => boolean, between: (i: number) => void = () => {}): Promise<number> {
  for (let i = 1; i <= max; i++) {
    const now = new Date(clock);
    await tick({
      store: openStore(state), host: r.host, forge: r.forge, now: () => now,
      notify: async (k, m) => { r.notes.push(m); await notifyOnce(k, m); },
    });
    r.host.advance();
    between(i);
    clock += STEP_MS;
    if (until()) return i;
  }
  throw new Error(`drive: condition not met in ${max} ticks; units: ${JSON.stringify(Object.values(readRun().units).map((u) => [u.id, u.stage, u.parked?.reason ?? null]))}`);
}
const settle = async (r: Rig, n: number) => {
  let i = 0;
  await drive(r, n, () => ++i >= n);
};

// ---- the tests -----------------------------------------------------------------------------------

test("a two-item round runs to the second spine close", async () => {
  await arm();
  const host = newHost((_u, n) => {
    if (n === 1) {
      queue(W1, 1, 1);
      queue(W2, 1, 2);
      put(out("lane", "lane.done"), "x");
    } else put(join(runDir, "rounds.done"), "x");
  });
  const r = rig(host);
  const seen: Record<string, { repo: string; head: string; status: string; dispatches: number }> = {};
  await drive(r, 80, () => readRun().status === "done", () => {
    const run = readRun();
    for (const wi of [W1, W2]) {
      if (run.units[wi]?.stage === "done" && !seen[wi]) {
        seen[wi] = { repo: repoTip(), head: git(repo, "symbolic-ref", "--short", "HEAD"), status: item(wi).status, dispatches: item(wi).dispatches };
      }
    }
    // The operator merges the spine PR by hand once baton asks.
    if (run.units[SPINE_UNIT]?.stage === "spine_ack") {
      r.forge.views.set(prUrl(SPINE_UNIT), { ...r.forge.views.get(prUrl(SPINE_UNIT))!, state: "MERGED", head: "spinehead" });
    }
  });

  const run = readRun();
  expect(run.status).toBe("done");
  // w1 merged before w2, each as one merge commit on the spine branch.
  expect(r.forge.merges.map((m) => m.url)).toEqual([prUrl(W1), prUrl(W2)]);
  expect(mergeCommits()).toEqual([`merge ${W1}`, `merge ${W2}`]);
  // After each merge the canonical root's spine branch is origin's as that merge left it.
  for (const wi of [W1, W2]) {
    expect(seen[wi]).toEqual({ repo: r.forge.landedTip.get(prUrl(wi))!, head: BRANCH, status: "complete", dispatches: 1 });
  }
  expect(repoTip()).toBe(originTip());
  for (const wi of [W1, W2]) expect(moves(wi)).toEqual(["implement>verify", "verify>close", ...TO_LAND, "land>done"]);
  // verify launched in the item worktree on the verifier's agent, told its name and the verdict file
  const v = host.of(W1, "verify")[0];
  expect([v.request.instance, v.request.model]).toEqual(["verifier-agent", "verifier-model"]);
  expect(v.request.message).toContain("verifier-agent");
  expect(v.request.message).toContain(`Verdict file: ${out(W1, "verdict.json")}.`);
  expect(v.claim?.env).toMatchObject({ BATON_ROLE: "verifier", OSSIFY_VERIFY_WORKTREE: join(root, "wt", W1), SEAT_MODS_ROLE: "verifier" });
  expect(host.of(SPINE_UNIT, "spine_review")[0].request.message.startsWith(`/review ${prUrl(SPINE_UNIT)} previous: ${out(SPINE_UNIT, "review-prev.md")} Then read`)).toBe(true);
  expect(moves("lane")).toEqual(["lane>lane_wait", "lane_wait>lane", "lane>spine_open", "spine_open>done"]);
  expect(moves(SPINE_UNIT)).toEqual(["spine_review>spine_wait", "spine_wait>spine_ack", "spine_ack>spine_finish", "spine_finish>done"]);
  expect(host.of("lane", "lane")).toHaveLength(2);
  // One notice names the spine PR: the ask to merge it.
  const log = readFileSync(join(state, "notify.log"), "utf8").split("\n").filter((l) => l.includes(prUrl(SPINE_UNIT)));
  expect(log).toHaveLength(1);
  expect(log[0]).toContain("then merge it only where the project's governance grants that, else ask the operator");
  expect(log[0]).not.toContain("phone");
  expect(readState().spines[0].status).toBe("closed");
  expect(readdirSync(join(state, "claims"))).toEqual([]);
});

test("a gap waits for a live sibling", async () => {
  await arm();
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); queue(W2, 1, 2); put(out("lane", "lane.done"), "x"); }
  }, {
    implement: (u, n) => (u === W1 && n === 1 ? put(out(u, "gaps.json"), "{}") : put(workFile(u, "report.md"), "r")),
  });
  host.script.implement = { ticks: 3, end: "completed" }; // w2's implementer is at work for three ticks
  const r = rig(host);
  // The build slot (1) runs one implementer at a time: w2's launches in the tick w1 gaps.
  let held = 0;
  await drive(r, 40, () => host.of(W1, "implement").length === 2, () => {
    const run = readRun();
    if (run.units[W1]?.stage === "gap_wait" && run.units[W2]?.session) held++;
  });

  // w1 sat in gap_wait while w2's implementer was live; regap launched only after w2's session ended.
  const w2Ended = moved(W2, "implement", "verify");
  expect(held).toBeGreaterThanOrEqual(2);
  expect(moved(W1, "implement", "gap_wait")).toBeLessThan(w2Ended);
  expect(launchedEv(W1, "regap")).toBeGreaterThan(w2Ended);
  // regap rewrote w1's record: w1 relaunched, counted as its second dispatch.
  expect(moves(W1)).toEqual(["implement>gap_wait", "gap_wait>regap", "regap>implement"]);
  expect(item(W1).dispatches).toBe(2);
  expect(existsSync(out(W1, "gaps.json"))).toBe(false); // the answered gap went with the before hook
});

test("two gaps in a round re-enter one at a time", async () => {
  await arm();
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); queue(W2, 1, 2); put(out("lane", "lane.done"), "x"); }
  }, {
    implement: (u, n) => (n === 1 ? put(out(u, "gaps.json"), "{}") : put(workFile(u, "report.md"), "r")),
  });
  const r = rig(host);
  await drive(r, 60, () => host.of(W2, "regap").length === 1 || unit(W2)?.parked !== undefined);

  // w2's re-entry launched only after w1 re-entered, relaunched its implementer, and left implement:
  // never in the tick w1's regap ended, when w1 sat in implement with no session yet.
  const w1Closed = moved(W1, "implement", "verify");
  expect(w1Closed).toBeGreaterThan(-1); // -1 (never) would make the next comparison vacuous
  expect(launchedEv(W2, "regap")).toBeGreaterThan(w1Closed);
  expect(launchedEv(W1, "implement", 2)).toBeGreaterThan(moved(W1, "regap", "implement"));
  expect(moves(W1).slice(0, 4)).toEqual(["implement>gap_wait", "gap_wait>regap", "regap>implement", "implement>verify"]);
  expect(moves(W2)).toEqual(["implement>gap_wait", "gap_wait>regap"]);
});

test("a gap with no sibling live re-enters on the next tick", async () => {
  await arm();
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); put(out("lane", "lane.done"), "x"); }
  }, {
    implement: (u, n) => (n === 1 ? put(out(u, "gaps.json"), "{}") : put(workFile(u, "report.md"), "r")),
  });
  const r = rig(host);
  let gapAt = 0, regapAt = 0;
  await drive(r, 30, () => regapAt > 0, (i) => {
    if (!gapAt && unit(W1)?.stage === "gap_wait") gapAt = i;
    if (!regapAt && host.of(W1, "regap").length) regapAt = i;
  });
  expect(gapAt).toBeGreaterThan(0);
  expect(regapAt).toBe(gapAt + 1);
});

test("a gap waits while a sibling is in correction", async () => {
  await arm();
  // w2 is declared first, so it implements and closes before w1's implementer gaps.
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W2, 1, 1); queue(W1, 1, 2); put(out("lane", "lane.done"), "x"); }
  }, {
    implement: (u, n) => (u === W1 && n === 1 ? put(out(u, "gaps.json"), "{}") : put(workFile(u, "report.md"), "r")),
    close: (u, n) => (n === 1 ? fidelityRed(u) : oss("work_item_pr", u, prUrl(u))),
    correct: (u, n) => put(out(u, n === 1 ? "stop" : "corrected"), "x"),
  });
  const r = rig(host);
  await drive(r, 40, () => unit(W2)?.parked !== undefined);
  await settle(r, 5);

  let w2 = unit(W2);
  expect(w2.stage).toBe("correct");
  expect(w2.parked?.reason).toBe("stop");
  expect(w2.session).toBeUndefined();
  expect(unit(W1).stage).toBe("gap_wait");
  expect(host.of(W1, "regap")).toHaveLength(0);

  // Control: the operator clears the stop and unparks w2; regap launches once w2 reaches land.
  rmSync(out(W2, "stop"));
  expect(await main(["unpark", "r1", W2])).toBe(0);
  let w2AtRegap = "";
  await drive(r, 30, () => host.of(W1, "regap").length > 0, () => {
    if (!w2AtRegap && host.of(W1, "regap").length) w2AtRegap = unit(W2).stage;
  });
  // the item PR's review does not hold the gap: only the stages that mutate the worktree do
  expect(w2AtRegap).toBe("item_ready");
  expect(moves(W2).slice(0, 6)).toEqual(["implement>verify", "verify>close", "close>correct", "correct>verify", "verify>close", "close>item_ready"]);
  expect(launchedEv(W1, "regap")).toBeGreaterThan(moved(W2, "close", "item_ready"));
});

test("an item at the dispatch cap parks before a fourth execution", async () => {
  setState({ [W1]: 2, [W2]: 3 });
  await arm();
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); queue(W2, 1, 2); put(out("lane", "lane.done"), "x"); }
  }, {
    close: fidelityRed,
  });
  const r = rig(host);
  await drive(r, 40, () => unit(W1)?.parked !== undefined && unit(W2)?.parked !== undefined);
  await settle(r, 3);

  // w1: its third execution (implement) ran; the correction that would be the fourth did not.
  expect(unit(W1).stage).toBe("correct");
  expect(unit(W1).parked?.reason).toBe("before failed");
  expect(host.of(W1, "implement")).toHaveLength(1);
  expect(host.of(W1, "correct")).toHaveLength(0);
  expect(item(W1).dispatches).toBe(3);
  // w2 came in at the cap: no implement launch at all.
  expect(unit(W2).stage).toBe("implement");
  expect(unit(W2).parked?.reason).toBe("before failed");
  expect(host.of(W2, "implement")).toHaveLength(0);
  expect(item(W2).dispatches).toBe(3);
});

test("control: an item below the dispatch cap launches its correction", async () => {
  setState({ [W1]: 1, [W2]: 0 });
  await arm();
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); put(out("lane", "lane.done"), "x"); }
  }, {
    close: fidelityRed,
  });
  const r = rig(host);
  await drive(r, 30, () => host.of(W1, "correct").length === 1);
  expect(unit(W1).parked).toBeUndefined();
  expect(item(W1).dispatches).toBe(3);
});

test("a lane that writes nothing parks instead of looping", async () => {
  await arm();
  const host = newHost(() => put(out("lane", "lane.done"), "x"));
  host.script.driver = oneTick(); // the driver ends without writing a result
  const r = rig(host);
  await drive(r, 10, () => unit("lane").parked !== undefined);
  await settle(r, 5);

  expect(unit("lane").stage).toBe("lane");
  expect(unit("lane").parked?.reason).toBe("outcome");
  expect(host.of("lane", "lane")).toHaveLength(1);
  // The recipe's driver launched and ended without writing a result, so the park is escalated.
  expect(host.of("lane", "driver")).toHaveLength(1);
  expect(events().filter((e) => e.kind === "launch unknown" || e.kind === "orphan")).toEqual([]);
  expect(r.notes).toEqual(["baton r1/lane parked in lane: outcome — driver gave no valid result (no result file)"]);
  expect(existsSync(out("lane", "lane.done"))).toBe(false);
});

test("a merged item with the canonical root off the spine branch parks", async () => {
  git(repo, "checkout", "main");
  const mainBefore = git(repo, "rev-parse", "main");
  await arm();
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); put(out("lane", "lane.done"), "x"); }
  });
  const r = rig(host);
  await drive(r, 30, () => unit(W1)?.parked !== undefined);

  expect(r.forge.merges.map((m) => m.url)).toEqual([prUrl(W1)]); // merged on the remote
  expect(unit(W1).stage).toBe("land");
  expect(unit(W1).parked?.reason).toBe("run failed"); // generic: any run_after argv failing reads the same
  expect(git(repo, "rev-parse", "main")).toBe(mainBefore); // load-bearing: nothing fast-forwarded main
  expect(git(repo, "symbolic-ref", "--short", "HEAD")).toBe("main");
  expect(item(W1).status).toBe("active");
});

const HEAD1 = "e".repeat(40);
const HEAD2 = "f".repeat(40);
const reviewOf = (verdict: string, head: string) => `verdict: ${verdict}\nhead: ${head}\n${verdict === "block" ? "- [blocking] AC2 is not covered\n" : "no findings\n"}`;
const setHead = (r: Rig, wi: string, head: string) => r.forge.views.set(prUrl(wi), { ...r.forge.views.get(prUrl(wi))!, head });
const oneItem = (extra: Record<string, Effect> = {}) => newHost((_u, n) => {
  if (n === 1) { queue(W1, 1, 1); put(out("lane", "lane.done"), "x"); }
}, extra);

test("item CI red goes to item_fix, and red that fixing never clears parks at review 3", async () => {
  await arm();
  const host = oneItem();
  const forge = new SpineForge();
  forge.views.set(prUrl(W1), { ...openPr(BRANCH), checks: "red" });
  const r = rig(host, forge);
  await drive(r, 60, () => unit(W1)?.parked !== undefined);

  expect(unit(W1).stage).toBe("item_wait");
  expect(unit(W1).parked?.reason).toBe("outcome");
  expect(forge.merges).toEqual([]);
  expect(host.of(W1, "item_review")).toHaveLength(3);
  expect(host.of(W1, "item_fix")).toHaveLength(2);
  expect(item(W1).status).toBe("active");
});

test("close records the PR in the queue record; the review is told the URL, then fix, re-review and land the reviewed head", async () => {
  await arm();
  const asked: string[] = [];
  const host = oneItem({
    item_review: (u, n) => {
      put(out(u, "review.md"), n === 1 ? reviewOf("block", HEAD0) : reviewOf("pass", HEAD1));
      if (n === 1) put(out(u, "operator.md"), "ruling: AC2 is a known limit"); // the orchestrator rules on the block
    },
    item_fix: (u) => {
      asked.push(`${existsSync(out(u, "operator.md"))}:${readFileSync(out(u, "review.md"), "utf8").split("\n")[0]}`);
      setHead(r, u, HEAD1); // the fixer pushed once
      put(out(u, "round-done"), "x");
    },
  });
  const r = rig(host);
  await drive(r, 60, () => unit(W1)?.stage === "done" || unit(W1)?.parked !== undefined);

  expect(moves(W1)).toEqual([
    "implement>verify", "verify>close", "close>item_ready", "item_ready>item_review", "item_review>item_wait",
    "item_wait>item_fix", "item_fix>item_review", "item_review>item_wait", "item_wait>land", "land>done",
  ]);
  // the merge is pinned to the head the second review saw, never the head the first one blocked
  expect(r.forge.merges).toEqual([{ url: prUrl(W1), head: HEAD1 }]);
  // the queue record carries the PR url and everything it carried
  const rec = JSON.parse(readFileSync(join(runDir, "queue", `${W1}.json`), "utf8"));
  expect(rec).toMatchObject({ work_item_id: W1, round: 1, order: 1, branch: `work/${W1}`, pr_url: prUrl(W1) });
  expect(readdirSync(join(runDir, "queue")).sort()).toEqual([`${W1}.json`]); // no temp file left beside it
  // item_review: the PR URL is the command's own argument, the previous review the next word
  const reviews = host.of(W1, "item_review");
  expect(reviews).toHaveLength(2);
  expect(reviews[0].request.message.startsWith(`/review ${prUrl(W1)} previous: ${out(W1, "review-prev.md")} Then read`)).toBe(true);
  expect(reviews[0].request.cwd).toBe(join(root, "wt", W1));
  expect(reviews[0].claim?.env).toMatchObject({ BATON_ROLE: "item reviewer", SEAT_MODS_ROLE: "reviewer" });
  // item_fix: the work-PR session, in the item worktree, told the review, the Ruling file and the round done file
  const fixes = host.of(W1, "item_fix");
  expect(fixes).toHaveLength(1);
  expect(fixes[0].request.cwd).toBe(join(root, "wt", W1));
  expect(fixes[0].claim?.env).toMatchObject({ BATON_ROLE: "work-PR session" });
  for (const f of [`Item PR: ${prUrl(W1)}.`, `Review: ${out(W1, "review.md")}.`, `Ruling file: ${out(W1, "operator.md")}.`, `Round done file: ${out(W1, "round-done")}.`]) {
    expect([f, fixes[0].request.message.includes(f)]).toEqual([f, true]);
  }
  expect(asked).toEqual(["true:verdict: block"]); // the ruling and the blocking review were there when the fixer ran
  // the files: review 1 kept as review-1.md and review-prev.md, the ruling archived, the done file cleared
  expect(readFileSync(out(W1, "review-1.md"), "utf8")).toBe(reviewOf("block", HEAD0));
  expect(readFileSync(out(W1, "review-prev.md"), "utf8")).toBe(reviewOf("block", HEAD0));
  expect(readFileSync(out(W1, "review.md"), "utf8")).toBe(reviewOf("pass", HEAD1));
  expect(existsSync(out(W1, "review-2.md"))).toBe(false);
  expect(existsSync(out(W1, "operator.md"))).toBe(false);
  expect(readFileSync(out(W1, "operator-1.md"), "utf8")).toContain("known limit");
  expect(existsSync(out(W1, "round-done"))).toBe(false);
});

test("a head that moves after a passing review goes back to item_review and merges only the re-reviewed head", async () => {
  await arm();
  const host = oneItem({ item_review: (u, n) => put(out(u, "review.md"), reviewOf("pass", n === 1 ? HEAD0 : HEAD1)) });
  const r = rig(host);
  let pushed = false;
  await drive(r, 60, () => unit(W1)?.stage === "done" || unit(W1)?.parked !== undefined, () => {
    // somebody pushes while no seat of this unit is running: the unit has just entered land
    if (!pushed && unit(W1)?.stage === "land") { pushed = true; setHead(r, W1, HEAD1); }
  });

  expect(pushed).toBe(true);
  expect(moves(W1)).toEqual([
    "implement>verify", "verify>close", "close>item_ready", "item_ready>item_review", "item_review>item_wait", "item_wait>land",
    "land>item_moved", "item_moved>item_review", "item_review>item_wait", "item_wait>land", "land>done",
  ]);
  expect(r.forge.merges).toEqual([{ url: prUrl(W1), head: HEAD1 }]); // never HEAD0
  expect(events().filter((e) => e.kind === "head moved")).toHaveLength(1);
  expect(host.of(W1, "item_review")).toHaveLength(2);
  expect(readFileSync(out(W1, "review-1.md"), "utf8")).toBe(reviewOf("pass", HEAD0));
  expect(unit(W1).parked).toBeUndefined();
});

const WRONG = "9".repeat(40);

test("a passing review whose head never matches parks in item_moved after three reviews and never merges (#1079 C2)", async () => {
  await arm();
  const host = oneItem({ item_review: (u) => put(out(u, "review.md"), reviewOf("pass", WRONG)) });
  const r = rig(host);
  await drive(r, 80, () => unit(W1)?.parked !== undefined);

  expect(unit(W1).parked?.reason).toBe("outcome");
  expect(unit(W1).stage).toBe("item_moved");
  expect(host.of(W1, "item_review")).toHaveLength(3);
  expect(existsSync(out(W1, "review-1.md")) && existsSync(out(W1, "review-2.md")) && existsSync(out(W1, "review.md"))).toBe(true);
  expect(existsSync(out(W1, "review-3.md"))).toBe(false);
  expect(moves(W1).filter((m) => m === "land>item_moved")).toHaveLength(3);
  expect(r.forge.merges).toEqual([]);
  expect(item(W1).status).toBe("active");
});

test("one moved head is legitimate: the second review matches and merges after two reviews, the cap does not fire early", async () => {
  await arm();
  const host = oneItem({ item_review: (u, n) => put(out(u, "review.md"), reviewOf("pass", n === 1 ? WRONG : HEAD0)) });
  const r = rig(host);
  await drive(r, 60, () => unit(W1)?.stage === "done" || unit(W1)?.parked !== undefined);

  expect(unit(W1).parked).toBeUndefined();
  expect(host.of(W1, "item_review")).toHaveLength(2);
  expect(moves(W1)).toContain("land>item_moved");
  expect(moves(W1)).toContain("item_moved>item_review");
  expect(r.forge.merges).toEqual([{ url: prUrl(W1), head: HEAD0 }]);
});

test("after the item_moved park, --to item_review runs one more review, and the next moved head parks at once", async () => {
  await arm();
  const host = oneItem({ item_review: (u) => put(out(u, "review.md"), reviewOf("pass", WRONG)) });
  const r = rig(host);
  await drive(r, 80, () => unit(W1)?.parked !== undefined);
  expect(host.of(W1, "item_review")).toHaveLength(3);

  expect(await main(["unpark", "r1", W1, "--to", "item_review"])).toBe(0);
  await drive(r, 40, () => unit(W1)?.parked !== undefined && host.of(W1, "item_review").length === 4);
  expect(host.of(W1, "item_review")).toHaveLength(4);
  expect(unit(W1).stage).toBe("item_moved");
  expect(existsSync(out(W1, "review-3.md"))).toBe(true);
  expect(r.forge.merges).toEqual([]);
});

test("review 3 blocking is a stop; --to land accepts the findings on the reviewed head, --to item_fix takes a ruling", async () => {
  await arm();
  const host = oneItem({ item_review: (u) => put(out(u, "review.md"), reviewOf("block", theForge.views.get(prUrl(u))!.head)) });
  const r = rig(host);
  await drive(r, 60, () => unit(W1)?.parked !== undefined);

  // reviews 1 and 2 each sent the item to item_fix; review 3 parks in item_wait, with the fixer not launched a third time
  expect(unit(W1).stage).toBe("item_wait");
  expect(unit(W1).parked?.reason).toBe("outcome");
  expect(host.of(W1, "item_review")).toHaveLength(3);
  expect(host.of(W1, "item_fix")).toHaveLength(2);
  expect(moves(W1).filter((m) => m === "item_wait>item_fix")).toHaveLength(2);
  expect(existsSync(out(W1, "review-1.md")) && existsSync(out(W1, "review-2.md"))).toBe(true);
  expect(existsSync(out(W1, "review-3.md"))).toBe(false);
  expect(r.forge.merges).toEqual([]);

  // the ruling route: a fourth fix round, then a fourth review that blocks again parks again at once
  put(out(W1, "operator.md"), "fix AC2 only");
  expect(await main(["unpark", "r1", W1, "--to", "item_fix"])).toBe(0);
  await drive(r, 40, () => unit(W1)?.parked !== undefined && host.of(W1, "item_review").length === 4);
  expect(host.of(W1, "item_fix")).toHaveLength(3);
  expect(unit(W1).stage).toBe("item_wait");
  expect(readFileSync(out(W1, "operator-1.md"), "utf8")).toBe("fix AC2 only");

  // the accept route: land merges the head of the last review, and a head that moved since goes to review instead
  setHead(r, W1, HEAD2);
  expect(await main(["unpark", "r1", W1, "--to", "land"])).toBe(0);
  await drive(r, 3, () => unit(W1)?.stage === "item_moved" || r.forge.merges.length > 0);
  expect(r.forge.merges).toEqual([]);
  // review-2.md exists, so item_moved parks at once instead of sending the item to a fifth review
  await drive(r, 3, () => unit(W1)?.parked !== undefined);
  expect(unit(W1).stage).toBe("item_moved");
  expect(moves(W1).at(-1)).toBe("land>item_moved");
});

test("review 3 blocking: --to land merges the reviewed head when it has not moved", async () => {
  await arm();
  const host = oneItem({ item_review: (u) => put(out(u, "review.md"), reviewOf("block", theForge.views.get(prUrl(u))!.head)) });
  const r = rig(host);
  await drive(r, 60, () => unit(W1)?.parked !== undefined);
  expect(await main(["unpark", "r1", W1, "--to", "land"])).toBe(0);
  await drive(r, 10, () => unit(W1)?.stage === "done");
  expect(r.forge.merges).toEqual([{ url: prUrl(W1), head: HEAD0 }]);
});

/** A person merges the item PR by hand: its head lands on the spine branch and the PR reads MERGED. */
function handMerge(wi: string): void {
  git(other, "fetch", "origin");
  git(other, "checkout", "-B", BRANCH, `origin/${BRANCH}`);
  git(other, "checkout", "-b", `hand-${wi}`);
  const head = commit(other, `hand-${wi}`);
  git(other, "checkout", BRANCH);
  git(other, "merge", "--no-ff", "-m", `hand merge ${wi}`, `hand-${wi}`);
  git(other, "push", "origin", BRANCH);
  theForge.views.set(prUrl(wi), { ...theForge.views.get(prUrl(wi))!, state: "MERGED", head });
}

test("a hand-merged item PR whose review blocks goes to land and ends the unit: no fixer is sent to a merged branch (#1079 C4)", async () => {
  await arm();
  const host = oneItem({ item_review: (u) => { put(out(u, "review.md"), reviewOf("block", HEAD0)); handMerge(u); } });
  const r = rig(host);
  await drive(r, 40, () => unit(W1)?.stage === "done");
  expect(host.of(W1, "item_fix")).toHaveLength(0);
  expect(moves(W1).slice(-3)).toEqual(["item_review>item_wait", "item_wait>land", "land>done"]);
  expect(r.forge.merges).toEqual([]); // baton merged nothing: the merge was the person's
  expect(item(W1).status).not.toBe("active");
});

test("review 3 passed, the PR closed, checks undecided: the item parks instead of waiting behind the checks (#1079 C3b)", async () => {
  await arm();
  const host = oneItem({ item_review: (u) => put(out(u, "review.md"), reviewOf("pass", HEAD0)) });
  const forge = new SpineForge();
  forge.views.set(prUrl(W1), { ...openPr(BRANCH), state: "CLOSED", checks: "pending", mergeable: "UNKNOWN" });
  const r = rig(host, forge);
  put(out(W1, "review-2.md"), reviewOf("block", HEAD0)); // two reviews already ran: the cap clauses are live
  await drive(r, 40, () => unit(W1)?.parked !== undefined);
  expect([unit(W1).stage, unit(W1).parked?.reason]).toEqual(["item_wait", "outcome"]);
  expect(forge.merges).toEqual([]);
});

test("review 3 passed, the PR in conflict, checks undecided: the item parks instead of waiting behind the checks (#1079 C3b)", async () => {
  await arm();
  const host = oneItem({ item_review: (u) => put(out(u, "review.md"), reviewOf("pass", HEAD0)) });
  const forge = new SpineForge();
  forge.views.set(prUrl(W1), { ...openPr(BRANCH), mergeable: "CONFLICTING", checks: "pending" });
  const r = rig(host, forge);
  put(out(W1, "review-2.md"), reviewOf("block", HEAD0));
  await drive(r, 40, () => unit(W1)?.parked !== undefined);
  expect([unit(W1).stage, unit(W1).parked?.reason]).toEqual(["item_wait", "outcome"]);
  expect(forge.merges).toEqual([]);
});

test("control: review 3 passed, checks undecided, the PR open and mergeable: the item keeps waiting (#1079 C3b)", async () => {
  await arm();
  const host = oneItem({ item_review: (u) => put(out(u, "review.md"), reviewOf("pass", HEAD0)) });
  const forge = new SpineForge();
  forge.views.set(prUrl(W1), { ...openPr(BRANCH), checks: "pending" });
  const r = rig(host, forge);
  put(out(W1, "review-2.md"), reviewOf("block", HEAD0));
  await settle(r, 25);
  expect([unit(W1).stage, unit(W1).parked]).toEqual(["item_wait", undefined]);
});

test("the pr_url write is no rewrite: a gap after it still waits on regap's own rewrite", async () => {
  await arm();
  const host = oneItem({
    item_review: (u) => put(out(u, "stop"), "x"), // park the item once its PR is recorded
    implement: (u, n) => (n === 2 ? put(out(u, "gaps.json"), "{}") : put(workFile(u, "report.md"), "r")),
  });
  const r = rig(host);
  await drive(r, 40, () => unit(W1)?.parked !== undefined && unit(W1).stage === "item_review");
  expect(JSON.parse(readFileSync(join(runDir, "queue", `${W1}.json`), "utf8")).pr_url).toBe(prUrl(W1));
  expect(unit(W1).vars.pr_url).toBe(prUrl(W1));
  // the operator sends the item back to implement; its seat gaps, and the record is rewritten by regap only
  rmSync(out(W1, "stop"));
  rmSync(workFile(W1, "report.md")); // the new pass writes its own
  expect(await main(["unpark", "r1", W1, "--to", "implement"])).toBe(0);
  await drive(r, 30, () => moved(W1, "regap", "implement") > -1);
  // (an unpark --to records no transition, so the moves after the first four are the new pass's)
  expect(moves(W1).slice(4, 7)).toEqual(["implement>gap_wait", "gap_wait>regap", "regap>implement"]);
  // regap ran its seat before the unit left it: the digest the pr_url write changed did not route it at entry
  expect(launchedEv(W1, "regap")).toBeGreaterThan(-1);
  expect(launchedEv(W1, "regap")).toBeLessThan(moved(W1, "regap", "implement"));
  expect(host.of(W1, "regap")).toHaveLength(1);
});

test("a review without a verdict relaunches, then parks", async () => {
  await arm();
  const host = newHost(() => put(join(runDir, "rounds.done"), "x"), {
    spine_review: (u) => put(out(u, "review.md"), "head: abc123\nlooks fine\n"),
  });
  host.script.driver = oneTick(); // the driver ends without writing a result
  const r = rig(host);
  await drive(r, 60, () => unit(SPINE_UNIT)?.parked !== undefined);

  expect(unit(SPINE_UNIT).stage).toBe("spine_review");
  expect(unit(SPINE_UNIT).parked?.reason).toBe("no result");
  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(3);
  expect(moves(SPINE_UNIT)).toEqual([]);
  await settle(r, 5);
  // The recipe's driver launched and ended without writing a result, so the park is escalated.
  expect(host.of(SPINE_UNIT, "driver")).toHaveLength(1);
  expect(events().filter((e) => e.kind === "launch unknown" || e.kind === "orphan")).toEqual([]);
  expect(r.notes).toEqual([`baton r1/${SPINE_UNIT} parked in spine_review: no result — driver gave no valid result (no result file)`]);
});

test("a spine PR conflict parks the spine PR", async () => {
  await arm();
  const host = newHost(() => put(join(runDir, "rounds.done"), "x"));
  const forge = new SpineForge();
  forge.views.set(prUrl(SPINE_UNIT), { ...openPr("main"), mergeable: "CONFLICTING" });
  const r = rig(host, forge);
  await drive(r, 40, () => unit(SPINE_UNIT)?.parked !== undefined || host.of(SPINE_UNIT, "spine_work").length > 0);
  await settle(r, 3);

  expect(unit(SPINE_UNIT).stage).toBe("spine_wait");
  expect(unit(SPINE_UNIT).parked?.reason).toBe("outcome");
  expect(host.of(SPINE_UNIT, "spine_work")).toHaveLength(0);
  expect(moves(SPINE_UNIT)).toEqual(["spine_review>spine_wait"]);
});

// ---- #1206: the spine PR loop has a cap, and spine_ack only follows a review of the PR's own head ----

const spineHost = (extra: Record<string, Effect> = {}) => newHost(() => put(join(runDir, "rounds.done"), "x"), extra);
const setSpine = (r: Rig, patch: Partial<PrView>) => r.forge.views.set(prUrl(SPINE_UNIT), { ...r.forge.views.get(prUrl(SPINE_UNIT))!, ...patch });
const spineParked = () => unit(SPINE_UNIT)?.parked !== undefined;
const spineAt = (stage: string) => () => unit(SPINE_UNIT)?.stage === stage;
const reviewFile = (n: string) => readFileSync(out(SPINE_UNIT, n), "utf8");

test("a pass of the PR's own head reaches spine_ack after one review and the notice goes out (#1206)", async () => {
  await arm();
  const host = spineHost();
  const r = rig(host);
  await drive(r, 40, spineAt("spine_ack"));

  expect(moves(SPINE_UNIT)).toEqual(["spine_review>spine_wait", "spine_wait>spine_ack"]);
  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(1);
  expect(r.notes.filter((n) => n.includes("passed review"))).toHaveLength(1);
  // the notice carries the reviewed head, 40 hex, to pin the merge to, and the way back to review if the head moves
  const note = r.notes.find((n) => n.includes("passed review"))!;
  expect(note).toContain(`passed review at head ${HEAD0} `);
  expect(note).toContain(`gh pr merge --match-head-commit ${HEAD0}`);
  expect(note).toContain(`baton unpark r1 ${SPINE_UNIT} --to spine_review`);
  expect(note).toContain(`${out(SPINE_UNIT, "review.md")}`);
});

test("a pass of an older head with green checks goes back to spine_review, never to spine_ack; the review of the current head then does (#1206 defect 2)", async () => {
  await arm();
  const host = spineHost({ spine_review: (u, n) => put(out(u, "review.md"), reviewOf("pass", n === 1 ? WRONG : HEAD0)) });
  const r = rig(host);
  await drive(r, 60, spineAt("spine_ack"));

  expect(moves(SPINE_UNIT)).toEqual(["spine_review>spine_wait", "spine_wait>spine_review", "spine_review>spine_wait", "spine_wait>spine_ack"]);
  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(2);
  // the stale review is kept as review-stale-1.md and was the next review's `previous:`; it took no review number
  expect(reviewFile("review-stale-1.md")).toBe(reviewOf("pass", WRONG));
  expect(reviewFile("review-prev.md")).toBe(reviewOf("pass", WRONG));
  expect(reviewFile("review.md")).toBe(reviewOf("pass", HEAD0));
  expect(existsSync(out(SPINE_UNIT, "review-1.md"))).toBe(false);
  expect(r.notes.filter((n) => n.includes("passed review"))).toHaveLength(1); // one notice, for the head a review saw
});

test("a head that moves after a passing review goes back to spine_review, and the notice waits for a review of the new head (#1206 defect 2)", async () => {
  await arm();
  const host = spineHost({ spine_review: (u) => put(out(u, "review.md"), reviewOf("pass", theForge.views.get(prUrl(u))!.head)) });
  const r = rig(host);
  let pushed = false;
  // the review passes HEAD0; somebody pushes before spine_wait reads the PR again
  await drive(r, 60, spineAt("spine_ack"), () => {
    if (!pushed && unit(SPINE_UNIT)?.stage === "spine_wait") { pushed = true; setSpine(r, { head: HEAD1 }); }
  });

  expect(pushed).toBe(true);
  expect(moves(SPINE_UNIT)).toEqual(["spine_review>spine_wait", "spine_wait>spine_review", "spine_review>spine_wait", "spine_wait>spine_ack"]);
  expect(reviewFile("review-stale-1.md")).toBe(reviewOf("pass", HEAD0));
  expect(reviewFile("review.md")).toBe(reviewOf("pass", HEAD1));
});

test("a PR head that cannot be read as 40 hex never matches: spine_wait parks, spine_ack is not reached, and no stale review loop starts (#1206 defect 2)", async () => {
  await arm();
  const host = spineHost({ spine_review: (u) => put(out(u, "review.md"), reviewOf("pass", HEAD0)) });
  const r = rig(host);
  setSpine(r, { head: "abc123" });
  await drive(r, 40, spineParked);

  expect(unit(SPINE_UNIT).stage).toBe("spine_wait");
  expect(unit(SPINE_UNIT).parked?.reason).toBe("exit0 error"); // rc 2, not a match and not a mismatch
  expect(moves(SPINE_UNIT)).toEqual(["spine_review>spine_wait"]);
  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(1);
  expect(existsSync(out(SPINE_UNIT, "review-stale-1.md"))).toBe(false);
});

test("a PR read that fails never reaches spine_ack; the unit waits, then parks at the third failure (#1206 defect 2)", async () => {
  await arm();
  const host = spineHost();
  const r = rig(host);
  await drive(r, 40, spineAt("spine_wait"));
  r.forge.viewFails = 1000;
  await drive(r, 20, spineParked);

  expect(unit(SPINE_UNIT).parked?.reason).toBe("pr view failed");
  expect(moves(SPINE_UNIT)).toEqual(["spine_review>spine_wait"]);
});

for (const [name, text] of [["no head line", "verdict: pass\nno findings\n"], ["a short head", "verdict: pass\nhead: abc123\nno findings\n"], ["a 41-hex head", `verdict: pass\nhead: ${HEAD0}0\n`]] as const) {
  test(`a spine review with ${name} does not move to spine_wait (#1206 defect 2)`, async () => {
    await arm();
    const host = spineHost({ spine_review: (u) => put(out(u, "review.md"), text) });
    host.script.driver = oneTick();
    const r = rig(host);
    await drive(r, 60, spineParked);

    expect(unit(SPINE_UNIT).stage).toBe("spine_review");
    expect(unit(SPINE_UNIT).parked?.reason).toBe("no result");
    expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(3);
    expect(moves(SPINE_UNIT)).toEqual([]);
  });
}

const SPINE_CYCLE = ["spine_review>spine_wait", "spine_wait>spine_work", "spine_work>spine_review"];

test("a spine PR that keeps blocking parks after review 3, as the item PR does; reviews 1 and 2 go to spine_work (#1206 defect 1)", async () => {
  await arm();
  const host = spineHost({ spine_review: (u) => put(out(u, "review.md"), reviewOf("block", HEAD0)) });
  const r = rig(host);
  await drive(r, 80, spineParked);

  expect(unit(SPINE_UNIT).stage).toBe("spine_wait");
  expect(unit(SPINE_UNIT).parked?.reason).toBe("outcome");
  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(3);
  expect(host.of(SPINE_UNIT, "spine_work")).toHaveLength(2);
  expect(moves(SPINE_UNIT)).toEqual([...SPINE_CYCLE, ...SPINE_CYCLE, "spine_review>spine_wait"]);
  // each round kept its review under the next number: review 3 is the latest and has no number yet
  expect(existsSync(out(SPINE_UNIT, "review-1.md")) && existsSync(out(SPINE_UNIT, "review-2.md"))).toBe(true);
  expect(existsSync(out(SPINE_UNIT, "review-3.md"))).toBe(false);
  expect(reviewFile("review.md")).toBe(reviewOf("block", HEAD0));
  expect(existsSync(out(SPINE_UNIT, "round-done"))).toBe(false);
  expect(r.forge.merges).toEqual([]);

  // the operator sends it back for one more round: the next review that blocks parks at once, because the review files keep counting
  expect(await main(["unpark", "r1", SPINE_UNIT, "--to", "spine_work"])).toBe(0);
  await drive(r, 40, () => host.of(SPINE_UNIT, "spine_review").length === 4 && spineParked());
  expect(host.of(SPINE_UNIT, "spine_work")).toHaveLength(3);
  expect(unit(SPINE_UNIT).stage).toBe("spine_wait");
  expect(existsSync(out(SPINE_UNIT, "review-3.md"))).toBe(true);
});

test("after the review-3 park, a merge by the merge holder and a plain unpark take the spine to spine_finish (#1206)", async () => {
  await arm();
  const host = spineHost({ spine_review: (u) => put(out(u, "review.md"), reviewOf("block", HEAD0)) });
  const r = rig(host);
  await drive(r, 80, spineParked);
  expect(unit(SPINE_UNIT).stage).toBe("spine_wait");
  setSpine(r, { state: "MERGED" });
  expect(await main(["unpark", "r1", SPINE_UNIT])).toBe(0);
  await drive(r, 20, spineAt("spine_finish"));
  expect(moves(SPINE_UNIT).at(-1)).toBe("spine_wait>spine_finish");
});

test("red checks that fixing never clears park the spine PR at review 3; a passing review does not stop that (#1206 defect 1)", async () => {
  await arm();
  const host = spineHost();
  const r = rig(host);
  setSpine(r, { checks: "red" });
  await drive(r, 80, spineParked);

  expect(unit(SPINE_UNIT).stage).toBe("spine_wait");
  expect(unit(SPINE_UNIT).parked?.reason).toBe("outcome");
  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(3);
  expect(host.of(SPINE_UNIT, "spine_work")).toHaveLength(2);
  expect(moves(SPINE_UNIT)).toEqual([...SPINE_CYCLE, ...SPINE_CYCLE, "spine_review>spine_wait"]);
  expect(moves(SPINE_UNIT)).not.toContain("spine_wait>spine_ack");
});

test("red checks after review 1 or 2 go to spine_work as before: the cap needs review-2.md (#1206 defect 1)", async () => {
  await arm();
  const host = spineHost();
  const r = rig(host);
  setSpine(r, { checks: "red" });
  await drive(r, 40, () => host.of(SPINE_UNIT, "spine_work").length === 1 && unit(SPINE_UNIT)?.stage === "spine_review"); // the round has ended
  expect(spineParked()).toBe(false);
  expect(existsSync(out(SPINE_UNIT, "review-1.md"))).toBe(true);
  expect(existsSync(out(SPINE_UNIT, "review-2.md"))).toBe(false);
  await drive(r, 40, () => host.of(SPINE_UNIT, "spine_work").length === 2 && unit(SPINE_UNIT)?.stage === "spine_review"); // the round has ended
  expect(spineParked()).toBe(false);
  expect(existsSync(out(SPINE_UNIT, "review-2.md"))).toBe(true);
});

test("a stale pass that arrives with review-2.md present and red checks is reviewed again, not parked on: it is no third review (#1206 defect 1)", async () => {
  await arm();
  // reviews 1 and 2 count; review 3 passes an older head, so it is stale; the fourth is review 3 and the cap parks on it
  const host = spineHost({ spine_review: (u, n) => put(out(u, "review.md"), reviewOf(n === 3 ? "pass" : "block", n === 3 ? WRONG : HEAD0)) });
  const r = rig(host);
  setSpine(r, { checks: "red" });
  await drive(r, 100, spineParked);

  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(4);
  expect(host.of(SPINE_UNIT, "spine_work")).toHaveLength(2);
  expect(reviewFile("review-stale-1.md")).toBe(reviewOf("pass", WRONG));
  expect(existsSync(out(SPINE_UNIT, "review-3.md"))).toBe(false);
});

const staleThen = (staleCount: number) => spineHost({ spine_review: (u, n) => put(out(u, "review.md"), reviewOf("pass", n <= staleCount ? WRONG : HEAD0)) });

test("a reviewer that keeps reading an old head parks the spine PR at the fourth stale pass: three are kept, no fifth spine_review runs (#1206 follow-up)", async () => {
  await arm();
  const host = staleThen(100);
  const r = rig(host);
  await drive(r, 100, spineParked);

  expect(unit(SPINE_UNIT).stage).toBe("spine_wait");
  expect(unit(SPINE_UNIT).parked?.reason).toBe("outcome");
  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(4);
  expect(host.of(SPINE_UNIT, "spine_work")).toHaveLength(0);
  expect(moves(SPINE_UNIT)).toEqual(["spine_review>spine_wait", "spine_wait>spine_review", "spine_review>spine_wait", "spine_wait>spine_review", "spine_review>spine_wait", "spine_wait>spine_review", "spine_review>spine_wait"]);
  expect([1, 2, 3].every((n) => existsSync(out(SPINE_UNIT, `review-stale-${n}.md`)))).toBe(true);
  expect(existsSync(out(SPINE_UNIT, "review-stale-4.md"))).toBe(false); // the fourth is left in place as review.md
  expect(reviewFile("review.md")).toBe(reviewOf("pass", WRONG));
  await settle(r, 5);
  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(4); // and it stays parked
});

for (const stale of [2, 3]) {
  test(`${stale} stale passes still go back to spine_review and the next review of the current head reaches spine_ack: the cap is the fourth (#1206 follow-up)`, async () => {
    await arm();
    const host = staleThen(stale);
    const r = rig(host);
    await drive(r, 100, spineAt("spine_ack"));

    expect(unit(SPINE_UNIT).parked).toBeUndefined();
    expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(stale + 1);
    expect(existsSync(out(SPINE_UNIT, `review-stale-${stale}.md`))).toBe(true);
    expect(existsSync(out(SPINE_UNIT, `review-stale-${stale + 1}.md`))).toBe(false);
  });
}

test("a stale review is not a review: it spends no number, so the cap parks after the third counted review (#1206 defect 1)", async () => {
  await arm();
  const host = spineHost({ spine_review: (u, n) => put(out(u, "review.md"), n === 1 ? reviewOf("pass", WRONG) : reviewOf("block", HEAD0)) });
  const r = rig(host);
  await drive(r, 100, spineParked);

  expect(host.of(SPINE_UNIT, "spine_review")).toHaveLength(4); // one stale, then three that count
  expect(host.of(SPINE_UNIT, "spine_work")).toHaveLength(2);
  expect(unit(SPINE_UNIT).parked?.reason).toBe("outcome");
  expect(reviewFile("review-stale-1.md")).toBe(reviewOf("pass", WRONG));
  expect(existsSync(out(SPINE_UNIT, "review-1.md")) && existsSync(out(SPINE_UNIT, "review-2.md"))).toBe(true);
  expect(existsSync(out(SPINE_UNIT, "review-3.md"))).toBe(false);
});

test("a molt successor gets the handoff path and is not a dispatch", async () => {
  await arm();
  const handoff = join(aiRoot, "handoffs", "w1-molt.md");
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); put(out("lane", "lane.done"), "x"); }
  }, {
    implement: (u, n) => {
      if (n === 1) put(out(u, "molt.log"), `${new Date(clock + 1000).toISOString()} handed-off ${handoff}\n`);
      else put(workFile(u, "report.md"), "r");
    },
  });
  const r = rig(host);
  await drive(r, 30, () => unit(W1)?.stage === "verify");

  const launches = host.of(W1, "implement");
  expect(launches).toHaveLength(2);
  expect(launches[1].request.message).toBe(
    `Continue from the handoff at ${handoff}. Then read the brief named in it and finish the stage.`);
  expect(launches[1].claim?.nonce).toBe(launches[0].claim!.nonce); // the same claim, untouched
  expect(unit(W1).launches.implement).toBe(1);
  expect(item(W1).dispatches).toBe(1);
  expect(at((e) => e.kind === "successor" && e.unit === W1)).toBeGreaterThan(0);
});

test("the lane watches the latest round", async () => {
  await arm();
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); put(out("lane", "lane.done"), "x"); }
    else if (n === 2) { queue(W2, 2, 1); put(out("lane", "lane.done"), "x"); }
    else put(join(runDir, "rounds.done"), "x");
  });
  const r = rig(host);
  await drive(r, 60, () => unit("lane").stage === "spine_open" || unit("lane").stage === "done");

  expect(moves("lane").slice(0, 5)).toEqual(["lane>lane_wait", "lane_wait>lane", "lane>lane_wait", "lane_wait>lane", "lane>spine_open"]);
  expect(events().some((e) => e.kind === "park")).toBe(false);
  // Each lane relaunch comes only after its round's last item merged.
  expect(launchedEv("lane", "lane", 2)).toBeGreaterThan(moved(W1, "land", "done"));
  expect(moved(W2, "land", "done")).toBeGreaterThan(launchedEv("lane", "lane", 2));
  expect(launchedEv("lane", "lane", 3)).toBeGreaterThan(moved(W2, "land", "done"));
  expect(readRun().units[W2].group).toBe(2);
});

test("a red close at any layer routes through the correction packet", async () => {
  await arm();
  let packetAtCorrect = false;
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); put(out("lane", "lane.done"), "x"); }
  }, {
    // A Layer 1 red: impl-check halts before Layer 4, so there is no verify.md, only the packet.
    close: (u, n) => (n === 1 ? put(out(u, "correction.txt"), packet(u, "[AC] AC1 fails: exit 1")) : oss("work_item_pr", u, prUrl(u))),
    correct: (u) => {
      packetAtCorrect = existsSync(out(u, "correction.txt"));
      put(out(u, "corrected"), "x");
    },
  });
  const r = rig(host);
  await drive(r, 40, () => unit(W1)?.stage === "done" || unit(W1)?.parked !== undefined);

  expect(existsSync(workFile(W1, "verify.md"))).toBe(false);
  expect(moves(W1)).toEqual(["implement>verify", "verify>close", "close>correct", "correct>verify", "verify>close", ...TO_LAND, "land>done"]);
  expect(host.of(W1, "close")).toHaveLength(2); // routed on the first close, no no-result relaunch; the second lands
  expect(host.of(W1, "correct")[0].request.message).toContain(`Correction packet: ${out(W1, "correction.txt")}.`);
  expect(packetAtCorrect).toBe(true);
  expect(existsSync(out(W1, "correction.txt"))).toBe(false); // moved aside on the way to verify
  expect(readFileSync(out(W1, "correction-1.txt"), "utf8")).toContain("[AC] AC1 fails: exit 1"); // the first round's packet stays (#1005)
  expect(item(W1).dispatches).toBe(2);
});

// #1110: a hook of correct's outcome fails after the seat wrote `corrected`; a plain unpark must take the
// outcome again, not launch a second correct seat. The recipe copy wraps only the tested hook's argv: it fails
// while the flag file exists and otherwise runs the shipped argv unchanged.
function faultRecipe(hook: number): { path: string; flag: string } {
  const r = raw();
  const run = r.stages.correct.outcomes[0].run as string[][];
  const flag = join(root, "fail-hook");
  run[hook] = ["sh", "-c", '[ ! -e "$0" ] || exit 1; exec "$@"', flag, ...run[hook]];
  const path = join(root, "recipe-fault.json");
  writeFileSync(path, JSON.stringify(r));
  return { path, flag };
}
const toCorrect = () => newHost((_u, n) => {
  if (n === 1) { queue(W1, 1, 1); put(out("lane", "lane.done"), "x"); }
}, {
  close: (u, n) => (n === 1 ? put(out(u, "correction.txt"), packet(u, "[AC] AC1 fails: exit 1")) : oss("work_item_pr", u, prUrl(u))),
  correct: (u) => put(out(u, "corrected"), "x"),
});
const finished = () => unit(W1)?.stage === "done" || unit(W1)?.parked !== undefined;
const skipped = () => events().filter((e) => e.kind === "relaunch skipped" && e.unit === W1 && e.stage === "correct");

test("a failed hook at the last step of correct's outcome: a plain unpark takes the outcome again, with no second seat (#1110)", async () => {
  const f = faultRecipe(1); // the second hook, `rm -f corrected` in the shipped order
  await arm(f.path);
  writeFileSync(f.flag, "");
  const host = toCorrect();
  const r = rig(host);
  await drive(r, 40, finished);
  expect([unit(W1).stage, unit(W1).parked?.reason]).toEqual(["correct", "run failed"]);
  expect(existsSync(out(W1, "corrected"))).toBe(true); // the trigger survived the failure
  rmSync(f.flag);
  expect(await main(["unpark", "r1", W1])).toBe(0);
  await drive(r, 40, finished);
  expect(unit(W1).stage).toBe("done");
  expect(host.of(W1, "correct")).toHaveLength(1);
  expect(item(W1).dispatches).toBe(2);
  expect(skipped()).toHaveLength(1);
  expect(existsSync(out(W1, "corrected"))).toBe(false);
  expect(existsSync(out(W1, "correction.txt"))).toBe(false);
  expect(readFileSync(out(W1, "correction-1.txt"), "utf8")).toContain("AC1 fails");
  expect(existsSync(out(W1, "correction-2.txt"))).toBe(false);
});

test("control: a failure at correct's first hook also reruns the hooks with no second seat (#1110)", async () => {
  const f = faultRecipe(0);
  await arm(f.path);
  writeFileSync(f.flag, "");
  const host = toCorrect();
  const r = rig(host);
  await drive(r, 40, finished);
  expect([unit(W1).stage, unit(W1).parked?.reason]).toEqual(["correct", "run failed"]);
  expect(existsSync(out(W1, "corrected"))).toBe(true);
  rmSync(f.flag);
  expect(await main(["unpark", "r1", W1])).toBe(0);
  await drive(r, 40, finished);
  expect(unit(W1).stage).toBe("done");
  expect(host.of(W1, "correct")).toHaveLength(1);
  expect(skipped()).toHaveLength(1);
  expect(readdirSync(dirname(out(W1, "x"))).filter((n) => n.startsWith("correction-"))).toEqual(["correction-1.txt"]);
});

test("control: with no hook failure the correction runs once and nothing is skipped (#1110)", async () => {
  const f = faultRecipe(1); // wrapped, flag never written
  await arm(f.path);
  const host = toCorrect();
  await drive(rig(host), 40, finished);
  expect(unit(W1).stage).toBe("done");
  expect(host.of(W1, "correct")).toHaveLength(1);
  expect(skipped()).toHaveLength(0);
});

test("a halting verdict runs verify, close, correct, then verify and close again", async () => {
  await arm();
  let verdictAtVerify2: boolean | undefined;
  const host = newHost((_u, n) => {
    if (n === 1) { queue(W1, 1, 1); put(out("lane", "lane.done"), "x"); }
  }, {
    verify: (u, n) => {
      // the second pass: the first verdict went before its launch, so it cannot route this pass
      if (n === 2) verdictAtVerify2 = existsSync(out(u, "verdict.json"));
      put(out(u, "verdict.json"), verdict(u, n === 1 ? STAYED_GREEN : []));
    },
  });
  const r = rig(host);
  await drive(r, 50, () => unit(W1)?.stage === "done" || unit(W1)?.parked !== undefined);

  expect(moves(W1)).toEqual([
    "implement>verify", "verify>close", "close>correct", "correct>verify", "verify>close", ...TO_LAND, "land>done",
  ]);
  expect(host.of(W1, "verify")).toHaveLength(2);
  expect(host.of(W1, "close")).toHaveLength(2);
  expect(host.of(W1, "correct")).toHaveLength(1);
  expect(verdictAtVerify2).toBe(false);
  // Each round's verdict stays (#1005): the first holds the stayed-green result that sent it back.
  expect(JSON.parse(readFileSync(out(W1, "verdict-1.json"), "utf8")).mutation).toEqual(STAYED_GREEN);
  expect(JSON.parse(readFileSync(out(W1, "verdict.json"), "utf8")).mutation).toEqual([]);
  expect(existsSync(out(W1, "verdict-2.json"))).toBe(false);
  expect(item(W1).dispatches).toBe(2); // implement and correct; verify is no dispatch
});

// ---- #1095: spine_finish reads origin/main, and a PR-only workspace waits for its close PR ----

/** Drive a run with no items to the second close: the spine PR is merged by hand at the ack, and the finish seat does `finish`. */
async function toFinish(finish: Effect, until: () => boolean, between: (r: Rig) => void = () => {}) {
  await arm();
  const host = newHost(() => put(join(runDir, "rounds.done"), "x"), { spine_finish: finish });
  const r = rig(host);
  r.forge.views.set(CLOSE_PR, { state: "OPEN", head: HEAD0, base: "main", mergeable: "MERGEABLE", checks: "green" });
  await drive(r, 60, until, () => {
    if (unit(SPINE_UNIT)?.stage === "spine_ack") {
      r.forge.views.set(prUrl(SPINE_UNIT), { ...r.forge.views.get(prUrl(SPINE_UNIT))!, state: "MERGED", head: "spinehead" });
    }
    between(r);
  });
  return r;
}
const parkedIn = (stage: string) => () => unit(SPINE_UNIT)?.stage === stage && unit(SPINE_UNIT)?.parked !== undefined;
const closeView = (r: Rig, v: Partial<PrView>) => r.forge.views.set(CLOSE_PR, { ...r.forge.views.get(CLOSE_PR)!, ...v });
/** The close PR merges: the branch lands on origin/main. */
const landClose = () => git(aiRoot, "push", "origin", "docs/close:main");
const onMain = () => git(aiRoot, "symbolic-ref", "--short", "HEAD");

test("a close that reached origin/main ends spine_finish done (#1095)", async () => {
  await toFinish(seats().spine_finish, () => readRun().status === "done");
  expect(moves(SPINE_UNIT).at(-1)).toBe("spine_finish>done");
  expect(git(aiRoot, "show", "origin/main:.ossify/project-state.json")).toContain('"closed"');
});

test("a close only in the local state file is not done: origin/main still reads planned (#1095 regression)", async () => {
  // the seat closes locally and neither pushes nor opens a PR: the old local read called that done
  const r = await toFinish(closeLocally, parkedIn("spine_finish"));
  expect(readRun().status).not.toBe("done");
  expect(moves(SPINE_UNIT)).not.toContain("spine_finish>done");
  expect(unit(SPINE_UNIT).parked?.reason).toBe("no result");
  expect(r.host.of(SPINE_UNIT, "spine_finish")).toHaveLength(3);
});

test("close-pr.txt routes spine_finish to spine_close_wait, and a merged close PR with origin/main closed ends done (#1095)", async () => {
  const r = await toFinish(() => closeOnBranch(), () => unit(SPINE_UNIT)?.stage === "spine_close_wait");
  expect(moves(SPINE_UNIT).at(-1)).toBe("spine_finish>spine_close_wait"); // the recipe's outcome, not the fake seat's own action
  expect(r.host.of(SPINE_UNIT, "spine_finish")).toHaveLength(1);
  expect(r.notes.some((n) => n.includes("close-pr.txt"))).toBe(true);
  await settle(r, 3);
  expect(unit(SPINE_UNIT).stage).toBe("spine_close_wait"); // an open PR waits, with no park
  expect(unit(SPINE_UNIT).parked).toBeUndefined();
  closeView(r, { state: "MERGED" });
  landClose();
  await drive(r, 10, () => readRun().status === "done");
  expect(moves(SPINE_UNIT).slice(-2)).toEqual(["spine_finish>spine_close_wait", "spine_close_wait>done"]);
});

test("spine_close_wait parks a close PR that merged while origin/main does not read closed (#1095)", async () => {
  const r = await toFinish(() => closeOnBranch(), () => unit(SPINE_UNIT)?.stage === "spine_close_wait");
  closeView(r, { state: "MERGED" }); // merged, but the record never reached main
  await drive(r, 10, parkedIn("spine_close_wait"));
  expect(unit(SPINE_UNIT).parked?.reason).toBe("outcome"); // not "exit0 error"
  expect(readRun().status).not.toBe("done");
});

test("spine_close_wait parks a close PR closed without a merge (#1095)", async () => {
  const r = await toFinish(() => closeOnBranch(), () => unit(SPINE_UNIT)?.stage === "spine_close_wait");
  closeView(r, { state: "CLOSED" });
  await drive(r, 10, parkedIn("spine_close_wait"));
  expect(unit(SPINE_UNIT).parked?.reason).toBe("outcome");
});

test("spine_close_wait parks a close PR in conflict (#1095)", async () => {
  const r = await toFinish(() => closeOnBranch(), () => unit(SPINE_UNIT)?.stage === "spine_close_wait");
  closeView(r, { mergeable: "CONFLICTING" });
  await drive(r, 10, parkedIn("spine_close_wait"));
  expect(unit(SPINE_UNIT).parked?.reason).toBe("outcome");
});

test("spine_close_wait parks `pr url` when close-pr.txt holds no PR URL (#1095)", async () => {
  await toFinish(() => closeOnBranch("not a url"), parkedIn("spine_close_wait"));
  expect(unit(SPINE_UNIT).parked?.reason).toBe("pr url");
});

test("spine_close_wait parks `exit0 error` when the PR is merged and origin cannot be reached (#1095 C3)", async () => {
  const r = await toFinish(() => closeOnBranch(), () => unit(SPINE_UNIT)?.stage === "spine_close_wait");
  closeView(r, { state: "MERGED" });
  git(aiRoot, "remote", "set-url", "origin", join(root, "nowhere.git")); // the stale origin/main ref stays: the fetch failure must park, not read false
  await drive(r, 10, parkedIn("spine_close_wait"));
  expect(unit(SPINE_UNIT).parked?.reason).toBe("exit0 error");
  expect(readRun().status).not.toBe("done");
});
