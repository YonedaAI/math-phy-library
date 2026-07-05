import katex from 'katex';
import { applyCommonFixups } from './tex-fixups';

/**
 * A best-effort renderer for `tikz-cd` commutative diagrams.
 *
 * KaTeX has no notion of the `tikzcd` package, so we never hand its raw
 * source to `katex.renderToString`. Instead we parse the diagram's grid
 * structure and arrow list ourselves (tikz-cd's own grammar: rows separated
 * by `\\`, cells by `&`, arrows written `\arrow[<dir>, "<label>"]` where
 * <dir> is a run of u/d/l/r letters giving the exact row/column delta),
 * and render it as a CSS grid of KaTeX-typeset nodes plus a small
 * "morphisms" legend of source -> target arrows. This reproduces the
 * diagram's content and topology losslessly even though the line geometry
 * is only approximate.
 */

interface ArrowSpec {
  fromRow: number;
  fromCol: number;
  toRow: number;
  toCol: number;
  labels: string[];
  dashed: boolean;
  equal: boolean;
  mapsto: boolean;
  phantom: boolean;
}

interface NodeSpec {
  row: number;
  col: number;
  text: string;
}

function splitTopLevel(body: string, sepIsBackslashAmp: boolean): string[][] {
  const rows: string[][] = [];
  let cur = '';
  let curRow: string[] = [];
  let depth = 0;
  let i = 0;
  while (i < body.length) {
    const ch = body[i];
    if (ch === '{') {
      depth++;
      cur += ch;
      i++;
      continue;
    }
    if (ch === '}') {
      depth--;
      cur += ch;
      i++;
      continue;
    }
    if (depth === 0) {
      if (ch === '\\' && body[i + 1] === '\\') {
        curRow.push(cur.trim());
        rows.push(curRow);
        curRow = [];
        cur = '';
        i += 2;
        continue;
      }
      if (sepIsBackslashAmp && ch === '\\' && body[i + 1] === '&') {
        curRow.push(cur.trim());
        cur = '';
        i += 2;
        continue;
      }
      if (!sepIsBackslashAmp && ch === '&') {
        curRow.push(cur.trim());
        cur = '';
        i += 1;
        continue;
      }
    }
    cur += ch;
    i++;
  }
  if (cur.trim().length || curRow.length) {
    curRow.push(cur.trim());
  }
  if (curRow.length) rows.push(curRow);
  return rows;
}

function extractArrows(cellText: string): { text: string; arrows: string[] } {
  const arrows: string[] = [];
  let out = '';
  let i = 0;
  while (i < cellText.length) {
    if (cellText.startsWith('\\arrow', i) && cellText[i + 6] === '[') {
      let depth = 1;
      let j = i + 7;
      while (j < cellText.length && depth > 0) {
        if (cellText[j] === '[') depth++;
        else if (cellText[j] === ']') depth--;
        j++;
      }
      arrows.push(cellText.slice(i + 7, j - 1));
      i = j;
      continue;
    }
    out += cellText[i];
    i++;
  }
  return { text: out.trim(), arrows };
}

function splitArrowOptions(opts: string): string[] {
  const tokens: string[] = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < opts.length; i++) {
    const ch = opts[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
      cur += ch;
      continue;
    }
    if (ch === ',' && !inQuotes) {
      tokens.push(cur.trim());
      cur = '';
      continue;
    }
    cur += ch;
  }
  if (cur.trim()) tokens.push(cur.trim());
  return tokens;
}

function parseArrow(opts: string, row: number, col: number): ArrowSpec | null {
  const tokens = splitArrowOptions(opts);
  let drow = 0;
  let dcol = 0;
  let hasDir = false;
  const labels: string[] = [];
  let dashed = false;
  let equal = false;
  let mapsto = false;
  let phantom = false;

  for (const tok of tokens) {
    if (/^[udlr]+$/i.test(tok)) {
      hasDir = true;
      for (const ch of tok.toLowerCase()) {
        if (ch === 'u') drow -= 1;
        else if (ch === 'd') drow += 1;
        else if (ch === 'l') dcol -= 1;
        else if (ch === 'r') dcol += 1;
      }
      continue;
    }
    if (tok === 'dashed' || tok === 'dashed, ') {
      dashed = true;
      continue;
    }
    if (tok === 'equal' || tok === 'equals') {
      equal = true;
      continue;
    }
    if (tok === 'mapsto') {
      mapsto = true;
      continue;
    }
    if (tok === 'phantom') {
      phantom = true;
      continue;
    }
    if (tok.startsWith('"')) {
      const m = tok.match(/^"([\s\S]*)"/);
      if (m) labels.push(m[1]);
      continue;
    }
    // ignore: swap, shift left/right, bend left/right, near end/start, equal-sign options, etc.
  }

  if (!hasDir && drow === 0 && dcol === 0) return null;

  return {
    fromRow: row,
    fromCol: col,
    toRow: row + drow,
    toCol: col + dcol,
    labels,
    dashed,
    equal,
    mapsto,
    phantom,
  };
}

function arrowGlyph(a: ArrowSpec): string {
  if (a.equal) return '=';
  if (a.mapsto) return '↦';
  const dr = Math.sign(a.toRow - a.fromRow);
  const dc = Math.sign(a.toCol - a.fromCol);
  if (dr === 0 && dc > 0) return '→';
  if (dr === 0 && dc < 0) return '←';
  if (dc === 0 && dr > 0) return '↓';
  if (dc === 0 && dr < 0) return '↑';
  if (dr > 0 && dc > 0) return '↘';
  if (dr > 0 && dc < 0) return '↙';
  if (dr < 0 && dc > 0) return '↗';
  if (dr < 0 && dc < 0) return '↖';
  return '→';
}

function renderInline(tex: string, macros: Record<string, string>): string {
  const trimmed = applyCommonFixups(tex.trim());
  if (!trimmed) return '';
  try {
    return katex.renderToString(trimmed, {
      displayMode: false,
      throwOnError: false,
      trust: true,
      strict: 'ignore',
      output: 'html',
      macros: { ...macros },
    });
  } catch {
    return `<span class="tikzcd-fallback">${trimmed}</span>`;
  }
}

/**
 * Render plain-TeX-text that may contain embedded `$...$` math shifts
 * (the default content mode of a `\node{...}` in a free-form tikzpicture,
 * as opposed to a tikzcd cell, which is already math). `\\` becomes a
 * line break and `\ ` a literal space; anything else outside `$...$` is
 * used verbatim (these labels are short plain-English phrases).
 */
function renderLabelText(text: string, macros: Record<string, string>): string {
  const parts = text.split(/(\$[^$]*\$)/g);
  return parts
    .map((part) => {
      if (part.startsWith('$') && part.endsWith('$') && part.length >= 2) {
        return renderInline(part.slice(1, -1), macros);
      }
      return part.replace(/\\\\/g, '<br/>').replace(/\\ /g, ' ');
    })
    .join('');
}

/** Detect `\begin{tikzcd}[...] BODY \end{tikzcd}` and render it to HTML. */
export function renderTikzCd(source: string, macros: Record<string, string>): string {
  const beginMatch = source.match(/\\begin\{tikzcd\}(\[([^\]]*)\])?/);
  if (!beginMatch) return '';
  const options = beginMatch[2] || '';
  const bodyStart = beginMatch.index! + beginMatch[0].length;
  const endIdx = source.lastIndexOf('\\end{tikzcd}');
  const body = source.slice(bodyStart, endIdx === -1 ? undefined : endIdx);

  const sepIsBackslashAmp = /ampersand replacement\s*=\s*\\&/.test(options);
  const rows = splitTopLevel(body, sepIsBackslashAmp);

  const nodes: NodeSpec[] = [];
  const arrows: ArrowSpec[] = [];
  let maxCol = 0;

  rows.forEach((cells, r) => {
    cells.forEach((cellRaw, c) => {
      maxCol = Math.max(maxCol, c);
      const { text, arrows: arrowOpts } = extractArrows(cellRaw);
      if (text) nodes.push({ row: r, col: c, text });
      for (const opts of arrowOpts) {
        const a = parseArrow(opts, r, c);
        if (a) arrows.push(a);
      }
    });
  });

  const nodeAt = (r: number, c: number) => nodes.find((n) => n.row === r && n.col === c);

  const nodeHtml = new Map<NodeSpec, string>();
  for (const n of nodes) nodeHtml.set(n, renderInline(n.text, macros));

  const gridItems = nodes
    .map(
      (n) =>
        `<div class="tikzcd-node" style="grid-row:${n.row + 1};grid-column:${n.col + 1};">${nodeHtml.get(n)}</div>`
    )
    .join('\n');

  const edgeItems = arrows
    .filter((a) => !a.phantom)
    .map((a) => {
      const src = nodeAt(a.fromRow, a.fromCol);
      const tgt = nodeAt(a.toRow, a.toCol);
      if (!src) return '';
      const srcHtml = nodeHtml.get(src) || '';
      const tgtHtml = tgt ? nodeHtml.get(tgt) || '' : '';
      const labelHtml = a.labels.map((l) => renderInline(l, macros)).join(' / ');
      const glyphClass = a.dashed ? 'tikzcd-edge-arrow tikzcd-dashed' : 'tikzcd-edge-arrow';
      return (
        `<li class="tikzcd-edge">` +
        `<span class="tikzcd-edge-src">${srcHtml}</span>` +
        `<span class="${glyphClass}">${arrowGlyph(a)}</span>` +
        (tgtHtml ? `<span class="tikzcd-edge-tgt">${tgtHtml}</span>` : '') +
        (labelHtml ? `<span class="tikzcd-edge-label">${labelHtml}</span>` : '') +
        `</li>`
      );
    })
    .filter(Boolean)
    .join('\n');

  return (
    `<div class="tikzcd-diagram" role="img" aria-label="commutative diagram">` +
    `<div class="tikzcd-grid" style="--tikzcd-cols:${maxCol + 1};">${gridItems}</div>` +
    (edgeItems ? `<ul class="tikzcd-morphisms">${edgeItems}</ul>` : '') +
    `</div>`
  );
}

const TIKZCD_BLOCK_RE = /\\begin\{tikzcd\}[\s\S]*?\\end\{tikzcd\}/g;

/**
 * A math source string can contain more than one `tikzcd` diagram (e.g.
 * two small diagrams separated by `\qquad\qquad`). Split the source into
 * tikzcd blocks and ordinary math text, render each independently, and
 * lay diagrams out side by side when there is more than one.
 */
export function renderTikzSegments(source: string, macros: Record<string, string>): string {
  const segments: { kind: 'tikz' | 'text'; content: string }[] = [];
  let lastIndex = 0;
  let m: RegExpExecArray | null;
  TIKZCD_BLOCK_RE.lastIndex = 0;
  while ((m = TIKZCD_BLOCK_RE.exec(source))) {
    if (m.index > lastIndex) segments.push({ kind: 'text', content: source.slice(lastIndex, m.index) });
    segments.push({ kind: 'tikz', content: m[0] });
    lastIndex = TIKZCD_BLOCK_RE.lastIndex;
  }
  if (lastIndex < source.length) segments.push({ kind: 'text', content: source.slice(lastIndex) });

  const diagramCount = segments.filter((s) => s.kind === 'tikz').length;

  const rendered = segments.map((seg) => {
    if (seg.kind === 'tikz') return renderTikzCd(seg.content, macros);
    return renderInline(seg.content, macros);
  });

  if (diagramCount > 1) {
    return `<div class="tikzcd-diagram-row">${rendered.join('')}</div>`;
  }
  return rendered.join('');
}

function readBraceGroupPublic(text: string, start: number): [string, number] {
  let depth = 1;
  let i = start + 1;
  while (i < text.length && depth > 0) {
    if (text[i] === '{') depth++;
    else if (text[i] === '}') depth--;
    i++;
  }
  return [text.slice(start + 1, i - 1), i];
}

/**
 * A best-effort renderer for the free-form `tikzpicture` "pipeline" figures
 * used a couple of times in this series (a horizontal chain of
 * `\node[box, right=of PREV] (id) {label};` boxes joined by
 * `\path (a) edge node{label} (b);` / `\draw (a) -- (b);` arrows, plus an
 * optional dashed "feedback" node placed `below=of` one of the chain
 * nodes). Unlike tikzcd these have no column/row grid to key off, so we
 * reconstruct the chain purely from declaration order and the `right=of` /
 * `below=of` placement hints, which is exactly the information these two
 * source diagrams encode.
 */
export function renderTikzPicturePipeline(source: string, macros: Record<string, string>): string {
  interface PicNode { id: string; label: string; below?: string }
  interface PicEdge { from: string; to: string; label?: string; dashed: boolean }

  const nodes: PicNode[] = [];
  const nodeRe = /\\node\[([^\]]*)\]\s*\(([A-Za-z0-9]+)\)\s*\{/g;
  let m: RegExpExecArray | null;
  while ((m = nodeRe.exec(source))) {
    const opts = m[1];
    const id = m[2];
    const braceStart = nodeRe.lastIndex - 1;
    const [label, after] = readBraceGroupPublic(source, braceStart);
    nodeRe.lastIndex = after;
    const belowMatch = opts.match(/below[^,\]]*of\s+([A-Za-z0-9]+)/);
    nodes.push({ id, label, below: belowMatch ? belowMatch[1] : undefined });
  }

  const edges: PicEdge[] = [];
  const pathRe = /\\path\s*\(([A-Za-z0-9]+)[^)]*\)\s*edge\s*(?:node\[[^\]]*\]\s*\{([\s\S]*?)\}\s*)?\(([A-Za-z0-9]+)[^)]*\)\s*;/g;
  while ((m = pathRe.exec(source))) {
    edges.push({ from: m[1], to: m[3], label: m[2], dashed: false });
  }
  const drawRe = /\\draw\[([^\]]*)\]\s*\(([A-Za-z0-9]+)(?:\.[a-zA-Z]+)?\)\s*(?:--|\|-|-\|)\s*\(([A-Za-z0-9]+)(?:\.[a-zA-Z]+)?\)\s*;/g;
  while ((m = drawRe.exec(source))) {
    const opts = m[1];
    edges.push({ from: m[2], to: m[3], dashed: /dashed/.test(opts) });
  }

  const mainNodes = nodes.filter((n) => !n.below);
  const feedbackNodes = nodes.filter((n) => n.below);

  const nodeHtmlById = new Map<string, string>();
  for (const n of nodes) nodeHtmlById.set(n.id, renderLabelText(n.label, macros));

  const edgeBetween = (a: string, b: string) => edges.find((e) => e.from === a && e.to === b);

  const rowParts: string[] = [];
  mainNodes.forEach((n, i) => {
    rowParts.push(`<div class="pipeline-node">${nodeHtmlById.get(n.id)}</div>`);
    const next = mainNodes[i + 1];
    if (next) {
      const e = edgeBetween(n.id, next.id);
      const labelHtml = e?.label ? renderLabelText(e.label, macros) : '';
      rowParts.push(
        `<span class="pipeline-arrow">→${labelHtml ? `<span class="pipeline-arrow-label">${labelHtml}</span>` : ''}</span>`
      );
    }
  });

  const feedbackItems = feedbackNodes
    .map((n) => {
      const html = nodeHtmlById.get(n.id) || '';
      const e = edges.find((ed) => ed.from === n.id || ed.to === n.id);
      const dashedClass = e?.dashed ? 'tikzcd-dashed' : '';
      return (
        `<li class="tikzcd-edge">` +
        `<span class="tikzcd-edge-src">${html}</span>` +
        `<span class="tikzcd-edge-arrow ${dashedClass}">⇢</span>` +
        `<span class="tikzcd-edge-tgt">${nodeHtmlById.get(n.below!) || ''}</span>` +
        `</li>`
      );
    })
    .join('\n');

  return (
    `<div class="tikzcd-diagram" role="img" aria-label="pipeline diagram">` +
    `<div class="pipeline-row">${rowParts.join('\n')}</div>` +
    (feedbackItems ? `<ul class="tikzcd-morphisms">${feedbackItems}</ul>` : '') +
    `</div>`
  );
}
