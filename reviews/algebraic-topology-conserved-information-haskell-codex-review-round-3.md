---
reviewer: codex (OpenAI)
type: haskell
topic: algebraic-topology-conserved-information
round: 3
model: gpt-5.5 (reasoning_effort=xhigh)
date: 2026-07-04T22:15:37Z
---
**Findings**
None blocking. I do not see remaining High/Medium issues in `src/algebraic-topology-conserved-information/`.

The prior issues appear resolved:
- `dSquaredIsZero` now gates through `wellFormed`, and `wellFormed` rejects negative dimensions plus wrong boundary shapes.
- `frobeniusFormNondegenerate` now rejects `faDim < 1` and uses real-valued Gaussian elimination.
- DW state sums guard empty groups before normalization.
- `CharacteristicClass` adds `mkSurface`; the exported operations also guard negative genus.

Verification run:
- `ghc -isrc/algebraic-topology-conserved-information -fno-code .../Main.hs`
- `ghc -isrc/algebraic-topology-conserved-information -fno-code .../Properties.hs`
- `runghc -isrc/algebraic-topology-conserved-information .../Main.hs`
- `ghci -ignore-dot-ghci -isrc/algebraic-topology-conserved-information .../Properties.hs -e runAllProperties`

All compiled and passed. Residual non-blocking gap: constructors like `Surface(..)`, `FrobeniusAlgebra(..)`, and `FiniteGroup(..)` remain public, so invalid values can still be built directly; current functions mostly guard at use sites.

VERDICT: PASS
