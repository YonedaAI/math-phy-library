{-# LANGUAGE ScopedTypeVariables #-}

-- | Module      : QuotientStack
--   Description : Quotient stacks [X/G] with retained stabiliser data,
--                 realising Proposition 5.3 (Aut_{[X/G]}(x) = Stab_G(x)) and
--                 Theorem 8.3 (stack strictly finer than coarse space) of Part III.
--
--   The essential invariant a stack retains and a coarse quotient forgets is
--   the automorphism group of each point. We model a finite group action
--   concretely so that stabilisers, orbits, and the resulting "strictly finer"
--   phenomenon can be printed.
module QuotientStack
  ( GAction(..)
  , GroupSpec(..)
  , QuotientStack(..)
  , stabilizer
  , orbit
  , coarseQuotient
  , mkQuotientStack
  , isStrictlyFiner
  , isGroup
  , isAction
  , stabilizerIsSubgroup
  , z4OnSquare
  , z4Group
  ) where

import Data.List (nub, sort)

-- | A finite group action: how each group element acts on a point, together
--   with an enumeration of the group elements (finite, for concreteness).
data GAction g x = GAction
  { act      :: g -> x -> x
  , elements :: [g]
  , points   :: [x]
  }

-- | A finite group specified by its carrier, binary operation, unit, and
--   inverse. Carrying the group laws explicitly (rather than treating
--   @elements@ as an unstructured label set) lets us machine-check the group
--   and action axioms, so that 'stabilizer' is verified to be a genuine
--   subgroup rather than an arbitrary list filter.
data GroupSpec g = GroupSpec
  { gUnit  :: g
  , gMul   :: g -> g -> g
  , gInv   :: g -> g
  , gElems :: [g]
  }

-- | Check the finite-group axioms for a 'GroupSpec': a non-empty, duplicate-free
--   carrier containing the unit; closure; associativity; two-sided identity; and
--   two-sided inverses that themselves lie in the carrier.
isGroup :: (Eq g) => GroupSpec g -> Bool
isGroup gs = wellFormed && closure && assoc && identity && inverses
  where
    es = gElems gs
    wellFormed = not (null es)
                 && length es == length (nub es)
                 && gUnit gs `elem` es
    closure  = and [ gMul gs a b `elem` es | a <- es, b <- es ]
    assoc    = and [ gMul gs (gMul gs a b) c == gMul gs a (gMul gs b c)
                   | a <- es, b <- es, c <- es ]
    identity = and [ gMul gs (gUnit gs) a == a && gMul gs a (gUnit gs) == a
                   | a <- es ]
    inverses = and [ gInv gs a `elem` es
                     && gMul gs a (gInv gs a) == gUnit gs
                     && gMul gs (gInv gs a) a == gUnit gs
                   | a <- es ]

-- | Check the group-action axioms for @A@ under @gs@: @gs@ is a genuine group;
--   the action's element and point carriers are duplicate-free; the group
--   carrier and the action's element list agree (as sets); the action is closed
--   (@g . x@ stays in the point set); the unit acts trivially (@e . x = x@); and
--   the action is compatible with multiplication (@(g h) . x = g . (h . x)@).
isAction :: (Eq g, Eq x) => GroupSpec g -> GAction g x -> Bool
isAction gs ga = wellFormed && carrierAgrees && closed && unitActs && compatible
  where
    es = elements ga
    ps = points ga
    wellFormed = isGroup gs
                 && length es == length (nub es)
                 && length ps == length (nub ps)
    carrierAgrees = all (`elem` es) (gElems gs) && all (`elem` gElems gs) es
    closed     = and [ act ga g x `elem` ps | g <- es, x <- ps ]
    unitActs   = all (\x -> act ga (gUnit gs) x == x) ps
    compatible = and [ act ga (gMul gs g h) x == act ga g (act ga h x)
                     | g <- gElems gs, h <- gElems gs, x <- ps ]

-- | Verify that the stabiliser of @x@ is a genuine subgroup of @G@ (presupposing
--   @gs@ is a valid group): it is a subset of the group carrier, contains the
--   identity, and is closed under the group operation and inverses
--   (Proposition 5.3, so that @Aut_{[X/G]}(x)@ really is a group).
stabilizerIsSubgroup :: (Eq g, Eq x) => GroupSpec g -> GAction g x -> x -> Bool
stabilizerIsSubgroup gs ga x =
     isGroup gs
  && all (`elem` gElems gs) s
  && gUnit gs `elem` s
  && and [ gMul gs a b `elem` s | a <- s, b <- s ]
  && all (\a -> gInv gs a `elem` s) s
  where s = stabilizer ga x

-- | Stabiliser of a point: { g | g . x == x }.
--   By Proposition 5.3 this is exactly Aut_{[X/G]}(x), the automorphism group
--   of x as an object of the quotient stack.
stabilizer :: (Eq x) => GAction g x -> x -> [g]
stabilizer ga x = [ g | g <- elements ga, act ga g x == x ]

-- | Orbit of a point: { g . x }.
orbit :: (Eq x) => GAction g x -> x -> [x]
orbit ga x = nub [ act ga g x | g <- elements ga ]

-- | The coarse quotient X/G, as the set of orbits. It remembers *which* points
--   are identified but forgets *how* (it discards the stabiliser/automorphism
--   data). We present an orbit by its sorted list of members.
coarseQuotient :: (Eq x, Ord x) => GAction g x -> [[x]]
coarseQuotient ga = nub [ sort (orbit ga x) | x <- points ga ]

-- | A quotient stack remembers, for each point, its automorphism group
--   (= stabiliser). This is the extra data over the coarse quotient.
data QuotientStack g x = QuotientStack
  { action   :: GAction g x
  , autGroup :: x -> [g]   -- x |-> Stab_G(x) = Aut_{[X/G]}(x)
  }

-- | Build the quotient stack of an action, wiring in the stabiliser as the
--   automorphism-group assignment (Proposition 5.3).
mkQuotientStack :: (Eq x) => GAction g x -> QuotientStack g x
mkQuotientStack ga = QuotientStack
  { action   = ga
  , autGroup = stabilizer ga
  }

-- | Theorem 8.3 (constructive witness): the stack is strictly finer than the
--   coarse space iff some point has a nontrivial stabiliser (|Stab| > 1).
--   When True, the coarse quotient has lost genuine gauge-automorphism data.
isStrictlyFiner :: (Eq x) => QuotientStack g x -> Bool
isStrictlyFiner qs =
  any (\x -> length (autGroup qs x) > 1) (points (action qs))

-- | Concrete example: Z/4 acting on the 4 vertices of a square by rotation,
--   together with an added *fixed centre* point c that every rotation fixes.
--   The centre has full stabiliser Z/4 (a nontrivial gauge automorphism group),
--   exactly the [A^1 / G_m] symmetric-point phenomenon of Section 10.2.
data Sq = V0 | V1 | V2 | V3 | Centre deriving (Eq, Ord, Show)

z4OnSquare :: GAction Int Sq
z4OnSquare = GAction
  { act      = rot
  , elements = [0, 1, 2, 3]      -- Z/4
  , points   = [V0, V1, V2, V3, Centre]
  }
  where
    rot _ Centre = Centre         -- the centre is fixed by every rotation
    rot k v      = iterate step v !! (k `mod` 4)
    step V0 = V1
    step V1 = V2
    step V2 = V3
    step V3 = V0
    step Centre = Centre

-- | The cyclic group Z/4 as an explicit 'GroupSpec' (addition mod 4), under
--   which 'z4OnSquare' is a lawful action. Used to machine-check the group and
--   action axioms and that stabilisers are subgroups (Proposition 5.3).
z4Group :: GroupSpec Int
z4Group = GroupSpec
  { gUnit  = 0
  , gMul   = \a b -> (a + b) `mod` 4
  , gInv   = \a -> (4 - a) `mod` 4
  , gElems = [0, 1, 2, 3]
  }
