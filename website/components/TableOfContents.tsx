'use client';

import { useEffect, useRef, useState } from 'react';
import type { Heading } from '../lib/paper-content';

export function TableOfContents({ headings }: { headings: Heading[] }) {
  const [activeId, setActiveId] = useState('');
  const [open, setOpen] = useState(false);
  // Avoid re-rendering on every scroll tick: only setState when the
  // computed active id actually changes.
  const activeIdRef = useRef('');

  useEffect(() => {
    // Heading DOM nodes don't move without a resize/content change, so
    // their offsetTop is cached once instead of re-queried on every
    // scroll event.
    let offsets: { id: string; top: number }[] = [];
    const computeOffsets = () => {
      offsets = headings
        .map(({ id }) => {
          const el = document.getElementById(id);
          return el ? { id, top: el.offsetTop } : null;
        })
        .filter((x): x is { id: string; top: number } => x !== null);
    };
    computeOffsets();

    let ticking = false;
    const update = () => {
      ticking = false;
      const scrollY = window.scrollY + 100; // offset for sticky header
      let current = '';
      for (const { id, top } of offsets) {
        if (top <= scrollY) current = id;
      }
      if (current !== activeIdRef.current) {
        activeIdRef.current = current;
        setActiveId(current);
      }
    };
    const onScroll = () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(update);
      }
    };
    const onResize = () => {
      computeOffsets();
      update();
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onResize, { passive: true });
    update();
    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onResize);
    };
  }, [headings]);

  if (headings.length === 0) return null;

  return (
    <div className="toc-wrapper">
      <button
        type="button"
        className="toc-mobile-toggle"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-controls="paper-toc"
      >
        <span aria-hidden="true">&#9776;</span> Contents
      </button>
      <nav id="paper-toc" className={`toc ${open ? '' : 'collapsed'}`} aria-label="Table of contents">
        {headings.map(({ id, text, level }) => (
          <a
            key={id}
            href={`#${id}`}
            className={`toc-item ${level === 3 ? 'toc-sub' : ''} ${activeId === id ? 'toc-active' : ''}`}
            aria-current={activeId === id ? 'true' : undefined}
            onClick={() => setOpen(false)}
          >
            {text}
          </a>
        ))}
      </nav>
    </div>
  );
}
