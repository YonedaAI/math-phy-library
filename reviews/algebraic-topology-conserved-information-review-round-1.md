---
reviewer: Gemini 3.1 Pro (High)
paper: algebraic-topology-conserved-information
round: 1
date: 2026-07-04T20:19:21Z
---

Here is a peer review of the provided manuscript, evaluating it across the requested criteria.

### Mathematical Correctness & Completeness
The manuscript does a remarkable job of mapping rigorous algebraic topology onto physical representation theories. The definitions are precise, and the included proofs (such as the Mayer-Vietoris sequence and the invariance of Dijkgraaf-Witten theory under Pachner moves) correctly capture the underlying mechanics. However, there are two significant mathematical contradictions in the specific examples and formulas that need to be addressed. As an overview of a modular library, the completeness of the mathematical topics covered (homology $\to$ TQFT $\to$ Bordism) is exceptional.

### Logical Structure & Clarity
The framing of topological concepts as a "realization pipeline" is highly lucid and well-sustained. The logical progression from local boundary operations to global invariants, and finally to topological field theories, provides an excellent pedagogical flow. The use of epistemic status labels ($\Sfont, \Hfont, \Pfont$) is an excellent mechanism for disambiguating rigorous mathematics from physical heuristic.

### LaTeX Quality
The TeX source is extremely clean, well-organized, and utilizes robust semantic macros. The formatting is professional, though it relies on one deprecated package. 

***

### 🔴 Critical Issues
*(None found. The core definitions, theorems, and proofs are fundamentally sound.)*

### 🟠 Major Issues
1. **Section 3.4, Example 3.20 (Conserved charge on the torus):**
   - **Issue:** The text states: *"A flat gauge field on $T^2$ is classified up to gauge by its holonomies, i.e. by a class in $H^1(T^2; \mathrm{U}(1))$; the integer $\int_{T^2} F/2\pi = \langle a\smile b, [T^2] \rangle$ is the conserved first Chern number..."*
   - **Reasoning:** This conflates two mutually exclusive topological regimes. A *flat* gauge field has identically vanishing curvature ($F=0$), meaning its first Chern number is strictly $0$. A gauge field with a non-zero first Chern number (which pairs with $a \smile b \in H^2(T^2; \Zm)$) is necessarily non-flat. The moduli space of flat connections $H^1(T^2; \Umone)$ corresponds exclusively to bundles with trivial topological charge.
   - **Fix:** Disambiguate these two examples. Use the flat gauge field to illustrate holonomies in $H^1$, and then separately introduce a non-flat bundle/magnetic monopole to illustrate the non-zero Chern class in $H^2$.

2. **Section 6.1 & 6.2, Equation 6.2 (Dijkgraaf-Witten state sum):**
   - **Issue:** The state sum formula applies an exponential: $\exp(2\pi i \langle \phi^*\omega, [X] \rangle)$.
   - **Reasoning:** In Definition 6.1, you define the group cohomology coefficients as $\mathrm{U}(1)$ and write the coboundary operator multiplicatively (using $\prod$). In standard mathematical notation, this implies $\mathrm{U}(1)$ is the multiplicative circle group $\{z \in \mathbb{C} \mid |z|=1\}$. Therefore, the pairing $\langle \phi^*\omega, [X] \rangle$ already evaluates to an element of $\mathrm{U}(1)$ (a complex number). Exponentiating this value as $e^{2\pi i z}$ is a mathematical type error.
   - **Fix:** Either drop the exponential and simply write the state sum as $\frac{1}{|G|}\sum_{\phi} \langle\phi^*\omega,[X]\rangle$, or alternatively, redefine the group cohomology coefficients to take values in $\mathbb{R}/\mathbb{Z}$ additively, which would make the exponential valid.

### 🟡 Minor Issues
1. **Section 5.2, Example 5.4 (2D TQFT):**
   - **Issue:** The text states *"the disk gives the unit/counit, and the sphere gives the Frobenius trace."*
   - **Reasoning:** To be strictly precise with TQFT cobordisms, the disk ($\emptyset \to S^1$) yields the unit, the *reversed* disk ($S^1 \to \emptyset$) yields the counit (which is the Frobenius trace map $A \to k$), and the sphere ($\emptyset \to \emptyset$) evaluates to a scalar representing the trace of the identity (the dimension of the algebra).
   - **Fix:** Clarify that the reversed disk represents the trace map, and that the sphere evaluates to the dimension scalar.

2. **Section 7.2, Theorem 7.3 (Cohomology degree notation):**
   - **Issue:** The text denotes the Anderson dual cohomology isomorphism as $[MTH, \Sigma^{n+1}I\Zm] \cong (I\Zm)^n(MTH)$.
   - **Reasoning:** An $(n+1)$-fold suspension of the classifying spectrum corresponds to generalized cohomology in degree $n+1$, not $n$.
   - **Fix:** Update the isomorphism index to read $(I\Zm)^{n+1}(MTH)$.

3. **LaTeX Source (Preamble):**
   - **Issue:** The `everypage` package is used to generate the GrokRxiv sidebar.
   - **Reasoning:** The `everypage` package was officially deprecated in late 2020 and will trigger compilation warnings in modern LaTeX distributions.
   - **Fix:** Replace the `everypage` package with native LaTeX `shipout` hooks (e.g., `\AddToHook{shipout/page}{...}`).

VERDICT: MAJOR REVISIONS
