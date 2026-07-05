---
reviewer: codex (OpenAI)
type: haskell
topic: motives-periods-amplitudes
round: 3
model: gpt-5.5 (model_reasoning_effort=xhigh)
date: 2026-07-04T21:53:38Z
---
Findings: none blocking.

Round-2 fixes hold on re-review. `isFinitePeriod` now documents the `Double` overflow limitation correctly in [Period.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Period.hs:63), and the exterior cobracket is no longer vacuously satisfiable: [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Properties.hs:177) compares against `referenceExterior`, while [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Properties.hs:183) checks the `ab`/`ba` sign cases explicitly.

Type safety looks acceptable for the model scope: `Natural` removes negative amplitude depth, and `mkKummerLog` gives a total validated constructor while leaving raw `kummerLog` as a documented precondition API. Proof coverage is still executable/finite, not machine proof, but the statements are now honest about that and the added exterior checks cover the prior semantic gap.

Verification run:
- `ghc -Wall -Wextra -Werror ... Main.hs`: passed
- `ghc -Wall -Wextra -Werror -main-is Properties ... Properties.hs`: passed
- `tmp/mpa-haskell-final/mpa-main`: passed, including `80/80` proof checks
- `tmp/mpa-haskell-final/mpa-props`: passed, `30/30` QuickCheck properties

Minor non-blocking nit: [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/motives-periods-amplitudes/Properties.hs:175) says `strict-Map accumulation`, but `referenceExterior` is list/`nub` based. This is stale prose only.

VERDICT: PASS
