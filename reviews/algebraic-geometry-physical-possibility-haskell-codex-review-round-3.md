---
reviewer: codex (OpenAI, gpt-5.5, model_reasoning_effort=xhigh)
type: haskell
topic: algebraic-geometry-physical-possibility
round: 3
date: 2026-07-04T23:37:44Z
note: 2-pass Codex cap reached (3rd invocation); further safe hardening applied post-review and re-verified by compilation + full test run.
---

**Findings**
- High: [Properties.hs:512](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-geometry-physical-possibility/Properties.hs:512) and [Properties.hs:519](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-geometry-physical-possibility/Properties.hs:519) do not typecheck with the local QuickCheck API: `isSuccess` is not in scope. Fix by pattern matching on `Success{}` or importing a compatible helper explicitly.
- High: [QuotientStack.hs:74](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-geometry-physical-possibility/QuotientStack.hs:74) still accepts malformed actions. It does not require `isGroup gs`, duplicate-free `elements ga`, action closure `act ga g x elem points ga`, or duplicate-free point carriers. [QuotientStack.hs:87](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-geometry-physical-possibility/QuotientStack.hs:87) also proves subgroup status without first requiring a valid group action. Add those guards and negative QuickCheck cases.
- Medium: [Hodge.hs:89](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-geometry-physical-possibility/Hodge.hs:89) is weaker than the comment claims. It checks decreasing filtration by row counts, does not require `rank f0 == r`, does not validate the connection matrix is `r x r`, and maps all positive filtration levels into `F^0` instead of checking each `F^p -> F^(p-1)`. Use pairwise rank/span checks.
- Medium: [DerivedCritical.hs:26](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-geometry-physical-possibility/DerivedCritical.hs:26) exports `DerivedCritical(..)` and [DerivedCritical.hs:70](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-geometry-physical-possibility/DerivedCritical.hs:70) exports the unsafe constructor path, so negative dimensions remain constructible despite `mkDerivedCriticalSafe`. Hide the constructor/unsafe builder or use a non-negative type for `smoothDim`.
- Medium: [PositiveGeometry.hs:78](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-geometry-physical-possibility/PositiveGeometry.hs:78) removes all copies of a pole, while the model documents simple poles. Either reject duplicate pole labels before `fromForm` or represent multiplicity intentionally and remove one occurrence per residue.
- Low: [Proofs.hs:208](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-geometry-physical-possibility/Proofs.hs:208) checks Picard-Fuchs at `lambda = 0.5`, where `c1 = 0`, so the executable proof misses the nonzero `f'` coefficient path. Use a nonsymmetric value such as `0.4`, or check multiple base points.

Existing `./props` and `./test` binaries pass, but fresh source typechecking of `Properties.hs` fails on the `isSuccess` issue. `Main.hs`/`Proofs.hs` typecheck cleanly with `-fno-code -Wall -Wextra -Werror`.

VERDICT: NEEDS_FIX