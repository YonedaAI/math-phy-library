---
reviewer: codex (OpenAI)
model: gpt-5.5 (reasoning=high)
type: haskell
topic: synthesis
round: 1
date: 2026-07-05T00:49:27Z
---
**Findings**
- **High:** exported permutation/group APIs are partial and do not enforce invariants. [Gauge.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Gauge.hs:57) uses `!!` in `composePerm`, [Gauge.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Gauge.hs:77) uses `!!` in `applyPerm`, and [Gauge.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Gauge.hs:81) exports `Group(..)`, so callers can construct invalid groups that crash or make proofs meaningless. Fix: hide constructors, add `mkPerm`/`mkGroup` validators requiring length `n`, image set `[0..n-1]`, `n > 0`, identity, closure, and preferably expose total `applyPerm :: Perm -> Int -> Maybe Int`.

- **High:** negative code parameters can be accepted as valid because negative exponents are silently clamped. [Closure.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Closure.hs:85) defines `pow e = 2 ^ max 0 e`; [Closure.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Closure.hs:97) then validates equations without checking `nPhys`, `kLog`, `gGauge`, `rStab >= 0`. Example shape: `CodeParams (-1) 0 0 (-1)` can satisfy the formulas with fake dimensions. Fix: use `Natural`/`Word` for counts or reject negatives before computing dimensions; remove `max 0`.

- **High:** negative genus is not ruled out, which makes topological and QEC claims unsound. [Homology.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Homology.hs:141) builds dimensions `[1, 2*g, 1]` for any `Int`; [Homology.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Homology.hs:190) can then evaluate `2 ^ h1Rank g` with a negative exponent. Fix: represent genus as `Natural`, or make `genusSurface`, `h1Rank`, and `surfaceCodeLogicalDim` return `Maybe`/`Either` for invalid input.

- **Medium:** GF(2) matrix code is partial or silently dimension-truncating on malformed matrices. [Homology.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Homology.hs:62) indexes rows with `r !! c`; [Homology.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Homology.hs:71) multiplies via `transpose`/`zipWith`, which can silently ignore mismatched dimensions. Fix: validate rectangular matrices and compatible dimensions, or encode `Mat rows cols` with a validated constructor.

- **Medium:** QuickCheck generators avoid the dangerous input space, so key safety properties are not actually tested. [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Properties.hs:97), [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Properties.hs:121), and [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Properties.hs:128) only generate positive group sizes, nonnegative genus, and well-formed code parameters. Fix: add explicit invalid-input properties for constructors/validators, or change the production types so invalid states are unrepresentable.

- **Medium:** the “equational proofs” are mostly worked-example checks, not general proof obligations. For example [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Proofs.hs:70), [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Proofs.hs:86), [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Proofs.hs:100), and [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Proofs.hs:115) verify one concrete case. Fix: rename these as examples/smoke checks, or back them with QuickCheck/general lemmas over validated domains.

- **Low:** gauge/QEC factorization swaps semantic names even though multiplication hides it. [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Proofs.hs:153) and [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Properties.hs:318) pass `sectors` as `content` and `logDim * gaugeDim` as `redundancy`, while [Closure.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Closure.hs:36) documents `content * redundancy`. Fix: call `redundancyFactorization (physDim s) (logDim s * gaugeDim s) (sectors s)` or rename the arguments to avoid semantic drift.

- **Low:** coverage around chain complexes is mostly fixtures, not arbitrary validated complexes. [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Properties.hs:289) checks only `genusSurface` and `filledTriangle`; it does not exercise arbitrary valid boundary maps, malformed dimensions, or nonzero `d1/d2` combinations beyond one fixture. Fix: add a `ValidChainComplex` generator with rectangular matrices and `d . d = 0`, plus negative tests for invalid complexes.

Verification note: the checked-in `src/synthesis/synth_test` binary passes all 9 proof checks and 28 QuickCheck properties. A fresh `ghc` build did not complete in this environment because GHC emitted x86-style assembly rejected by the ARM assembler, so I did not treat that as a source-code failure.

VERDICT: NEEDS_FIX
