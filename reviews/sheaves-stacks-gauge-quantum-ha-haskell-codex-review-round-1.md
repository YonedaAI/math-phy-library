---
reviewer: codex (OpenAI)
type: haskell
topic: sheaves-stacks-gauge-quantum-ha
round: 1
model: gpt-5.5 (model_reasoning_effort=xhigh)
command: codex exec -m gpt-5.5 -c 'model_reasoning_effort="xhigh"' "Review Haskell in src/sheaves-stacks-gauge-quantum-ha/ ..."
date: 2026-07-04T21:38:46Z
---

**Findings**

- **High:** T2 sheaf gluing is unsound. `Sheaf.hs:67` zips overlaps with
  local-section pairs, and `Sheaf.hs:84` uses `zipWith`, so missing or extra
  local sections are silently ignored. In GHCi, `glues pf (Cover [[1],[2]]) [[]]`
  and `isSheafFor ... [[]]` both returned `True`. The demo in `Main.hs:65` also
  claims a constant presheaf glues over a disjoint cover, but mixed local values
  should be compatible over an empty overlap and should not glue to one constant
  global section.

- **High:** Stabilizer invariants are not type-safe. `Stabilizer.hs:33`
  represents Pauli bit vectors as raw `[Int]`, and `Stabilizer.hs:37` truncates
  mismatched lengths via `zipWith`. `Stabilizer.hs:53` allows `k < 0`;
  `codeSpaceDim (StabilizerCode 1 [..two generators..])` throws `Negative
  exponent`. QuickCheck avoids this by construction rather than making the API
  safe.

- **Medium:** QHA and stack APIs export invalid states that crash or produce
  nonsensical values. `QHA.hs:33` allows zero/negative dimensions; `availability`
  with `dimLogical = 0` returned `NaN`. `Stack.hs:34` does not enforce nonempty
  unique group elements or identity/group laws; `orbifoldEulerChar` with an empty
  element list throws `Ratio has zero denominator`.

- **Medium:** Several QuickCheck properties are mostly tautological or under-cover
  the claimed math. `Properties.hs:239` checks `codeSpaceDim c === 2 ^
  numLogicalQubits c`, which is just the implementation. `Properties.hs:224`
  compares functions both defined as `2 * g`. There are no T2/sheaf properties,
  no invalid-input properties, and Hopf coverage omits coassociativity, counit
  laws, and right antipode.

- **Medium:** The "proof" module overstates what is verified. `Proofs.hs:5`
  describes executable equational proofs, but checks such as `Proofs.hs:122`,
  `Proofs.hs:214`, and `Proofs.hs:253` are finite examples or restatements of the
  same implementation, not independent machine-checked proofs of the general
  theorems.

- **Low:** The Hopf tree representation likely models ordered rooted trees despite
  comments implying commutative forests. `Hopf.hs:28` derives `Eq/Ord` over
  child-list order; if Connes-Kreimer non-planar rooted trees are intended,
  children should be canonicalized or the planar variant should be documented.

Verification run: `ghc -v0 -fforce-recomp -fno-code Main.hs` and `Properties.hs`
both passed; existing `./test` reported 9/9 proof checks passed; existing
`./props` reported 16/16 QuickCheck properties passed. `hlint` is not installed.
The passing tests do not cover the defects above.

VERDICT: NEEDS_FIX
