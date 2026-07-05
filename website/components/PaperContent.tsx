/**
 * Injects pre-rendered (KaTeX + tikzcd), sanitized paper HTML.
 *
 * This is a plain Server Component using `dangerouslySetInnerHTML` rather
 * than a client-side ref callback. For a fully static export
 * (`output: 'export'`), a ref callback only ever runs in the browser after
 * hydration — there is no real DOM during static HTML generation — so the
 * page's initial HTML would ship with an *empty* `<div>` and the entire
 * paper would be invisible until client JS ran (worse than the "flash of
 * unrendered math" this pattern is meant to avoid). `dangerouslySetInnerHTML`
 * is emitted directly into the server-rendered/static HTML, and React 18
 * treats that subtree as opaque during hydration (it does not diff into
 * it), so there is no reconciliation/mangling risk either. This is safe
 * here because the HTML is our own pandoc + KaTeX build output, sanitized
 * with DOMPurify — not user-supplied content.
 */
export function PaperContent({ html }: { html: string }) {
  // eslint-disable-next-line react/no-danger
  return <div className="paper-content" dangerouslySetInnerHTML={{ __html: html }} />;
}
