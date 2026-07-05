---
reviewer: codex (OpenAI)
type: haskell
topic: motives-periods-amplitudes
round: 1
model: gpt-5.5 (model_reasoning_effort=xhigh)
date: 2026-07-04T21:38:46Z
---
**Findings**

1. [Coalgebra.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Coalgebra.hs:58): the cobracket is represented as an unnormalized signed list, but the comments/proofs treat it as an exterior-algebra value in `Lambda^2`. For repeated letters, `cobracket (Word' ['a','a'])` returns two cancelling terms rather than zero. This makes the executable proof of antisymmetry in [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Proofs.hs:144) too weak: it proves the construction is symmetric under swap/negate, not that the result is sound in the exterior quotient.

2. [Period.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Period.hs:39): `kummerLog :: Double -> PeriodDatum` accepts invalid inputs. `kummerLog (-1)` produces `NaN`, and `checkMultiplicative (kummerLog (-1)) (kummerLog 2)` returns `False`. The type should encode positive finite inputs or return `Maybe`/`Either`; QuickCheck currently avoids this by generating arbitrary `PeriodDatum` values directly in [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Properties.hs:68).

3. [Amplitude.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Amplitude.hs:24): `MotivicAmplitude(..)` exports a constructor with unconstrained `amDepth :: Int`, so negative or inconsistent depths are valid values. I confirmed `MotivicAmplitude (Word' ['a','b','c']) (-7)` is accepted. Use `Natural` plus a smart constructor, or compute depth from `amWord`, and add properties covering this type.

4. [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Properties.hs:127): several QuickCheck properties are mostly definitional restatements. `prop_cobracketAntisym`, `prop_discDefinition`, and the period multiplicativity/additivity properties largely mirror the implementation. They are useful regression checks, but they do not cover the invalid states above or prove the intended algebraic quotient semantics.

5. [Main.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Main.hs:41): demo `check` failures only print `[FAIL]`; they do not affect the process exit code. `Main` exits nonzero only if `runAllProofs` fails. Accumulate all demo checks into the final status.

Verification run: `./src/motives-periods-amplitudes/props` passed 22/22, `./src/motives-periods-amplitudes/test` passed 60/60, and both `Main.hs` and `Properties.hs` compile cleanly with `ghc -Wall -Wcompat -Werror -fforce-recomp -fno-code`.

VERDICT: NEEDS_FIX
