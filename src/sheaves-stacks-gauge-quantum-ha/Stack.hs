{-# LANGUAGE ScopedTypeVariables #-}

-- | Module      : Stack
--   Part VI of "A Math->Physics Representation Library".
--
--   Gauge redundancy as a group action, and the two quotients:
--
--     * the coarse quotient  X/G   (records orbits only), and
--     * the stack quotient  [X/G]  (records orbits AND the stabilizer/isotropy).
--
--   Theorem T1 (paper Theorem, isotropy of the quotient stack):
--
--       Aut_{[X/G]}(x)  ==  Stab_G(x).
--
--   This module makes the isotropy retention concrete: 'stackQuotient' returns
--   the orbit together with the stabilizer subgroup, while 'coarseQuotient'
--   returns only the orbit.  The difference is exactly the gauge information a
--   stack keeps and the coarse quotient forgets.
module Stack
  ( GaugeAction(..)
  , orbit
  , stabilizer
  , coarseQuotient
  , stackQuotient
  , isFreeAction
  , orbifoldEulerChar
  ) where

import Data.List (nub)
import Data.Ratio ((%))

-- | A (right/left) group action of a finite group @g@ on a finite set @x@,
--   given by the acting function and the full list of group elements.
data GaugeAction x g = GaugeAction
  { act      :: g -> x -> x   -- ^ the action g . x
  , elements :: [g]           -- ^ the (finite) group G, all elements
  }

-- | Orbit of a point:  Orb_G(x) = { g . x : g in G }.
orbit :: (Eq x) => GaugeAction x g -> x -> [x]
orbit ga x = nub [ act ga g x | g <- elements ga ]

-- | Stabilizer of a point:  Stab_G(x) = { g in G : g . x = x }.
--   By Theorem T1 this is exactly Aut_{[X/G]}(x).
stabilizer :: (Eq x) => GaugeAction x g -> x -> [g]
stabilizer ga x = [ g | g <- elements ga, act ga g x == x ]

-- | Coarse quotient at a point: just the orbit (isomorphism class).  Forgets
--   automorphisms -- this is X/G.
coarseQuotient :: (Eq x) => GaugeAction x g -> x -> [x]
coarseQuotient = orbit

-- | Stack quotient at a point: the orbit PLUS the retained stabilizer.
--   This is the computational witness of "stacks retain gauge information":
--   the second component is Aut_{[X/G]}(x) = Stab_G(x).
stackQuotient :: (Eq x) => GaugeAction x g -> x -> ([x], [g])
stackQuotient ga x = (orbit ga x, stabilizer ga x)

-- | The action is free iff every stabilizer is trivial; then and only then the
--   coarse quotient is faithful (paper Corollary, faithfulness gap).
isFreeAction :: (Eq x) => GaugeAction x g -> [x] -> Bool
isFreeAction ga pts = all (\x -> length (stabilizer ga x) == 1) pts

-- | Orbifold Euler characteristic  sum_{orbits} 1 / |Stab| .  An observable
--   computable from [X/G] but NOT from X/G (paper Proposition, Prop. stacks
--   retain gauge information): it depends on the isotropy the coarse quotient
--   has discarded.
--   Precondition: @ga@ is a genuine finite group action, i.e. 'elements' is a
--   nonempty group containing the identity (so every stabilizer is nonempty).
--   For a degenerate action with an empty group we return @0@ rather than
--   dividing by a zero-size stabilizer; the @max 1@ guard on the stabilizer size
--   is a no-op on any genuine action (where @|Stab| >= 1@ always).
orbifoldEulerChar :: (Eq x) => GaugeAction x g -> [x] -> Rational
orbifoldEulerChar ga pts
  | null (elements ga) = 0
  | otherwise =
      sum [ 1 % fromIntegral (max 1 (length (stabilizer ga rep)))
          | rep <- orbitReps ]
  where
    orbitReps = representatives pts
    representatives []       = []
    representatives (y : ys) =
      y : representatives [ z | z <- ys, z `notElem` orbit ga y ]
