-- | Module      : QHA
--   Part VI of "A Math->Physics Representation Library".
--
--   Quantum high-availability (QHA) encodings (paper Definition (Quantum
--   high-availability representation) and Section 6).  An encoding embeds a
--   logical space into a larger physical space; an equivalence groupoid of
--   physical variations leaves logical observables invariant; a syndrome
--   detects the error sector and a recovery map returns to the code space.
--
--   The subsystem decomposition realized here is the master formula
--
--       H_phys  ~=  (H_log (x) H_gauge)  (+)  H_err .
--
--   'availability' reports the redundancy dim H_phys / dim H_log.
module QHA
  ( Syndrome
  , QHAEncoding(..)
  , subsystemDim
  , availability
  , correct
  , trivialSyndrome
  ) where

-- | A syndrome is the outcome of the error/gauge-sector detector.
type Syndrome = [Int]

-- | A QHA encoding between a logical and a physical carrier type.
data QHAEncoding hLogical hPhys = QHAEncoding
  { embed        :: hLogical -> hPhys              -- ^ iota : H_log -> H_phys
  , equivalences :: [hPhys -> hPhys]               -- ^ allowed gauge variations
  , syndromeOf   :: hPhys -> Syndrome              -- ^ error/gauge-sector detector
  , correctable  :: Syndrome -> Maybe (hPhys -> hPhys) -- ^ recovery map
  , dimLogical   :: Integer                        -- ^ dim H_log
  , dimGauge     :: Integer                        -- ^ dim H_gauge (redundancy)
  , dimError     :: Integer                        -- ^ dim H_err (syndrome sectors)
  }

-- | dim H_phys reconstructed from the subsystem decomposition
--   H_phys ~= (H_log (x) H_gauge) (+) H_err.
--   A well-formed encoding has nonnegative subsystem dimensions; each factor is
--   clamped at 0 so a degenerate encoding with a negative declared dimension can
--   never produce a negative total.  Dimensions are 'Integer' (unbounded), so no
--   fixed-width overflow can turn a large product negative either.
subsystemDim :: QHAEncoding a b -> Integer
subsystemDim e =
  max 0 (dimLogical e) * max 0 (dimGauge e) + max 0 (dimError e)

-- | Availability = redundancy factor dim H_phys / dim H_log (as a Double).
--   A well-formed encoding has @dimLogical > 0@; for a degenerate encoding with a
--   nonpositive logical dimension we return @0@ rather than a @NaN@/infinity.
availability :: QHAEncoding a b -> Double
availability e
  | dimLogical e <= 0 = 0
  | otherwise         =
      fromIntegral (subsystemDim e) / fromIntegral (dimLogical e)

-- | The trivial syndrome (no error detected).
trivialSyndrome :: Syndrome
trivialSyndrome = []

-- | Attempt to correct a physical state: measure its syndrome, and if the
--   sector is correctable, apply the recovery map.
correct :: QHAEncoding a b -> b -> Maybe b
correct e phys =
  case correctable e (syndromeOf e phys) of
    Just recover -> Just (recover phys)
    Nothing      -> Nothing
