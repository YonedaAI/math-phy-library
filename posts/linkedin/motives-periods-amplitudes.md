---
platform: linkedin
topic: motives-periods-amplitudes
title: "Motives, Periods, and Amplitudes: The Coalgebraic Anatomy of Physical Representation"
url: "https://math-phy-library.vercel.app/papers/motives-periods-amplitudes/"
status: draft
created: 2026-07-04
---

Particle physicists have noticed for years that scattering amplitudes computed from Feynman integrals show striking arithmetic regularities. Their discontinuities, cuts, and residues factorize in patterns that look like algebraic coproducts, especially for polylogarithms and multiple zeta values. Why this happens has mostly been folklore.

Part II of the modular series "A Math→Physics Representation Library" gives the phenomenon a rigorous home. It formalizes the motive of a mathematical object as its "functional essence," instantiates Part I's abstract realization channels as four concrete cohomology theories (Betti, de Rham, Hodge, étale), and makes the period map the observable. At the center is a motivic amplitude object carrying a coaction and a cobracket taken from Goncharov's Lie coalgebra of iterated integrals.

The main result is a Conditional Amplitude Decomposition theorem. It shows that realization channels, read as homomorphisms of motivic-Galois Hopf algebras, transport the abstract coaction into the concrete decomposition physicists see in cuts and discontinuities. The paper also establishes multiplicativity of the period pairing under direct sum and tensor product. Just as usefully, it proves a real limitation: non-Tate motives, elliptic ones among them, provably escape this polylogarithmic anatomy, which marks a clear boundary on where the method applies.

For the amplitudes community, that adds up to a precise arithmetic account of why certain factorization patterns show up, together with an honest map of where the technique runs out. It is the second module in a seven-part modular series rather than a unified theory, and it builds directly on Part I's representation stack. It comes with a compiling Haskell formalization and Lean type sketches after peer and code review.

Paper: https://math-phy-library.vercel.app/papers/motives-periods-amplitudes/
Code: https://github.com/YonedaAI/math-phy-library

#MathematicalPhysics #ScatteringAmplitudes #MotivicCohomology #ParticlePhysics #AlgebraicGeometry #FormalVerification #TheoreticalPhysics
