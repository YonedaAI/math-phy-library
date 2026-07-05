---
reviewer: Gemini-3.1-Pro-High
paper: motives-periods-amplitudes
round: 1
date: 2026-07-04T20:12:46Z
---

Here is the structured peer review for the provided manuscript.

# Peer Review Report

**Title:** Motives, Periods, and Amplitudes: The Coalgebraic Anatomy of Physical Representation
**Author:** Matthew Long

## 1. Overall Evaluation
The paper presents an ambitious and conceptually fascinating framework for formalizing the extraction of physical observables from mathematical structures. The use of motives, periods, and the Goncharov Lie coalgebra is compelling, and the epistemic status tracking (S/H/P labels) is a rigorous and highly commendable methodological addition. The LaTeX formatting is exceptionally clean, well-commented, and visually excellent. However, the manuscript suffers from a severe category error in its central theorem, conflating categorical objects (motives) with elements of vector spaces (periods), which renders the statement and proof of Theorem 5.3 mathematically incoherent.

## 2. Critical Issues

- **Line 333 (Theorem 5.3) - Severe Category Error:** The statement and proof of Theorem 5.3 conflate the category of motives with the algebra of motivic periods. $\Real_\alpha$ is introduced as a "lax monoidal functor from the category of motivic periods". However, the Kontsevich-Zagier period ring $\mathcal{P}$ (as defined in Section 4.1) is a $\mathbb{Q}$-algebra, not a category. Furthermore, the theorem applies $\Real_\alpha$ to $\Amm \in A$, treating $\Amm$ as an object (in order to use the monoidal structure map $\mu_{X,Y}$) while simultaneously treating it as an element of a vector space over which the coaction $\Delta$ is defined as a sum of tensors $\sum \Amm_{i,1} \otimes \Amm_{i,2}$. Functors apply to objects and morphisms, not to elements of a vector space. You cannot use a monoidal functor's structure map $\mu$ to split a tensor product of vector space elements. The fix is either to define $\Real_\alpha$ as an algebra homomorphism (or comodule map) between vector spaces/algebras (abandoning the functor language here), or to correctly lift $\Amm$ to an object in $\text{MM}(k)$ and $\Delta$ to a morphism (which fundamentally changes the nature of the coaction sum).
- **Line 300 (Definition 5.1 / 5.2) - Ill-defined Reduced Coaction:** The reduced coaction is defined as $\Delta' = \Delta - (\mathrm{id} \otimes 1) - (1 \otimes \mathrm{id})$. While $(\mathrm{id} \otimes 1)(a) = a \otimes 1_H$ is well-defined for any right $H$-comodule $A$, the term $(1 \otimes \mathrm{id})(a) = 1_A \otimes a$ is undefined unless $A$ is a unital algebra and there is a canonical projection $A \to H$. A general right comodule $A$ does not possess an element $1_A$ or this projection. You must explicitly require $A$ to be a comodule algebra that projects to $H$, which is true for mixed Tate motivic periods (where $A = \mathcal{P}_{mot}$) but not for general comodules as stated in the definition.

## 3. Major Issues

- **Line 417 (Theorem 6.2) - Terminology of Generation:** The title of the theorem is "Weight-graded primitives generate $\LG(F)$". However, $\LG(F)$ is a Lie *coalgebra*. The correct terminology (as accurately used in the proof on Line 443) is that primitives *cogenerate* a connected coalgebra. Using "generate" in the title is algebraically imprecise and risks confusing algebraic generation with coalgebraic cogeneration.
- **Line 261 (Theorem 4.2) - Framing of the Period Map:** The theorem deduces that the period map is a "ring homomorphism from the $\mathbb{Q}$-algebra of formal period data... to the period ring $\mathcal{P}$". This is essentially tautological since $\mathcal{P}$ is defined in Section 4.1 exactly as the image of this evaluation map. This should be explicitly stated as the *definition* of the ring structure on $\mathcal{P}$ rather than a consequence of the theorem.
- **Line 21 (LaTeX Quality) - Obsolete Package:** The `\usepackage{everypage}` package is obsolete and deprecated in modern LaTeX distributions, which will trigger compiler warnings. Given the paper is dated 2026, you should use `eso-pic` or the native LaTeX hook `\AddToHook{shipout/background}` for the GrokRxiv overlay instead.

## 4. Minor Issues

- **Line 667 (Lean Formalization):** In the Lean code sketch, `Real : P -> R` is typed as a function between types. This actually aligns with the "algebra homomorphism" correction needed for Theorem 5.3, further highlighting that the "monoidal functor" terminology in the LaTeX text is incorrect.
- **Line 628 (Haskell Code):** The `cobracket` function returns a list of tuples representing a formal sum. Because it does not combine like terms, it is a slightly naive representation of an element in the exterior algebra. This is acceptable for a demonstration script, but a comment acknowledging that algebraic simplification of terms is omitted would be helpful.
- **Line 77 (Typographic Consistency):** The `\Slab`, `\Hlab`, and `\Plab` labels are a great semantic tool. However, in the text they are sometimes used in math mode. Consider defining them with `\mathsf{S}` rather than `\textsf{S}` so they adapt gracefully to math mode spacing without font warnings.

VERDICT: REJECT (critical issues remain)
