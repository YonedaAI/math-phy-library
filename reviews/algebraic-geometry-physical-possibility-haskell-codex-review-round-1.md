---
reviewer: codex (OpenAI, gpt-5.5, model_reasoning_effort=xhigh)
type: haskell
topic: algebraic-geometry-physical-possibility
round: 1
date: 2026-07-04T22:03:07Z
---

**Findings**

- High: `PositiveGeometry.hs:25-28` says 0-dimensional forms have no poles, but `interval` endpoints at `PositiveGeometry.hs:84-85` and `simplex` leaves from `PositiveGeometry.hs:99-101` still have poles. `residueTree` at `PositiveGeometry.hs:64-66` also just copies child forms instead of checking residues. Fix: make point forms `DiffForm [] ±1`, store facet labels on boundary edges, and test every edge satisfies `childForm == residueAt facet parentForm`.

- High: `QuotientStack.hs:27-31` does not encode group laws, closure, identities, inverses, or duplicate-free elements. Since `mkQuotientStack` defines `autGroup = stabilizer` at `QuotientStack.hs:58-62`, `prop_autEqualsStabilizer` in `Properties.hs:177-186` and `proof_autEqualsStabilizer` in `Proofs.hs:90-100` are tautological. Fix: add a lawful finite-group/action constructor and test stack automorphisms independently from `stabilizer`.

- High: The Gauss-Manin/Picard-Fuchs checks are mostly algebraic self-checks. `legendreVHS` builds the companion matrix from `picardFuchsLegendre` at `Hodge.hs:78-93`, and `Properties.hs:246-256` checks the cancellation caused by that construction, not that transported periods satisfy the ODE. `griffithsOK` is just a stored Boolean at `Hodge.hs:49-52`. Fix: validate matrix dimensions, reject invalid step counts in `transportPeriod`, compute transversality, and add finite-difference PF residual checks for transported solutions.

- Medium: `DerivedCritical.hs:47-50` treats `length generators` as dimension, even when relations exist. `hasGhosts` at `DerivedCritical.hs:92-96` is false by construction, so `Properties.hs:329-334` is largely vacuous. There is no Koszul differential or homology computation, so `classicalCrit` only appends equations. Fix: store smooth dimension explicitly, model the Koszul differential, and test `H^0` against `R/(dS)` on concrete examples.

- Medium: `Scheme.hs:34` permits invalid polynomials: negative exponents, duplicate variables, and variables outside the ring. `Properties.hs:129-135` even generates ideal variables not in the ring. Also, `Properties.hs:356-357` compares relations via `show` because core types lack `Eq`. Fix: derive `Eq`/`Ord`, normalize monomials, and add smart constructors that reject malformed polynomials.

- Medium: `Proofs.hs` is executable example checking, not sound equational proof. For example, `Proofs.hs:183-194`, `Proofs.hs:208-212`, and `Proofs.hs:226-232` use fixed values while the comments state universal results. Fix: rename these as checks or parameterize them as laws with explicit preconditions.

Verification: the target modules typecheck with `-Wall -Wextra -Werror`; QuickCheck reports `20 / 20` passing; `Main` reports `8 / 8` proof checks passing. Passing here shows internal consistency, but several properties are tautological or too weak for the paper claims.

VERDICT: NEEDS_FIX