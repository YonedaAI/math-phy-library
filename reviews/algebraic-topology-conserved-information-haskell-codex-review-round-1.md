---
reviewer: codex (OpenAI)
type: haskell
topic: algebraic-topology-conserved-information
round: 1
model: gpt-5.5 (reasoning_effort=xhigh)
date: 2026-07-04T21:47:37Z
---
**Findings**
- **High:** `dSquaredIsZero` can certify malformed complexes because `matMul` silently truncates mismatched dimensions with `zipWith`. See [ChainComplex.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/ChainComplex.hs:68) and [ChainComplex.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/ChainComplex.hs:82). Repro: `ChainComplex [1,2,1] [[[0]], [[1],[1]]]` returns `True` even though `d1` has the wrong shape.

- **High:** `rankQ` claims rational rank but computes through `Double`, so large integer matrices can get the wrong rank. See [ChainComplex.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/ChainComplex.hs:93). Repro: `rankQ [[9007199254740992,9007199254740992],[9007199254740993,9007199254740992]]` returns `1`, but the exact rational rank is `2`.

- **High:** The Frobenius/TQFT checks are not sound as stated. `frobeniusLawsHold` checks only assoc/comm/unit and ignores the Frobenius compatibility law and nondegenerate counit; `partitionSurface` ignores `faMul`, `faUnit`, and `faCounit` entirely. See [TQFT.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/TQFT.hs:131) and [TQFT.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/TQFT.hs:141). A degenerate counit can still pass the advertised “Frobenius laws”.

- **Medium:** Several public constructors accept invalid mathematical domains that tests mask: `groupAlgebraZn 0` has vacuous unit laws, `zmod 0` produces `NaN` DW values, `partitionSurface` accepts negative genus, and `Surface (-1)` is allowed. See [TQFT.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/TQFT.hs:101), [TQFT.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/TQFT.hs:155), and [CharacteristicClass.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/CharacteristicClass.hs:53).

- **Medium:** The `Double` amplitude monoidality properties are false over the stated input type because of overflow, `NaN`, and floating non-associativity. See [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/Properties.hs:219). Example: `1e308, 1e308, 0` breaks associativity.

- **Medium:** The equational “proof” module is mostly finite executable spot checks, not proof evidence. For example, `proof_boundarySquared` checks only two simplices and `proof_eulerPoincare` checks only torus/sphere instances. See [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/algebraic-topology-conserved-information/Proofs.hs:13).

**Coverage Gaps**
Missing tests for matrix shape validation, exact rank against an independent oracle, arbitrary chains with coefficients, duplicate/unsorted simplex inputs, invalid domain rejection, real Frobenius compatibility/nondegeneracy, and nonabelian DW cases beyond hard-coded `S3`.

**Verification**
I ran fresh source checks, not just the existing binaries:

- `ghc -Wall -fforce-recomp -fno-code ... Main.hs`
- `ghc -Wall -fforce-recomp -fno-code ... Properties.hs`
- freshly compiled `Properties.runAllProperties`: passed
- freshly compiled `Main`: proof/demo checks passed

The current checks pass, but they do not establish the advertised safety/proof claims.

VERDICT: NEEDS_FIX
