import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { getAllPapers, getPaperBySlug, getAdjacentPapers } from '../../../lib/papers';
import { getPaperContent, getAbstractHtml } from '../../../lib/paper-content';
import { PaperContent } from '../../../components/PaperContent';
import { TableOfContents } from '../../../components/TableOfContents';

export function generateStaticParams() {
  return getAllPapers().map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: { slug: string };
}): Promise<Metadata> {
  const paper = getPaperBySlug(params.slug);
  if (!paper) return {};
  return {
    title: paper.title,
    description: paper.abstract,
    openGraph: {
      title: paper.title,
      description: paper.abstract,
      type: 'article',
      url: `/papers/${paper.slug}`,
      images: [{ url: `/og/${paper.slug}.png`, width: 1200, height: 630 }],
    },
    twitter: {
      card: 'summary_large_image',
      title: paper.title,
      description: paper.abstract,
      images: [`/og/${paper.slug}.png`],
    },
  };
}

export default function PaperPage({ params }: { params: { slug: string } }) {
  const paper = getPaperBySlug(params.slug);
  if (!paper) notFound();

  const { contentHtml, headings } = getPaperContent(paper.slug);
  const abstractHtml = getAbstractHtml(paper.slug);
  const { prev, next } = getAdjacentPapers(paper.slug);

  return (
    <main>
      <div className="paper-layout">
        <div className="paper-header">
          <span className="part-badge">{paper.part}</span>
          <h1>{paper.title}</h1>
          <div className="meta">
            {paper.category} &middot; {paper.pages} pages
          </div>
        </div>

        <section className="paper-abstract">
          <h2>Abstract</h2>
          <PaperContent html={abstractHtml} />
        </section>

        <TableOfContents headings={headings} />

        <PaperContent html={contentHtml} />

        <nav className="paper-pagenav" aria-label="Paper navigation">
          {prev ? (
            <Link href={`/papers/${prev.slug}/`} prefetch={false}>
              <span className="dir-label">&larr; Previous</span>
              <span className="paper-title-nav">{prev.title}</span>
            </Link>
          ) : (
            <span />
          )}
          {next ? (
            <Link href={`/papers/${next.slug}/`} className="next-col" prefetch={false}>
              <span className="dir-label">Next &rarr;</span>
              <span className="paper-title-nav">{next.title}</span>
            </Link>
          ) : (
            <span />
          )}
        </nav>
      </div>

      <a className="pdf-fab" href={`/pdf/${paper.slug}.pdf`} download>
        <span aria-hidden="true">&#8681;</span> Download PDF
      </a>
    </main>
  );
}
