import fs from 'fs';
import path from 'path';
import DOMPurify from 'isomorphic-dompurify';
import { REPO_ROOT } from './macros';
import { restoreDroppedFigures } from './fix-figures';
import { renderMathInHtml, decodeEntities } from './render-math';
import { resolveCrossReferences } from './resolve-refs';

export interface Heading {
  id: string;
  text: string;
  level: number;
}

const DOCS_PAPERS_DIR = path.join(REPO_ROOT, 'docs', 'papers');

/** Very small LaTeX-fragment-to-plain-text cleaner, used only to build
 * readable sidebar TOC labels for the handful of section headings that
 * contain inline math (e.g. `Rung \(\textsc{i}\to\textsc{ii}\)`). This is
 * not meant to be a general TeX renderer — just legible nav text.
 */
function humanizeMathForToc(latex: string): string {
  let s = latex;
  s = s.replace(/\\textsc\{([^}]*)\}/g, (_m, x) => String(x).toUpperCase());
  s = s.replace(/\\(mathbb|mathcal|mathsf|mathrm|mathfrak|text|textbf|emph|operatorname)\{([^}]*)\}/g, '$2');
  s = s.replace(/\\to|\\rightarrow|\\longrightarrow/g, '→');
  s = s.replace(/\\Rightarrow/g, '⇒');
  s = s.replace(/[{}]/g, '');
  s = s.replace(/\\[a-zA-Z]+/g, '');
  s = s.replace(/\\/g, '');
  return s.replace(/\s+/g, ' ').trim();
}

/**
 * Extract section/subsection headings for the sidebar TOC from the
 * *pre-KaTeX* pandoc HTML (post-KaTeX, math spans balloon into deeply
 * nested MathML+HTML markup that is not safe to flatten to plain text).
 * Any inline math inside a heading is humanized to plain text rather
 * than typeset.
 *
 * Pandoc's LaTeX reader maps `\section` -> `<h1>` and `\subsection` ->
 * `<h2>`. Because the paper page itself already has an `<h1>` (the paper
 * title), `shiftHeadingLevels` below demotes every imported heading by
 * one level so the page keeps a single `<h1>` — so what is `<h1>`/`<h2>`
 * here ends up as `<h2>`/`<h3>` in the final DOM; the `level` reported
 * reflects that final, post-shift level.
 */
function extractHeadings(rawHtml: string): Heading[] {
  const headings: Heading[] = [];
  const headingRe = /<h([12])[^>]*id="([^"]+)"[^>]*>([\s\S]*?)<\/h\1>/g;
  let m: RegExpExecArray | null;
  while ((m = headingRe.exec(rawHtml))) {
    const level = parseInt(m[1], 10) + 1; // shifted level in the final DOM
    const id = m[2];
    let inner = m[3];
    inner = inner.replace(/<span class="header-section-number">[\s\S]*?<\/span>/, '');
    inner = inner.replace(/<span class="math (?:inline|display)">([\s\S]*?)<\/span>/g, (_full, tex: string) => {
      let t = decodeEntities(tex).trim();
      if (t.startsWith('\\(') && t.endsWith('\\)')) t = t.slice(2, -2);
      else if (t.startsWith('\\[') && t.endsWith('\\]')) t = t.slice(2, -2);
      return humanizeMathForToc(t);
    });
    const text = inner
      .replace(/<[^>]+>/g, '')
      .replace(/\s+/g, ' ')
      .trim();
    if (text) headings.push({ id, text, level });
  }
  return headings;
}

/**
 * Demote every heading tag so a paper's own section headings never
 * collide with the page's single `<h1>` title — while never *skipping* a
 * level anywhere in the document outline, which is its own accessibility
 * bug. A naive "shift every level by +1" breaks here because pandoc's
 * LaTeX reader maps `\section` -> h1, `\subsection` -> h2, and
 * `\paragraph` -> h4 directly (these papers never use `\subsubsection`,
 * so h3 is simply never emitted); shifting blindly turns h1/h2/h4 into
 * h2/h3/h5, jumping from h3 to h5. A single global "compact the distinct
 * levels used" pass isn't enough either: it fixes the *set* of levels
 * used across the whole document but not a *specific* h4 that happens to
 * follow an h1 with no intervening h2 at that point in the outline.
 *
 * Instead we walk headings in document order maintaining a stack of
 * (original level, assigned level) ancestors — exactly how a browser's
 * accessibility tree / outline algorithm reasons about heading depth —
 * and assign each heading exactly one level deeper than its nearest
 * shallower ancestor, regardless of how big the jump in the *original*
 * numbering was. Closing tags reuse whatever level was just assigned to
 * the (single, non-nesting) heading that opened them.
 */
function shiftHeadingLevels(html: string): string {
  const ancestry: { original: number; normalized: number }[] = [];
  let currentNormalized = 2;
  return html.replace(/<(\/?)h([1-6])(?=[\s>])/g, (_m, closing: string, levelStr: string) => {
    if (closing) {
      return `</h${currentNormalized}`;
    }
    const original = parseInt(levelStr, 10);
    while (ancestry.length && ancestry[ancestry.length - 1].original >= original) {
      ancestry.pop();
    }
    const parent = ancestry[ancestry.length - 1];
    const normalized = Math.min(6, parent ? parent.normalized + 1 : 2);
    ancestry.push({ original, normalized });
    currentNormalized = normalized;
    return `<h${normalized}`;
  });
}

const SANITIZE_OPTS = { ADD_TAGS: ['annotation'], ADD_ATTR: ['encoding'] };

/** Full server-side pipeline for one paper's pandoc HTML: recover any
 * tikzcd/tikzpicture diagrams pandoc dropped, demote heading levels,
 * pre-render all math with KaTeX, resolve cross-reference links, then
 * sanitize. The result is static HTML with no client-side rendering step.
 */
function processHtml(raw: string, slug: string): string {
  let html = restoreDroppedFigures(raw, slug);
  html = shiftHeadingLevels(html);
  const { html: mathHtml, equationNumbers } = renderMathInHtml(html);
  html = resolveCrossReferences(mathHtml, equationNumbers);
  html = DOMPurify.sanitize(html, SANITIZE_OPTS);
  return html;
}

export function getPaperContent(slug: string): { contentHtml: string; headings: Heading[] } {
  const raw = fs.readFileSync(path.join(DOCS_PAPERS_DIR, `${slug}.html`), 'utf-8');
  const headings = extractHeadings(raw);
  const contentHtml = processHtml(raw, slug);
  return { contentHtml, headings };
}

export function getAbstractHtml(slug: string): string {
  const raw = fs.readFileSync(path.join(DOCS_PAPERS_DIR, `${slug}-abstract.html`), 'utf-8');
  return processHtml(raw, slug);
}
