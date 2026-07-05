import fs from 'fs';
import path from 'path';
import { REPO_ROOT, getKatexMacros } from './macros';
import { renderTikzSegments, renderTikzPicturePipeline } from './tikzcd';

/**
 * Pandoc's LaTeX reader only treats `\[...\]`/`\(...\)`/`$...$` spans as
 * "raw math" it round-trips verbatim. A `tikzcd`/`tikzpicture` diagram
 * placed directly inside a bare `\begin{figure}...\end{figure}` (i.e. not
 * wrapped in a math shift) is therefore invisible to it and is silently
 * dropped, leaving an empty `<figure id="X">...<figcaption>...` shell in
 * the HTML output. We recover the original diagram source from the
 * paper's own .tex file (matched by the figure's `\label{X}`) and splice
 * a rendered replacement back in.
 */

function findEnclosingFigureBody(tex: string, label: string): string | null {
  const labelTag = `\\label{${label}}`;
  const labelIdx = tex.indexOf(labelTag);
  if (labelIdx === -1) return null;
  const figStart = tex.lastIndexOf('\\begin{figure}', labelIdx);
  if (figStart === -1) return null;
  // also accept \begin{figure}[...]
  let start = figStart;
  const bracketMatch = tex.slice(figStart + '\\begin{figure}'.length).match(/^\[[^\]]*\]/);
  if (bracketMatch) start = figStart + '\\begin{figure}'.length + bracketMatch[0].length;
  else start = figStart + '\\begin{figure}'.length;
  const figEnd = tex.indexOf('\\end{figure}', labelIdx);
  if (figEnd === -1) return null;
  return tex.slice(start, figEnd);
}

const EMPTY_FIGURE_RE = /<figure id="([^"]+)"[^>]*>\s*<figcaption/g;

export function restoreDroppedFigures(html: string, slug: string): string {
  const texPath = path.join(REPO_ROOT, 'papers', 'latex', `${slug}.tex`);
  let tex: string;
  try {
    tex = fs.readFileSync(texPath, 'utf-8');
  } catch {
    return html;
  }

  const macros = getKatexMacros();

  const labels: string[] = [];
  let m: RegExpExecArray | null;
  EMPTY_FIGURE_RE.lastIndex = 0;
  while ((m = EMPTY_FIGURE_RE.exec(html))) labels.push(m[1]);

  let out = html;
  for (const label of labels) {
    const body = findEnclosingFigureBody(tex, label);
    if (!body) continue;

    let rendered = '';
    if (body.includes('\\begin{tikzcd}')) {
      // Diagrams are sometimes squeezed into `\resizebox{w}{h}{% ... %}`;
      // trim to the first `\begin{tikzcd}` .. last `\end{tikzcd}` span so
      // that wrapper/caption/label text never gets treated as math.
      const first = body.indexOf('\\begin{tikzcd}');
      const last = body.lastIndexOf('\\end{tikzcd}');
      const tikzSource = body.slice(first, last + '\\end{tikzcd}'.length);
      rendered = renderTikzSegments(tikzSource, macros);
    } else if (body.includes('\\begin{tikzpicture}')) {
      const first = body.indexOf('\\begin{tikzpicture}');
      const last = body.lastIndexOf('\\end{tikzpicture}');
      const picSource = body.slice(first, last + '\\end{tikzpicture}'.length);
      rendered = renderTikzPicturePipeline(picSource, macros);
    } else {
      continue;
    }

    const marker = `<figure id="${label}"`;
    const markerIdx = out.indexOf(marker);
    if (markerIdx === -1) continue;
    const figcaptionIdx = out.indexOf('<figcaption', markerIdx);
    if (figcaptionIdx === -1) continue;
    out = out.slice(0, figcaptionIdx) + rendered + '\n' + out.slice(figcaptionIdx);
  }

  return out;
}
