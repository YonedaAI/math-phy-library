{-# LANGUAGE RankNTypes #-}

-- |
-- Module      : RepCat
-- Description : Categories, functors, and natural transformations for
--               Part V (Category Theory and HoTT) of the Math->Physics
--               Representation Library.
--
-- This module encodes the composition/identity structures of Section 3 of
-- the paper: the 'Category' class (associativity + unit laws), functors as
-- structure-preserving translations, and natural transformations as uniform
-- deformations satisfying the naturality square (Definition 3.5).
module RepCat
  ( Category(..)
  , Fn(..)
  , (>>>)
  , leftUnitHolds
  , rightUnitHolds
  , assocHolds
  , functorPreservesComposition
  , NatTrans(..)
  , safeHead
  , naturalitySquareHolds
  ) where

-- | A category: a collection of objects (implicit as type indices) with a
-- morphism type @cat a b@, an identity morphism, and an associative,
-- unital composition. Mirrors Definition 3.1 of the paper.
class Category cat where
  identity :: cat a a
  compose  :: cat b c -> cat a b -> cat a c

-- | The category whose morphisms are ordinary functions (a stand-in for the
-- ambient category @Set@ / @Hask@).
newtype Fn a b = Fn { runFn :: a -> b }

instance Category Fn where
  identity            = Fn (\x -> x)
  compose (Fn g) (Fn f) = Fn (\x -> g (f x))

-- | Diagrammatic-order composition @f >>> g = compose g f@ ("do f, then g").
(>>>) :: Category cat => cat a b -> cat b c -> cat a c
f >>> g = compose g f
infixl 1 >>>

-- | Check the left unit law @identity . f == f@ on a sample of inputs
-- (Equation (unit) of the paper).
leftUnitHolds :: (Eq b) => Fn a b -> [a] -> Bool
leftUnitHolds f xs =
  all (\x -> runFn (compose identity f) x == runFn f x) xs

-- | Check the right unit law @f . identity == f@.
rightUnitHolds :: (Eq b) => Fn a b -> [a] -> Bool
rightUnitHolds f xs =
  all (\x -> runFn (compose f identity) x == runFn f x) xs

-- | Check associativity @h . (g . f) == (h . g) . f@ (Equation (assoc)).
assocHolds :: (Eq d) => Fn c d -> Fn b c -> Fn a b -> [a] -> Bool
assocHolds h g f xs =
  all (\x -> runFn (compose h (compose g f)) x
          == runFn (compose (compose h g) f) x) xs

-- | Functoriality law @F(g . f) == F g . F f@ (Equation (functor-laws)).
-- We use the concrete endofunctor @Maybe@ acting on function-morphisms via
-- 'fmap'; this witnesses that a functor preserves composition.
functorPreservesComposition
  :: (Eq c) => (b -> c) -> (a -> b) -> [Maybe a] -> Bool
functorPreservesComposition g f xs =
  all (\m -> fmap (g . f) m == (fmap g . fmap f) m) xs

-- | A natural transformation @F => G@ between functors valued in a target
-- category @d@ (Definition 3.5): a polymorphic family of components that are
-- morphisms /in @d@/, not hardcoded Haskell functions. The target category is
-- an explicit parameter, so components live in @d (f a) (g a)@; naturality is
-- checked separately.
newtype NatTrans d f g = NatTrans { component :: forall a. d (f a) (g a) }

-- | The canonical natural transformation @[] => Maybe@ taking the head, with
-- components in the function category 'Fn' (our stand-in for @Set@).
safeHead :: NatTrans Fn [] Maybe
safeHead = NatTrans (Fn (\xs -> case xs of { []    -> Nothing
                                           ; (y:_) -> Just y }))

-- | Check the naturality square (Equation (naturality)):
-- @fmap f . eta == eta . fmap f@ for the component 'safeHead'. The component
-- is run through 'runFn' because it is a morphism in the target category 'Fn'.
naturalitySquareHolds :: (Eq c) => (a -> c) -> [[a]] -> Bool
naturalitySquareHolds f xss =
  all (\xs -> fmap f (runFn (component safeHead) xs)
           == runFn (component safeHead) (fmap f xs)) xss
