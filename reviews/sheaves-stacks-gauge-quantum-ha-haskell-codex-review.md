---
reviewer: codex (OpenAI)
type: haskell
topic: sheaves-stacks-gauge-quantum-ha
round: final (re-review after post-cap fixes)
model: gpt-5.5 (model_reasoning_effort=high)
date: 2026-07-04T00:00:00Z
note: Confirmation re-review run after the earlier 3-invocation cap. The prior
      cap-round findings (Int overflow -> Integer; unsound sheaf gluing ->
      length- and admissibility-guarded compatibility; negative-exponent clamp;
      IndepCode validity for the halving law) were fixed and are here confirmed
      resolved. Verdict token now reflects the actual (fixed) state.
---

**Findings**

None. Codex confirmed the prior cap-round issues are resolved in the current
source.

The fixes are present and covered:

- QHA dimensions are now `Integer`, with clamping before multiplication in
  `QHA.hs:33` (`subsystemDim`/`availability`); the `maxBound` overflow
  regression is tested by `prop_subsystemNoOverflow` in `Properties.hs:590`.
- Sheaf compatibility is length-guarded and rejects inadmissible local values in
  `Sheaf.hs:81` (`compatible` requires `wellFormedFamily` and each local value
  `elem` `sections pf piece`); wrong-length, gappy non-gluing, and junk-section
  regressions are covered by `prop_wrongLengthNotCompatible`,
  `prop_gappyNotSheaf`, and `prop_inadmissibleValueRejected`.
- Stabilizer negative exponents are clamped in `Stabilizer.hs:64`
  (`numLogicalQubits = max 0 (n - #generators)`), with over-specified-code
  coverage in `prop_codeSpaceDimClamped` (`Properties.hs:423`).
- The halving law now ranges over validated independent, pairwise-commuting
  `IndepCode` fixtures (`Properties.hs:210` / `prop_stabilizerHalving`,
  `Properties.hs:414`) and asserts `surfaceCodeCommuting c === True` alongside
  `dim(code) * 2^r = 2^n`, tying halving to a validated code.

**Verification performed by Codex**

- `./props`: `34/34 passed`, `ALL PROPERTIES PASSED`.
- `./demo`: proof runner reported `9/9` proof checks passed.
- Fresh source compile with `ghc -Wall -Wextra -Werror` for `Main.hs`: passed.
- Fresh source compile with `ghc -Wall -Wextra -Werror -package QuickCheck
  -main-is Properties` for `Properties.hs`: passed.
- Fresh `/tmp` binaries for both demo and properties also passed.

**Independent re-verification by the agent (this session)**

- `ghc -Wall -Wextra -Werror -O0` clean for Main + all 8 modules (Hopf, QHA,
  Sheaf, Stabilizer, Stack, Proofs, Main); zero warnings.
- `ghc -Wall -Wextra -Werror -O0 -main-is Properties -package QuickCheck` clean;
  zero warnings.
- QuickCheck: 34/34 properties passed (`ALL PROPERTIES PASSED`, exit 0).
- Equational proofs via `./demo`: 9/9 checks passed, exit 0.
- `lean/sheaves-stacks-gauge-quantum-ha/SheavesStacksGauge.lean` elaborates
  (exit 0; only expected `sorry`/unused-variable linter warnings for the deferred
  T1/T4 statements).

VERDICT: PASS
