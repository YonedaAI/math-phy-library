import katex from 'katex';
import { getKatexMacros } from './macros';
import { renderTikzSegments } from './tikzcd';
import { applyCommonFixups } from './tex-fixups';

/** Decode the small set of HTML entities pandoc uses when it embeds raw
 * LaTeX math source as text content of a `<span class="math ...">`. This
 * MUST happen before the string is handed to KaTeX, because e.g. a literal
 * `&` (alignment separator inside `aligned`/`align`) round-trips through
 * pandoc's HTML writer as `&amp;` — if left encoded, KaTeX would see the
 * literal text "&amp;" instead of a column separator.
 */
export function decodeEntities(s: string): string {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

/**
 * Extract every `\label{...}` in a (display) math source and strip it —
 * KaTeX does not implement `\label` as a no-op the way real LaTeX's
 * cross-referencing machinery does; left in place it renders as visible
 * red error-colored text. The stripped labels are returned so the caller
 * can attach a real HTML `id` to the rendered wrapper, making in-page
 * `\eqref`/`\Cref` links to that equation actually resolve.
 */
function extractAndStripLabels(src: string): { text: string; labels: string[] } {
  const labels: string[] = [];
  const text = src.replace(/\\label\{([^}]*)\}/g, (_m, id: string) => {
    labels.push(id);
    return '';
  });
  return { text, labels };
}

const MATH_SPAN_RE = /<span class="math (display|inline)">([\s\S]*?)<\/span>/g;

export interface MathRenderResult {
  html: string;
  /** label -> equation number, in document order, for cross-reference resolution. */
  equationNumbers: Map<string, number>;
}

/**
 * Render every pandoc math span in `html` to static KaTeX HTML (or, for
 * tikzcd content, a hand-rolled diagram). This is a pure, synchronous,
 * build-time transform — no client JS is involved in producing the math
 * markup that ships to the browser.
 *
 * KaTeX's `output` is set to `'html'` (not the default `'htmlAndMathml'`):
 * the MathML branch embeds the *raw TeX source* in an `<annotation>` tag
 * for every single piece of math on the page (hundreds per paper), which
 * (a) is literal uncompiled LaTeX sitting in the static HTML, (b) roughly
 * doubles page weight, and (c) introduces `<mtable>/<mtr>/<mtd>` nodes
 * that do not respect our CSS overflow rules and were the primary cause
 * of horizontal scroll on mobile for pages with display equations.
 */
export function renderMathInHtml(html: string): MathRenderResult {
  const macros = getKatexMacros();
  const equationNumbers = new Map<string, number>();
  let eqCounter = 0;

  const outHtml = html.replace(MATH_SPAN_RE, (full, kind: string, inner: string) => {
    const decoded = decodeEntities(inner).trim();

    // Strip the \[ \] / \( \) / $$ $$ / $ $ delimiters pandoc wraps the
    // raw source in; we drive display vs inline from the span class.
    let src = decoded;
    if (src.startsWith('\\[') && src.endsWith('\\]')) src = src.slice(2, -2);
    else if (src.startsWith('\\(') && src.endsWith('\\)')) src = src.slice(2, -2);
    else if (src.startsWith('$$') && src.endsWith('$$')) src = src.slice(2, -2);
    else if (src.startsWith('$') && src.endsWith('$')) src = src.slice(1, -1);

    if (src.includes('\\begin{tikzcd}')) {
      // A tikzcd diagram is sometimes wrapped in a numbered `equation`
      // environment purely so it can carry a \label; the wrapper has no
      // rendering role for us (we render diagrams as their own HTML block,
      // not via KaTeX's equation counter), and if left in place it splits
      // into an orphaned `\begin{equation}`/`\end{equation}` half-fragment
      // once the tikzcd body is carved out below.
      let tikzSrc = src.trim();
      const eqWrap = tikzSrc.match(
        /^\\begin\{equation\*?\}\s*([\s\S]*?)\\end\{equation\*?\}\s*$/
      );
      if (eqWrap) tikzSrc = eqWrap[1];
      // The wrapping wasn't always tidy: a \label can land before, after,
      // or even inside the tikzcd body (e.g. between \end{tikzcd} and
      // \end{equation}). Strip every \label{...} left over — KaTeX has no
      // \label support and renders it as visible red error text — and
      // attach the first one as the diagram's HTML id so in-page
      // \eqref/\Cref links to it still resolve.
      const diagramLabels: string[] = [];
      tikzSrc = tikzSrc.replace(/\\label\{([^}]*)\}/g, (_m, id: string) => {
        diagramLabels.push(id);
        return '';
      });
      try {
        const diagramHtml = renderTikzSegments(tikzSrc, macros);
        if (diagramLabels.length === 0) return diagramHtml;
        const extraAnchors = diagramLabels
          .slice(1)
          .map((l) => `<span id="${l}"></span>`)
          .join('');
        return `<div id="${diagramLabels[0]}">${extraAnchors}${diagramHtml}</div>`;
      } catch {
        return full;
      }
    }

    const { text: unlabeled, labels } = extractAndStripLabels(src);
    src = applyCommonFixups(unlabeled);

    let rendered: string;
    try {
      rendered = katex.renderToString(src, {
        displayMode: kind === 'display',
        throwOnError: false,
        trust: true,
        strict: 'ignore',
        output: 'html',
        macros: { ...macros },
      });
    } catch {
      return full;
    }

    if (labels.length > 0 && kind === 'display') {
      // Assign each \label its own sequential number (an `aligned`/`align`
      // block can carry several independently-numbered lines), so
      // cross-reference text stays monotonic even though we only render
      // one combined visual tag for the whole KaTeX block.
      const labelNums = labels.map((label) => {
        eqCounter += 1;
        equationNumbers.set(label, eqCounter);
        return eqCounter;
      });
      const tagText =
        labelNums.length > 1
          ? `(${labelNums[0]}–${labelNums[labelNums.length - 1]})`
          : `(${labelNums[0]})`;
      const extraAnchors = labels
        .slice(1)
        .map((l) => `<span id="${l}"></span>`)
        .join('');
      return (
        `<div class="katex-eq-row" id="${labels[0]}">${extraAnchors}` +
        `<div class="katex-eq-body">${rendered}</div>` +
        `<span class="katex-eq-tag">${tagText}</span></div>`
      );
    }

    return rendered;
  });

  return { html: outHtml, equationNumbers };
}
