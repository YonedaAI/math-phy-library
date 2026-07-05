-- |
-- Module      : Amplitude
-- Description : Motivic amplitude objects and the Conditional Amplitude
--               Decomposition theorem at the model level.
--
-- A motivic amplitude object A^m is modelled as a word carrying weight and
-- depth gradings.  A realization channel Real_alpha is a monoidal functor,
-- modelled as a letterwise map @g -> b@ extended to words.  The naturality
-- square below is Theorem (Conditional Amplitude Decomposition):
--   Delta'(Real w) = (Real (x) Real)(Delta' w).
module Amplitude
  ( MotivicAmplitude(..)
  , mkMotivicAmplitude
  , amWeight
  , amCoaction
  , realizeWord
  , coactionTransports
  ) where

import Coalgebra
import Data.List (sort)
import Numeric.Natural (Natural)

-- | A motivic amplitude object @A^m@: a word plus a depth grading (weight is
-- read off the word length).  The depth is a 'Natural', so the invalid state of
-- a negative iterated-integral nesting is unrepresentable at the type level.
data MotivicAmplitude g = MotivicAmplitude
  { amWord  :: Word' g   -- ^ the underlying pre-numerical word
  , amDepth :: Natural    -- ^ depth grading (iterated-integral nesting, >= 0)
  } deriving (Eq, Show)

-- | Smart constructor for a motivic amplitude object.  The 'Natural' depth
-- statically rules out negative depths; this is the recommended way to build a
-- 'MotivicAmplitude'.
mkMotivicAmplitude :: Word' g -> Natural -> MotivicAmplitude g
mkMotivicAmplitude = MotivicAmplitude

-- | Weight grading = word length.
amWeight :: MotivicAmplitude g -> Int
amWeight = weight . amWord

-- | The coaction @Delta(A^m) = sum_i A^m_{i,1} (x) A^m_{i,2}@ (reduced part).
amCoaction :: MotivicAmplitude g -> [(Word' g, Word' g)]
amCoaction = reducedCoproduct . amWord

-- | Realization of a word by a letterwise map @f : g -> b@ (a monoidal
-- functor on the free coalgebra).
realizeWord :: (g -> b) -> Word' g -> Word' b
realizeWord f (Word' gs) = Word' (map f gs)

-- | Naturality of the coaction under realization: the model form of
-- Theorem (Conditional Amplitude Decomposition).  Returns @True@ when
-- @Delta'(Real w)@ equals @(Real (x) Real)(Delta' w)@ as multisets.
coactionTransports :: Ord b => (g -> b) -> Word' g -> Bool
coactionTransports f w =
  let realized  = realizeWord f w
      viaTarget = sort (reducedCoproduct realized)
      viaSource = sort [ (realizeWord f a, realizeWord f b)
                       | (a, b) <- reducedCoproduct w ]
  in viaTarget == viaSource
