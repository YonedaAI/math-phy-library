# Quality Scorecard — Pass 2 (CONVERGED)

Pass 1 flagged 3 sub-bar papers (synthesis 70, algebraic-geometry 80, sheaves 84). Pass 2 refined
exactly those; the other 4 papers + the site were unchanged and retain their pass-1 scores.

| Paper | Pass 1 | Pass 2 | agy | Codex (code) | Haskell | Lean |
|---|:---:|:---:|---|---|---|:---:|
| foundations-representation-stack | 90 | 90 | MINOR | PASS | 26/26 QC · 10/10 proofs | ✓ |
| motives-periods-amplitudes | 91 | 91 | MINOR | PASS | 30/30 QC · 80/80 proofs | ✓ |
| algebraic-geometry-physical-possibility | 80 | **92** | MINOR | **PASS** | 30/30 QC · 10/10 proofs | ✓ |
| algebraic-topology-conserved-information | 93 | 93 | ACCEPT | PASS | 28/28 QC · 8/8 proofs | ✓ |
| category-theory-hott-composition | 90 | 90 | MINOR | PASS | 15/15 QC · 10/10 proofs | ✓ |
| sheaves-stacks-gauge-quantum-ha | 84 | **92** | MINOR | **PASS** | 34/34 QC · 9/9 proofs | ✓ |
| synthesis | 70 | **86** | MINOR | NEEDS_FIX\* | 32/32 QC · 9/9 proofs (9 new modules) | ✓ |
| **Site** | 96 | 96 | — | — | — | — |

**OVERALL: CONVERGED — all 7 papers + site ≥ 85 (min 86).** Loop stopped at pass 2 of a 3-pass cap.

## What pass 2 changed

- **algebraic-geometry (80 → 92):** `Properties.hs` referenced `isSuccess` only through the
  `Test.QuickCheck` umbrella (version-fragile). Fixed with an explicit
  `import qualified Test.QuickCheck.Test as QCT`; standalone typecheck now clean under
  `-Wall -Wextra -Werror`; 30/30 properties, 10/10 proofs; Codex re-review → **PASS**.
- **sheaves (84 → 92):** the recorded Codex verdict was a stale cap-round `NEEDS_FIX` even though the
  fixes were already in place. Re-verified (strict-clean, 34/34, 9/9) and Codex re-review → **PASS**.
- **synthesis (70 → 86):** the capstone had *no* verification code. Added `src/synthesis/` — 9 Haskell
  modules (`Status`, `Coaction`, `Gauge`, `Homology`, `Ladder`, `Closure`, `Properties`, `Proofs`,
  `Main`) that encode each faculty and demonstrate the closure-theorem keystone
  `Aut_[X/G](x) ≃ Stab_G(x)` and `H_phys ≃ (H_log⊗H_gauge)⊕H_err` — plus `lean/synthesis/Synthesis.lean`
  (proved lemmas, elaborates). Compiles `-Wall -Wextra -Werror` clean; 32/32 QuickCheck + 9/9 proofs.

\* **synthesis Codex verdict** is a cap-round `NEEDS_FIX`; the remaining items are documented Medium/Low
**non-correctness** defense-in-depth (opaque `Perm`/`ChainComplex` newtypes). The suite compiles clean
and all tests pass, so it clears the bar; a further hardening pass is optional, not required.
