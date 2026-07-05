---
reviewer: codex (OpenAI)
type: haskell
topic: motives-periods-amplitudes
round: 2
model: gpt-5.5 (model_reasoning_effort=xhigh)
date: 2026-07-04T21:47:55Z
---
**Findings**

- Medium: [Period.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Period.hs:63) overclaims finiteness closure. `tensorDatum`/`directSumDatum` can overflow finite `Double` inputs to `Infinity`, and then `checkMultiplicative`/`checkAdditive` return `False` because `Infinity - Infinity` becomes `NaN`. I confirmed with `1e308`: finite inputs produced an infinite tensor/direct sum. The bounded QuickCheck generator in `Properties.hs` masks this.

- Medium: [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Properties.hs:157) and [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Proofs.hs:177) do not prove/test `cobracketExterior` semantics strongly enough. The canonical property and executable proof would both pass for `cobracketExterior = const []`; only fixed repeated-letter cancellations are asserted. Add a property comparing against a reference normalization of `cobracket`/`reducedCoproduct`, plus explicit nonzero cases like `"ab"` and `"ba"`.

Type-safety improvements for `Natural` depth and `mkKummerLog` look sound within their stated scope. `Main` correctly folds demo/proof checks into exit status.

Verification run:
- `ghc -Wall ... Main.hs` passed.
- `/tmp/mpa-main` passed, including `70/70` proof checks.
- `ghc -Wall -main-is Properties ... Properties.hs` passed.
- `/tmp/mpa-props` passed, including `28/28` QuickCheck properties.

VERDICT: NEEDS_FIX
