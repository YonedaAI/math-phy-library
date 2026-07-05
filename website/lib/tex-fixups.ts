/**
 * Shared LaTeX-source-string fixups applied before any `katex.renderToString`
 * call (both the main math-span pipeline in render-math.ts and the
 * tikzcd/tikzpicture node-label renderer in tikzcd.ts). KaTeX 0.17 does not
 * implement a number of constructs pandoc's LaTeX reader passes through
 * verbatim; left unfixed, KaTeX's `strict: 'ignore'` setting does NOT throw
 * for these — it silently renders the literal command name as inline text
 * in the KaTeX "error color" (`#cc0000`), which is a real, visible defect
 * (found by auditing every built page for `color:#cc0000` — 352 instances
 * across `\label`, `\sffamily`, `\bfseries`, `\textsc`, `\ensuremath`
 * before this module existed).
 */

/** Extract a `{...}`-delimited argument starting at `text[start] === '{'`. */
export function readBraceGroup(text: string, start: number): [string, number] {
  let depth = 1;
  let i = start + 1;
  while (i < text.length && depth > 0) {
    if (text[i] === '{') depth++;
    else if (text[i] === '}') depth--;
    i++;
  }
  return [text.slice(start + 1, i - 1), i];
}

/** Strip every `\ensuremath{...}` wrapper down to its argument (KaTeX has
 * no notion of "ensure math mode" since we are always already in math
 * mode when this runs).
 */
function stripEnsuremath(input: string): string {
  let out = input;
  let idx: number;
  while ((idx = out.indexOf('\\ensuremath')) !== -1) {
    const braceStart = idx + '\\ensuremath'.length;
    if (out[braceStart] !== '{') break;
    const [content, after] = readBraceGroup(out, braceStart);
    out = out.slice(0, idx) + content + out.slice(after);
  }
  return out;
}

/** `\textsc{X}` (small caps) has no KaTeX equivalent; approximate it as
 * upper-cased plain text, which is the visually closest thing KaTeX can
 * render and is used here purely for roman-numeral part markers
 * (`\textsc{i}`, `\textsc{vi}`, ...).
 */
function fixTextsc(input: string): string {
  let out = '';
  let i = 0;
  while (i < input.length) {
    if (input.startsWith('\\textsc', i) && input[i + 7] === '{') {
      const [content, after] = readBraceGroup(input, i + 7);
      out += `\\text{${content.toUpperCase()}}`;
      i = after;
      continue;
    }
    out += input[i];
    i++;
  }
  return out;
}

/** `\textnormal{\sffamily\bfseries X}` (the expansion of this series'
 * `\status`-style badge macros) uses two legacy TeX font-declaration
 * commands KaTeX does not implement as declarations. Rewrite to the
 * KaTeX-supported function form with the same visual result (bold
 * sans-serif).
 */
function fixSffamilyBfseries(input: string): string {
  return input.replace(
    /\\textnormal\{\\sffamily\\bfseries\s+([^}]*)\}/g,
    '\\textsf{\\textbf{$1}}'
  );
}

/**
 * Pandoc's LaTeX reader textually expands `\newcommand` macros before we
 * ever see the math source. That is a win almost everywhere, but it
 * defeats TeX's own argument-grabbing for accent commands: `\bar\Hh`
 * (accent applied to a single macro *token*, which itself later expands)
 * becomes the literal text `\bar\mathcal{H}`, which KaTeX's stricter
 * parser rejects because `\mathcal` alone is not a valid single-token
 * argument once it's followed by its own `{H}` group. Rewrap as
 * `\bar{\mathcal{H}}`.
 */
function fixUnbracedAccents(input: string): string {
  const accents = [
    'bar', 'hat', 'tilde', 'widehat', 'widetilde', 'overline',
    'vec', 'dot', 'ddot', 'check', 'breve', 'acute', 'grave',
  ];
  let out = '';
  let i = 0;
  outer: while (i < input.length) {
    for (const acc of accents) {
      const prefix = '\\' + acc + '\\';
      if (input.startsWith(prefix, i)) {
        let k = i + prefix.length;
        const nameStart = k;
        while (k < input.length && /[a-zA-Z]/.test(input[k])) k++;
        if (k > nameStart && input[k] === '{') {
          const cmdName = input.slice(nameStart, k);
          const [content, after] = readBraceGroup(input, k);
          out += `\\${acc}{\\${cmdName}{${content}}}`;
          i = after;
          continue outer;
        }
      }
    }
    out += input[i];
    i++;
  }
  return out;
}

/**
 * Unwrap `\resizebox{w}{h}{$...$}` (used to squeeze a display equation to
 * page width) down to its inner content — `\resizebox` is a graphics
 * command, not a math primitive KaTeX understands.
 */
function stripResizebox(input: string): string {
  const out = input;
  const resizeIdx = out.indexOf('\\resizebox');
  if (resizeIdx === -1) return out;
  let i = resizeIdx + '\\resizebox'.length;
  if (out[i] !== '{') return out;
  const [, afterW] = readBraceGroup(out, i);
  i = afterW;
  if (out[i] !== '{') return out;
  const [, afterH] = readBraceGroup(out, i);
  i = afterH;
  if (out[i] !== '{') return out;
  const [content, afterContent] = readBraceGroup(out, i);
  let inner = content.trim();
  if (inner.startsWith('$')) inner = inner.slice(1);
  if (inner.endsWith('$')) inner = inner.slice(0, -1);
  return out.slice(0, resizeIdx) + inner + out.slice(afterContent);
}

/**
 * All fixups that are safe to apply unconditionally to any math-mode LaTeX
 * fragment before handing it to `katex.renderToString`.
 */
export function applyCommonFixups(raw: string): string {
  let out = raw;
  out = stripResizebox(out);
  out = stripEnsuremath(out);
  // \text{...$...$...} -> \text{...}...\text{...} (amsmath's "re-enter
  // math mode inside \text", which KaTeX's \text does not support).
  out = out.replace(/\\text\{([^{}$]*)\$([^$]*)\$([^{}]*)\}/g, '\\text{$1}$2\\text{$3}');
  // multline/multline* -> gathered (KaTeX has no multline support).
  out = out
    .replace(/\\begin\{multline\*?\}/g, '\\begin{gathered}')
    .replace(/\\end\{multline\*?\}/g, '\\end{gathered}');
  // psmallmatrix (mathtools) -> parenthesized smallmatrix.
  out = out
    .replace(/\\begin\{psmallmatrix\}/g, '\\left(\\begin{smallmatrix}')
    .replace(/\\end\{psmallmatrix\}/g, '\\end{smallmatrix}\\right)');
  out = fixSffamilyBfseries(out);
  out = fixTextsc(out);
  out = fixUnbracedAccents(out);
  return out;
}
