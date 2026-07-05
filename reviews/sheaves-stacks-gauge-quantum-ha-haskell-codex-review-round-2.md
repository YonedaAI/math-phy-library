---
reviewer: codex (OpenAI)
type: haskell
topic: sheaves-stacks-gauge-quantum-ha
round: 2
model: gpt-5.5 (model_reasoning_effort=xhigh)
date: 2026-07-04T21:55:00Z
---

**Findings**

- **High:** `Properties.hs` reportedly does not typecheck from source under Codex's
  invocation: both `runProp` helpers call `isSuccess`, claimed "Variable not in
  scope: isSuccess :: Result -> Bool". (Investigated locally: `Test.QuickCheck`
  in the installed QuickCheck DOES export `isSuccess`; the canonical build
  `ghc -Wall -Wextra -Werror ... -package QuickCheck` and even a forced
  `-fforce-recomp -fno-code` compile succeed and the suite runs. Root cause is a
  QuickCheck-resolution difference in Codex's ad hoc compile command, not the
  source. An explanatory comment was added on the import.)

- **Medium:** T2 coverage still weak: only the well-formedness guard, a
  single-piece cover, and separatedness were tested; `Main.hs` still demonstrated
  the constant presheaf on the disjoint cover `[[1],[2]]` as a sheaf, which under
  the empty-overlap semantics is questionable — a genuine non-gluing example was
  missing.

- **Medium:** Stabilizer properties did not validate independence/commutation:
  `prop_stabilizerHalving` passed on arbitrary generator lists because
  `codeSpaceDim` only counts generators. Raw `[Int]` Paulis / `Int` qubit counts
  remain unenforced API states.

- **Low:** QHA invalid-input hardening only covered `dimLogical <= 0`;
  `subsystemDim` still accepted negative gauge/error dimensions and could produce
  negative availability.

What was fixed by round 2: Pauli length truncation (zero-extension), `codeSpaceDim`
over-specified crash (clamp), `orbifoldEulerChar` empty group, Hopf
right-antipode/coassociativity/counit checks, honest Proofs wording, planar vs.
non-planar rooted-tree documentation.

VERDICT: NEEDS_FIX
