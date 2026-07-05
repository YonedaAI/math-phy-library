---
reviewer: codex (OpenAI)
type: haskell
topic: algebraic-topology-conserved-information
round: 2
model: gpt-5.5 (reasoning_effort=xhigh)
date: 2026-07-04T22:15:37Z
---
**Findings**
- **High:** [ChainComplex.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/ChainComplex.hs:132) still lets `dSquaredIsZero` certify malformed complexes when the bad matrices happen to be conformable. It does not gate on [wellFormed](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/ChainComplex.hs:109), and [bettiNumbers](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/ChainComplex.hs:184) computes anyway. Repro: `ChainComplex [2,2,2] [[[0]], [[0]]]` gives `(wellFormed, dSquaredIsZero, bettiNumbers) == (False, True, [2,2,2])`.

- **Medium:** [wellFormed](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/ChainComplex.hs:109) does not reject negative dimensions. `ChainComplex [-1] []` is considered well-formed and yields Betti `[-1]`.

- **Medium:** Public raw constructors still bypass the new domain guards. [FrobeniusAlgebra(..)](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/TQFT.hs:86) lets a zero-dimensional algebra pass `frobeniusLawsHold`; [FiniteGroup(..)](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/TQFT.hs:173) allows `elements = []`, producing `NaN` in DW sums; [Surface(..)](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/CharacteristicClass.hs:53) accepts negative genus.

- **Medium:** [frobeniusFormNondegenerate](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/TQFT.hs:144) rounds `Double` Gram entries to `Int` before exact rank. That is sound for the integer-valued `groupAlgebraZn` case, but the exported signature claims a general `FrobeniusAlgebra -> Bool`.

**Verification**
Passed:
- `ghc -Wall -Wextra -Werror ... Main.hs`
- `ghc -Wall -Wextra -Werror -fno-code ... Properties.hs`
- `tmp/atci-hs-review/atci-main`
- `Properties.runAllProperties`

The current tests pass, but they miss the malformed conformable-complex and raw-constructor invalid-domain cases above.

VERDICT: NEEDS_FIX
