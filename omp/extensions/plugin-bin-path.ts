// User-level loader for pulsestack's OMP bin-path module.
// Copy this file once into ~/.omp/agent/extensions/ (spec B §4.2). It holds no
// logic that should change: it finds the module the installed plugins ship
// (<plugin>/omp/bin-path.ts), imports the newest, and runs it — so updating
// the plugins updates the behaviour. Bump LOADER_VERSION when this file changes;
// raise MIN_LOADER_VERSION only after the corrected warning has reached users.
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

export const LOADER_VERSION = 3;
const MARKETPLACE = "pulsestack";
// The pre-rename name, read for one release so a host that has not re-added the marketplace still loads.
const LEGACY_MARKETPLACE = "claude-agent-scaffolding";
const DOWNLOAD = "https://raw.githubusercontent.com/pulseai-labs/pulsestack/main/omp/extensions/plugin-bin-path.ts";

function updateCommand(): string {
  try {
    const target = fileURLToPath(import.meta.url);
    return `curl -fsSL ${DOWNLOAD} --create-dirs -o '${target.replace(/'/g, "'\\''")}'`;
  } catch { return `${DOWNLOAD} (save it over this loader file)`; }
}

type Entry = { scope?: string; installPath?: string };
function installPaths(record: string): string[] {
  const paths: string[] = [];
  try {
    const plugins = JSON.parse(readFileSync(record, "utf8"))?.plugins ?? {};
    for (const [id, e] of Object.entries(plugins)) {
      if (!id.endsWith(`@${MARKETPLACE}`) && !id.endsWith(`@${LEGACY_MARKETPLACE}`)) continue;
      const entries: Entry[] = Array.isArray(e) ? e : [];
      const pick = entries.find((x) => x?.scope === "user");
      if (typeof pick?.installPath === "string" && pick.installPath) paths.push(pick.installPath);
    }
  } catch {}
  return paths;
}

export function moduleCandidates(home: string): string[] {
  const paths = [
    ...installPaths(join(home, ".omp", "plugins", "installed_plugins.json")),
    ...installPaths(join(home, ".claude", "plugins", "installed_plugins.json")),
  ];
  return [...new Set(paths.map((p) => join(p, "omp", "bin-path.ts")))].filter((f) => existsSync(f));
}

export async function load(pi: unknown, home: string = homedir()): Promise<void> {
  const mods: { VERSION?: number; MIN_LOADER_VERSION?: number; default?: unknown }[] = [];
  for (const f of moduleCandidates(home)) {
    // The installed record selects this module at runtime; a static import cannot load it.
    try { mods.push(await import(f)); }
    catch (e) { console.warn(`plugin bin paths: cannot load ${f} (${(e as Error).message})`); }
  }
  if (!mods.length) { console.warn("plugin bin paths not added: no installed plugin ships omp/bin-path.ts"); return; }
  const mod = mods.reduce((a, b) => ((b.VERSION ?? 0) > (a.VERSION ?? 0) ? b : a));
  if ((mod.MIN_LOADER_VERSION ?? 0) > LOADER_VERSION)
    console.warn(`plugin-bin-path.ts loader is out of date (loader ${LOADER_VERSION}, module needs ${mod.MIN_LOADER_VERSION}); update it: ${updateCommand()}`);
  if (typeof mod.default !== "function") { console.warn("plugin bin paths not added: the newest module has no default factory"); return; }
  try { await mod.default(pi); }
  catch (e) { console.warn(`plugin bin paths not added: the module failed (${(e as Error).message})`); }
}

// A loader error must never reject the extension factory: users cannot patch this file once copied.
export default async function (pi: unknown) {
  try { await load(pi); }
  catch (e) { console.warn(`plugin bin paths not added: ${(e as Error).message}`); }
}
