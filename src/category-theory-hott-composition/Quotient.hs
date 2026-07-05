-- |
-- Module      : Quotient
-- Description : Groupoid quotient vs set quotient (Theorem T4, Section 6.4).
--
-- Theorem T4 says the groupoid quotient @X // G@ is strictly finer than the
-- set quotient @X / G@: the former retains each point's stabilizer as
-- nontrivial automorphism loops, @Aut_{[X/G]}(x) ~ Stab_G(x)@, while the
-- 0-truncation @X / G@ forgets them, retaining only orbits. This module
-- computes both from a finite group action and exhibits the lost information.
--
-- The group and action are given as explicit finite data together with
-- law-validators ('isGroup', 'isActionOf'): a 'GroupAction' is a finite action
-- /witness/, and its lawfulness (that @G@ really is a group and the action
-- satisfies the action axioms) is checked, not assumed. The orbit-stabilizer
-- theorem ('orbitStabilizerHolds') and the orbit partition ('orbitsPartition')
-- give the quantitative content that distinguishes the two quotients.
module Quotient
  ( -- * Finite groups and actions
    FiniteGroup(..)
  , GroupAction(..)
  , isGroup
  , isActionOf
    -- * Orbits, stabilizers, quotients
  , orbit
  , orbits
  , orbitsPartition
  , stabilizer
  , setQuotient
  , groupoidAutomorphisms
  , retainsGaugeInfo
  , orbitStabilizerHolds
    -- * Concrete lawful examples
  , cyclicGroup
  , regularAction
  , z2TrivialOnPoint
  ) where

import Data.List (nub, sort)

-- | A finite group presented by explicit data: a carrier, a unit, a binary
-- operation, and an inverse. Lawfulness is /checked/ by 'isGroup', not assumed.
data FiniteGroup g = FiniteGroup
  { carrier :: [g]          -- ^ underlying finite set (no repeats when lawful)
  , gUnit   :: g            -- ^ identity element
  , gMul    :: g -> g -> g  -- ^ group multiplication
  , gInv    :: g -> g       -- ^ inverse
  }

-- | A finite (left) group action: a list of group elements and an action
-- function @act g x@. On its own this is only an action /witness/; use
-- 'isActionOf' with a 'FiniteGroup' to certify the action axioms.
data GroupAction g x = GroupAction
  { elements :: [g]              -- ^ carrier of the group G (as used by orbits)
  , act      :: g -> x -> x      -- ^ the action  G x X -> X
  }

-- | Check the group axioms on the finite carrier: the carrier has no repeats,
-- contains the unit, is closed under multiplication, is associative, the unit
-- is two-sided, and every element has a two-sided inverse in the carrier.
isGroup :: (Eq g) => FiniteGroup g -> Bool
isGroup grp = and
  [ nub es == es                                              -- no repeats
  , gUnit grp `elem` es                                       -- unit present
  , all (\a -> all (\b -> gMul grp a b `elem` es) es) es      -- closure
  , all (\a -> all (\b -> all (\c ->
        gMul grp (gMul grp a b) c == gMul grp a (gMul grp b c)) es) es) es
                                                              -- associativity
  , all (\a -> gMul grp (gUnit grp) a == a
            && gMul grp a (gUnit grp) == a) es                -- two-sided unit
  , all (\a -> gInv grp a `elem` es
            && gMul grp a (gInv grp a) == gUnit grp
            && gMul grp (gInv grp a) a == gUnit grp) es       -- inverses
  ]
  where es = carrier grp

-- | Check the (left) action axioms of @grp@ on the carrier @xs@ of X. This
-- validates, in order:
--
--   * /carrier match/: the action's 'elements' enumerate exactly the group's
--     'carrier' (same set, same multiplicity) -- so a stale or duplicated
--     'elements' list cannot make orbit/stabilizer counts reason about a
--     different enumeration of @G@;
--   * /closure/: the action stays inside @xs@, @g . x `elem` xs@;
--   * /unit/: the identity acts as the identity, @e . x = x@;
--   * /compatibility/: @(h * g) . x = h . (g . x)@.
isActionOf :: (Eq g, Eq x) => FiniteGroup g -> GroupAction g x -> [x] -> Bool
isActionOf grp ga xs = and
  [ length es == length cs
      && all (`elem` cs) es && all (`elem` es) cs                 -- carrier
  , all (\g -> all (\x -> act ga g x `elem` xs) xs) cs            -- closure
  , all (\x -> act ga (gUnit grp) x == x) xs                      -- unit
  , all (\g -> all (\h -> all (\x ->
        act ga (gMul grp h g) x == act ga h (act ga g x)) xs)
        cs) cs                                                    -- compat
  ]
  where
    es = elements ga
    cs = carrier grp

-- | The orbit @G . x@ of a point (a point of the set quotient @X / G@).
orbit :: (Ord x) => GroupAction g x -> x -> [x]
orbit ga x = sort (nub [ act ga g x | g <- elements ga ])

-- | The distinct orbits over a chosen carrier @xs@ of X.
orbits :: (Ord x) => GroupAction g x -> [x] -> [[x]]
orbits ga xs = nub [ orbit ga x | x <- xs ]

-- | The orbits genuinely /partition/ the carrier: they cover @xs@ and are
-- pairwise disjoint (so the set quotient is a well-defined partition, not just
-- a list of images).
orbitsPartition :: (Ord x) => GroupAction g x -> [x] -> Bool
orbitsPartition ga xs =
  let os      = orbits ga xs
      covered = sort (nub (concat os)) == sort (nub xs)
      disjoint =
        and [ null [ e | e <- o1, e `elem` o2 ]
            | (i, o1) <- zip [0 :: Int ..] os
            , (j, o2) <- zip [0 :: Int ..] os
            , i < j ]
  in covered && disjoint

-- | The stabilizer @Stab_G(x) = { g | g . x = x }@. Its cardinality is the
-- number of automorphism loops the groupoid quotient retains at @x@.
stabilizer :: (Eq x) => GroupAction g x -> x -> [g]
stabilizer ga x = [ g | g <- elements ga, act ga g x == x ]

-- | The set quotient @X / G@: the distinct orbits over a chosen carrier
-- @xs@ of X. This is the 0-truncated construction; it keeps orbits only.
setQuotient :: (Ord x) => GroupAction g x -> [x] -> [[x]]
setQuotient = orbits

-- | The automorphism count the groupoid quotient @X // G@ retains at @x@,
-- i.e. @|Stab_G(x)|@ (the loop space at @x@).
groupoidAutomorphisms :: (Eq x) => GroupAction g x -> x -> Int
groupoidAutomorphisms ga x = length (stabilizer ga x)

-- | The groupoid quotient retains gauge information at @x@ exactly when the
-- stabilizer is nontrivial (more than the identity loop) -- the content of
-- Theorem T4(c): then @X // G@ cannot be equivalent to @X / G@.
retainsGaugeInfo :: (Eq x) => GroupAction g x -> x -> Bool
retainsGaugeInfo ga x = groupoidAutomorphisms ga x > 1

-- | The orbit-stabilizer theorem at @x@: @|G| = |orbit(x)| * |Stab_G(x)|@.
-- Holds for any lawful action whose 'elements' enumerate the whole group
-- without repeats; it is the quantitative backbone of Theorem T4.
orbitStabilizerHolds :: (Ord x) => GroupAction g x -> x -> Bool
orbitStabilizerHolds ga x =
  length (elements ga)
    == length (orbit ga x) * length (stabilizer ga x)

-- ---------------------------------------------------------------------------
-- Concrete lawful examples
-- ---------------------------------------------------------------------------

-- | The cyclic group @Z/n@ (for @n >= 1@) with carrier @[0 .. n-1]@, addition
-- modulo @n@, unit @0@, and inverse @a |-> (n - a) mod n@. 'isGroup' certifies
-- it is a genuine group.
cyclicGroup :: Int -> FiniteGroup Int
cyclicGroup n = FiniteGroup
  { carrier = [0 .. n - 1]
  , gUnit   = 0
  , gMul    = \a b -> (a + b) `mod` n
  , gInv    = \a -> (n - a) `mod` n
  }

-- | The regular (left-translation) action of @Z/n@ on itself:
-- @g . x = (g + x) mod n@. It is free and transitive, so every stabilizer is
-- trivial and there is a single orbit -- the extreme where @X // G@ and
-- @X / G@ agree.
regularAction :: Int -> GroupAction Int Int
regularAction n = GroupAction
  { elements = [0 .. n - 1]
  , act      = \g x -> (g + x) `mod` n
  }

-- | Canonical witness: Z/2 acting trivially on a one-point set. The set
-- quotient is a single point (one orbit, no automorphisms); the groupoid
-- quotient is the delooping @B(Z/2)@ with automorphism group Z/2. This is the
-- minimal example where @X // G@ is strictly finer than @X / G@.
z2TrivialOnPoint :: GroupAction Int ()
z2TrivialOnPoint = GroupAction
  { elements = [0, 1]            -- Z/2 = {e, s}
  , act      = \_ _ -> ()        -- trivial action on the one point ()
  }
