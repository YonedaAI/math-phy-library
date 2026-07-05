import type { Metadata } from 'next';
import { getAllPapers } from '../lib/papers';
import { PaperCard } from '../components/PaperCard';

export const metadata: Metadata = {
  openGraph: {
    images: [{ url: '/og/og-default.png', width: 1200, height: 630 }],
  },
  twitter: {
    card: 'summary_large_image',
    images: ['/og/og-default.png'],
  },
};

export default function Home() {
  const papers = getAllPapers();

  return (
    <main>
      <section className="hero">
        <div className="hero-inner">
          <span className="hero-eyebrow">math.CT &middot; math-ph &middot; seven-part modular series</span>
          <h1>A Math→Physics Representation Library</h1>
          <p>
            Six mathematical faculties (motives, algebraic geometry, algebraic topology, category
            theory &amp; homotopy type theory, and sheaves/stacks/gauge), each formalized as a
            physical-representation module. The modules compose hierarchically, Part I through
            Part VI, into a single modular synthesis.
          </p>
          <div className="hero-stats">
            <div className="hero-stat">
              <div className="hero-stat-num">{papers.length}</div>
              <div className="hero-stat-label">Papers</div>
            </div>
            <div className="hero-stat">
              <div className="hero-stat-num">6</div>
              <div className="hero-stat-label">Faculties</div>
            </div>
            <div className="hero-stat">
              <div className="hero-stat-num">1</div>
              <div className="hero-stat-label">Synthesis</div>
            </div>
          </div>
        </div>
      </section>

      <section className="papers-section">
        <h2 className="papers-section-heading">The Papers</h2>
        <div className="papers-grid">
          {papers.map((paper) => (
            <PaperCard key={paper.slug} paper={paper} />
          ))}
        </div>
      </section>
    </main>
  );
}
