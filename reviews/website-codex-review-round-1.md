# Website Codex Review — Round 1

Command: codex exec -m gpt-5.5 -c 'model_reasoning_effort="high"'
Date: Sat Jul  4 16:37:14 CST 2026

**Findings**

1. [website/components/PaperCard.tsx](/Users/mlong/Documents/Development/math-phy-library/website/components/PaperCard.tsx:13): home page skips from `h1` to card `h3`s.  
Fix: change card titles to `h2`, or add a real `h2` heading for the papers section and keep cards under it.

2. [website/components/PaperContent.tsx](/Users/mlong/Documents/Development/math-phy-library/website/components/PaperContent.tsx:19) + [website/app/papers/[slug]/page.tsx](/Users/mlong/Documents/Development/math-phy-library/website/app/papers/[slug]/page.tsx:52): paper pages render the page title as `h1`, then injected paper HTML contains many more `h1`s. Rendered Part VI had 14 `h1`s.  
Fix: demote imported paper headings during `processHtml()` so paper body `h1 -> h2`, `h2 -> h3`, etc., or generate pandoc HTML with shifted heading levels.

3. [website/lib/render-math.ts](/Users/mlong/Documents/Development/math-phy-library/website/lib/render-math.ts:173) and [website/lib/tikzcd.ts](/Users/mlong/Documents/Development/math-phy-library/website/lib/tikzcd.ts:213): KaTeX defaults to `htmlAndMathml`, which exports hundreds of raw TeX annotations per paper. Example export: `out/papers/algebraic-topology-conserved-information/index.html` has 830 `annotation encoding="application/x-tex"` nodes. This violates “no raw LaTeX in static HTML” and bloats pages.  
Fix: pass `output: 'html'` to both `katex.renderToString()` calls, or post-process KaTeX output to remove `<annotation encoding="application/x-tex">…</annotation>`.

4. [website/app/globals.css](/Users/mlong/Documents/Development/math-phy-library/website/app/globals.css:769): mobile paper pages horizontally overflow. Chrome headless at 390px reported `scrollWidth=725`; widest offenders were KaTeX MathML `mtable/mtr/mtd` nodes from display equations.  
Fix: same as issue 3, plus keep `.katex-display { overflow-x: auto; max-width: 100%; }`; if retaining MathML, force `.katex-mathml { overflow: hidden; max-width: 1px; }`.

5. [website/app/globals.css](/Users/mlong/Documents/Development/math-phy-library/website/app/globals.css:99): the header overflows on mobile because the logo is `white-space: nowrap` and the nav stays on the same flex row. Home at 390px reported `scrollWidth=496`; nav links started at x=390/460.  
Fix: add a mobile breakpoint allowing `.site-header-inner { flex-wrap: wrap; }`, shorten/hide the logo text, or make `.site-logo { white-space: normal; min-width: 0; }`.

6. [website/components/TableOfContents.tsx](/Users/mlong/Documents/Development/math-phy-library/website/components/TableOfContents.tsx:31): mobile TOC button has `aria-expanded` but no `aria-controls`, and the controlled nav has no `id`.  
Fix: give the nav a stable id, e.g. `id="paper-toc"`, and add `aria-controls="paper-toc"` to the button.

7. [website/components/TableOfContents.tsx](/Users/mlong/Documents/Development/math-phy-library/website/components/TableOfContents.tsx:41): active TOC state is visual only; the active link does not expose `aria-current`.  
Fix: set `aria-current={activeId === id ? 'true' : undefined}` on TOC links.

8. [website/lib/paper-content.ts](/Users/mlong/Documents/Development/math-phy-library/website/lib/paper-content.ts:70): generated paper content contains broken internal hash links, especially multi-label refs and equation refs. Examples include missing `#eq:pipeline`, `#sec:sheaves,sec:stacks`, `#eq:master-aut`; the checker found 80+ unresolved hashes.  
Fix: in the paper HTML pipeline, either preserve/generate ids for equations/tables/theorems, split comma-combined references into separate links, or render unresolved refs as plain text instead of anchors.

9. [website/app/globals.css](/Users/mlong/Documents/Development/math-phy-library/website/app/globals.css:331) and [website/app/globals.css](/Users/mlong/Documents/Development/math-phy-library/website/app/globals.css:416): small metadata text uses `--text-dim` with insufficient contrast for small text. `#7c7397` on `#150f30` is about 4.16:1; on `#0b0818` about 4.48:1.  
Fix: lighten `--text-dim` or use `--text-muted` for small metadata/footer text.

10. [website/components/PaperCard.tsx](/Users/mlong/Documents/Development/math-phy-library/website/components/PaperCard.tsx:9): card images use raw `<img>` without `width`/`height`, so the browser cannot reserve exact intrinsic dimensions.  
Fix: add explicit `width` and `height` matching the generated images, or use `next/image` with static dimensions.

11. [website/components/PaperCard.tsx](/Users/mlong/Documents/Development/math-phy-library/website/components/PaperCard.tsx:19) and [website/app/globals.css](/Users/mlong/Documents/Development/math-phy-library/website/app/globals.css:346): standalone card action links render about 36px tall, below the 44px mobile touch target target. Header/footer links are also smaller.  
Fix: increase vertical padding/min-height for standalone nav/action links to at least 44px; inline citation links can remain exempt.

12. [website/app/papers/[slug]/page.tsx](/Users/mlong/Documents/Development/math-phy-library/website/app/papers/[slug]/page.tsx:65): exported paper pages are very large: 1.6-3.0 MiB HTML each, before assets. This is mainly duplicated static paper HTML plus KaTeX MathML/RSC payload.  
Fix: first remove MathML annotations with `output: 'html'`; then consider moving huge paper bodies to static HTML fragments or another rendering path that avoids duplicating `dangerouslySetInnerHTML` content into the App Router flight payload.

Checked: `npm run build` passes; local images/PDFs referenced by exported pages exist; every paper page has absolute `og:url`, `og:image`, `twitter:image`, `og:title`, `og:description`, and `twitter:card`; `metadataBase` is set.

VERDICT: NEEDS_FIX
