---
reviewer: agy (Gemini 3.1 Pro (High))
paper: sheaves-stacks-gauge-quantum-ha
round: 1
date: 2026-07-04T20:16:00Z
---

Here is a structured peer review of the provided manuscript, evaluating its mathematical correctness, clarity, completeness, logical structure, and LaTeX quality.

### **Completeness and Logical Structure**
The paper is structurally excellent. It accomplishes exactly what a "capstone" module should: it clearly connects the descent and gluing formalisms from previous modules to concrete, rigorously verifiable physical examples (surface codes and BPHZ renormalization). The explicit demarcation of epistemic statuses (\textsf{S}/\textsf{H}/\textsf{P}) is a superb structural choice that prevents overclaiming and clarifies the boundary between mathematical theorems and physical analogies. The progression from Grothendieck topologies to quotient stacks, and then to quantum error correction, is logically coherent and well-motivated. 

### **Critical Issues**
*None.* The central mathematical theorems (T1, T2, T3, T4) are true as stated, and the proofs (or proof sketches) capture the correct theoretical mechanics.

### **Major Issues**
**1. Mathematical/Conceptual: Stabilizer vs. Subsystem Codes (Lines 305–307, 368–370)**
* **Issue:** In Eq. (6), you present the subsystem code decomposition $\mathcal{H}_{\mathrm{phys}} \simeq (\mathcal{H}_{\log} \otimes \mathcal{H}_{\mathrm{gauge}}) \oplus \mathcal{H}_{\mathrm{err}}$. You then claim in Corollary 7.3 that for surface codes, the "contractible-loop (boundary) operators are the gauge/isotropy sector $\mathcal{H}_{\mathrm{gauge}}$." This conflates pure stabilizer codes with subsystem codes.
* **Correction:** For a pure stabilizer code like the standard surface code, the gauge group is trivial, meaning $\dim \mathcal{H}_{\mathrm{gauge}} = 1$. The stabilizers (contractible loops) act strictly as the identity on the code space, not as operators acting on a redundant tensor factor $\mathcal{H}_{\mathrm{gauge}}$. The redundancy in a stabilizer code lies entirely in the orthogonal syndrome sectors ($\mathcal{H}_{\mathrm{err}}$), corresponding to the full kinematic Hilbert space projecting down to the physical space. To preserve your exact Eq. (6) analogy where $\mathcal{H}_{\mathrm{gauge}}$ is nontrivial, you must explicitly invoke *subsystem codes* (e.g., the Bacon-Shor code) where gauge operators exist and commute with the stabilizers. Otherwise, rephrase Corollary 7.3 to clarify that for strict stabilizer codes, the redundancy is realized via the syndrome sectors rather than a code-space tensor factor.

**2. LaTeX Quality: Overwriting Semantic Macros (Line 75)**
* **Issue:** `\renewcommand{\coprod}{\Delta}` is highly discouraged in LaTeX. The `\coprod` macro is standard for the categorical coproduct / disjoint union (it renders as an inverted `\prod`). Redefining it to yield the Greek letter $\Delta$ breaks the semantic integrity of the document, will confuse anyone reading the source code, and will break other packages that rely on `\coprod` for its intended purpose.
* **Correction:** Define a new custom macro (e.g., `\newcommand{\cop}{\Delta}`) or simply type `\Delta` directly in your equations (e.g., in lines 155 and 382).

**3. LaTeX Quality: Obsolete Packages (Line 25)**
* **Issue:** You are using `\usepackage{everypage}`. This package is obsolete and deprecated. LaTeX kernels from October 2020 onward have built-in hook management. Using this package will trigger compilation warnings and may cause compatibility issues with modern LaTeX distributions.
* **Correction:** Remove `everypage` and replace `\AddEverypageHook` (Line 95) with the native LaTeX hook `\AddToHook{shipout/background}`, or use the `eso-pic` package for background overlays.

### **Minor Issues**
**1. Mathematical Notation: Boundary Operator (Line 354)**
* **Issue:** The equation $c=\partial^\top b$ uses the transpose symbol for what should be the standard topological boundary operator $\partial_2: C_2 \to C_1$. Since $b$ is explicitly a 2-chain and $c$ is a 1-chain, applying the standard boundary operator $\partial b$ is mathematically standard. Using $\partial^\top$ (which implies a coboundary moving from chains to cochains) is confusing here.
* **Correction:** Change to $c = \partial b$.

**2. Mathematical Notation: Laurent Series Brackets (Line 393)**
* **Issue:** The notation `\CC[z^{-1},z]]` has unbalanced brackets (one square bracket on the left, two on the right), which looks like a typo.
* **Correction:** Use standard notation for formal Laurent series, such as `\CC((z))` or `\CC[[z]][z^{-1}]`.

**3. Mathematical Notation: Direct Limit Indexing (Line 179)**
* **Issue:** The subscript on the colimit is written as `\varinjlim_{y\in U}`. Traditionally, the directed set of open neighborhoods containing $y$ is indexed as $U \ni y$. 
* **Correction:** Change to `\varinjlim_{U \ni y}F(U)`.

**4. Mathematical Precision: Surface Code Relations (Line 334)**
* **Issue:** You write "these are the \emph{only} relations" regarding $\prod A_v = I$ and $\prod B_f = I$. 
* **Correction:** While entirely correct, for maximum clarity you should add a half-sentence noting that this holds specifically because the lattice is embedded on a *closed* surface $\Sigma$ (without boundary).

**5. Typography: Spacing (Lines 132, 147)**
* **Issue:** The title formatting `Math$\to$Physics` treats the arrow as a mathematical relation, resulting in slightly awkward, wide horizontal spacing around it.
* **Correction:** Consider using `Math$\to$\,Physics` or wrapping it in text mode (e.g., `Math\textrightarrow Physics`) for cleaner typography.

***

VERDICT: MINOR REVISIONS
