---
reviewer: codex (OpenAI)
type: haskell
topic: foundations-representation-stack
round: 2
model: gpt-5.5 (reasoning effort high)
date: 2026-07-04T21:57:04Z
---

**Findings**

- High: `RepEntry` still does not enforce the status invariant at the API boundary. [RepStack.hs:14](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/RepStack.hs:14) exports `RepEntry(..)`, so external callers can construct `RepEntry ... (SpeculativeMap ...) Std` directly, bypassing `mkRepEntry` at [RepStack.hs:128](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/RepStack.hs:128). `composeEntry` then trusts the stored statuses at [RepStack.hs:161](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/RepStack.hs:161), so invalid entries can produce invalid composites. Make `RepEntry` abstract, export selectors only, or make unsafe construction explicit/internal.

- Medium: the `Int` overflow fix is incomplete in `Main.hs`. Properties/proofs use `Integer`, but the demo model still defines `Config Int`, `gauge = negate`, and `coarseClass = abs` at [Main.hs:111](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Main.hs:111)-[Main.hs:120](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Main.hs:120). This reintroduces the old `minBound :: Int` pathology in the runnable example and contradicts `Proofs.hs` saying the toy model mirrors `Main.hs` at [Proofs.hs:306](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Proofs.hs:306).

- Medium: the coarse descent witness is better than round 1, but the wording still overclaims. [Properties.hs:468](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Properties.hs:468)-[Properties.hs:487](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Properties.hs:487) and [Proofs.hs:289](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Proofs.hs:289)-[Proofs.hs:304](/Users/mlong/Documents/Development/math-phy-library/src/foundations-representation-stack/Proofs.hs:304) show two distinct fine cocycles with identical local and global coarse classes. That supports “coarse quotient is non-faithful / fine gluing is not reconstructible,” but not literally that the coarse set-valued presheaf has two distinct global coarse gluings, since `globalCoarseClass` is `()` for both.

The round-2 fixes otherwise look faithful: `mkRepEntry` normalizes candidate/status correctly, `composeEntryChecked` implements the `P1 = M2` premise, the composable generator matches it, the pipeline now checks identity and composition on morphisms, and the status/proof enumerations cover the claimed finite domains. I did not rebuild or run tests, per instruction.

VERDICT: NEEDS_FIX
