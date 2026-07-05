# Website Codex Review — Round 3

Note: the first round-3 attempt (`model_reasoning_effort="high"`) hung for >20
minutes with no log progress (stuck mid-way through a Chrome DevTools Protocol
check against a headless Chrome instance) and was killed; per the fallback
instruction, effort was dropped to `medium` and the review re-run successfully
below.

Command: codex exec -m gpt-5.5 -c 'model_reasoning_effort="medium"' (after killing a hung "high" attempt)

**Findings**

1. Heading hierarchy skips from `h2` to `h4` on exported paper pages.
   Owner: website/lib/paper-content.ts:90. The global distinct-level remap preserves original `h4` paragraph headings as final `h4`, so pages can emit `h2 -> h4` with no intervening `h3`. Confirmed in exported pages for `category-theory-hott-composition` and `synthesis`.
   Fix: remap heading levels by document outline/order, or explicitly normalize pandoc paragraph headings under current section to `h3`/`h4` without skipping. Add an export check that fails on any heading jump greater than 1.

   STATUS: FIXED post-review. Replaced the global "distinct levels used"
   compaction with a document-order, ancestor-stack-based normalizer (see
   `shiftHeadingLevels` in lib/paper-content.ts) that assigns each heading
   exactly one level below its nearest shallower ancestor, regardless of
   the gap in pandoc's original numbering. Verified via a document-order
   scan of all 7 exported pages: zero skips (no heading level increases by
   more than 1 anywhere in any page), and open/close tag counts balance.

2. Paper pages ship very large duplicated HTML payloads.
   Owner: website/app/papers/[slug]/page.tsx:65, website/components/PaperContent.tsx:17. The full KaTeX-rendered paper body is emitted as static DOM and again inside Next Flight scripts. Exported paper pages are 1.1-2.2 MB raw each, with `algebraic-topology-conserved-information` at 2.2 MB.
   Fix: avoid sending the full paper body through App Router RSC serialization. Use a non-RSC/static HTML generation path for paper pages, or move the heavy paper body to separately generated static HTML while keeping metadata and navigation in Next.

   STATUS: ACKNOWLEDGED, partially mitigated, not fully resolved. This is
   an inherent characteristic of Next.js 14 App Router static export: any
   page mixing a Server Component with a Client Component (here,
   `TableOfContents`) has its full rendered tree serialized into the RSC
   flight payload for client-side hydration/navigation, which duplicates
   large static content. Already-applied mitigations: (a) KaTeX
   `output: 'html'` instead of the default `htmlAndMathml` dropped the
   `<annotation>` MathML branch entirely, roughly halving page weight;
   (b) `prefetch={false}` on all `<Link>`s pointing at paper pages (home
   page cards, prev/next nav) so viewing the homepage no longer triggers
   background downloads of all 7 large paper payloads. A full fix would
   require restructuring paper pages to avoid Server+Client component
   mixing (e.g. dropping the TOC's client-side scroll-spy in favor of a
   CSS-only or non-React-hydrated approach), which is a larger change
   deferred given the review-round budget; raw HTML size is also not
   representative of wire size, since text/HTML compresses very well
   under gzip/Brotli (which Vercel applies automatically).

**Verified OK (from this round)**

`metadataBase` is set. Every paper page has `og:title`, `og:description`, `og:url`, `og:image`, `twitter:card`, and absolute URLs in exported HTML. KaTeX is server-rendered; exported pages contain no raw `\begin`, `\(`, `\[`, `\label`, `<span class="math">`, or KaTeX `<annotation>` remnants. Local exported links/assets scanned clean: no missing images, PDFs, internal pages, CSS, or JS assets. Contrast ratios pass WCAG AA. Mobile/desktop screenshots rendered without first-viewport overlap; touch targets sized at 44px via CSS. `npm run lint` and `npm run build` both pass.

VERDICT: NEEDS_FIX (one finding fixed post-review; one finding is an acknowledged Next.js App Router architectural trade-off, mitigated but not eliminated)
