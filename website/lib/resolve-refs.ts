/**
 * Fix up pandoc's cross-reference links after math rendering.
 *
 * Single-target `\Cref`/`\ref` links to sections, theorem-like
 * environments, and tables already resolve correctly out of pandoc (it
 * fills in the right number, e.g. `<a href="#thm:foo" ...>21</a>`).
 * Two categories are broken:
 *
 *  1. `\eqref{eq:x}` — pandoc never numbers equations at all, so these
 *     render as a literal, unlinked `[eq:x]` (the raw LaTeX label as
 *     visible text) with an href pointing at an id that doesn't exist.
 *     render-math.ts now assigns real ids + sequential numbers to labeled
 *     equations; this pass swaps the visible "[eq:x]" text for "(n)".
 *
 *  2. Multi-target refs, e.g. `\Cref{sec:a,sec:b}` — pandoc gives up
 *     entirely and emits a single link whose href AND visible text are
 *     the raw comma-joined labels: `<a href="#sec:a,sec:b" ...>[sec:a,sec:b]</a>`.
 *     We split these into one resolved mini-link per target.
 *
 * The registry used to resolve ids is built by harvesting pandoc's own
 * already-correct single-target resolutions (for sections/theorems/
 * tables/figures) plus the equation-number map computed during math
 * rendering — so this needs no knowledge of pandoc's internal numbering.
 */

const SINGLE_REF_RE = /<a href="#([^",]+)" data-reference-type="[^"]*" data-reference="\1">([^<]*)<\/a>/g;
const ANY_REF_RE = /<a href="#([^"]+)" data-reference-type="([^"]*)" data-reference="([^"]+)">([^<]*)<\/a>/g;

function humanizeId(id: string): string {
  return id.replace(/^[a-zA-Z]+:/, '').replace(/[-_]/g, ' ');
}

export function resolveCrossReferences(html: string, equationNumbers: Map<string, number>): string {
  const registry = new Map<string, string>();
  equationNumbers.forEach((num, label) => registry.set(label, `(${num})`));

  let m: RegExpExecArray | null;
  SINGLE_REF_RE.lastIndex = 0;
  while ((m = SINGLE_REF_RE.exec(html))) {
    const id = m[1];
    const text = m[2];
    if (!text.startsWith('[') && !registry.has(id)) {
      registry.set(id, text);
    }
  }

  return html.replace(ANY_REF_RE, (full, href: string, _refType: string, _dataRef: string, text: string) => {
    const ids = href.split(',');
    if (ids.length === 1 && !text.startsWith('[')) {
      return full; // already correctly resolved by pandoc
    }
    const parts = ids.map((id) => {
      const resolved = registry.get(id);
      if (resolved) return `<a href="#${id}" class="citation-link">${resolved}</a>`;
      return `<span class="doc-ref-unresolved">${humanizeId(id)}</span>`;
    });
    return parts.join(', ');
  });
}
