import papersData from '../data/papers.json';

export interface Paper {
  slug: string;
  title: string;
  part: string;
  abstract: string;
  pages: number;
  hasCode: boolean;
  category: string;
}

export const papers: Paper[] = papersData as Paper[];

export function getAllPapers(): Paper[] {
  return papers;
}

export function getPaperBySlug(slug: string): Paper | undefined {
  return papers.find((p) => p.slug === slug);
}

export function getAdjacentPapers(slug: string): { prev: Paper | null; next: Paper | null } {
  const idx = papers.findIndex((p) => p.slug === slug);
  if (idx === -1) return { prev: null, next: null };
  return {
    prev: idx > 0 ? papers[idx - 1] : null,
    next: idx < papers.length - 1 ? papers[idx + 1] : null,
  };
}
