---
reviewer: codex (OpenAI, gpt-5.5, model_reasoning_effort=xhigh)
type: haskell
topic: algebraic-geometry-physical-possibility
round: 2
date: 2026-07-04T23:22:51Z
---

Findings:

- `src/algebraic-geometry-physical-possibility/PositiveGeometry.hs:101`: `residueAxiomHolds` exempts point strata, so terminal residues are never checked. For `interval`, `residueAt "a" (DiffForm ["a","b"] 1)` yields `DiffForm ["b"] 1`, not the vertex 0-form at `PositiveGeometry.hs:123`. Fix by making `residueAt` model boundary restriction correctly through dimension drops, then require equality on every boundary edge, including vertices.

- `src/algebraic-geometry-physical-possibility/Hodge.hs:60`: `griffithsAt` is mostly a shape check. `all ((== r) . length) images` only proves matrix-vector multiplication returned length `rank`; it does not prove `nabla F^p subset F^{p-1}`. Fix with dimension checks for vectors/matrices and an actual subspace-membership test against `F^{p-1}`.

- `src/algebraic-geometry-physical-possibility/Properties.hs:316`: `prop_transportSolvesODE` does not check the Picard-Fuchs ODE. It only compares the finite difference of the first component with the stored second component, so a broken second row of the companion system can still pass. Fix by checking `c2*f'' + c1*f' + c0*f ~= 0` from finite differences, or by checking both components against `A(s)v`.

- `src/algebraic-geometry-physical-possibility/QuotientStack.hs:52`: `isGroup` accepts vacuous or malformed carriers because it does not require non-empty, duplicate-free `gElems`, `gUnit elem gElems`, or `gInv a elem gElems`. `isAction` at `QuotientStack.hs:68` also does not require `elements ga` to match the group carrier used for the laws. Add those checks, and require stabilizers to be subsets of the checked carrier.

- `src/algebraic-geometry-physical-possibility/Scheme.hs:107`: `wellFormedIdeal` can return `True` over an ill-formed ring because it does not include `wellFormedRing r`. The property at `Properties.hs:197` only tests valid generated examples, so the validators are not proven to reject malformed inputs. Add negative QuickCheck cases for duplicate generators, out-of-ring variables, duplicate monomial variables, and negative exponents.

- `src/algebraic-geometry-physical-possibility/DerivedCritical.hs:62`: `mkDerivedCritical` accepts negative `smoothDim`, and `ghostDegrees` at `DerivedCritical.hs:113` accepts negative gauge dimensions. Those invalid states silently produce empty complexes. Use a smart constructor returning `Either`/`Maybe`, or a non-negative dimension type, and add coverage for rejection.

- `src/algebraic-geometry-physical-possibility/Proofs.hs:188`: the equational proof checks are executable examples, not proofs of the universal comments. The residue proof is the most serious: it checks only non-terminal `simplex 2` facets and only that interval vertices have no poles. Either weaken the wording to “representative checks” or strengthen the checks to quantify over the constructed finite geometries after fixing the residue invariant.

I verified the target code compiles with `-Wall -Wextra -Werror`, and the current property/proof runners pass, but several passing checks are too weak or self-fulfilling for the claimed invariants.

VERDICT: NEEDS_FIX