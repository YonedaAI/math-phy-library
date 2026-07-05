---
platform: linkedin
topic: motives-periods-amplitudes
title: "Motives, Periods, and Amplitudes: The Coalgebraic Anatomy of Physical Representation"
url: "https://math-phy-library.vercel.app/papers/motives-periods-amplitudes/"
status: draft
created: 2026-07-04
---

Problem: Particle physicists have long observed that scattering amplitudes computed via Feynman integrals exhibit striking arithmetic regularities — their discontinuities, cuts, and residues factorize in patterns reminiscent of algebraic coproducts, especially for polylogarithms and multiple zeta values. Why this happens has largely been treated as folklore.

Approach: Part II of the modular series "A Math→Physics Representation Library" gives this phenomenon a rigorous home. It formalizes the motive of a mathematical object as its "functional essence," instantiates Part I's abstract realization channels as four concrete cohomology theories (Betti, de Rham, Hodge, étale), and makes the period map the observable. The centerpiece is a motivic amplitude object equipped with a coaction and a cobracket drawn from Goncharov's Lie coalgebra of iterated integrals.

Key finding: The paper proves a Conditional Amplitude Decomposition theorem showing that realization channels, understood as homomorphisms of motivic-Galois Hopf algebras, transport the abstract coaction into the concrete decomposition physicists observe in cuts and discontinuities. It also establishes multiplicativity of the period pairing under direct sum and tensor product, and — importantly — proves a genuine limitation: non-Tate motives, such as elliptic ones, provably escape this polylogarithmic anatomy, marking a clear boundary of the method's applicability.

Implications: This gives the amplitudes community a precise arithmetic account of why certain factorization patterns appear, together with an honest map of where the technique runs out. It is the second module in a seven-part modular series (not a unified theory), building directly on Part I's representation stack, and comes with a compiling Haskell formalization and Lean type sketches, following peer and code review.

Paper: https://math-phy-library.vercel.app/papers/motives-periods-amplitudes/
Code: https://github.com/YonedaAI/math-phy-library

#MathematicalPhysics #ScatteringAmplitudes #MotivicCohomology #ParticlePhysics #AlgebraicGeometry #FormalVerification #TheoreticalPhysics
