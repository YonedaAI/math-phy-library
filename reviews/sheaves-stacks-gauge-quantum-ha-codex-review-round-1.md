---
reviewer: codex (OpenAI)
model: gpt-5.5 (reasoning xhigh)
type: formatting
paper: sheaves-stacks-gauge-quantum-ha
round: 1
date: 2026-07-04T20:53:08Z
---

Findings from a 3-pass temp `pdflatex` build and selected PDF renders. I did not modify files.

- [sheaves-stacks-gauge-quantum-ha.tex:21](/Users/mlong/Documents/Development/math-phy-library/papers/latex/sheaves-stacks-gauge-quantum-ha.tex:21): `\usepackage[htt]{hyphenat}` triggers persistent Latin Modern mono font-shape substitution warnings. Fix by removing `[htt]` and using `\path{...}`/`url` or `xurl` for breakable paths.

- [sheaves-stacks-gauge-quantum-ha.tex:1170](/Users/mlong/Documents/Development/math-phy-library/papers/latex/sheaves-stacks-gauge-quantum-ha.tex:1170): the Results table floats into the middle of the Discussion item list on page 19. Fix with `placeins` plus `\FloatBarrier` before `\section{Discussion}`, or otherwise force the table to stay before line 1199.

- [sheaves-stacks-gauge-quantum-ha.tex:1173](/Users/mlong/Documents/Development/math-phy-library/papers/latex/sheaves-stacks-gauge-quantum-ha.tex:1173): the fixed-width table columns produce visible loose spacing and underfull boxes in headers/cells. Fix by switching to `tabularx` with ragged-right paragraph columns, or shortening headers and cell text.

- [sheaves-stacks-gauge-quantum-ha.tex:887](/Users/mlong/Documents/Development/math-phy-library/papers/latex/sheaves-stacks-gauge-quantum-ha.tex:887): theorem item 2 has an underfull line from long inline math/text. Fix by splitting the sentence and moving the `H_1`/`H^1` isomorphisms into displayed equations.

- [sheaves-stacks-gauge-quantum-ha.tex:1250](/Users/mlong/Documents/Development/math-phy-library/papers/latex/sheaves-stacks-gauge-quantum-ha.tex:1250): open-problem bullet has loose spacing around “single motivic-renormalization”. Fix by rephrasing shorter, e.g. “Is there a single Hopf algebra unifying the Goncharov and Connes--Kreimer coproducts?”

- [sheaves-stacks-gauge-quantum-ha.tex:1288](/Users/mlong/Documents/Development/math-phy-library/papers/latex/sheaves-stacks-gauge-quantum-ha.tex:1288): companion formalizations paragraph produces an underfull box due dense inline `\texttt` paths/identifiers. Fix by splitting Haskell and Lean into separate bullets and using `\path{...}` for paths.

- [sheaves-stacks-gauge-quantum-ha.tex:1301](/Users/mlong/Documents/Development/math-phy-library/papers/latex/sheaves-stacks-gauge-quantum-ha.tex:1301): bibliography entries at lines 1309, 1320, 1362, 1369, and 1394 still produce underfull boxes. Fix by adding `\raggedright` inside `thebibliography`, or manually breaking long titles/arXiv tokens.

No remaining undefined references/citations, overfull boxes, or theorem/equation numbering defects showed up in the temp build.

VERDICT: NEEDS_FIX
