// Puts the bin/ of this marketplace's installed plugins on PATH for OMP sessions.
// OMP has no plugin bin/ mechanism, so skills resolving a plugin's bin/ command
// through `command -v` fail without this. Install paths come from records, never
// from "newest in cache". It writes no file and never searches the filesystem.
//
// This file is the source of truth. Plugins that ship a bin/ carry byte-identical
// copies at <plugin>/omp/bin-path.ts, held by tests/test-omp-surface.sh check 6.
// The user-level loader (omp/extensions/plugin-bin-path.ts) imports the newest
// installed copy, so a plugin update refreshes this logic. Bump VERSION on any
// behaviour change, and MIN_LOADER_VERSION only when old loaders must warn.
// Skill-first question 2: mechanical selection from known install-record shapes.
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { delimiter, join } from "node:path";

export const VERSION = 3;
export const MIN_LOADER_VERSION = 1;
export const MARKETPLACE = "pulsestack";
// The marketplace's name before the pulsestack rename. Its entries are still read, for one
// release, so a host that has not re-added the marketplace keeps its bin paths; an entry under
// MARKETPLACE replaces one under this name. Removing it is a filed follow-up issue.
export const LEGACY_MARKETPLACE = "claude-agent-scaffolding";

type Entry = { scope?: string; installPath?: string };
type Plugins = Record<string, Entry[]>;
export type ResolveOpts = { ompRecord: string; claudeRecord: string };

// OMP keeps its record under $HOME/.omp whatever PI_CODING_AGENT_DIR says (probe report 12).
export function ompRecordPath(home: string): string {
  return join(home, ".omp", "plugins", "installed_plugins.json");
}

// undefined = file absent; throws on a file that exists but cannot be read or parsed.
function load(path: string): Plugins | undefined {
  if (!existsSync(path)) return undefined;
  const d = JSON.parse(readFileSync(path, "utf8"));
  return (d && typeof d.plugins === "object" && d.plugins) || {};
}

function ours(plugins: Plugins | undefined): Map<string, Entry> {
  const fresh = new Map<string, Entry>(), legacy = new Map<string, Entry>();
  for (const [id, entries] of Object.entries(plugins ?? {})) {
    const at = id.lastIndexOf("@");
    const mkt = at < 0 ? "" : id.slice(at + 1);
    const to = mkt === MARKETPLACE ? fresh : mkt === LEGACY_MARKETPLACE ? legacy : undefined;
    if (to === undefined || !Array.isArray(entries)) continue;
    const e = entries.find((x) => x?.scope === "user");
    if (typeof e?.installPath === "string" && e.installPath) to.set(id.slice(0, at), e);
  }
  for (const [name, e] of legacy) if (!fresh.has(name)) fresh.set(name, e);
  return fresh;
}

// User-scope entries only; project-scope entries are never used.
// An absent file gives an empty map; an unreadable or unparseable existing file throws.
export function installPaths(record: string): Map<string, string> {
  return new Map([...ours(load(record))].map(([name, e]) => [name, e.installPath!]));
}

export function resolveBinDirs(opts: ResolveOpts): { dirs: string[]; warnings: string[] } {
  let omp: Plugins | undefined, claude: Plugins | undefined;
  try { omp = load(opts.ompRecord); } catch (e) {
    return { dirs: [], warnings: [`plugin bin paths not added: unreadable ${opts.ompRecord} (${(e as Error).message})`] };
  }
  try { claude = load(opts.claudeRecord); } catch { claude = undefined; }
  if (omp === undefined && claude === undefined)
    return { dirs: [], warnings: [`plugin bin paths not added: no install record at ${opts.ompRecord} or ${opts.claudeRecord}`] };

  const chosen = ours(claude);
  for (const [name, e] of ours(omp)) chosen.set(name, e); // an OMP entry wins
  const dirs: string[] = [], warnings: string[] = [];
  for (const [name, e] of chosen) {
    const bin = join(e.installPath!, "bin");
    if (existsSync(bin)) dirs.push(bin);
    else warnings.push(`plugin bin path skipped: ${name} has no bin/ at ${e.installPath}`);
  }
  return { dirs, warnings };
}

export function prependPath(current: string | undefined, dirs: string[]): string {
  const rest = (current ?? "").split(delimiter).filter((d) => d && !dirs.includes(d));
  return [...new Set(dirs), ...rest].join(delimiter);
}

// The effectful step, with the home and env injectable so it can be tested.
export function apply(home: string, env: { PATH?: string } = process.env): void {
  const { dirs, warnings } = resolveBinDirs({
    ompRecord: ompRecordPath(home),
    claudeRecord: join(home, ".claude", "plugins", "installed_plugins.json"),
  });
  for (const w of warnings) console.warn(w);
  if (dirs.length) env.PATH = prependPath(env.PATH, dirs);
}

export default function (_pi: unknown) {
  apply(homedir());
}
