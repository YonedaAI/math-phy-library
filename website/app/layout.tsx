import type { Metadata } from 'next';
import { Space_Grotesk, Source_Serif_4, JetBrains_Mono } from 'next/font/google';
import Link from 'next/link';
import 'katex/dist/katex.min.css';
import './globals.css';

const spaceGrotesk = Space_Grotesk({
  subsets: ['latin'],
  variable: '--font-space-grotesk',
  weight: ['500', '600', '700'],
  display: 'swap',
});

const sourceSerif = Source_Serif_4({
  subsets: ['latin'],
  variable: '--font-source-serif',
  weight: ['400', '600', '700'],
  display: 'swap',
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-jetbrains-mono',
  weight: ['400', '500', '700'],
  display: 'swap',
});

// Injected at deploy time (falls back to the known production URL so
// metadataBase is never localhost in a shipped build).
const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://math-phy-library.vercel.app';

const SERIES_TITLE = 'A Math→Physics Representation Library';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: SERIES_TITLE,
    template: `%s | ${SERIES_TITLE}`,
  },
  description:
    'Six mathematical faculties (motives, algebraic geometry, algebraic topology, category theory & HoTT, and sheaves/stacks) formalized as physical-representation modules that compose into a modular synthesis.',
  openGraph: {
    type: 'website',
    siteName: SERIES_TITLE,
    title: SERIES_TITLE,
    description:
      'A seven-part modular research program formalizing mathematical domains as physical-representation modules.',
    images: [{ url: '/og/og-default.png', width: 1200, height: 630 }],
  },
  twitter: {
    card: 'summary_large_image',
    title: SERIES_TITLE,
    images: ['/og/og-default.png'],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${spaceGrotesk.variable} ${sourceSerif.variable} ${jetbrainsMono.variable} antialiased`}
      >
        <header className="site-header">
          <div className="site-header-inner">
            <Link href="/" className="site-logo">
              <span className="site-logo-mark" aria-hidden="true" />
              A Math→Physics Representation Library
            </Link>
            <nav className="site-nav" aria-label="Primary">
              <Link href="/">Papers</Link>
              <a href="https://github.com/YonedaAI/math-phy-library" target="_blank" rel="noopener noreferrer">
                Code
              </a>
            </nav>
          </div>
        </header>
        {children}
        <footer className="site-footer">
          <div className="site-footer-inner">
            <span>
              &copy; {new Date().getFullYear()} Matthew Long &middot; The YonedaAI Collaboration
            </span>
            <span>
              <a href="https://github.com/YonedaAI/math-phy-library" target="_blank" rel="noopener noreferrer">
                GitHub
              </a>
            </span>
          </div>
        </footer>
      </body>
    </html>
  );
}
