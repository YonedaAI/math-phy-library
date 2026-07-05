-- | Module      : Properties
--   Part VII (Synthesis): QuickCheck properties for the Closure Theorem and the
--   modular composition ladder.
--
--   Each property encodes a mathematical claim of the synthesis (not an
--   implementation detail); the Haddock note names the corresponding theorem /
--   master formula of papers/latex/synthesis.tex.
--
--     PI/T3  (status calculus)      : composition takes status to @max@.
--     eq.mf5 (coaction)             : deconcatenation coaction is coassociative.
--     eq.mf7 (isotropy keystone)    : Aut_{[X/G]}(x) ~= Stab_G(x); orbit-stab.
--     eq.mf8 (high availability)    : H_phys = (H_log (x) H_gauge) (+) H_err;
--                                     surface-code logical dim 2^{2g}.
--     Table "ladder" (composition)  : builds-on composition is associative.
module Properties
  ( -- * Arbitrary wrappers
    AnyStatus(..)
  , WordCase(..)
  , ActionCase(..)
  , Genus(..)
  , CodeCase(..)
  , ChainCase(..)
  , FourRungs(..)
  , RungCase(..)
  , ValidComplex(..)
    -- * Part I : status calculus (PI/T3)
  , prop_statusAssoc
  , prop_statusCommutative
  , prop_statusIdempotent
  , prop_statusUnit
  , prop_statusMonoidAssoc
  , prop_statusNeverImproves
  , prop_worstOfIsUpperBound
    -- * Part II : coalgebraic anatomy (eq. mf5)
  , prop_coproductReconstructs
  , prop_coproductGraded
  , prop_coactionCoassociative
  , prop_counitLeft
    -- * Parts III/VI : isotropy keystone (eq. mf7)
  , prop_isotropyAutEqStab
  , prop_orbitStabilizer
  , prop_stabilizerIsSubgroup
  , prop_generatedIsGroup
  , prop_generatedGroupAlwaysValid
  , prop_keystoneHolds
    -- * Parts IV/VI : high availability and surface codes (eq. mf8)
  , prop_h1RankIs2g
  , prop_surfaceLogicalDim
  , prop_surfaceEuler
  , prop_boundarySquaredZero
  , prop_eulerRelation
  , prop_randomBoundarySquaredZero
  , prop_generatedComplexWellFormed
  , prop_subsystemMasterFormula
  , prop_surfaceCodeValid
  , prop_gaugeEqualsQEC
    -- * Part V + ladder : compositional grammar (Table "ladder")
  , prop_morComposeTransitive
  , prop_morComposeAssoc
  , prop_commutingTriangle
  , prop_entryComposeAssoc
  , prop_ladderStatusIsWorst
    -- * Runner
  , runAllProperties
  ) where

import Numeric.Natural (Natural)
import Test.QuickCheck   -- exports isSuccess, stdArgs, quickCheckWithResult, etc.

import Closure
import Coaction
import Gauge
import Homology
import Ladder
import Status

-- ------------------------------------------------------------------
-- Arbitrary wrappers
-- ------------------------------------------------------------------

-- | An arbitrary epistemic status.
newtype AnyStatus = AnyStatus Status
  deriving (Eq, Show)

instance Arbitrary AnyStatus where
  arbitrary = AnyStatus <$> elements [S, H, P]

-- | A bounded-length word for the coaction coalgebra.
newtype WordCase = WordCase [Int]
  deriving (Eq, Show)

instance Arbitrary WordCase where
  arbitrary = do
    n <- choose (0, 12)
    WordCase <$> vectorOf n (choose (0, 5 :: Int))

-- | A finite group action @G @<@ X@ together with a base point @x@.
data ActionCase = ActionCase Group Int
  deriving (Eq, Show)

instance Arbitrary ActionCase where
  arbitrary = do
    n    <- choose (1, 4)
    kind <- choose (0, 2 :: Int)
    grp  <- case kind of
      0 -> pure (symmetricGroup n)
      1 -> pure (cyclicGroup n)
      _ -> do
        ng   <- choose (1, 2)
        gens <- vectorOf ng (shuffle [0 .. n - 1])
        pure (generatedGroup n gens)
    x <- choose (0, n - 1)
    pure (ActionCase grp x)

-- | An arbitrary rung of the ladder (wrapped to avoid an orphan instance).
newtype RungCase = RungCase Rung
  deriving (Eq, Show)

instance Arbitrary RungCase where
  arbitrary = RungCase <$> elements allRungs

-- | An arbitrary genus @g@ in @[0,8]@ (as a 'Natural': no negative genus).
newtype Genus = Genus Natural
  deriving (Eq, Show)

instance Arbitrary Genus where
  arbitrary = (Genus . fromIntegral) <$> choose (0 :: Int, 8)

-- | Arbitrary subsystem-code parameters with @n = k + g + r@ by construction
--   and 'Natural' (hence non-negative) counts.
newtype CodeCase = CodeCase CodeParams
  deriving (Eq, Show)

instance Arbitrary CodeCase where
  arbitrary = do
    k <- choose (0 :: Int, 6)
    g <- choose (0 :: Int, 6)
    r <- choose (0 :: Int, 6)
    let nat = fromIntegral :: Int -> Natural
    pure (CodeCase (mkCodeParams (nat k) (nat g) (nat r)))

-- | An arbitrary /valid/ chain complex over @GF(2)@: three chain groups of
--   random dimension, an arbitrary rectangular boundary @d_1@, and a boundary
--   @d_2@ whose columns are random combinations of a basis of @ker d_1@ (so
--   @im d_2 ⊆ ker d_1@, i.e. @d_1 . d_2 = 0@, with /both/ maps genuinely
--   nonzero in general).  Exercises 'rankGF2', 'kernelBasisGF2', and the real
--   cancellation @d^2 = 0@.
newtype ValidComplex = ValidComplex ChainComplex
  deriving (Eq, Show)

instance Arbitrary ValidComplex where
  arbitrary = do
    d0 <- choose (0, 4)
    d1 <- choose (0, 4)
    d2 <- choose (0, 4)
    b1 <- vectorOf d0 (vectorOf d1 arbitrary)          -- arbitrary d0 x d1
    let ker = kernelBasisGF2 d1 b1                      -- basis of ker d_1 ⊆ GF(2)^{d1}
    -- each of the d2 columns of d_2 is a random GF(2)-combination of ker
    coeffs <- vectorOf d2 (vectorOf (length ker) arbitrary)
    let zeroCol = replicate d1 False
        columns = [ foldr xorVec zeroCol [ v | (v, c) <- zip ker cs, c ]
                  | cs <- coeffs ]
        b2 = transposeMat d1 columns                    -- d1 x d2 boundary
    pure (ValidComplex (ChainComplex [d0, d1, d2] [b1, b2]))
    where
      xorVec :: [Bool] -> [Bool] -> [Bool]
      xorVec = zipWith (/=)
      -- transpose a list of columns (each length rows) into a rows x cols matrix
      transposeMat :: Int -> [[Bool]] -> [[Bool]]
      transposeMat rows cols = [ [ col !! i | col <- cols ] | i <- [0 .. rows - 1] ]

-- | Three statuses used to build a composable chain of entries.
data ChainCase = ChainCase Status Status Status
  deriving (Eq, Show)

instance Arbitrary ChainCase where
  arbitrary = do
    AnyStatus a <- arbitrary
    AnyStatus b <- arbitrary
    AnyStatus c <- arbitrary
    pure (ChainCase a b c)

-- | Four rungs in ladder order (sorted), for associativity of composition.
newtype FourRungs = FourRungs (Rung, Rung, Rung, Rung)
  deriving (Eq, Show)

instance Arbitrary FourRungs where
  arbitrary = do
    xs <- vectorOf 4 (elements allRungs)
    pure (FourRungs (toTuple (sortRungs xs)))
    where
      toTuple :: [Rung] -> (Rung, Rung, Rung, Rung)
      toTuple (a : b : c : d : _) = (a, b, c, d)
      toTuple _                   = (I, I, I, I)  -- unreachable (vectorOf 4)

-- | Insertion sort (avoids importing Data.List just for @sort@).
sortRungs :: [Rung] -> [Rung]
sortRungs = foldr ins []
  where
    ins :: Rung -> [Rung] -> [Rung]
    ins y []       = [y]
    ins y (z : zs) = if y <= z then y : z : zs else z : ins y zs

-- ------------------------------------------------------------------
-- Part I : status calculus (PI/T3)
-- ------------------------------------------------------------------

-- | @composeStatus@ is associative.
prop_statusAssoc :: AnyStatus -> AnyStatus -> AnyStatus -> Property
prop_statusAssoc (AnyStatus a) (AnyStatus b) (AnyStatus c) =
  composeStatus a (composeStatus b c) === composeStatus (composeStatus a b) c

-- | @composeStatus@ is commutative.
prop_statusCommutative :: AnyStatus -> AnyStatus -> Property
prop_statusCommutative (AnyStatus a) (AnyStatus b) =
  composeStatus a b === composeStatus b a

-- | @composeStatus@ is idempotent.
prop_statusIdempotent :: AnyStatus -> Property
prop_statusIdempotent (AnyStatus a) = composeStatus a a === a

-- | @S@ is the unit of the status monoid.
prop_statusUnit :: AnyStatus -> Property
prop_statusUnit (AnyStatus a) = composeStatus S a === a .&&. composeStatus a S === a

-- | The wrapped @max@-monoid is associative and unital.
prop_statusMonoidAssoc :: AnyStatus -> AnyStatus -> AnyStatus -> Property
prop_statusMonoidAssoc (AnyStatus a) (AnyStatus b) (AnyStatus c) =
  ((sa <> sb) <> sc) === (sa <> (sb <> sc))
    .&&. (mempty <> sa) === sa
  where
    sa = StatusMax a
    sb = StatusMax b
    sc = StatusMax c

-- | Status never improves under composition (PI/T3): the composite is at least
--   as speculative as each factor.
prop_statusNeverImproves :: AnyStatus -> AnyStatus -> Bool
prop_statusNeverImproves (AnyStatus a) (AnyStatus b) =
  composeStatus a b >= a && composeStatus a b >= b

-- | @worstOf@ is an upper bound for every element of the chain.
prop_worstOfIsUpperBound :: [AnyStatus] -> Bool
prop_worstOfIsUpperBound xs =
  all (<= worstOf [ s | AnyStatus s <- xs ]) [ s | AnyStatus s <- xs ]

-- ------------------------------------------------------------------
-- Part II : coalgebraic anatomy (eq. mf5)
-- ------------------------------------------------------------------

-- | Every summand of the coaction reconstructs the word: @w_1 ++ w_2 = w@.
prop_coproductReconstructs :: WordCase -> Bool
prop_coproductReconstructs (WordCase xs) =
  all (\(a, b) -> a ++ b == xs) (coproduct xs)

-- | The coaction is graded: @degree w_1 + degree w_2 = degree w@.
prop_coproductGraded :: WordCase -> Bool
prop_coproductGraded (WordCase xs) =
  all (\(a, b) -> degree a + degree b == degree xs) (coproduct xs)

-- | Coassociativity (eq. mf5): @(Delta (x) id) . Delta = (id (x) Delta) . Delta@.
prop_coactionCoassociative :: WordCase -> Property
prop_coactionCoassociative (WordCase xs) =
  sortTriples (leftCoaction xs) === sortTriples (rightCoaction xs)
  where
    sortTriples :: [([Int], [Int], [Int])] -> [([Int], [Int], [Int])]
    sortTriples = foldr insT []
    insT :: ([Int], [Int], [Int]) -> [([Int], [Int], [Int])] -> [([Int], [Int], [Int])]
    insT y []       = [y]
    insT y (z : zs) = if y <= z then y : z : zs else z : insT y zs

-- | Left counit law: keeping only the summands whose left factor is group-like
--   ('counit' @= 1@) reconstructs the original word (eq. mf6 connectedness).
prop_counitLeft :: WordCase -> Property
prop_counitLeft (WordCase xs) =
  [ w2 | (w1, w2) <- coproduct xs, counit w1 == 1 ] === [xs]

-- ------------------------------------------------------------------
-- Parts III/VI : isotropy keystone (eq. mf7)
-- ------------------------------------------------------------------

-- | The isotropy keystone (eq. mf7): @Aut_{X//G}(x) ~= Stab_G(x)@ computed by
--   two independent code paths agree.
prop_isotropyAutEqStab :: ActionCase -> Bool
prop_isotropyAutEqStab (ActionCase g x) = isotropy g x

-- | Orbit-stabilizer: @|orbit| * |Stab| = |G|@.
prop_orbitStabilizer :: ActionCase -> Bool
prop_orbitStabilizer (ActionCase g x) = orbitStabilizer g x

-- | The stabilizer is a subgroup.
prop_stabilizerIsSubgroup :: ActionCase -> Bool
prop_stabilizerIsSubgroup (ActionCase g x) = stabilizerIsSubgroup g x

-- | Generated groups really are groups (closed, with identity).
prop_generatedIsGroup :: ActionCase -> Bool
prop_generatedIsGroup (ActionCase g _) = isGroup g

-- | Robustness: 'generatedGroup' rejects invalid generators (via 'isPerm'), so
--   its output is a genuine group even on arbitrary garbage generator lists.
prop_generatedGroupAlwaysValid :: [[Int]] -> Property
prop_generatedGroupAlwaysValid gens =
  forAll (choose (1, 4)) (\n -> isGroup (generatedGroup n gens))

-- | The full keystone check at a worked example: isotropy plus a well-defined
--   gauge redundancy.
prop_keystoneHolds :: ActionCase -> Bool
prop_keystoneHolds (ActionCase g x) = keystoneHolds g x

-- ------------------------------------------------------------------
-- Parts IV/VI : high availability and surface codes (eq. mf8)
-- ------------------------------------------------------------------

-- | @rank H_1(Sigma_g; Z_2) = 2g@ (computed via GF(2) Gaussian elimination).
prop_h1RankIs2g :: Genus -> Property
prop_h1RankIs2g (Genus g) = h1Rank g === 2 * fromIntegral g

-- | Surface-code logical dimension @= 2^{2g}@ (eq. mf8, PVI/T3).
prop_surfaceLogicalDim :: Genus -> Property
prop_surfaceLogicalDim (Genus g) =
  surfaceCodeLogicalDim g === (2 :: Integer) ^ (2 * g)

-- | Euler characteristic of @Sigma_g@ is @2 - 2g@, and the dim/Betti forms
--   agree.
prop_surfaceEuler :: Genus -> Property
prop_surfaceEuler (Genus g) =
  eulerFromDims cc === 2 - 2 * fromIntegral g
    .&&. eulerFromDims cc === eulerFromBetti cc
  where
    cc = genusSurface g

-- | @d^2 = 0@ for the surface complex (and, spot-checked, the filled triangle).
prop_boundarySquaredZero :: Genus -> Bool
prop_boundarySquaredZero (Genus g) =
  boundarySquaredZero (genusSurface g) && boundarySquaredZero filledTriangle

-- | The Euler relation @sum (-1)^n dim C_n = sum (-1)^n b_n@ holds for an
--   /arbitrary/ chain complex (rank-nullity), tested over random GF(2)
--   boundary maps.
prop_eulerRelation :: ValidComplex -> Property
prop_eulerRelation (ValidComplex cc) = eulerFromDims cc === eulerFromBetti cc

-- | @d^2 = 0@ holds for every generated 'ValidComplex': its @d_2@ has columns
--   in @ker d_1@, so the genuine cancellation @d_1 . d_2 = 0@ is tested with
--   both maps nonzero in general.  We also require structural well-formedness,
--   so @boundarySquaredZero@ is never read off a malformed complex.
prop_randomBoundarySquaredZero :: ValidComplex -> Bool
prop_randomBoundarySquaredZero (ValidComplex cc) =
  wellFormed cc && boundarySquaredZero cc

-- | Every generated 'ValidComplex' is structurally well-formed (rectangular,
--   dimension-compatible boundary matrices).
prop_generatedComplexWellFormed :: ValidComplex -> Bool
prop_generatedComplexWellFormed (ValidComplex cc) = wellFormed cc

-- | The high-availability master formula (eq. mf8): for @n = k + g + r@,
--   @H_phys = (H_log (x) H_gauge) (+) H_err@ and @H_phys@ is @2^r@ copies of
--   one @(H_log (x) H_gauge)@ sector.
prop_subsystemMasterFormula :: CodeCase -> Bool
prop_subsystemMasterFormula (CodeCase cp) = validSubsystem cp (subsystemDims cp)

-- | The genus-@g@ surface code is a valid subsystem code with logical
--   dimension @2^{2g}@.
prop_surfaceCodeValid :: Genus -> Genus -> Property
prop_surfaceCodeValid (Genus g) (Genus extra) =
  property (validSubsystem cp (subsystemDims cp))
    .&&. logDim (subsystemDims cp) === surfaceCodeLogicalDim g
  where
    cp = surfaceCode g (2 * g + extra)

-- | Gauge redundancy = QEC redundancy (Closure keystone physical face): the
--   single law @total = content * redundancy@ holds simultaneously for
--
--     * the gauge orbit-stabilizer factorization
--       @|G| = |orbit| * |Stab|@  (content = orbit, redundancy = stabilizer);
--     * the QEC logical/gauge sector factorization
--       @dim(H_log (x) H_gauge) = dim H_log * dim H_gauge@
--       (content = logical, redundancy = gauge) -- the exact analogue.
prop_gaugeEqualsQEC :: ActionCase -> CodeCase -> Bool
prop_gaugeEqualsQEC (ActionCase grp x) (CodeCase cp) =
  gaugeOk && qecOk
  where
    (_, _, _, gaugeOk) = gaugeRedundancy grp x
    s     = subsystemDims cp
    qecOk = redundancyFactorization (logDim s * gaugeDim s) (logDim s) (gaugeDim s)

-- ------------------------------------------------------------------
-- Part V + ladder : compositional grammar (Table "ladder")
-- ------------------------------------------------------------------

-- | Builds-on composition is transitive: @J_{j,k} . J_{i,j} = J_{i,k}@.
prop_morComposeTransitive :: FourRungs -> Property
prop_morComposeTransitive (FourRungs (a, b, c, _)) =
  case (buildsOn a b, buildsOn b c) of
    (Just m1, Just m2) -> composeMor m1 m2 === buildsOn a c
    _                  -> property Discard

-- | Composition of builds-on morphisms is associative.
prop_morComposeAssoc :: FourRungs -> Property
prop_morComposeAssoc (FourRungs (a, b, c, d)) =
  case (buildsOn a b, buildsOn b c, buildsOn c d) of
    (Just m1, Just m2, Just m3) ->
      (composeMor m1 m2 >>= \mm -> composeMor mm m3)
        === (composeMor m2 m3 >>= composeMor m1)
    _ -> property Discard

-- | Every builds-on triangle commutes into the single target @Phys@.
prop_commutingTriangle :: RungCase -> RungCase -> Bool
prop_commutingTriangle (RungCase i) (RungCase j) = commutesTriangle i j

-- | Composition of representation entries is associative, with status
--   @max@-propagation (PI/T3).
prop_entryComposeAssoc :: ChainCase -> Property
prop_entryComposeAssoc (ChainCase s1 s2 s3) =
  ( composeEntries e1 e2 >>= \e12 -> composeEntries e12 e3 )
    === ( composeEntries e2 e3 >>= composeEntries e1 )
  where
    e1 = RepEntry "d0" "d1" s1
    e2 = RepEntry "d1" "d2" s2
    e3 = RepEntry "d2" "d3" s3

-- | The six-faculty ladder composite has status @worstOf@ the rung statuses,
--   and that status dominates every rung.
prop_ladderStatusIsWorst :: Bool
prop_ladderStatusIsWorst =
  entryStatus ladderComposite == worstOf (map rungStatus allRungs)
    && all (<= entryStatus ladderComposite) (map rungStatus allRungs)

-- ------------------------------------------------------------------
-- Runner
-- ------------------------------------------------------------------

-- | Run all synthesis properties.  Returns 'True' iff every property passes.
runAllProperties :: IO Bool
runAllProperties = do
  putStrLn "--- QuickCheck Properties (synthesis) ---"
  results <- sequence
    [ check "prop_statusAssoc              " prop_statusAssoc
    , check "prop_statusCommutative        " prop_statusCommutative
    , check "prop_statusIdempotent         " prop_statusIdempotent
    , check "prop_statusUnit               " prop_statusUnit
    , check "prop_statusMonoidAssoc        " prop_statusMonoidAssoc
    , check "prop_statusNeverImproves      " prop_statusNeverImproves
    , check "prop_worstOfIsUpperBound      " prop_worstOfIsUpperBound
    , check "prop_coproductReconstructs    " prop_coproductReconstructs
    , check "prop_coproductGraded          " prop_coproductGraded
    , check "prop_coactionCoassociative    " prop_coactionCoassociative
    , check "prop_counitLeft               " prop_counitLeft
    , check "prop_isotropyAutEqStab        " prop_isotropyAutEqStab
    , check "prop_orbitStabilizer          " prop_orbitStabilizer
    , check "prop_stabilizerIsSubgroup     " prop_stabilizerIsSubgroup
    , check "prop_generatedIsGroup         " prop_generatedIsGroup
    , check "prop_generatedGroupAlwaysValid" prop_generatedGroupAlwaysValid
    , check "prop_keystoneHolds            " prop_keystoneHolds
    , check "prop_h1RankIs2g               " prop_h1RankIs2g
    , check "prop_surfaceLogicalDim        " prop_surfaceLogicalDim
    , check "prop_surfaceEuler             " prop_surfaceEuler
    , check "prop_boundarySquaredZero      " prop_boundarySquaredZero
    , check "prop_eulerRelation            " prop_eulerRelation
    , check "prop_randomBoundarySquaredZero" prop_randomBoundarySquaredZero
    , check "prop_generatedComplexWellFormed" prop_generatedComplexWellFormed
    , check "prop_subsystemMasterFormula   " prop_subsystemMasterFormula
    , check "prop_surfaceCodeValid         " prop_surfaceCodeValid
    , check "prop_gaugeEqualsQEC           " prop_gaugeEqualsQEC
    , check "prop_morComposeTransitive     " prop_morComposeTransitive
    , check "prop_morComposeAssoc          " prop_morComposeAssoc
    , check "prop_commutingTriangle        " prop_commutingTriangle
    , check "prop_entryComposeAssoc        " prop_entryComposeAssoc
    , check "prop_ladderStatusIsWorst      " (property prop_ladderStatusIsWorst)
    ]
  let passed  = length (filter id results)
      nProps  = length results
  putStrLn $ "Properties passed: " ++ show passed ++ "/" ++ show nProps
  pure (and results)

-- | Run one property with a fixed 500-case budget, printing its name.
check :: Testable prop => String -> prop -> IO Bool
check name p = do
  putStr ("  " ++ name ++ " ")
  r <- quickCheckWithResult stdArgs { maxSuccess = 500 } p
  pure (isSuccess r)
