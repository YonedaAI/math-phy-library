-- | Module      : Closure
--   Part VII (Synthesis): the Closure Theorem keystone.
--
--   Assembles the isotropy correspondence and its physical face (synthesis
--   Theorem "Closure Theorem", eqs. mf7--mf8):
--
--     Aut_{[X/G]}(x) ~= Stab_G(x)        (isotropy keystone; 'Gauge.isotropy')
--     H_phys ~= (H_log (x) H_gauge) (+) H_err   (high-availability decomposition)
--
--   and the identification /gauge redundancy = quantum high availability/:
--   both are instances of the same "many physical representatives, one logical
--   content" factorization @total = content * redundancy (+ error)@.  On the
--   gauge side this is orbit-stabilizer (@|G| = |orbit| * |Stab|@); on the QEC
--   side it is the subsystem-code dimension count (@2^n = 2^r * 2^{k+g}@,
--   PVI/T3), with the genus-@g@ surface code carrying logical dimension
--   @2^{2g}@.
module Closure
  ( -- * The redundancy factorization (both faces of the keystone)
    redundancyFactorization
    -- * Gauge face: orbit-stabilizer as redundancy = content x redundancy
  , gaugeRedundancy
    -- * QEC face: subsystem decomposition H_phys = (H_log (x) H_gauge) (+) H_err
    --
    -- The 'CodeParams' constructor is hidden; build parameters with
    -- 'mkCodeParams', which sets @n = k + g + r@ by construction, so an
    -- inconsistent parameter set is unrepresentable.
  , CodeParams
  , nPhys, kLog, gGauge, rStab
  , mkCodeParams
  , Subsystem(..)
  , subsystemDims
  , validSubsystem
  , surfaceCode
    -- * The keystone check on a worked example
  , keystoneHolds
  ) where

import Numeric.Natural (Natural)

import Gauge    (Group, groupElems, isotropy, orbit, stabilizer)
import Homology (h1Rank)

-- | The universal redundancy law shared by both faces of the keystone:
--   @total == content * redundancy@.  "Content" is the gauge-invariant /
--   logical part; "redundancy" is the multiplicity of physical representatives.
redundancyFactorization :: Integer -> Integer -> Integer -> Bool
redundancyFactorization total content redundancy =
  total == content * redundancy

-- | Gauge face.  For a group action @G @<@ X@ at a point @x@, orbit-stabilizer
--   presents @|G|@ as @content * redundancy@ with @content = |orbit|@ (the
--   distinct logical outcomes) and @redundancy = |Stab_G(x)|@ (the physically
--   equivalent representatives that leave the content fixed).  Returns
--   @(total, content, redundancy, holds)@.
gaugeRedundancy :: Group -> Int -> (Integer, Integer, Integer, Bool)
gaugeRedundancy g x =
  let total      = fromIntegral (length (groupElems g))
      content    = fromIntegral (length (orbit g x))
      redundancy = fromIntegral (length (stabilizer g x))
  in (total, content, redundancy, redundancyFactorization total content redundancy)

-- | Parameters of a stabilizer / subsystem code: @n@ physical qubits split as
--   @n = k + g + r@ into @k@ logical, @g@ gauge and @r@ stabilizer
--   (syndrome-generator) qubits.  Counts are 'Natural', so negative qubit
--   counts (which would fake dimensions via a negative exponent) are
--   unrepresentable.
data CodeParams = CodeParams
  { nPhys  :: Natural  -- ^ physical qubits @n@
  , kLog   :: Natural  -- ^ logical qubits @k@
  , gGauge :: Natural  -- ^ gauge qubits @g@
  , rStab  :: Natural  -- ^ stabilizer generators @r@ (@n = k + g + r@)
  } deriving (Eq, Show)

-- | Build code parameters from @k@ logical, @g@ gauge and @r@ stabilizer
--   qubits; the physical count @n = k + g + r@ is derived, so the invariant
--   @n = k + g + r@ holds by construction.
mkCodeParams :: Natural -> Natural -> Natural -> CodeParams
mkCodeParams k g r =
  CodeParams { nPhys = k + g + r, kLog = k, gGauge = g, rStab = r }

-- | The subsystem decomposition @H_phys ~= (H_log (x) H_gauge) (+) H_err@
--   (synthesis eq. mf8), recorded by the dimensions of its parts.
data Subsystem = Subsystem
  { physDim  :: Integer  -- ^ @dim H_phys  = 2^n@
  , logDim   :: Integer  -- ^ @dim H_log   = 2^k@
  , gaugeDim :: Integer  -- ^ @dim H_gauge = 2^g@
  , errDim   :: Integer  -- ^ @dim H_err   = 2^n - 2^{k+g}@
  , sectors  :: Integer  -- ^ number of syndrome sectors @2^r@
  } deriving (Eq, Show)

-- | Read off the subsystem dimensions from code parameters.  Because counts
--   are 'Natural', every exponent is non-negative by construction (no clamping).
subsystemDims :: CodeParams -> Subsystem
subsystemDims cp = Subsystem
  { physDim  = pow (nPhys cp)
  , logDim   = pow (kLog cp)
  , gaugeDim = pow (gGauge cp)
  , errDim   = pow (nPhys cp) - pow (kLog cp + gGauge cp)
  , sectors  = pow (rStab cp)
  }
  where
    pow :: Natural -> Integer
    pow e = (2 :: Integer) ^ e

-- | The two master identities of the high-availability decomposition
--   (synthesis eq. mf8):
--
--     (a)  H_phys = (H_log (x) H_gauge) (+) H_err
--          i.e. @physDim = logDim * gaugeDim + errDim@;
--     (b)  the whole space is @sectors@ copies of one @(H_log (x) H_gauge)@
--          sector, i.e. @physDim = sectors * (logDim * gaugeDim)@.
--
--   Both hold precisely when @n = k + g + r@.
validSubsystem :: CodeParams -> Subsystem -> Bool
validSubsystem cp s =
     nPhys cp == kLog cp + gGauge cp + rStab cp
  && physDim s == logDim s * gaugeDim s + errDim s
  && physDim s == sectors s * (logDim s * gaugeDim s)

-- | The genus-@g@ surface code as a subsystem-code parameter set: no gauge
--   qubits, @k = 2g = rank H_1(Sigma_g; Z_2)@ logical qubits, and @r = n - k@
--   stabilizer generators over @n@ physical qubits (@n >= 2g@).  Its logical
--   dimension is @2^{2g}@ (synthesis PVI/T3, eq. mf8).
surfaceCode :: Natural -> Natural -> CodeParams
surfaceCode g n =
  let k  = h1Rank g          -- 2g logical qubits (>= 0)
      nn = max n k           -- need at least k physical qubits
  in mkCodeParams k 0 (nn - k)

-- | The isotropy keystone at a worked example: @Aut_{[X/G]}(x) ~= Stab_G(x)@
--   /and/ orbit-stabilizer holds, so the gauge redundancy is well defined.
keystoneHolds :: Group -> Int -> Bool
keystoneHolds g x =
  let (_, _, _, ok) = gaugeRedundancy g x
  in isotropy g x && ok
