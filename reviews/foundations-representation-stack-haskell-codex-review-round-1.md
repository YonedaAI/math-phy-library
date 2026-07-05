---
reviewer: codex (OpenAI)
type: haskell
topic: foundations-representation-stack
round: 1
model: gpt-5.5 (reasoning effort high)
date: 2026-07-04T21:46:34Z
---

**Findings**

- High: [RepStack.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/RepStack.hs:92) permits invalid entries such as `SpeculativeMap ...` with `status = Std`, and [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Properties.hs:115) generates exactly that kind of entry. This breaks the paper’s “strength of tau is what sigma records” discipline. Fix by hiding `RepEntry(..)` behind `mkRepEntry`, enforcing `candidateStatus translation <= assignedStatus`, or normalizing with `assigned <> candidateStatus translation`; update generators to produce only valid entries.

- High: [RepStack.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/RepStack.hs:120) composes entries by type only, ignoring the theorem premise that `P1 = M2`. [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Properties.hs:223) then tests status laws over random, semantically non-composable entries. Fix with `composeEntryChecked :: Eq b => RepEntry b c -> RepEntry a b -> Maybe (RepEntry a c)` or composable-entry generators that set `mathStruct e2 = physRep e1`.

- High: pipeline functoriality is not faithfully encoded. [Pipeline.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Pipeline.hs:57) checks `runPipeline` against its own definition, and [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Properties.hs:271) only proves object-level composition, not identity/composition preservation on morphisms. [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Properties.hs:280) similarly checks a definitional post-composition, not naturality of `theta : Real_alpha => Real_beta`; it also never changes or uses `channel`. Fix by either representing functors with object and morphism maps plus laws, or renaming these as object-composite smoke tests and adding separate morphism-level properties.

- High: the coarse-quotient obstruction tests do not encode the numbered theorem. [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Properties.hs:341) and [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Proofs.hs:231) show orbit collapse under a toy `Z/2` action, but the theorem is a descent/sheaf failure via nontrivial automorphism torsors. Add a toy Cech cocycle/descent model showing local classes agree but global gluing is non-unique, or relabel the current checks as the weaker “coarse quotient forgets gauge data” corollary.

- Medium: [Properties.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Properties.hs:349) is false for `minBound :: Int`: `negate minBound == minBound`, so `Config n /= gauge (Config n)` can fail with `n /= 0`. QuickCheck may miss it. Fix by using `Integer`, `NonZero Integer`, or adding `n /= minBound` to the precondition.

- Medium: [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Proofs.hs:70) through [Proofs.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Proofs.hs:138) are sound as concrete checks, but overclaim as equational proofs of the general results. They omit status associativity/commutativity/right unit, enumerate only one translation-strength case, and check one composition-status case. Fix by enumerating all three statuses, all 16 translation-strength pairs, and all status pairs/triples, or rename these as executable examples.

- Medium: natural translations are under-modeled. The paper gives candidate status `S/H`, but [RepStack.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/RepStack.hs:37) always maps `NaturalTranslation` to `Std`. Fix with `NaturalTranslation Status (m -> p)` constrained to `Std` or `Heur`, or split constructors such as `NaturalStd` and `NaturalHeur`.

- Low: comments say “meet” where the implementation and theorem use join: [RepStack.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/RepStack.hs:6), [Pipeline.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Pipeline.hs:5), and [Main.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Main.hs:13). Replace “meet” with “join”.

- Low: [Status.hs](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Status.hs:27) relies on derived constructor order for the semantic reliability order. That is compact, but brittle. Prefer an explicit `rank` case split and define comparisons/join through it if this is meant as a durable formal encoding.

I did not rebuild or run tests, per instruction.

VERDICT: NEEDS_FIX
