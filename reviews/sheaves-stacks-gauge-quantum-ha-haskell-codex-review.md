---
reviewer: codex (OpenAI)
type: haskell
topic: sheaves-stacks-gauge-quantum-ha
round: 3
model: gpt-5.5 (model_reasoning_effort=xhigh)
date: 2026-07-04T22:05:00Z
note: 3rd Codex invocation -- the 2-fix-pass / 3-invocation cap. The findings
      below were nonetheless resolved locally after this review; no 4th Codex
      round was run (cap reached). See "Post-review resolution".
---

**Findings**

- **High:** `QHA.hs` `subsystemDim`/`availability` could still return negative
  values via `Int` overflow. Probe: `dimLogical=maxBound`, `dimGauge=2`,
  `dimError=0` returned `subsystemDim = -2` and negative `availability`. The
  clamp handled negative inputs, but not overflow after multiplication. Use
  `Integer` dimensions or checked/saturating arithmetic.

- **Medium:** `prop_stabilizerHalving` still tested halving over arbitrary
  `CodeGen` generators, not `indepCode`. A noncommuting code returns
  `surfaceCodeCommuting = False` while the halving property still evaluated
  `True`, a property-soundness gap.

- **Medium:** `Sheaf.hs` `compatible` checked family length and overlap
  agreement, but not that each local value belongs to `sections pf piece`. For
  `constantPresheaf ["a","b"]`, `compatible pf cov ["z","z"]` returned `True`, so
  out-of-domain data could make a sheaf appear non-gluing.

**Verified by Codex**

- Exact requested build command passed with `-Wall -Wextra -Werror`.
- `props` completed with `properties: 33/33 passed`.
- `Main.hs` builds with `-Wall -Wextra -Werror`; demo prints the `[B,B]` gappy
  non-sheaf case and `9/9` equational proof checks pass.
- The gappy non-sheaf regression is real and covered; the negative-input QHA
  clamp is present but was incomplete because of overflow.

VERDICT: NEEDS_FIX

---

## Post-review resolution (applied after the 3-invocation cap; no further Codex round)

All three round-3 findings were fixed and re-verified locally:

1. **QHA overflow (High).** `dimLogical/dimGauge/dimError` and `subsystemDim`
   were changed from `Int` to unbounded `Integer` in `QHA.hs`, so no
   fixed-width wraparound is possible; each factor is still clamped at 0. Added
   `prop_subsystemNoOverflow` reproducing the exact `maxBound` probe: it asserts
   `subsystemDim (mkEncoding maxBound 2 0) = 2*maxBound > 0`. PASS.

2. **Stabilizer halving (Medium).** `prop_stabilizerHalving` now ranges over
   `IndepCode` (the genuinely independent, pairwise-commuting single-qubit
   `Z_0..Z_{r-1}` code) and asserts `surfaceCodeCommuting c === True` alongside
   `dim(code)*2^r = 2^n`, so halving is tied to a validated code. PASS.

3. **Sheaf admissibility (Medium).** `compatible` in `Sheaf.hs` now also requires
   each local value to be an admissible section (`s \`elem\` sections pf piece`).
   Added `prop_inadmissibleValueRejected`: `compatible constPf twoCover ["z","z"]
   === False`. PASS.

Final local verification after these fixes:
- `ghc -Wall -Wextra -Werror` clean for Main+Proofs and for Properties (with
  `-package QuickCheck`); zero warnings.
- QuickCheck: 34/34 properties pass (100+ cases each; antipode axioms at 1000).
- Equational proofs: 9/9 pass via `Main`, which exits 0.
