-- |
-- Module      : Coalgebra
-- Description : Graded coalgebra of words with the (Goncharov-style)
--               deconcatenation coproduct, reduced coproduct, cobracket,
--               and decidable primitivity.
--
-- This module encodes the coalgebraic anatomy of Part II
-- ("Motives, Periods, and Amplitudes"): a motivic amplitude object is
-- modelled as a formal word in weight-one generators, its coaction is the
-- deconcatenation coproduct, the cobracket is the antisymmetrized reduced
-- coproduct, and the primitives are exactly the weight <= 1 words
-- (Theorem: Weight-graded primitives generate the Goncharov Lie coalgebra).
module Coalgebra
  ( Word'(..)
  , weight
  , emptyWord
  , coproduct
  , reducedCoproduct
  , cobracket
  , cobracketExterior
  , isPrimitive
  , coproductLeft
  , coproductRight
  , coassocHolds
  , anatomyDepth
  ) where

import Data.List (nub, sort)

-- | A word in generators of type @g@.  Weight is the word length; this is
-- the transcendental-weight grading of the amplitude dictionary.
newtype Word' g = Word' { letters :: [g] } deriving (Eq, Ord)

instance Show g => Show (Word' g) where
  show (Word' []) = "1"
  show (Word' gs) = concatMap show gs

-- | Weight = word length (transcendentality / loop depth in the dictionary).
weight :: Word' g -> Int
weight (Word' gs) = length gs

-- | The counit's support: the empty word (weight zero, the unit).
emptyWord :: Word' g
emptyWord = Word' []

-- | Deconcatenation coproduct
--   @Delta(w) = sum_{k=0}^{|w|} (take k w) (x) (drop k w)@.
-- This is the model coaction @Delta(A^m) = sum_i A^m_{i,1} (x) A^m_{i,2}@.
coproduct :: Word' g -> [(Word' g, Word' g)]
coproduct (Word' xs) =
  [ (Word' (take k xs), Word' (drop k xs)) | k <- [0 .. length xs] ]

-- | Reduced coproduct: strip the two trivial terms @1 (x) w@ and @w (x) 1@.
-- This is the physically meaningful part @Delta' = Delta - (id (x) 1) - (1 (x) id)@.
reducedCoproduct :: Word' g -> [(Word' g, Word' g)]
reducedCoproduct w =
  [ (a, b) | (a, b) <- coproduct w, weight a > 0, weight b > 0 ]

-- | Cobracket @delta = pi . Delta'@: antisymmetrization of the reduced
-- coproduct.  Returns signed pairs; @(a,b,+1)@ and @(b,a,-1)@ encode
-- @a /\ b@.
--
-- NOTE: this is a formal signed sum with like terms NOT combined; it is a
-- deliberately naive representation of an element of the exterior algebra
-- @Lambda^2 L@ (adequate for the demonstration, not a normal form).
cobracket :: Word' g -> [(Word' g, Word' g, Rational)]
cobracket w =
  [ (a, b, 1)  | (a, b) <- reducedCoproduct w ] ++
  [ (b, a, -1) | (a, b) <- reducedCoproduct w ]

-- | Normalized cobracket as a genuine element of the exterior square
-- @Lambda^2 L@: like terms are combined, diagonal terms @a /\ a@ vanish, and
-- each surviving wedge is recorded once in canonical order @a < b@ with its net
-- integer coefficient.  Whereas 'cobracket' is a formal signed sum (so a
-- repeated-letter word yields cancelling terms rather than @0@), this is the
-- honest value in @Lambda^2 L@ that the antisymmetrization @pi . Delta'@
-- produces: e.g. @cobracketExterior (Word' [a,a]) == []@ and
-- @cobracketExterior (Word' [a,a,a]) == []@ because @a /\ (aa) - (aa) /\ a = 0@.
cobracketExterior :: Ord g => Word' g -> [(Word' g, Word' g, Rational)]
cobracketExterior w =
  [ (a, b, coeff a b)
  | (a, b) <- basis
  , coeff a b /= 0
  ]
  where
    splits = reducedCoproduct w
    -- Canonical basis wedges: unordered pairs @{a,b}@ with @a < b@ that occur
    -- (in either orientation) among the reduced splits.
    basis = nub [ (min a b, max a b) | (a, b) <- splits, a /= b ]
    -- Net coefficient of the wedge @a /\ b@ (a < b): occurrences of @(a,b)@ in
    -- the reduced coproduct minus occurrences of @(b,a)@.
    coeff a b = fromIntegral (occ a b - occ b a) :: Rational
    occ x y = length [ () | (p, q) <- splits, p == x, q == y ]

-- | Primitivity is decidable: @delta(x) = 0@ iff the reduced coproduct is
-- empty iff @weight x <= 1@.  Weight-one primitives are the logarithms
-- @F^x (x) Q@ of the generation theorem.
isPrimitive :: Word' g -> Bool
isPrimitive w = null (reducedCoproduct w)

-- | Left iterate @(Delta (x) id) . Delta@.
coproductLeft :: Word' g -> [(Word' g, Word' g, Word' g)]
coproductLeft w =
  [ (a1, a2, b) | (a, b) <- coproduct w, (a1, a2) <- coproduct a ]

-- | Right iterate @(id (x) Delta) . Delta@.
coproductRight :: Word' g -> [(Word' g, Word' g, Word' g)]
coproductRight w =
  [ (a, b1, b2) | (a, b) <- coproduct w, (b1, b2) <- coproduct b ]

-- | Coassociativity check as a multiset equality of the two iterates.
coassocHolds :: Ord g => Word' g -> Bool
coassocHolds w = sort (coproductLeft w) == sort (coproductRight w)

-- | Depth of the coalgebraic anatomy tree: the number of reduced-coproduct
-- steps needed to reduce @w@ to primitive (weight-one) leaves.
-- For a weight-@n@ word this equals @n - 1@ (Proposition: Termination).
anatomyDepth :: Word' g -> Int
anatomyDepth w
  | isPrimitive w = 0
  | otherwise =
      1 + maximum (0 : [ max (anatomyDepth a) (anatomyDepth b)
                       | (a, b) <- reducedCoproduct w ])
