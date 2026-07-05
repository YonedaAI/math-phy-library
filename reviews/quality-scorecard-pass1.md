# Quality Scorecard — Pass 1 (completeness-critic)

Series: 7-paper modular math→physics representation library + website.
Rubric bar = 85. Scored against: mathematical rigor, depth (≥20 pp), peer review
(agy ACCEPT / MINOR REVISIONS), code review (Codex PASS on formatting + Haskell),
formal verification (Properties.hs + Proofs.hs compile, Lean sketch present),
real citations. Date: 2026-07-04.

## Scorecard

| Paper | Score | agy | Codex | Haskell | Lean | Gaps |
|-------|-------|-----|-------|---------|------|------|
| foundations-representation-stack | 90 | MINOR REV | PASS | PASS | present | 3 open agy nits (sheaf-condition hypothesis, HoTT encoding note, axiom numbering); all cosmetic. 25 pp, 4 thm / 6 proofs, 15 refs. |
| motives-periods-amplitudes | 91 | MINOR REV | PASS | PASS | present | Restrict Thm 6.2 to number fields; legacy `everypage` hook. Haskell 80/80 proof checks. 26 pp, 7 thm / 8 proofs, 16 refs. |
| algebraic-geometry-physical-possibility | 80 | MINOR REV | PASS | **NEEDS_FIX** | present | Haskell Codex verdict unresolved: fresh typecheck of `Properties.hs` fails on `isSuccess` (compiled binaries pass, but source does not typecheck clean) — dings both code-review AND formal-verification "compiles". Also Medium: pole-multiplicity handling; Low: Picard–Fuchs base point at λ=0.5 misses c1 path. 27 pp, 7 thm / 9 proofs, 18 refs. |
| algebraic-topology-conserved-information | 93 | ACCEPT | PASS | PASS | present | Only note: pseudo-Haskell typeclass sketch merges object/morphism ops on one type var (explicitly a sketch, acceptable). Strongest paper: 24 pp, 18 thm / 19 proofs, 13 refs. |
| category-theory-hott-composition | 90 | MINOR REV | PASS | PASS | present | One agy nit: clarify HoTT transport phrasing in T1 proof. "essentially ready for publication." 24 pp, 10 thm / 11 proofs, 11 refs. |
| sheaves-stacks-gauge-quantum-ha | 84 | MINOR REV | PASS | **NEEDS_FIX** | present | Haskell review VERDICT token is NEEDS_FIX (Codex 3-invocation cap), BUT documented post-verdict fixes re-verified as passing (`-Wall -Wextra -Werror` clean, QuickCheck 34/34, equational proofs 9/9). Gap is that the verdict token was never flipped to PASS. 23 pp, 9 thm / 10 proofs, 20 refs. |
| synthesis | 70 | MINOR REV | PASS | **N/A (missing)** | **MISSING** | Formal-verification criterion entirely absent: no `src/synthesis/` dir, no Properties.hs / Proofs.hs, no `lean/synthesis/`, no haskell-codex review. In-paper rigor thin for a capstone (1 theorem / 1 proof, no code listings). Strengths: 24 pp, 37 refs (richest bibliography). |
| **Site** | 96 | — | — | — | — | Home + `/papers/synthesis/` both HTTP 200; 0 `katex-error`; 0 raw LaTeX (`\frac`/`\mathcal`) leaking outside math; og:image absolute (`https://math-phy-library.vercel.app/og/...png`, 1200×630). Clean. |

## Overall

REFINE: algebraic-geometry-physical-possibility, sheaves-stacks-gauge-quantum-ha, synthesis

### Refinement priorities
1. **synthesis** (70) — hardest miss. Add `src/synthesis/{Properties.hs,Proofs.hs}`
   + `lean/synthesis/` sketch and run the Haskell Codex review; optionally lift
   in-paper rigor beyond the single theorem/proof. Three rubric dimensions unmet.
2. **algebraic-geometry-physical-possibility** (80) — fix the `isSuccess`
   typecheck failure in `Properties.hs` so source (not just binaries) compiles
   clean, then re-run Haskell Codex to a PASS. Address pole-multiplicity and
   Picard–Fuchs base-point notes.
3. **sheaves-stacks-gauge-quantum-ha** (84) — mostly bookkeeping: the fixes are
   already applied and re-verified passing; re-run/close the Haskell Codex review
   so the recorded VERDICT reads PASS instead of NEEDS_FIX.

Four papers (foundations 90, motives 91, algebraic-topology 93,
category-theory 90) and the site (96) clear the bar.
