import { describe, expect, test, spyOn, afterEach } from "bun:test";
import { mkdtempSync, mkdirSync, writeFileSync, copyFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { load, moduleCandidates, LOADER_VERSION } from "./plugin-bin-path";

const M = "claude-agent-scaffolding";
const homes: string[] = [];
function home() { const h = mkdtempSync(join(tmpdir(), "pbl-")); homes.push(h); return h; }
afterEach(() => { for (const h of homes.splice(0)) rmSync(h, { recursive: true, force: true }); });
const entry = (scope: string, installPath: string, projectPath?: string) => ({
  scope, installPath, version: "0.11.0", installedAt: "2026-11-19T15:30:06.679Z",
  lastUpdated: "2026-11-19T15:30:06.679Z", ...(projectPath === undefined ? {} : { projectPath }),
});
function entries(f: string, values: unknown[]) {
  mkdirSync(join(f, ".."), { recursive: true });
  writeFileSync(f, JSON.stringify({ version: 2, plugins: { "merge-bar@pulsestack": values } }));
}
function stub(h: string, name: string, version: number, minLoader = 1, body = "") {
  const p = join(h, "cache", `${name}-${version}`);
  mkdirSync(join(p, "omp"), { recursive: true });
  writeFileSync(join(p, "omp", "bin-path.ts"), body ||
    `export const VERSION = ${version}; export const MIN_LOADER_VERSION = ${minLoader};
     export default function (pi: any) { pi.ran = "${name}@${version}"; }`);
  return p;
}
function record(h: string, which: ".omp" | ".claude", plugins: Record<string, string>, m = M) {
  const f = join(h, which, "plugins", "installed_plugins.json");
  mkdirSync(join(f, ".."), { recursive: true });
  writeFileSync(f, JSON.stringify({ version: 2, plugins: Object.fromEntries(
    Object.entries(plugins).map(([n, p]) => [`${n}@${m}`, [{ scope: "user", installPath: p }]])) }));
}

describe("loader", () => {
  test("runs the highest-VERSION installed module", async () => {
    const h = home();
    // the higher version comes first, so "take the last module" would fail this test
    record(h, ".omp", { ossify: stub(h, "ossify", 2), "workspace-init": stub(h, "workspace-init", 1) });
    const pi: any = {};
    await load(pi, h);
    expect(pi.ran).toBe("ossify@2");
  });
  test("finds modules through the Claude record too", async () => {
    const h = home();
    record(h, ".claude", { "sage": stub(h, "sage", 1) });
    const pi: any = {};
    await load(pi, h);
    expect(pi.ran).toBe("sage@1");
  });
  test("both user records remain candidates for the newest module (control)", async () => {
    const h = home();
    record(h, ".omp", { ossify: stub(h, "omp-user", 1) });
    record(h, ".claude", { ossify: stub(h, "claude-user", 3) });
    const pi: { ran?: string } = {};
    await load(pi, h);
    expect(pi.ran).toBe("claude-user@3");
  });
  test("a plugin of our marketplace without omp/bin-path.ts yields no candidate", () => {
    const h = home();
    const bare = join(h, "cache", "merge-bar-9");
    mkdirSync(bare, { recursive: true });
    record(h, ".omp", { "merge-bar": bare });
    expect(moduleCandidates(h)).toEqual([]);
  });
  test("any plugin of our marketplace that ships omp/bin-path.ts is a candidate, not only a fixed list", () => {
    const h = home();
    const p = stub(h, "brand-new-plugin", 1);
    record(h, ".omp", { "brand-new-plugin": p });
    expect(moduleCandidates(h)).toEqual([join(p, "omp", "bin-path.ts")]);
  });
  test("moduleCandidates finds modules under both names", () => {
    const h = home();
    const a = stub(h, "ossify", 1), b = stub(h, "merge-bar", 1);
    record(h, ".omp", { ossify: a }, "pulsestack");
    record(h, ".claude", { "merge-bar": b }, "claude-agent-scaffolding");
    expect(moduleCandidates(h).sort()).toEqual([join(a, "omp", "bin-path.ts"), join(b, "omp", "bin-path.ts")].sort());
  });
  test("a plugin of another marketplace that ships omp/bin-path.ts yields no candidate", () => {
    const h = home();
    const p = stub(h, "ossify", 1);
    const f = join(h, ".omp", "plugins", "installed_plugins.json");
    mkdirSync(join(f, ".."), { recursive: true });
    writeFileSync(f, JSON.stringify({ version: 2, plugins: { "ossify@someone-else": [{ scope: "user", installPath: p }] } }));
    expect(moduleCandidates(h)).toEqual([]);
  });
  test("an entry whose installPath is not a string is skipped, not thrown on", () => {
    const h = home();
    const good = stub(h, "ossify", 1);
    const f = join(h, ".omp", "plugins", "installed_plugins.json");
    mkdirSync(join(f, ".."), { recursive: true });
    writeFileSync(f, JSON.stringify({ version: 2, plugins: {
      [`workspace-init@${M}`]: [{ scope: "user", installPath: 42 }],
      [`ossify@${M}`]: [{ scope: "user", installPath: good }] } }));
    expect(moduleCandidates(h)).toEqual([join(good, "omp", "bin-path.ts")]);
  });
  test("no installed module: one warning, nothing runs", async () => {
    const h = home();
    const warn = spyOn(console, "warn").mockImplementation(() => {});
    const pi: any = {};
    await load(pi, h);
    expect(pi.ran).toBeUndefined();
    expect(warn).toHaveBeenCalledTimes(1);
    expect(String(warn.mock.calls[0][0])).toContain("no installed plugin ships omp/bin-path.ts");
    warn.mockRestore();
  });
  test("an out-of-date relocated loader targets its own file with shell-safe quoting", async () => {
    const h = home();
    const loaderFile = join(h, "relocated space ' $HOME", "plugin-bin-path.ts");
    mkdirSync(join(loaderFile, ".."), { recursive: true });
    copyFileSync(join(import.meta.dir, "plugin-bin-path.ts"), loaderFile);
    // Runtime copy: import.meta.url must identify the relocated file, not the source checkout.
    const relocated = await import(pathToFileURL(loaderFile).href);
    record(h, ".omp", { ossify: stub(h, "ossify", 4, 4) });
    const warn = spyOn(console, "warn").mockImplementation(() => {});
    try {
      const pi: { ran?: string } = {};
      await relocated.load(pi, h);
      expect(pi.ran).toBe("ossify@4");
      const warning = String(warn.mock.calls[0]?.[0]);
      const command = warning.slice(warning.indexOf("curl -fsSL"));
      const parsed = Bun.spawnSync(["bash", "-c", `curl() { printf '%s\\0' "$@"; }; ${command}`],
        { env: { HOME: h, PATH: process.env.PATH }, stdout: "pipe", stderr: "pipe" });
      expect(parsed.exitCode).toBe(0);
      expect(parsed.stdout.toString().split("\0").filter(Boolean)).toEqual([
        "-fsSL", "https://raw.githubusercontent.com/pulseai-labs/pulsestack/main/omp/extensions/plugin-bin-path.ts",
        "--create-dirs", "-o", loaderFile,
      ]);
    } finally { warn.mockRestore(); }
  });
  test("a loader without a file URL gives the download URL and save-over instruction", async () => {
    const h = home();
    record(h, ".omp", { ossify: stub(h, "ossify", 4, 4) });
    const source = await Bun.file(join(import.meta.dir, "plugin-bin-path.ts")).text();
    const javascript = new Bun.Transpiler({ loader: "ts" }).transformSync(source);
    // A VM module supplies a genuine non-file URL without rewriting loader source.
    // Its dynamic-import callback preserves normal file imports for installed modules.
    const child = Bun.spawnSync(["node", "--experimental-vm-modules", "--input-type=module", "-e", `
      import vm from "node:vm";
      import { pathToFileURL } from "node:url";
      const loader = new vm.SourceTextModule(${JSON.stringify(javascript)}, {
        initializeImportMeta(meta) { meta.url = "https://example.invalid/plugin-bin-path.ts"; },
        importModuleDynamically(specifier) { return import(pathToFileURL(specifier).href); },
      });
      await loader.link(async (specifier) => {
        const imported = await import(specifier), names = Object.keys(imported);
        return new vm.SyntheticModule(names, function () { for (const name of names) this.setExport(name, imported[name]); });
      });
      await loader.evaluate();
      const pi = {}; await loader.namespace.load(pi, ${JSON.stringify(h)}); console.log(JSON.stringify(pi));
    `],
      { env: { HOME: h, PATH: process.env.PATH }, stdout: "pipe", stderr: "pipe" });
    expect(child.exitCode).toBe(0);
    expect(JSON.parse(child.stdout.toString())).toEqual({ ran: "ossify@4" });
    const warning = child.stderr.toString();
    expect(warning).toContain("https://raw.githubusercontent.com/pulseai-labs/pulsestack/main/omp/extensions/plugin-bin-path.ts");
    expect(warning).toContain("save it over this loader file");
    expect(warning).not.toContain("-o ");
  });
  test("a module requiring loader 3 runs without an obsolete-loader warning", async () => {
    const h = home();
    record(h, ".omp", { ossify: stub(h, "ossify", 3, 3) });
    const warn = spyOn(console, "warn").mockImplementation(() => {});
    try {
      const pi: { ran?: string } = {};
      await load(pi, h);
      expect(pi.ran).toBe("ossify@3");
      expect(warn.mock.calls).toEqual([]);
    } finally { warn.mockRestore(); }
  });
  for (const which of [".omp", ".claude"]) {
    test(`${which} another project's module is never a candidate`, () => {
      const h = home();
      entries(join(h, which, "plugins", "installed_plugins.json"), [
        entry("project", stub(h, "foreign", 99), which === ".claude" ? join(h, "other") : undefined),
      ]);
      expect(moduleCandidates(h)).toEqual([]);
    });
    test(`${which} user module survives beside a project entry (control)`, async () => {
      const h = home();
      entries(join(h, which, "plugins", "installed_plugins.json"), [
        entry("project", stub(h, "project", 99), which === ".claude" ? process.cwd() : undefined),
        entry("user", stub(h, "user", 3)),
      ]);
      const pi: { ran?: string } = {};
      await load(pi, h);
      expect(pi.ran).toBe("user@3");
    });
  }
  test("a current Claude project module is never used even when it is the only entry", () => {
    const h = home();
    entries(join(h, ".claude", "plugins", "installed_plugins.json"), [entry("project", stub(h, "current-project", 99), process.cwd())]);
    expect(moduleCandidates(h)).toEqual([]);
  });
  test("a module that fails to import is skipped with a warning; another runs", async () => {
    const h = home();
    record(h, ".omp", { ossify: stub(h, "ossify", 5, 1, "this is not typescript {{{"),
                        "workspace-init": stub(h, "workspace-init", 1) });
    const warn = spyOn(console, "warn").mockImplementation(() => {});
    const pi: any = {};
    await load(pi, h);
    expect(pi.ran).toBe("workspace-init@1");
    expect(String(warn.mock.calls[0][0])).toContain("cannot load");
    warn.mockRestore();
  });
  test("a module whose default factory throws: one warning, load resolves", async () => {
    const h = home();
    record(h, ".omp", { ossify: stub(h, "ossify", 1, 1, `export const VERSION = 1; export default function () { throw new Error("boom"); }`) });
    const warn = spyOn(console, "warn").mockImplementation(() => {});
    await load({}, h);
    expect(warn).toHaveBeenCalledTimes(1);
    expect(String(warn.mock.calls[0][0])).toContain("boom");
    warn.mockRestore();
  });
  test("a module with no default function: one warning, load resolves", async () => {
    const h = home();
    record(h, ".omp", { ossify: stub(h, "ossify", 1, 1, `export const VERSION = 1; export default 7;`) });
    const warn = spyOn(console, "warn").mockImplementation(() => {});
    await load({}, h);
    expect(warn).toHaveBeenCalledTimes(1);
    expect(String(warn.mock.calls[0][0])).toContain("no default factory");
    warn.mockRestore();
  });
});
