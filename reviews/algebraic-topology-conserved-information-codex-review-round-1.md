---
reviewer: codex (OpenAI)
type: formatting
paper: algebraic-topology-conserved-information
round: 1
date: 2026-07-04T20:42:36Z
---

**Findings**

1. Lines 40-48: `cleveref` renders all shared-counter theorem-like environments as “Theorem”. Definitions, propositions, examples, remarks, and corollaries referenced with `\Cref` are mislabeled in the PDF, e.g. lines 348, 416, 520, 684, 1215, 1269.  
Concrete fix: give each environment a distinct `cleveref` type via `aliascnt`, or separate counters, then define `\crefname`/`\Crefname` for `definition`, `proposition`, `lemma`, `example`, `remark`, and `corollary`.

2. Lines 190-199: `\small` is used inside display math, producing `LaTeX Font Warning: Command \small invalid in math mode on input line 191.`  
Concrete fix: move sizing outside the display:
```latex
{\small
\[
  ...
\]
}
```

3. Lines 298-303: overfull hbox, 7.8786pt too wide, in the “Representation entry” definition.  
Concrete fix: put `E=(M,P,\tau,\sigma)` in a displayed equation before “where”, or insert an explicit line break after “quadruple”.

4. Lines 322-324: overfull hbox, 3.0549pt too wide, in the “Locality/descent axiom” definition heading/text.  
Concrete fix: change the theorem title to `Locality and descent axiom` or `Locality\slash descent axiom`.

5. Lines 803-811: overfull hbox, 8.5319pt too wide, in the Chern classes example.  
Concrete fix: move `H^*(B\mathrm{U}(k);\Zm)=\Zm[c_1,\dots,c_k]` to a displayed equation.

6. Lines 1078-1086: overfull hbox, 5.60902pt too wide, in the Dijkgraaf-Witten theorem text.  
Concrete fix: split the “well typed” sentence, e.g. make `\exp(2\pi i(-))\colon \Rm/\Zm\to\Umone` a displayed or separate inline clause, and replace `triangulation-independent` with “independent of triangulation”.

7. Lines 1215-1219: overfull hbox, 2.0638pt too wide, in the Results bullet combining de Rham gauge and Poincare duality.  
Concrete fix: split this into two bullets, or shorten the bold labels and keep the `\Cref`s outside the bold text.

8. Lines 1413-1465: appendix dictionary table is too tall for one page. The log reports `Overfull \vbox (594.4872pt too high)`, and the rendered PDF/text extraction cuts off rows after `Classifying space BG`; source rows 1444-1464 do not appear before References.  
Concrete fix: replace `center` + `tabular` with a multipage `longtable` and add `\usepackage{longtable}`. Also use ragged columns, e.g. `>{\raggedright\arraybackslash}p{...}`, to avoid the many underfull cells.

9. Lines 1413-1465: same table has repeated underfull hboxes and local overfull hboxes, especially rows 1417, 1421, 1422, 1424-1428, 1430, 1433, 1436-1439, 1442, 1444-1455, 1458-1460, and 1462; line 1445 has an overfull hbox, 7.50139pt too wide.  
Concrete fix: combine the `longtable` change with wider or flexible columns, ragged-right paragraph columns, and possibly `\scriptsize` or a split table.

No unresolved `\ref`/`\cref`/`\cite` warnings appear in the existing LaTeX log.

VERDICT: NEEDS_FIX
