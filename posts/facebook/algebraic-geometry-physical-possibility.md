---
platform: facebook
topic: algebraic-geometry-physical-possibility
title: "Algebraic Geometry: Spaces of Physical Possibility"
url: "https://math-phy-library.vercel.app/papers/algebraic-geometry-physical-possibility/"
status: draft
created: 2026-07-04
---

Physicists throw around phrases like "moduli space" and "space of configurations" to mean, roughly, every state a system could be in. What I kept bumping into is that two different mathematical descriptions of that same space can quietly disagree, and one of them throws away real physical information without anyone noticing.

Part III of our modular seven paper series pins down when that happens. Start with a classical solution space and you have a variety. Allow a little infinitesimal wiggle room and it becomes a scheme. Ask for the space of genuinely different physical setups and you get a moduli space. But keep track of each configuration's gauge symmetries instead of dividing them out, and you get a moduli stack, which carries strictly more information.

So when does the stack actually know something the plain quotient doesn't? We prove it is exactly when a configuration has nontrivial symmetry, a nonzero stabilizer. That is a theorem, not a matter of taste.

What you get out of it is a concrete test for when a very common shortcut in physics, just take the quotient, is silently discarding information. It also builds the geometry we need for the topology paper that comes next.

Part III of a modular seven paper program, peer reviewed, code reviewed, and checked in Haskell and Lean.

Read it here: https://math-phy-library.vercel.app/papers/algebraic-geometry-physical-possibility/

#AlgebraicGeometry #ModuliSpaces #GaugeTheory #MathPhysics
