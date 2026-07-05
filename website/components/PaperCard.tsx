import Link from 'next/link';
import type { Paper } from '../lib/papers';

export function PaperCard({ paper }: { paper: Paper }) {
  return (
    <article className="paper-card">
      <div className="paper-card-cover">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={`/images/${paper.slug}-thumb.png`}
          alt={`Cover illustration for ${paper.title}`}
          width={800}
          height={450}
          loading="lazy"
        />
        <span className="paper-card-part">{paper.part}</span>
      </div>
      <div className="paper-card-body">
        <h3 className="paper-card-title">{paper.title}</h3>
        <p className="paper-card-abstract">{paper.abstract.slice(0, 150)}{paper.abstract.length > 150 ? '…' : ''}</p>
        <div className="paper-card-meta">
          {paper.category} &middot; {paper.pages} pages{paper.hasCode ? ' · code' : ''}
        </div>
        <div className="paper-card-links">
          <Link href={`/papers/${paper.slug}/`} className="primary" prefetch={false}>
            Read
          </Link>
          <a href={`/pdf/${paper.slug}.pdf`}>PDF</a>
          <a href="https://github.com/YonedaAI/math-phy-library" target="_blank" rel="noopener noreferrer">
            Code
          </a>
        </div>
      </div>
    </article>
  );
}
