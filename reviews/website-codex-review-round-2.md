# Website Codex Review — Round 2

Command: codex exec -m gpt-5.5 -c 'model_reasoning_effort="high"'
Date: Sat Jul  4 17:12:37 CST 2026

**Findings**

1. [website/lib/paper-content.ts](/Users/mlong/Documents/Development/math-phy-library/website/lib/paper-content.ts:77) blindly shifts every imported heading down one level, which creates skipped heading levels in rendered paper pages. Example source headings in [docs/papers/synthesis.html](/Users/mlong/Documents/Development/math-phy-library/docs/papers/synthesis.html:95) become `<h5>` after an `<h3>` or `<h2>`.
Fix: normalize headings statefully so no heading is more than one level deeper than the previous heading, or remap imported `h4` paragraph headings to the next valid level for the current section.

2. [website/app/layout.tsx](/Users/mlong/Documents/Development/math-phy-library/website/app/layout.tsx:73) has an unlabeled primary `<nav>`, while paper pages also have TOC and paper-navigation landmarks.
Fix: add `aria-label="Primary"` to the header nav.

3. [website/app/globals.css](/Users/mlong/Documents/Development/math-phy-library/website/app/globals.css:92) and [website/app/globals.css](/Users/mlong/Documents/Development/math-phy-library/website/app/globals.css:129) leave header targets under 44px in one dimension. Rendered mobile: logo target was `335x22`; `Code` was `36x44`.
Fix: add `min-height: 44px` to `.site-logo`, and add horizontal padding or `min-width: 44px` to `.site-nav a`.

4. [website/app/globals.css](/Users/mlong/Documents/Development/math-phy-library/website/app/globals.css:498) makes TOC links only about `28-29px` tall when visible.
Fix: make `.toc-item` `display: flex; align-items: center; min-height: 44px;` and adjust padding/line-height accordingly.

5. [website/components/TableOfContents.tsx](/Users/mlong/Documents/Development/math-phy-library/website/components/TableOfContents.tsx:10) recalculates every heading’s `offsetTop` on every scroll event and calls `setActiveId` even when the active section has not changed.
Fix: throttle with `requestAnimationFrame`, cache heading offsets on resize/content load, and only call `setActiveId` when the id changes; or use `IntersectionObserver` while preserving scroll-position-based active state.

6. [website/components/PaperCard.tsx](/Users/mlong/Documents/Development/math-phy-library/website/components/PaperCard.tsx:9) serves full `2550x3300` PNG covers for 16:9 cropped cards. The files are ~592-812 KB each, and the homepage requested all seven during rendered QA.
Fix: generate card-specific responsive thumbnails, preferably AVIF/WebP, and serve via `<picture>`/`srcSet`; keep the large PNGs only where full-resolution inspection is needed.

7. [website/app/papers/[slug]/page.tsx](/Users/mlong/Documents/Development/math-phy-library/website/app/papers/[slug]/page.tsx:43) plus [website/components/PaperContent.tsx](/Users/mlong/Documents/Development/math-phy-library/website/components/PaperContent.tsx:19) embed very large processed paper HTML strings into App Router output. Static paper pages are ~1.19-2.27 MB before compression because the opaque article HTML is also serialized into Next’s RSC payload.
Fix: render the long paper body through a static template/postbuild step that avoids serializing the whole article through React flight data, or split article HTML into static assets and keep only lightweight React shell/TOC state in the App Router.

**Verified OK**

`npm --prefix website run build` passed. Local link/asset check found `0` missing local links. Every paper page has absolute `og:url`, `og:image`, and `twitter:image` in the exported HTML. KaTeX is server-rendered: exported paper pages had `0` raw `span.math`, `0` `katex-mathml`, `0` raw `\begin`, `\frac`, `\label`, `\eqref`, or `$$` hits, with rendered `.katex` present. Rendered desktop/mobile checks showed no horizontal overflow, no console errors, and TOC active-section tracking works after scroll.

VERDICT: NEEDS_FIX
