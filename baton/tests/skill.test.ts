// The prose that seats and orchestrators follow, pinned on the lines they cannot do without:
// the skill's approval stop and no-watch rule (#969 C11), and each done-file brief's last step
// (#908). Prose, so the pins are exact phrases, each read on one line of its source.
import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const SKILL = join(import.meta.dir, "..", "skills", "running-a-spine-on-baton", "SKILL.md");
const BRIEFS_DIR = join(import.meta.dir, "..", "examples", "ossify-spine", "briefs");
const skill = (): string => readFileSync(SKILL, "utf8");
/** The skill with every run of whitespace one space: a pin on a phrase must not depend on where the source wraps. */
const flatSkill = (): string => skill().replace(/\s+/g, " ");
const brief = (name: string): string => readFileSync(join(BRIEFS_DIR, name), "utf8");

/** The frontmatter's `description` value, or "" when there is none. */
function description(md: string): string {
  const fm = /^---\n([\s\S]*?)\n---\n/.exec(md);
  return /^description: (.*)$/m.exec(fm?.[1] ?? "")?.[1] ?? "";
}

/** The last numbered step of a brief, or "" when it has none. */
function lastStep(md: string): string {
  const steps = md.split("\n").filter((l) => /^\d+\. /.test(l));
  return steps.at(-1) ?? "";
}

describe("running-a-spine-on-baton", () => {
  test("the description tells baton arm apart from /ossify:run-spine", () => {
    const d = description(skill());
    expect(d).toContain('"on baton"');
    expect(d).toContain("`/ossify:run-spine`");
    expect(description("no frontmatter")).toBe("");
  });

  test("the approval stop survives a waiver and a changed value", () => {
    const s = skill();
    expect(s).toContain("do not waive this step");
    expect(s).toContain("A yes that changes or supplies a value is not that yes");
    expect(s).toContain("wait for an explicit yes");
  });

  // #993: seats come from crew's two files, resolved at arm time and approved with the command.
  test("the seat step reads crew's two files and stops on a role with no row", () => {
    const s = skill();
    expect(s).toContain("`.crew/roles.md`");
    expect(s).toContain("`~/.claude/crew/agents.md`");
    expect(s).toContain("A role with no row is one question, and arms nothing");
  });

  test("the seat table is shown with the command, and written only after the yes", () => {
    const s = skill();
    expect(s).toContain("| Stage | Role | Agent | Command | Model | Effort | From |");
    expect(s).toContain("--seats /home/<user>/baton-recipes/seats/<run>.json");
    expect(s).not.toContain("--seats ~");
    expect(s).toContain("never `~/…`");
    expect(s).toContain("Write the seat file only after the yes");
    // The write comes after the stop, never before it.
    expect(s.indexOf("Write the seat file only after the yes")).toBeGreaterThan(s.indexOf("wait for an explicit yes"));
  });

  test("an argv is built only from a plain program, Devin's ends with --, review drops its PR placeholder", () => {
    const s = skill();
    expect(s).toContain("a shell function or an alias");
    expect(s).toContain("End a Devin agent's argv with `--`");
    expect(s).toContain("drop a trailing `<PR_URL>` or `<PR>`");
  });

  test("via is gone from the skill and the README's arm example", () => {
    expect(skill()).not.toMatch(/\bvia\b/);
    const readme = readFileSync(join(import.meta.dir, "..", "README.md"), "utf8");
    expect(readme).not.toContain("--param via=");
    expect(readme).toContain("--seats <file>");
    expect("--param via=x").toContain("--param via="); // control: the probe matches the old line
  });

  // #1003: a spine's user: lines need a walker; the preflight says so before the arm instead of parking after the merge.
  test("the preflight reads the user: lines and the orders, and warns in the proposal rather than failing", () => {
    const s = skill();
    const bullet = s.split("\n- **").find((b) => b.startsWith("Who walks the `user:` lines."))?.replace(/\s+/g, " ") ?? "";
    // planned lines count: `oss demo_user_lines` is active-only, and a spine's lines are still planned before the arm
    expect(bullet).toContain(".type == \"user\"")
    expect(bullet).toContain("planned ones included");
    expect(bullet).not.toContain("demo_user_lines");
    expect(bullet).toContain("as the base branch has them");
    expect(bullet).toContain("no order that gives the demo walk to the `spine_finish` seat's role");
    expect(bullet).toContain("is not a failed check: say in the proposal that the run parks after the merge");
    // it sits in the preflight, before the proposal step that shows the command
    expect(s.indexOf("Who walks the `user:` lines.")).toBeGreaterThan(s.indexOf("## 1. Preflight"));
    expect(s.indexOf("Who walks the `user:` lines.")).toBeLessThan(s.indexOf("## 2. Propose, then stop"));
    // control: the bullet must not turn into a stop - it never says to stop or arm around it
    expect(bullet).not.toMatch(/\b(stop and report|do not arm|refuse)/i);
    // control: the probe finds nothing in a skill without the bullet
    expect("- **The recipe copy.** x".split("\n- **").find((b) => b.startsWith("Who walks the `user:` lines."))).toBeUndefined();
  });

  test("after arming, a watch request runs no command and the close is baton's", () => {
    const s = flatSkill();
    expect(s).toContain('"Keep an eye on it" is not a status request');
    expect(s).toContain("Do not start `/ossify:close` beside it.");
  });

  test("notices go to the orchestrator: no OpenBot, no spend-nothing line, a Notices section (#1045)", () => {
    const s = flatSkill();
    expect(s).not.toMatch(/openbot|phone/i);
    expect(s).not.toContain("spend no tokens on the run");
    expect(s).toContain('"notify": ["baton", "notify-orchestrator", "{key}", "{message}"]');
    expect(s).toContain("## Notices");
    expect(s).toContain("`baton orchestrator <run>` as its first step, and `baton orchestrator <run> --clear` before it stands down");
    // control: the flattened skill still matches a phrase the source wraps
    expect(flatSkill()).toContain("a lean successor (the top hands off by spawning one)");
    expect(s).toContain("[crew message baton] baton notice <key>");
    // design 5, row 2: no verb raises the dispatch cap
    expect(s).toContain("raising the dispatch cap (no verb does it");
    // no default merge authority
    expect(s).toContain("unless the project's governance grants this session merge authority");
  });
});

describe("done-file briefs", () => {
  // The label each stage's message gives its done file, read from the recipe.
  const recipe = JSON.parse(readFileSync(join(BRIEFS_DIR, "..", "recipe.json"), "utf8"));
  const labels = (stage: string): string[] =>
    [...String(recipe.stages[stage].message).matchAll(/([A-Z][a-z]+(?: [a-z]+)* done file|Corrected file): /g)].map((m) => m[1]);
  for (const [name, stage] of [["correct.md", "correct"], ["spine-work.md", "spine_work"], ["item-fix.md", "item_fix"], ["lane.md", "lane"]]) {
    test(`${name} ends by writing the done file its stage's message names`, () => {
      const ls = labels(stage);
      expect(ls.length).toBeGreaterThan(0);
      for (const l of ls) expect([l, lastStep(brief(name)).includes(`: > <${l} from your message>`)]).toEqual([l, true]);
    });
  }

  test("control: a brief whose done-file write is not the last step fails", () => {
    expect(lastStep("1. Write the file: `: > <Corrected file from your message>`.\n2. End.")).not.toContain(": > <");
    expect(lastStep("prose only")).toBe("");
  });
});

// #1075 C2: a ruling file holds one ruling. Appending handed a relaunched seat the old ruling first,
// and an unpark --to runs no outcome hook, so a left file reached the next close or spine-open seat.
describe("a ruling file holds one ruling (#1075)", () => {
  const readme = () => readFileSync(join(import.meta.dir, "..", "README.md"), "utf8").replace(/\s+/g, " ");
  const APPENDS = /append(ing)? (it |the ruling )?(to|if one)/i;
  test("the runbook says replace, never append, and to move the file aside before an unpark --to", () => {
    const r = readme();
    expect(r).toContain("replacing any file already there: the file holds one ruling");
    // the list is examples, not the whole set: any stage but the one the ruling is for (#1075 PR1076r2 C8)
    expect(r).toContain("any stage other than the one the ruling is for (for example `implement`, `regap`, `verify`, `correct`, `spine_review` or `item_review`, which name no Ruling file), move any `operator.md` aside as the next free `operator-<n>.md`: `--to` runs no outcome hook");
    expect(r).not.toContain("a stage that names no Ruling file (`implement`");
    expect(r).toContain("An implement, regap, verify or correct stop takes its ruling in the handoff's `## Clarifications`");
    expect(r).toContain("replace any file there");
    expect(r).not.toMatch(APPENDS);
    // a control per alternative: the probe matches the 0.16.0 wording and each variant it must also catch
    for (const alt of ["append to", "append it to, when", "append the ruling to", "appending to", "Append if one", "append it if one", "Appending the ruling to"]) {
      expect([alt, APPENDS.test(alt)]).toEqual([alt, true]);
    }
    for (const fine of ["replacing any file already there", "the file holds one ruling, never two", "append rulings"]) {
      expect([fine, APPENDS.test(fine)]).toEqual([fine, false]); // and it does not match prose that says the opposite
    }
  });
  test("the item review stop is in the notices and the README runbook (#1046)", () => {
    const row = skill().split("\n").find((l) => l.startsWith("| Item review stop")) ?? "";
    expect(row).toContain("--to item_fix");
    expect(row).toContain("--to land");
    expect(skill()).toContain("on each reviewer row (`reviewer`, `item reviewer`)");
    const r = readme();
    for (const pin of ["The item review stop.", "at most three reviews", "`out/<wi>/review-2.md` exists (review 3 has run)",
      "`baton unpark <run> <wi> --to item_fix`", "`baton unpark <run> <wi> --to land`", "`item_wait` parks** on `closed` and `conflict`",
      "`item reviewer` (with `review`)", "`expect_head` (optional)", "`outcomes.moved`, which is then required"]) {
      expect([pin, r.includes(pin)]).toEqual([pin, true]);
    }
  });
  test("the item_moved park has a notices row: nothing merged, one more review, or by hand; land parks again (#1079 C11)", () => {
    const row = skill().split("\n").find((l) => l.startsWith("| Item moved stop")) ?? "";
    expect(row).toContain("`item_moved` park");
    expect(row).toContain("nothing merged");
    expect(row).toContain("`--to item_review`");
    expect(row).toContain("one more review");
    expect(row).toContain("by hand");
    expect(row).toContain("`--to land` alone parks again");
    // control: the probe finds no row in a skill without it
    expect("| Close harvest | a | b |".split("\n").find((l) => l.startsWith("| Item moved stop"))).toBeUndefined();
  });
  test("every skill row that writes operator.md says replace, and the close row says move it aside", () => {
    const rows = skill().split("\n").filter((l) => l.startsWith("|") && l.includes("operator.md"));
    expect(rows.length).toBe(5);
    for (const row of rows) expect(row).toContain("replacing any");
    const close = rows.find((l) => l.startsWith("| Close or spine-open stop |")) ?? "";
    expect(close).toContain("move it aside as the next free `operator-<n>.md` before an unpark `--to` any stage other than the one the ruling is for");
  });
});

// 0.17.3 wording: the README and the skill, pinned on the lines an operator or an orchestrator acts on.
describe("README and skill wording (baton 0.17.3)", () => {
  const readmeRaw = () => readFileSync(join(import.meta.dir, "..", "README.md"), "utf8");
  const readme = () => readmeRaw().replace(/\s+/g, " ");
  /** A runbook bullet: the text from `- **<title>` to the next bullet, whitespace flattened; "" when absent. */
  const bullet = (title: string): string => readmeRaw().split("\n- **").find((b) => b.startsWith(title))?.replace(/\s+/g, " ") ?? "";

  test("expect_head does not itself require green checks: the stage's checks policy decides (#1079 CodeRabbit)", () => {
    const r = readme();
    expect(r).toContain("`expect_head` does not itself require green checks (the stage's `checks` policy still decides)");
    expect(r).not.toContain("green checks are still required");
  });

  test("an item_moved park has a runbook bullet of its own (#1079 C10)", () => {
    const b = bullet("An `item_moved` park");
    expect(b).toContain("nothing was merged");
    expect(b).toContain("`baton unpark <run> <wi> --to item_review`");
    expect(b).toContain("`--to land` parks again at once");
    expect(b).toContain("merge the PR yourself");
    // the item review stop's own bullet points at it instead of carrying the detail
    expect(bullet("The item review stop.")).toContain("`item_moved` park, below");
    // control: the probe finds no bullet in a README without it
    expect("- **x**".split("\n- **").find((t) => t.startsWith("An `item_moved` park"))).toBeUndefined();
  });

  test("the runbook's lines keep the file's wrap width (#1079 C12)", () => {
    const text = readmeRaw();
    const region = text.slice(text.indexOf("Operator runbook:"), text.indexOf("## Known limits")).split("\n");
    expect(region.filter((l) => l.length > 105)).toEqual([]);
    expect(region.length).toBeGreaterThan(60); // control: the region is the runbook, not an empty slice
    expect(["x".repeat(106)].filter((l) => l.length > 105)).toHaveLength(1); // control: the filter reports a long line
  });

  test("an item_ready park has a runbook route and a notice row: fix pr_url in both places, then --to item_ready", () => {
    const r = readme();
    expect(r).toContain("**An `item_ready` park** (the recorded `pr_url` is not a PR URL)");
    expect(r).toContain("in the run's `queue/<wi>.json`, which close copied it to, then `baton unpark <run> <wi> --to item_ready`");
    expect(flatSkill()).toContain("| PR URL stop (`item_ready` park) |");
    expect(flatSkill()).toContain("fix the item's `pr_url` in the ossify state and in `queue/<wi>.json`, then `--to item_ready`");
  });

  test("the example recipe needs a check on item and spine PRs, and the skill's preflight asks (#1079 Q1)", () => {
    const r = readme();
    expect(r).toContain("needs at least one check that runs on its item PRs (into the spine branch)");
    expect(r).toContain("`branches: [main]` runs on no item PR");
    expect(r).toContain("A PR with no checks reads as `none`");
    expect(r).toContain("waits in `item_wait`, `spine_wait` or `land` with no park");
    const bul = flatSkill().split(" - **").find((b) => b.startsWith("Checks on the PRs.")) ?? "";
    expect(bul).toContain("at least one check that runs on item PRs (into the spine branch)");
    expect(bul).toContain("not a recent PR's checks");
    expect(bul).toContain("with no park");
    expect(bul).toContain("is one question");
    expect(skill().indexOf("**Checks on the PRs.**")).toBeGreaterThan(skill().indexOf("## 1. Preflight"));
    expect(skill().indexOf("**Checks on the PRs.**")).toBeLessThan(skill().indexOf("## 2. Propose, then stop"));
  });

  test("the notice file name's character mapping is stated (#1053 C1)", () => {
    expect(readme()).toContain("notices/<key>.md` (mode 600; each character of the key outside `A-Za-z0-9._-` becomes `_`)");
  });

  test("the retired bridge clause is gone from the answer section (#1053 PR1054 C1)", () => {
    const r = readme();
    expect(r).not.toContain("bridge");
    expect(r).not.toContain("operator's tap");
    expect(r).toContain("Two commands let a caller answer it from outside the Orca terminal");
  });

  test("the readers of a Ruling file named in the README are the recipe's, and a lane barrier is ruled by planning (#1075 PR1076r2 C11)", () => {
    const r = readme();
    const m = /the next seat that reads the file \(([^)]*)\) would apply it/.exec(r);
    expect(m).not.toBeNull();
    const named = m![1].split(/,| or /).map((t) => t.replace(/[`\s]/g, "").replace(/-/g, "_")).filter(Boolean).sort();
    const recipe = JSON.parse(readFileSync(join(BRIEFS_DIR, "..", "recipe.json"), "utf8"));
    const readers = Object.entries(recipe.stages as Record<string, { message?: string }>)
      .filter(([, st]) => (st.message ?? "").includes("Ruling file:")).map(([n]) => n).sort();
    expect(named).toEqual(readers);
    expect(r).toContain("a lane round barrier is ruled by planning the round");
    // control: a reader missing from the README's list is reported by the same comparison
    expect(named.filter((n) => n !== "item_fix")).not.toEqual(readers);
  });

  test("a stop's ruling points at the Ruling-file bullet for the stages that read operator.md (#1075 C7)", () => {
    const b = bullet("A stop parks the unit.");
    expect(b).toContain("a close, spine-open or spine-finish stop takes `operator.md`, as the ruling bullet below says");
  });

  test("the spine_finish row is no longer a user:-line row only, and carries the move-aside clause (#1075 C7, C10)", () => {
    const row = skill().split("\n").find((l) => l.startsWith("| `spine_finish` stop |")) ?? "";
    expect(row).not.toContain("on a `user:` line |");
    expect(row).toContain("any other stop");
    expect(row).toContain("a `user:` line");
    expect(row).toContain("replacing any");
    expect(row).toContain("move it aside as the next free `operator-<n>.md` before an unpark `--to` any other stage");
    expect(skill()).not.toContain("| `spine_finish` stop on a `user:` line |");
  });
});

describe("briefs wording (baton 0.17.3)", () => {
  const flatBrief = (n: string): string => brief(n).replace(/\s+/g, " ");
  test("common's ledger entry quotes the ruling, it does not name a file that is archived later (#1075 C3, PR1076r1 C6)", () => {
    const c = flatBrief("common.md");
    expect(c).toContain("else as a ledger entry whose `A:` quotes the ruling in one line");
    expect(c).not.toContain("whose `A:` names the file");
  });
});

// 0.17.4 / 0.18.0 / 0.18.1 wording (#1095, #1053 C4, #1100): the runbook lines an operator or an orchestrator acts on.
describe("README, skill and release wording (baton 0.18.1)", () => {
  const readmeRaw = () => readFileSync(join(import.meta.dir, "..", "README.md"), "utf8");
  const bullet = (title: string): string => readmeRaw().split("\n- **").find((b) => b.startsWith(title))?.replace(/\s+/g, " ") ?? "";
  const changelog = () => readFileSync(join(import.meta.dir, "..", "CHANGELOG.md"), "utf8");

  test("a run failed park on a session stage: a plain unpark reads the outcomes first; --to skips it (#1053 C4, #1100)", () => {
    const b = bullet("A `run failed` park on a session stage");
    expect(b).toContain("a plain `baton unpark` reads the stage's outcomes first");
    expect(b).toContain("if the outcome still reads true, its hooks run again from the first and the unit moves on with no seat");
    expect(b).toContain("(in a run armed before 0.18.1, `correct`'s first hook removes `corrected`: archive `correction.txt` by hand, then `--to verify`), the seat relaunches and reruns the round");
    expect(b).toContain("run the remaining steps by hand, then `baton unpark <run> <unit> --to <next stage>`");
    expect(b).not.toContain("a plain `baton unpark` relaunches the seat");
    const row = skill().split("\n").find((l) => l.startsWith("| `run failed` park on a session stage |")) ?? "";
    expect(row).toContain("a plain unpark reruns the hooks and moves on with no seat if the outcome still reads true, else relaunches the seat");
    expect(row).toContain("(a run armed before 0.18.1: `correct`'s first hook removes `corrected`)");
    expect(row).toContain("run the remaining steps by hand, then `--to <next stage>`");
  });

  test("a stop: to make a seat apply a ruling, unpark --to the same stage; a plain unpark takes a result already written (#1100)", () => {
    const b = bullet("A stop parks the unit");
    expect(b).toContain("To make a seat apply a ruling, unpark `--to <the same stage>`");
    expect(b.replace(/\s+/g, " ")).toContain("if the seat had already written its result, the unit takes it and moves on with the ruling unapplied");
  });

  test("the README names the relaunch read, the event and the report count (#1100)", () => {
    const r = readmeRaw().replace(/\s+/g, " ");
    expect(r).toContain("A plain `unpark` of a stage where a worker had run reads the stage's outcomes before it launches again");
    expect(r).toContain("`unpark --to <stage>` enters a fresh visit and launches without reading them");
    expect(r).toContain("logs `relaunch skipped` (`unit`, `stage`, `to`, `outcome`: the matched outcome's 1-based place); `baton report` counts them");
  });

  test("spine_close_wait: the README names the close PR and its parks, the skill has a row (#1095)", () => {
    const b = bullet("A `spine_close_wait` park");
    for (const s of ["close-pr.txt", "merged but `origin/main` does not read the spine closed", "closed without a merge", "conflict"]) expect(b).toContain(s);
    const row = skill().split("\n").find((l) => l.startsWith("| `spine_close_wait` park |")) ?? "";
    expect(row).toContain("origin/main");
    expect(row).toContain("never merge");
    expect(row).toContain("`close-pr.txt` holds no PR URL");
    // C1: a plain unpark after removing the file only re-parks (`pr url`); the rerun needs --to spine_finish
    expect(b).toContain("reopen the PR; or replace `out/spine-pr/close-pr.txt` with a valid close-PR URL, then unpark; or remove it and rerun the close with `baton unpark <run> spine-pr --to spine_finish`");
    expect(b).not.toContain("replace or remove");
    const notice = skill().split("\n").find((l) => l.startsWith("| AI close PR recorded (")) ?? "";
    expect(notice).toContain("merge it if governance grants this session merge authority");
    expect(flatSkill()).toContain("the AI close PR, where the workspace takes PRs only");
  });

  test("the README names the failure lines in notify.log (N4)", () => {
    const r = readmeRaw().replace(/\s+/g, " ");
    expect(r).toContain("`<iso> <key> notify-orchestrator <where>: <reason>`");
  });

  test("the version is 0.19.0 in plugin.json and the changelog; 0.18.1, 0.18.0 and 0.17.4 keep their upgrade notes as history (#1110)", () => {
    expect(JSON.parse(readFileSync(join(import.meta.dir, "..", ".claude-plugin", "plugin.json"), "utf8")).version).toBe("0.19.0");
    const top = changelog().split("\n## ")[1].replace(/\s+/g, " ");
    expect(top.startsWith("0.19.0 - ")).toBe(true);
    const v181 = changelog().split("\n## ")[2].replace(/\s+/g, " ");
    expect(v181.startsWith("0.18.1 - ")).toBe(true);
    expect(v181).toContain("`correct` archives `correction.txt` before it removes `corrected`");
    expect(v181).toContain("#1110");
    expect(v181).toContain("Armed runs keep the order they were armed with");
    expect(v181).toContain("takes effect at that project's next `baton arm`");
    expect(v181).toContain("Never `cp -r` over a customised copy");
    expect(v181).toContain("`rm -f review.md round-done operator.md`");
    // 0.18.0 keeps its own upgrade note and its #1110 known limit as history
    const v18 = changelog().split("\n## ")[3].replace(/\s+/g, " ");
    expect(v18.startsWith("0.18.0 - ")).toBe(true);
    expect(v18).toContain("It reaches every armed run at its next tick");
    expect(v18).toContain("no recipe copy is needed");
    expect(v18).toContain("`relaunch skipped`");
    expect(v18).toContain("Reordering its hooks is #1110");
    // 0.17.4 keeps its own upgrade note
    const prev = changelog().split("\n## ")[4];
    expect(prev.startsWith("0.17.4 - ")).toBe(true);
    expect(prev).toContain("only when no run is armed or parked there");
    expect(prev).toContain("the archive snippet's ten copies");
    expect(prev).not.toContain("nine copies");
  });
});

// 0.19.0 (#931, #1049, #1053 C7, #1206): the runbook lines an orchestrator acts on after the spine PR loop and the close.
describe("README, skill and release wording (baton 0.19.0)", () => {
  const readmeFlat = () => readFileSync(join(import.meta.dir, "..", "README.md"), "utf8").replace(/\s+/g, " ");
  const changelog = () => readFileSync(join(import.meta.dir, "..", "CHANGELOG.md"), "utf8");
  const row = (start: string) => skill().split("\n").find((l) => l.startsWith(start)) ?? "";

  test("the changelog closes the four issues, names the engine as unchanged, and carries the known limits (#1053 moved its last item to merge-bar #1211)", () => {
    const top = changelog().split("\n## ")[1].replace(/\s+/g, " ");
    expect(top).toContain("Closes #931, #1049, #1053 and #1206");
    expect(top).toContain("The engine is unchanged");
    expect(top).not.toContain("loops `spine_review` and `spine_wait` with no park"); // the loop is parked now, not a known limit
    for (const pin of ["A run armed before 0.19.0 keeps its recipe and briefs", "The cap counts reviews, not wall time", "`spine_ack` checks the head only on entry", "The ack notice names the reviewed head and says to merge only that head", "the fourth parks `spine_wait` (`review-stale-3.md` exists)"]) {
      expect([pin, top.includes(pin)]).toEqual([pin, true]);
    }
  });

  test("the spine review stop is in the notices and the README runbook, beside the item one; the PR conflict row keeps the review under a number (#1206)", () => {
    const stop = row("| Spine review stop (`spine_wait` park, review 3) |");
    expect(stop).toContain("--to spine_work");
    expect(stop).toContain("out/spine-pr/operator.md");
    expect(stop).toContain("`main` to bring in");
    const ack = row('| "passed review … merge it" |');
    for (const pin of ["merge only the head the notice names (`gh pr merge --match-head-commit <head>`)", "move it aside as the next free `review-stale-<n>.md`", "`--to spine_review`"]) {
      expect([pin, ack.includes(pin)]).toEqual([pin, true]);
    }
    expect(stop).toContain("(then a plain unpark)");
    const staleStop = row("| Stale-review stop (`spine_wait` park, `review-stale-3.md` exists) |");
    expect(staleStop).toContain("find out why the reviewer keeps reading an old head");
    expect(staleStop).toContain("move it aside as the next free `review-stale-<n>.md`");
    expect(staleStop).toContain("unpark `--to spine_review`");
    expect(row("| PR conflict |")).toContain("copy `review.md` to `review-prev.md` and move it aside as the next free `review-<n>.md`");
    const r = readmeFlat();
    for (const pin of ["**The spine review stop.**", "at most three counted reviews", "once `review-2.md` exists (review 3 has run) parks `spine-pr` in `spine_wait`",
      "`review-stale-<n>.md`", "A stale review takes no review number", "A fourth stale pass (once `review-stale-3.md` exists) parks `spine-pr` in `spine_wait` with reason `outcome`",
      "`baton unpark <run> spine-pr --to spine_work`", "a plain `baton unpark <run> spine-pr` reads the merge",
      "`spine_ack` is entered only when `review.md`'s line 2 equals `head: <the PR's head>` at that moment; baton does not watch the head while `spine_ack` waits, and the merge pin is the merge holder's `--match-head-commit`",
      "only the head the notice names (`gh pr merge --match-head-commit <head>`); if the PR head has moved, copy `out/spine-pr/review.md` to `review-prev.md`, move it aside as the next free `review-stale-<n>.md` and `baton unpark <run> spine-pr --to spine_review`",
      "copy `out/spine-pr/review.md` to `review-prev.md` and move it aside as the next free `review-<n>.md`"]) {
      expect([pin, r.includes(pin)]).toEqual([pin, true]);
    }
    expect(r).not.toContain("as `land` does through `expect_head`"); // spine_ack has no merge-time pin, land does
    expect(r.indexOf("**The spine review stop.**")).toBeGreaterThan(r.indexOf("**The item review stop.**"));
  });

  test("the Close harvest row says where the candidates are and that the orchestrator applies the accepted set, and the README says the seat accepts none (#1049)", () => {
    const h = row("| Close harvest |");
    for (const pin of ["`out/spine-pr/harvest.md`", "`## Harvest candidates` in the close PR body", "apply the operator's accepted set (ossify harvest §7)",
      "on the close PR's branch before the merge", "as a follow-up commit where the workspace pushes direct"]) {
      expect([pin, h.includes(pin)]).toEqual([pin, true]);
    }
    expect(h.endsWith("| accept |")).toBe(true);
    const r = readmeFlat();
    for (const pin of ["writes the harvest candidates to `out/spine-pr/harvest.md`", "accepts and applies none", "commits the review-ledger and tech-debt lines"]) {
      expect([pin, r.includes(pin)]).toEqual([pin, true]);
    }
  });
});
