// Ambient module declarations for side-effect CSS imports (e.g.
// `import 'katex/dist/katex.min.css'` and `import './globals.css'` in
// app/layout.tsx), for standalone `tsc` type-checking environments that
// don't already get these from Next's webpack/plugin pipeline.
declare module '*.css';
