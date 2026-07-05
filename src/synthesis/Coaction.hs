-- | Module      : Coaction
--   Part VII (Synthesis), Part II face: coalgebraic anatomy.
--
--   A small honest representative of the "one Hopf/coalgebra of decomposition"
--   principle (synthesis Principle "Universal decomposition", eq. mf5--mf6).
--   We model a graded connected coalgebra on words (a stand-in for
--   polylogarithm symbols / boundary strata / rooted trees) whose coproduct is
--   the /deconcatenation coaction/
--
--     Delta(w) = sum over splittings   w_1 (x) w_2   with   w_1 ++ w_2 = w.
--
--   Deconcatenation is coassociative and connected (only the empty word sits
--   in degree 0), realizing the paper's claim that decomposition of an
--   amplitude is a genuine coalgebra operation:  @Amp = per(Amp^m)@ with
--   @Delta(Amp^m) = sum_i Amp^m_{i,1} (x) Amp^m_{i,2}@ (synthesis eq. mf5).
module Coaction
  ( -- * Words as a graded connected coalgebra
    Symbol
  , degree
    -- * The coaction (coproduct) and counit
  , coproduct
  , counit
    -- * Iterated coactions (used to state coassociativity)
  , leftCoaction
  , rightCoaction
  ) where

-- | A "symbol": a word in an alphabet, standing for one generator of the
--   coalgebra of decomposition.  Its 'degree' is its length (the analogue of
--   transcendental weight / number of boundary strata).
type Symbol a = [a]

-- | The grading: the weight of a symbol is its length.  The coalgebra is
--   /connected/ -- the only degree-0 element is the empty word.
degree :: Symbol a -> Int
degree = length

-- | The deconcatenation coaction @Delta@ (synthesis eq. mf5): all ordered
--   splittings of @w@ into a left and a right factor.  Returned as the list of
--   summands @(w_1, w_2)@ with @w_1 ++ w_2 == w@.
coproduct :: Symbol a -> [(Symbol a, Symbol a)]
coproduct xs = [ splitAt i xs | i <- [0 .. length xs] ]

-- | The counit @epsilon@: @1@ on the empty word (the group-like unit) and @0@
--   otherwise.  This is the connectedness datum of the coalgebra.
counit :: Symbol a -> Int
counit [] = 1
counit _  = 0

-- | @(Delta (x) id) . Delta@: split, then re-split the /left/ factor,
--   producing all ordered 3-part decompositions via the left branch.
leftCoaction :: Symbol a -> [(Symbol a, Symbol a, Symbol a)]
leftCoaction xs =
  [ (a1, a2, b)
  | (a, b)   <- coproduct xs
  , (a1, a2) <- coproduct a
  ]

-- | @(id (x) Delta) . Delta@: split, then re-split the /right/ factor.  By
--   coassociativity 'leftCoaction' and 'rightCoaction' agree as multisets --
--   both enumerate @{(u,v,w) : u ++ v ++ w == xs}@.
rightCoaction :: Symbol a -> [(Symbol a, Symbol a, Symbol a)]
rightCoaction xs =
  [ (a, b1, b2)
  | (a, b)   <- coproduct xs
  , (b1, b2) <- coproduct b
  ]
