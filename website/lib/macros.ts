import fs from 'fs';
import path from 'path';
import { applyCommonFixups } from './tex-fixups';

export const REPO_ROOT = path.join(process.cwd(), '..');
const LATEX_DIR = path.join(REPO_ROOT, 'papers', 'latex');

/**
 * Base KaTeX macros that are not necessarily defined via \newcommand in the
 * papers but are common enough (or referenced in code samples / captions)
 * that we register them as a safety net.
 */
const BASE_MACROS: Record<string, string> = {
  '\\slashed': '\\not{#1}',
  '\\bra': '\\langle #1 \\vert',
  '\\ket': '\\vert #1 \\rangle',
  '\\braket': '\\langle #1 \\vert #2 \\rangle',
  '\\Hom': '\\operatorname{Hom}',
  '\\Tr': '\\operatorname{Tr}',
  '\\Lan': '\\operatorname{Lan}',
  '\\Ran': '\\operatorname{Ran}',
  // \Cref / \cref cross-reference macros are expanded by pandoc almost
  // everywhere, but a handful of occurrences survive inside raw tikzcd
  // diagram bodies or aligned \text{} annotations. Render the reference
  // label as plain text rather than crashing KaTeX.
  '\\Cref': '\\text{#1}',
  '\\cref': '\\text{#1}',
};

interface ExtractedMacro {
  name: string;
  argCount: number;
  body: string;
}

/**
 * Scan a LaTeX source string for `\newcommand{\Name}[n]{body}` /
 * `\newcommand{\Name}{body}` definitions, respecting brace nesting inside
 * the replacement body (naive regexes truncate at the first `}`).
 */
export function extractNewcommands(tex: string): ExtractedMacro[] {
  const results: ExtractedMacro[] = [];
  const re = /\\newcommand\{\\([A-Za-z]+)\}(\[(\d+)\])?\s*\{/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(tex))) {
    const name = m[1];
    const argCount = m[3] ? parseInt(m[3], 10) : 0;
    let depth = 1;
    let i = re.lastIndex;
    const start = i;
    while (i < tex.length && depth > 0) {
      const ch = tex[i];
      if (ch === '{') depth++;
      else if (ch === '}') depth--;
      i++;
    }
    const body = tex.slice(start, i - 1);
    results.push({ name, argCount, body });
    re.lastIndex = i;
  }
  return results;
}

let cachedMacros: Record<string, string> | null = null;

/**
 * Build the full KaTeX macro map by extracting every `\newcommand` from
 * every paper's LaTeX preamble and merging with the base macro safety net.
 * Later files win on name collisions (in practice, definitions are shared
 * verbatim across the series).
 */
export function getKatexMacros(): Record<string, string> {
  if (cachedMacros) return cachedMacros;

  const macros: Record<string, string> = { ...BASE_MACROS };
  let files: string[] = [];
  try {
    files = fs
      .readdirSync(LATEX_DIR)
      .filter((f) => f.endsWith('.tex'))
      .sort();
  } catch {
    files = [];
  }

  for (const file of files) {
    const tex = fs.readFileSync(path.join(LATEX_DIR, file), 'utf-8');
    const defs = extractNewcommands(tex);
    for (const { name, body } of defs) {
      // Macros used inside content we recover straight from the .tex
      // source (dropped bare tikzcd/tikzpicture figures — see
      // fix-figures.ts) are expanded by KaTeX itself via this macros
      // table, *after* our string-level `applyCommonFixups` pass has
      // already run on the surrounding source. Fix up the macro bodies
      // here too so e.g. `\PI` -> `\textsc{i}` becomes `\PI` -> `\text{I}`
      // regardless of which path expands it.
      macros['\\' + name] = applyCommonFixups(body);
    }
  }

  cachedMacros = macros;
  return macros;
}
