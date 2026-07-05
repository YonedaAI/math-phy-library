-- |
-- Module      : Period
-- Description : Period data and the period map, with a numerical
--               demonstration of multiplicativity of the period pairing.
--
-- Encodes Definition (Period datum) Pi = (X, D, omega, Gamma) and the period
-- map per(Pi) = \int_Gamma omega, together with Theorem
-- (Multiplicativity of the period pairing):
--   per(Pi_1 (+) Pi_2) = per(Pi_1) + per(Pi_2)   (additivity)
--   per(Pi_1 (x) Pi_2) = per(Pi_1) * per(Pi_2)   (multiplicativity)
module Period
  ( PeriodDatum(..)
  , per
  , tensorDatum
  , directSumDatum
  , kummerLog
  , mkKummerLog
  , isFinitePeriod
  , checkMultiplicative
  , checkAdditive
  ) where

-- | A period datum @Pi = (X, D, omega, Gamma)@.  For the runnable
-- demonstration we carry a human-readable label and the precomputed numeric
-- value of the pairing @\int_Gamma omega@ (a real number here; complex in
-- general).
data PeriodDatum = PeriodDatum
  { pdSpace   :: String   -- ^ X (label)
  , pdDivisor :: String   -- ^ D (label)
  , pdForm    :: String   -- ^ omega (label)
  , pdCycle   :: String   -- ^ Gamma (label)
  , pdValue   :: Double    -- ^ the numeric period \int_Gamma omega
  } deriving (Eq, Show)

-- | The period map @per(Pi) = \int_Gamma omega@.
per :: PeriodDatum -> Double
per = pdValue

-- | The Kummer period datum for @H^1(G_m, {1,x})@ whose period is @log x@
-- (Example: the logarithm as a weight-two period).
--
-- PRECONDITION: @x > 0@ (the domain of @log@).  For @x <= 0@ (or non-finite
-- @x@) the period is not defined; use 'mkKummerLog' to obtain a validated,
-- total constructor that rejects out-of-domain inputs.
kummerLog :: Double -> PeriodDatum
kummerLog x = PeriodDatum
  { pdSpace   = "G_m"
  , pdDivisor = "{1," ++ show x ++ "}"
  , pdForm    = "dt/t"
  , pdCycle   = "path 1 -> " ++ show x
  , pdValue   = log x
  }

-- | Validated Kummer constructor: returns 'Nothing' when @x@ is out of the
-- @log@ domain (non-positive) or non-finite, so that no invalid period datum
-- (with @NaN@/@Infinity@ value) can be formed.  For @x > 0@ finite it yields
-- @'Just' ('kummerLog' x)@, whose value @log x@ is guaranteed finite.
mkKummerLog :: Double -> Maybe PeriodDatum
mkKummerLog x
  | x > 0 && not (isNaN x) && not (isInfinite x) = Just (kummerLog x)
  | otherwise                                    = Nothing

-- | A period datum is finite when its numeric value is neither @NaN@ nor
-- @Infinity@.  'mkKummerLog' guarantees a finite value for in-domain inputs.
-- NOTE: 'tensorDatum' and 'directSumDatum' do /not/ preserve finiteness in
-- general -- the product or sum of two finite 'Double' periods can still
-- overflow to @Infinity@ (e.g. for inputs near @1e308@).  This predicate is
-- precisely how such floating-point overflow is detected.
isFinitePeriod :: PeriodDatum -> Bool
isFinitePeriod pd = not (isNaN v) && not (isInfinite v)
  where v = pdValue pd

-- | Product period datum
--   @Pi_1 (x) Pi_2 = (X_1 x X_2, D_1 x X_2 u X_1 x D_2, omega_1 /\ omega_2,
--    Gamma_1 x Gamma_2)@ with period @per(Pi_1) * per(Pi_2)@.
tensorDatum :: PeriodDatum -> PeriodDatum -> PeriodDatum
tensorDatum a b = PeriodDatum
  { pdSpace   = pdSpace a ++ " x " ++ pdSpace b
  , pdDivisor = pdDivisor a ++ " u " ++ pdDivisor b
  , pdForm    = pdForm a ++ " /\\ " ++ pdForm b
  , pdCycle   = pdCycle a ++ " x " ++ pdCycle b
  , pdValue   = pdValue a * pdValue b
  }

-- | Direct-sum (disjoint-cycle) period datum with period
--   @per(Pi_1) + per(Pi_2)@ (same X, D, omega; disjoint cycles).
directSumDatum :: PeriodDatum -> PeriodDatum -> PeriodDatum
directSumDatum a b = PeriodDatum
  { pdSpace   = pdSpace a
  , pdDivisor = pdDivisor a
  , pdForm    = pdForm a
  , pdCycle   = pdCycle a ++ " (+) " ++ pdCycle b
  , pdValue   = pdValue a + pdValue b
  }

-- | Numerical verification that @per(Pi_1 (x) Pi_2) = per(Pi_1) * per(Pi_2)@.
checkMultiplicative :: PeriodDatum -> PeriodDatum -> Bool
checkMultiplicative a b =
  abs (per (tensorDatum a b) - per a * per b) < 1e-12

-- | Numerical verification that @per(Pi_1 (+) Pi_2) = per(Pi_1) + per(Pi_2)@.
checkAdditive :: PeriodDatum -> PeriodDatum -> Bool
checkAdditive a b =
  abs (per (directSumDatum a b) - (per a + per b)) < 1e-12
