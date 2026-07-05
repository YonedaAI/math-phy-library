# A Math→Physics Representation Library

> Six mathematical faculties, each formalized as a physical-representation **module**. The modules
> compose hierarchically into one **modular synthesis**, and every rung of the ladder adds an
> emergent representational property that the level below cannot express.

**Live site:** https://math-phy-library.vercel.app
&nbsp;·&nbsp; **Repository:** https://github.com/YonedaAI/math-phy-library

---

## Overview

This project decomposes a single representation-stack manuscript into six focused papers plus a
synthesis, seven in all. Each paper takes one mathematical domain and formalizes it as a
*module* in a shared **representation stack** with a common realization pipeline

```
Obs_α(M) = Obs( Real_α( Φ(M) ) )
```

The modules stay separate and compose instead of merging into a monolith. The synthesis proves a
closure theorem: Part I introduces the representation stack abstractly, and the Part VI capstone
discharges it via descent-theoretic stackification. The isotropy keystone
`Aut(x) ≃ Stab_G(x)` carries the argument, and its physical face is gauge redundancy ≅ quantum high-availability.

Every paper has been peer reviewed, code reviewed, and formally verified (see below).

## Papers

| Part | Title | Pages | Read | PDF |
|:---:|---|:---:|---|---|
| I | Foundations: The Representation Stack and the Realization Pipeline | 25 | [read](https://math-phy-library.vercel.app/papers/foundations-representation-stack/) | [pdf](https://math-phy-library.vercel.app/pdf/foundations-representation-stack.pdf) |
| II | Motives, Periods, and Amplitudes: The Coalgebraic Anatomy of Physical Representation | 26 | [read](https://math-phy-library.vercel.app/papers/motives-periods-amplitudes/) | [pdf](https://math-phy-library.vercel.app/pdf/motives-periods-amplitudes.pdf) |
| III | Algebraic Geometry: Spaces of Physical Possibility | 27 | [read](https://math-phy-library.vercel.app/papers/algebraic-geometry-physical-possibility/) | [pdf](https://math-phy-library.vercel.app/pdf/algebraic-geometry-physical-possibility.pdf) |
| IV | Algebraic Topology: Conserved Global Information | 24 | [read](https://math-phy-library.vercel.app/papers/algebraic-topology-conserved-information/) | [pdf](https://math-phy-library.vercel.app/pdf/algebraic-topology-conserved-information.pdf) |
| V | Category Theory and Homotopy Type Theory: Composition and Identity | 24 | [read](https://math-phy-library.vercel.app/papers/category-theory-hott-composition/) | [pdf](https://math-phy-library.vercel.app/pdf/category-theory-hott-composition.pdf) |
| VI | Sheaves, Stacks, Gauge Redundancy, and Quantum High-Availability | 23 | [read](https://math-phy-library.vercel.app/papers/sheaves-stacks-gauge-quantum-ha/) | [pdf](https://math-phy-library.vercel.app/pdf/sheaves-stacks-gauge-quantum-ha.pdf) |
| — | **A Modular Representation Synthesis:** Composing Six Mathematical Faculties into Physical Representation | 24 | [read](https://math-phy-library.vercel.app/papers/synthesis/) | [pdf](https://math-phy-library.vercel.app/pdf/synthesis.pdf) |

*173 pages total.*

## The Modular Composition Ladder

```
Part I    Foundations ──────────── the representation stack + realization pipeline
   │  ↳ coalgebraic anatomy
Part II   Motives / Periods / Amplitudes
   │  ↳ geometric variation
Part III  Algebraic Geometry
   │  ↳ functorial conservation
Part IV   Algebraic Topology
   │  ↳ universal compositional grammar
Part V    Category Theory & HoTT
   │  ↳ high availability / fault tolerance
Part VI   Sheaves, Stacks, Gauge Redundancy, Quantum High-Availability
   ↓
Synthesis  closure theorem — the ladder closes on itself
```

Each arrow names the emergent property that appears only after composition.

## Formal Verification

Each domain paper comes with machine-checked companions:

- **Haskell** (`src/<topic>/`): every major theorem has a QuickCheck property and an equational
  `Proofs.hs` derivation; all modules compile under `ghc -Wall -Wextra -Werror`, and `Main` exits 0.
  *(15 to 34 QuickCheck properties plus 8 to 10 equational proofs per topic, all passing.)*
- **Lean 4** (`lean/<topic>/`): best-effort formalization sketches of the core structures and
  theorem signatures; they elaborate standalone.

**Review.** Every paper went through iterative peer review by `agy` (Antigravity CLI, Gemini
3.1 Pro), which caught genuine mathematical errors across the series: a `Z₂^{4g}` surface-code
logical-group correction, a Conditional-Amplitude-Decomposition category error, a translation-strength
inconsistency, and more. Each paper also had a Codex (`gpt-5.5`) formatting and code review, and both
passes ran in fix loops until the reviewers were satisfied. Round-by-round reviews are in `reviews/`.

## Repository Layout

```
papers/latex/   LaTeX sources (7 papers)          website/     Next.js static site (deployed to Vercel)
papers/pdf/     compiled PDFs                       docs/papers/ pandoc HTML conversions
src/<topic>/    Haskell modules + Properties/Proofs posts/       social posts (4 platforms × 7 papers)
lean/<topic>/   Lean 4 sketches                     reviews/     agy + Codex review transcripts
images/         cover images (300 DPI)              context/     original source material
```

## Build Locally

```bash
# Papers
cd papers/latex && pdflatex -interaction=nonstopmode <topic>.tex   # ×2

# Haskell verification (per topic)
cd src/<topic> && ghc -Wall -Wextra -Werror -o test Main.hs *.hs -package QuickCheck && ./test

# Website
cd website && npm install && npm run build      # static export to website/out/
```

## Author

**Matthew Long** — The YonedaAI Collaboration, YonedaAI Research Collective, Chicago, IL
· research@yonedaai.com · https://yonedaai.com

## License

Research artifacts released for academic use.
