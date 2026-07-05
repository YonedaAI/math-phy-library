---
reviewer: agy (Gemini 3.1 Pro (High))
paper: sheaves-stacks-gauge-quantum-ha
round: 4
date: 2026-07-04T20:35:00Z
---

Here is the final peer-review pass for Part VI. The mathematical structure is highly sophisticated and beautifully presented. The previous minor issues (EGH reference, interaction hypergraph terminology, and bibliography entries for Parts II and III) have been successfully resolved. The conceptual bridge between gauge theory (stacks) and quantum error correction is compelling and rigorous.

There is, however, one major mathematical inaccuracy regarding the dimensionality of the logical operator group in the surface code, along with a few minor technical imprecisions that should be polished before final publication. 

### Critical Issues
*(None)*

### Major Issues
1. **Theorem 7.2, Part 2 (Logical operator isomorphism):** 
   - **Line reference:** `giving a canonical isomorphism (logical operators) \cong H_1(\Sigma;\ZZ_2) \cong \ZZ_2^{\,2g};`
   - **Issue:** The theorem incorrectly identifies the *entire* group of logical operators with $H_1(\Sigma; \mathbb{Z}_2) \cong \mathbb{Z}_2^{2g}$. As established in Part 1 of the theorem, there are $k=2g$ encoded qubits, which means the full group of logical Paulis modulo stabilizers forms a symplectic vector space of dimension $4g$ over $\mathbb{Z}_2$. $H_1(\Sigma; \mathbb{Z}_2)$ only classifies the $Z$-type logical operators (an isotropic subspace of dimension $2g$), while the $X$-type logicals correspond to the Poincaré dual classes $H^1(\Sigma; \mathbb{Z}_2)$. 
   - **Fix:** Update the isomorphism to reflect the full algebra, e.g., $\text{(logical operators)} \cong H_1(\Sigma; \mathbb{Z}_2) \oplus H^1(\Sigma; \mathbb{Z}_2) \cong \mathbb{Z}_2^{4g}$, and clarify that the $Z$-logicals and $X$-logicals individually form the $2g$-dimensional halves of this space.

2. **Proposition 6.4 (Syndrome presheaf vs. correction descent):**
   - **Line reference:** `Correctability (\Cref{lem:knill-laflamme}) is the statement that compatible local syndromes glue to a global correction --- a sheaf-like descent for syndrome data.`
   - **Issue:** There is a category error in the conceptual mapping here. The presheaf is defined as *syndrome outcomes* (functions from local generators to $\{\pm 1\}$). Gluing compatible local functions into a global function is trivially true for any set of local assignments and doesn't require the Knill-Laflamme conditions. The Knill-Laflamme conditions guarantee the existence of a unique *global error class / correction operator* given a valid global syndrome. Thus, the "descent" is not the gluing of the syndromes themselves, but rather the passage from local syndrome data to a unique global logical correction class.
   - **Fix:** Reword to clarify that while syndromes trivially form a sheaf, correctability (Knill-Laflamme) is the condition that allows these glued global syndromes to uniquely pick out an effective global correction operator (i.e., the map from syndromes to correctable error classes is well-defined).

### Minor Issues
1. **Theorem 4.5 (Local structure of the quotient stack):**
   - **Line reference:** `Hence the local model of \quot{X}{G} at [x] is \mathrm{B}\Stab_G(x).`
   - **Issue:** Strictly speaking, the restriction (or fiber) of the stack to the orbit is $\mathrm{B}\Stab_G(x)$. The *local structure* (in an open neighborhood) of a quotient stack generally incorporates the normal slice $S_x$ to the orbit, taking the form $[S_x / \Stab_G(x)]$. It only reduces completely to $\mathrm{B}\Stab_G(x)$ if the orbit is open (the slice is a point). 
   - **Fix:** Change "local structure" and "local model" to "residual gerbe" or "restriction of the stack to the orbit".

2. **Theorem 8.3 (Twisted antipode notation):**
   - **Line reference:** `The counterterm \varphi_-=\varphi\circ\antipode_R is the twisted (Rota--Baxter) antipode...`
   - **Issue:** The Rota-Baxter operator $R$ acts on the target algebra $\mathcal{A}$, not on the Hopf algebra $H$. Therefore, the notation $\varphi \circ \antipode_R$ is technically ill-typed since there isn't an operator $\antipode_R$ on $H$ that one can simply precompose with $\varphi$. (The recursive Bogoliubov formulas (10) and (11) correctly place $R$ on $\mathcal{A}$).
   - **Fix:** Write this as a twisted antipode on the character group, e.g., $\varphi_- = S_R(\varphi)$, or simply state that $\varphi_-$ is computed via the twisted Rota-Baxter antipode structure on $\Hom(H, \mathcal{A})$.

3. **Definition 6.2 (Stabilizer Code):**
   - **Line reference:** `with -I\notin S`
   - **Issue:** While $-I \notin S$ is a necessary condition, a valid stabilizer code also requires that $\pm i I \notin S$. Since $S$ is usually constructed from Hermitian Pauli elements this is often implied, but it is safer to state that $S$ does not contain any non-trivial phases.
   - **Fix:** Mention that $S$ does not contain non-trivial overall phases (i.e., $S \cap \{ \pm I, \pm i I \} = \{ I \}$).

VERDICT: MAJOR REVISIONS
