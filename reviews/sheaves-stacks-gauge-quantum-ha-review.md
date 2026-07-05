---
reviewer: agy (Gemini 3.1 Pro (High))
paper: sheaves-stacks-gauge-quantum-ha
round: 5 (confirming fix of round-4 MAJOR correctness item)
date: 2026-07-04T20:40:29Z
---

This is an exceptionally strong manuscript. The mathematical updates requested in the prior round have been implemented flawlessly. 

The identification of the surface-code logical Paulis with the symplectic space $H_1(\Sigma;\ZZ_2) \oplus H^1(\Sigma;\ZZ_2) \cong \ZZ_2^{4g}$ in **Theorem 7.2** is exact, elegantly unifying the surface code with the homological dictionary of Part IV. The clarification of the residual gerbe in **Theorem 4.5** utilizes slice-theorem language correctly, and the typing of the twisted antipode as an operator on the character group $\Hom(H, \mathcal A)$ in **Theorem 8.3** is mathematically spotless. The Rota–Baxter weight-($-1$) identity in the proof of Theorem 8.3 is precisely correct. 

The document is mathematically sound, logically well-structured, and the LaTeX is clean. There are no critical errors remaining, though there is one major consistency error in the final summary table and a few minor typographical/stylistic points to address.

### **Major Issues**
* **Contradiction between Proposition 6.4 and Table 1:** 
  In **Proposition 6.4**, you beautifully delineate the two layers of the error-correction pipeline: the *sheaf condition* handles the gluing of local syndromes (syndrome consistency), while the *descent step* is the transition from a global syndrome to a unique correctable global error class (recovery/correctability). 
  However, in **Table 1 (Section 10)**, the QI interpretations are swapped:
  * `Sheaf` is mapped to `correctable local errors`.
  * `Descent` is mapped to `syndrome consistency`.
  To align with Proposition 6.4, these should be reversed: `Sheaf` $\leftrightarrow$ `syndrome consistency` (or "local syndrome gluing"), and `Descent` $\leftrightarrow$ `correctable global error / recovery`.

### **Minor Issues / Suggestions**
* **Table 1 wording for Boundaries:** For the `Boundary c=\partial b` row, the QI interpretation is listed as "undetectable error". While technically true (a boundary cycle has a zero syndrome), logical operators (non-contractible cycles) are *also* undetectable. Because a boundary error lies in the stabilizer, it acts as the identity on the code space. It would be clearer and more precise to label this "trivial error" or "harmless equivalence" in the table, perfectly matching your text in Theorem 7.2 which states "a contractible error loop is undetectable and harmless".
* **Single Subsections (Sections 7 and 8):** Both Section 7 and Section 8 contain only a single subsection (`7.1 The toric/surface code` and `8.1 The Connes–Kreimer Hopf algebra`). In standard academic typesetting, if there is an X.1, there should be an X.2. You should either remove the subsection headers to let the text sit directly under the section heading, or split the text into two subsections.
* **LaTeX formatting of $\mathcal{H}om$:** In **Theorem 5.1**, the macro `\mathcal{H}om_{\mathrm{Stack}}` is used. Because `\mathcal` only applies to the first character unless braced, this renders as a script $\mathcal{H}$ followed by math-italic $o$ and $m$ (which LaTeX spaces slightly like a product of variables). If you want a clean "Hom" script, consider defining a macro using `\operatorname{\mathscr{H}\mathit{om}}` (with `mathrsfs`), or simply fall back to `\underline{\mathrm{Hom}}` which is standard for internal homs.
* **Theorem 7.2 proof wording:** When evaluating $k = 2 - \chi(\Sigma) = 2g$, the relation relies on the surface being *connected*. It is universally understood that "a closed orientable surface of genus $g$" is connected, but inserting the word "connected" in Definition 7.1 would make the topological invariant rigorously watertight. 

VERDICT: MINOR REVISIONS
