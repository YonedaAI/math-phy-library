---
reviewer: codex (OpenAI)
model: gpt-5.5 (reasoning=high)
type: haskell
topic: synthesis
round: 2
date: 2026-07-05T01:01:24Z
---
**Findings**

- **High:** Fresh source compile fails: [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Properties.hs:452) calls `isSuccess`, but this QuickCheck install does not export it from `Test.QuickCheck`. Fix by importing `qualified Test.QuickCheck.Test as QCT` and using `QCT.isSuccess r`, or pattern-match on `Success`.

- **High:** `Group` construction is hidden, but the exported builders are not actually validated. [Gauge.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Gauge.hs:96), [Gauge.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Gauge.hs:100), and [Gauge.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Gauge.hs:108) accept invalid degrees/generators; [Gauge.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Gauge.hs:64) and [Gauge.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Gauge.hs:78) still use partial indexing. Fix with validated `mkPerm`/`mkGroup` constructors requiring length `n`, image set `[0..n-1]`, identity, closure, and valid generators before closure.

- **Medium:** Chain complexes and matrices remain structurally unsafe. [Homology.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Homology.hs:23) exports `ChainComplex(..)`, [Homology.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Homology.hs:63) indexes ragged rows with `!!`, and [Homology.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Homology.hs:72) silently truncates incompatible dimensions via `zipWith`/`transpose`. Fix by hiding raw constructors and adding validated rectangular `Mat` plus `mkChainComplex` shape checks; make incompatible multiplication return `Maybe`/`Either`.

- **Medium:** `Natural` removed negative genus/counts, but large genus can still overflow through `Int`. [Homology.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Homology.hs:151), [Homology.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Homology.hs:189), and [Closure.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Closure.hs:113) convert between `Natural` and `Int`. Fix `h1Rank :: Natural -> Natural`, compute `surfaceCodeLogicalDim g = 2 ^ (2*g)`, and only convert to `Int` through checked bounds when allocating matrices.

- **Medium:** `CodeParams(..)` is still exported, so invalid nonnegative parameter sets can produce nonsensical negative `errDim` before validation. See [Closure.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Closure.hs:23) and [Closure.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Closure.hs:80). Fix by hiding the constructor and exposing `mkCodeParams` enforcing `n = k + g + r`, or make `subsystemDims` return `Maybe Subsystem`.

- **Medium:** QuickCheck coverage still avoids important failure space. `ActionCase` only generates valid small groups at [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Properties.hs:99), and `ValidComplex` forces `d2 = 0` at [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Properties.hs:150), making [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Properties.hs:326) mostly tautological. Add invalid-builder rejection properties and generate nonzero `d2` from `ker d1` to test real `d1 . d2 = 0`.

- **Low:** Equational “proof” checks are still mostly worked examples. [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Proofs.hs:5) frames them as proofs, but e.g. [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Proofs.hs:141) and [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/synthesis/Proofs.hs:158) are single-instance executable checks. Fix wording to “worked proof checks” or tie each proof block directly to a named general property.

Verification: `./synth_test` passes 9/9 proof checks and 30/30 properties, but fresh `ghc -Wall -Wextra -Werror -fno-code *.hs -package QuickCheck` fails on `isSuccess`, so the checked-in binary is not enough.

VERDICT: NEEDS_FIX
