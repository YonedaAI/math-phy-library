{-# OPTIONS_GHC -Wno-orphans #-}
-- |
-- Module      : Properties
-- Description : QuickCheck properties for the model-level theorems of Part II
--               ("Motives, Periods, and Amplitudes").  Each property tests one
--               mathematical claim of the paper (not an implementation detail).
--
-- Orphan @Arbitrary@ instances for the imported types 'Word'' and 'PeriodDatum'
-- are defined here (this is a test-only module), hence @-Wno-orphans@.
--
-- Correspondence to the paper:
--
--   * 'prop_coassoc'                -> Def. coalgebra (coassociativity axiom)
--   * 'prop_reducedWellDefined'     -> Eq. (reduced), well-definedness of Δ'
--   * 'prop_coproductGraded'        -> weight grading of the coaction
--   * 'prop_primitiveIffWeightLE1'  -> Generation thm (b) / Prop. Termination
--   * 'prop_anatomyDepth'           -> Prop. Termination (depth = weight − 1)
--   * 'prop_cobracketAntisym'       -> Def. Cobracket (antisymmetry)
--   * 'prop_cobracketGraded'        -> Eq. (GLCcobracket) (graded cobracket)
--   * 'prop_cobracketPrimitive'     -> primitives have vanishing cobracket
--   * 'prop_periodMultiplicative'   -> Thm. Multiplicativity (ii)
--   * 'prop_periodAdditive'         -> Thm. Multiplicativity (i)
--   * 'prop_periodBilinear'         -> Rmk. (ring structure) / bilinearity
--   * 'prop_realizePreservesWeight' -> realization is grading-preserving
--   * 'prop_realizeFunctorial'      -> realization is a monoidal functor
--   * 'prop_coactionTransports'     -> Thm. Conditional Amplitude Decomposition
--   * 'prop_discDefinition'         -> Prop. Discontinuity (first coaction slot)
--   * 'prop_discFirstSlot'          -> Prop. Discontinuity (weight/membership)
--   * 'prop_dilogCobracket'         -> Goncharov Lie coalgebra (dilog example)
--   * 'prop_dilogDisc'              -> Disc_x Li_2(x) = log(1−x)
--   * 'prop_weightOnePrimitives'    -> Generation thm (b): P_1 primitives
module Properties (main, runAllProperties) where

import Data.List (sort)
import Numeric.Natural (Natural)
import System.Exit (exitFailure)
import Test.QuickCheck

import Coalgebra
import Period
import Amplitude
import Goncharov
import Proofs (referenceExterior)

-- | A small finite alphabet for structural properties.  Keeping it small keeps
-- the quadratic-in-length coassociativity checks cheap while still exercising
-- repeated letters (which matter for multiset equalities).
data L = A | B | C | D | E
  deriving (Eq, Ord, Show, Enum, Bounded)

instance Arbitrary L where
  arbitrary = elements [minBound .. maxBound]

instance CoArbitrary L where
  coarbitrary = coarbitrary . fromEnum

instance Function L where
  function = functionMap fromEnum toEnum

-- | Random words of bounded length over the finite alphabet 'L'.
instance Arbitrary (Word' L) where
  arbitrary = do
    n  <- choose (0, 8)
    xs <- vectorOf n arbitrary
    pure (Word' xs)
  shrink (Word' xs) = [ Word' ys | ys <- shrinkList (const []) xs ]

-- | Period data carrying an arbitrary finite value in a bounded range (the
-- labels are irrelevant to the pairing, which only reads 'pdValue').
instance Arbitrary PeriodDatum where
  arbitrary = do
    v <- choose (-1000, 1000) :: Gen Double
    pure PeriodDatum
      { pdSpace   = "X"
      , pdDivisor = "D"
      , pdForm    = "w"
      , pdCycle   = "G"
      , pdValue   = v
      }

-- | Motivic amplitude objects over the finite alphabet, with a non-negative
-- ('Natural') depth grading.
instance Arbitrary (MotivicAmplitude L) where
  arbitrary = mkMotivicAmplitude <$> arbitrary <*> arbitrary

-- | Relative/absolute approximate equality for the floating-point period model.
approxEq :: Double -> Double -> Property
approxEq x y =
  counterexample (show x ++ " !~= " ++ show y)
                 (abs (x - y) <= 1.0e-6 * (1 + abs x + abs y))

-- ---------------------------------------------------------------------------
-- Coalgebra / coaction properties
-- ---------------------------------------------------------------------------

-- | Coassociativity of the deconcatenation coaction (coalgebra axiom).
prop_coassoc :: Word' L -> Bool
prop_coassoc = coassocHolds

-- | Well-definedness of the reduced coproduct on the augmentation ideal:
-- @Δ(w) = 1⊗w + w⊗1 + Δ'(w)@ as multisets, for @weight w ≥ 1@ (Eq. reduced).
prop_reducedWellDefined :: Word' L -> Property
prop_reducedWellDefined w =
  weight w >= 1 ==>
    sort (coproduct w)
      === sort ((emptyWord, w) : (w, emptyWord) : reducedCoproduct w)

-- | The coaction is weight-graded: every split's factors have weights summing
-- to the total weight.
prop_coproductGraded :: Word' L -> Property
prop_coproductGraded w =
  conjoin [ weight a + weight b === weight w | (a, b) <- coproduct w ]

-- | Every reduced-coproduct term has both tensor factors of positive weight
-- (connectedness; Eq. reduced).
prop_reducedPositiveWeight :: Word' L -> Property
prop_reducedPositiveWeight w =
  conjoin [ counterexample (show (a, b)) (weight a >= 1 && weight b >= 1)
          | (a, b) <- reducedCoproduct w ]

-- | Primitivity holds exactly for weight ≤ 1 (Generation thm (b);
-- Prop. Termination).
prop_primitiveIffWeightLE1 :: Word' L -> Property
prop_primitiveIffWeightLE1 w = isPrimitive w === (weight w <= 1)

-- | Anatomy depth equals @max 0 (weight − 1)@ (Prop. Termination).
prop_anatomyDepth :: Word' L -> Property
prop_anatomyDepth w = anatomyDepth w === max 0 (weight w - 1)

-- ---------------------------------------------------------------------------
-- Cobracket properties
-- ---------------------------------------------------------------------------

-- | The cobracket is antisymmetric: @(swap, negate)@ fixes it as a multiset
-- (Def. Cobracket; values in Λ²L).
prop_cobracketAntisym :: Word' L -> Property
prop_cobracketAntisym w =
  sort (cobracket w)
    === sort [ (b, a, negate c) | (a, b, c) <- cobracket w ]

-- | The cobracket is graded: @δ(L_n) ⊆ ⊕_{p+q=n, p,q≥1} L_p ∧ L_q@
-- (Eq. GLCcobracket).
prop_cobracketGraded :: Word' L -> Property
prop_cobracketGraded w =
  conjoin
    [ counterexample (show (a, b, c)) $
        weight a >= 1 && weight b >= 1 && weight a + weight b == weight w
    | (a, b, c) <- cobracket w ]

-- | Primitives (weight ≤ 1) have vanishing cobracket (Def. anatomy: leaves).
prop_cobracketPrimitive :: Word' L -> Property
prop_cobracketPrimitive w = isPrimitive w ==> null (cobracket w)

-- | The normalized cobracket is a genuine element of Λ²L: every surviving wedge
-- is in canonical order @a < b@ with a nonzero coefficient (no diagonal
-- @a∧a@ terms).  This is the exterior-quotient soundness that the formal
-- 'cobracket' lacks.
prop_cobracketExteriorCanonical :: Word' L -> Property
prop_cobracketExteriorCanonical w =
  conjoin [ counterexample (show t) (a < b && c /= 0)
          | t@(a, b, c) <- cobracketExterior w ]

-- | Repeated-letter words cancel in Λ²L: e.g. @a∧a = 0@ and
-- @a∧(aa) − (aa)∧a = 0@, so the normalized cobracket is empty even though the
-- formal 'cobracket' leaves cancelling terms.
prop_cobracketExteriorCancels :: Property
prop_cobracketExteriorCancels =
  once $
    conjoin
      [ counterexample (show w) (null (cobracketExterior w))
      | w <- [ Word' [A, A], Word' [A, A, A], Word' [B, B]
             , Word' [A, A, A, A] ] ]

-- | Soundness of 'cobracketExterior': it agrees with an /independent/ reference
-- normalization ('referenceExterior', a list/'nub'-based accumulation of signed
-- contributions).  This rules out a vacuous implementation — a @const []@ would
-- fail on @"ab"@.
prop_cobracketExteriorMatchesReference :: Word' L -> Property
prop_cobracketExteriorMatchesReference w =
  sort (cobracketExterior w) === sort (referenceExterior w)

-- | Explicit nonzero, sign-sensitive cases: @a⊗b@ gives @+ a∧b@ and @b⊗a@ gives
-- @− a∧b@ (canonicalized to the @a < b@ basis).
prop_cobracketExteriorNonzero :: Property
prop_cobracketExteriorNonzero =
  once $
    conjoin
      [ cobracketExterior (Word' [A, B]) === [(Word' [A], Word' [B], 1)]
      , cobracketExterior (Word' [B, A]) === [(Word' [A], Word' [B], -1)]
      ]

-- ---------------------------------------------------------------------------
-- Period pairing properties
-- ---------------------------------------------------------------------------

-- | Multiplicativity: @per(Π₁ ⊗ Π₂) = per(Π₁)·per(Π₂)@ (Thm. Multiplicativity
-- (ii); exact for the model because both sides are the same product).
prop_periodMultiplicative :: PeriodDatum -> PeriodDatum -> Property
prop_periodMultiplicative a b =
  per (tensorDatum a b) === per a * per b

-- | Additivity: @per(Π₁ ⊔ Π₂) = per(Π₁) + per(Π₂)@ (Thm. Multiplicativity (i)).
prop_periodAdditive :: PeriodDatum -> PeriodDatum -> Property
prop_periodAdditive a b =
  per (directSumDatum a b) === per a + per b

-- | The numeric verification harnesses agree with the exact identities.
prop_checkMultiplicative :: PeriodDatum -> PeriodDatum -> Bool
prop_checkMultiplicative = checkMultiplicative

prop_checkAdditive :: PeriodDatum -> PeriodDatum -> Bool
prop_checkAdditive = checkAdditive

-- | Bilinearity / ring structure of the period map (Rmk. after
-- Thm. Multiplicativity): @per(a ⊗ (b ⊔ c)) ≈ per(a⊗b) + per(a⊗c)@.  Tested up
-- to floating-point tolerance since the model realizes Q-bilinearity in
-- 'Double'.
prop_periodBilinear
  :: PeriodDatum -> PeriodDatum -> PeriodDatum -> Property
prop_periodBilinear a b c =
  approxEq (per (tensorDatum a (directSumDatum b c)))
           (per (tensorDatum a b) + per (tensorDatum a c))

-- | The validated Kummer constructor rejects out-of-domain inputs and only
-- produces finite periods: @mkKummerLog x@ is 'Just' a finite datum exactly
-- when @x > 0@ (and finite), 'Nothing' otherwise.  This encodes the @log@
-- domain that raw 'kummerLog' leaves as a precondition.
prop_mkKummerLogDomain :: Double -> Property
prop_mkKummerLogDomain x =
  case mkKummerLog x of
    Just pd ->
      counterexample "positive x must give a finite period"
        (x > 0 && isFinitePeriod pd)
    Nothing ->
      counterexample "non-positive/non-finite x must be rejected"
        (not (x > 0) || isNaN x || isInfinite x)

-- ---------------------------------------------------------------------------
-- Motivic amplitude object properties
-- ---------------------------------------------------------------------------

-- | The weight grading of a motivic amplitude object is its word length.
prop_amWeight :: MotivicAmplitude L -> Property
prop_amWeight ma = amWeight ma === weight (amWord ma)

-- | The amplitude coaction is the reduced coproduct of the underlying word
-- (Def. Motivic amplitude object, reduced part).
prop_amCoaction :: MotivicAmplitude L -> Property
prop_amCoaction ma = amCoaction ma === reducedCoproduct (amWord ma)

-- | The smart constructor preserves the (non-negative) depth grading; because
-- 'amDepth' is a 'Natural', negative depths are unrepresentable.
prop_mkAmplitudeDepth :: Word' L -> Natural -> Property
prop_mkAmplitudeDepth w d = amDepth (mkMotivicAmplitude w d) === d

-- ---------------------------------------------------------------------------
-- Realization / Conditional Amplitude Decomposition properties
-- ---------------------------------------------------------------------------

-- | Realization preserves weight (grading-preserving; Thm. CAD).
prop_realizePreservesWeight :: Fun L L -> Word' L -> Property
prop_realizePreservesWeight fn w =
  let f = applyFun fn in weight (realizeWord f w) === weight w

-- | Realization is a functor on words: @Real(g∘f) = Real g ∘ Real f@.
prop_realizeFunctorial :: Fun L L -> Fun L L -> Word' L -> Property
prop_realizeFunctorial fn gn w =
  let f = applyFun fn
      g = applyFun gn
  in realizeWord (g . f) w === realizeWord g (realizeWord f w)

-- | The coaction transports through an arbitrary realization channel:
-- @Δ'(Real w) = (Real ⊗ Real)(Δ' w)@ (Thm. Conditional Amplitude
-- Decomposition, naturality square Eq. compat).
prop_coactionTransports :: Fun L L -> Word' L -> Bool
prop_coactionTransports fn = coactionTransports (applyFun fn)

-- ---------------------------------------------------------------------------
-- Discontinuity properties (Prop. Discontinuity)
-- ---------------------------------------------------------------------------

-- | 'discAcross' selects exactly the first slots whose second slot is the
-- single letter @s@ (defining property of the discontinuity).
prop_discDefinition :: L -> Word' L -> Property
prop_discDefinition s w =
  discAcross s w === [ a | (a, b) <- reducedCoproduct w, b == Word' [s] ]

-- | Each discontinuity term is a genuine first coaction slot of weight
-- @weight w − 1@ (Prop. Discontinuity computes the first coaction slot).
prop_discFirstSlot :: L -> Word' L -> Property
prop_discFirstSlot s w =
  conjoin
    [ counterexample (show a) $
        ((a, Word' [s]) `elem` reducedCoproduct w)
          .&&. (weight a === weight w - 1)
    | a <- discAcross s w ]

-- ---------------------------------------------------------------------------
-- Goncharov Lie coalgebra: the dilogarithm example
-- ---------------------------------------------------------------------------

-- | The cobracket of the motivic dilogarithm is @log(1−x) ∧ log(x)@
-- (Example: Symbol of the dilogarithm).
prop_dilogCobracket :: Property
prop_dilogCobracket =
  once $
    sort dilogCobracket
      === sort [ (Word' [OneMinusX], Word' [X], 1)
               , (Word' [X], Word' [OneMinusX], -1) ]

-- | @Disc_x Li_2(x) = log(1−x)@ (Prop. Discontinuity, applied to the dilog).
prop_dilogDisc :: Property
prop_dilogDisc = once (discAcross X dilogSymbol === [Word' [OneMinusX]])

-- | The weight-one alphabet elements are all primitive (Generation thm (b):
-- @P_1 ≅ F^× ⊗ Q@).
prop_weightOnePrimitives :: Property
prop_weightOnePrimitives = once (property (all isPrimitive weightOnePrimitives))

-- ---------------------------------------------------------------------------
-- Runner
-- ---------------------------------------------------------------------------

-- | Run one named property with a raised test budget and report success.
runProp :: Testable p => String -> p -> IO Bool
runProp name p = do
  putStr ("  " ++ name ++ ": ")
  r <- quickCheckWithResult stdArgs { maxSuccess = 200 } p
  pure (isSuccess r)

-- | Run every property, printing results and returning whether all passed.
runAllProperties :: IO Bool
runAllProperties = do
  putStrLn "--- QuickCheck properties (Motives, Periods, Amplitudes) ---"
  oks <- sequence
    [ runProp "coassociativity (coalgebra axiom)"        prop_coassoc
    , runProp "reduced coproduct well-defined"           prop_reducedWellDefined
    , runProp "coproduct is weight-graded"               prop_coproductGraded
    , runProp "reduced terms positive-weight"            prop_reducedPositiveWeight
    , runProp "primitive <=> weight <= 1"                prop_primitiveIffWeightLE1
    , runProp "anatomy depth = weight - 1"               prop_anatomyDepth
    , runProp "cobracket antisymmetry"                   prop_cobracketAntisym
    , runProp "cobracket graded"                         prop_cobracketGraded
    , runProp "cobracket vanishes on primitives"         prop_cobracketPrimitive
    , runProp "exterior cobracket canonical (Lambda^2)"  prop_cobracketExteriorCanonical
    , runProp "exterior cobracket repeated cancels"      prop_cobracketExteriorCancels
    , runProp "exterior cobracket = reference"           prop_cobracketExteriorMatchesReference
    , runProp "exterior cobracket nonzero cases"         prop_cobracketExteriorNonzero
    , runProp "period multiplicativity"                  prop_periodMultiplicative
    , runProp "period additivity"                        prop_periodAdditive
    , runProp "checkMultiplicative harness"              prop_checkMultiplicative
    , runProp "checkAdditive harness"                    prop_checkAdditive
    , runProp "period bilinearity (ring structure)"      prop_periodBilinear
    , runProp "kummerLog domain (validated ctor)"        prop_mkKummerLogDomain
    , runProp "amplitude weight = word length"           prop_amWeight
    , runProp "amplitude coaction = reduced coproduct"   prop_amCoaction
    , runProp "amplitude depth preserved (Natural)"      prop_mkAmplitudeDepth
    , runProp "realization preserves weight"             prop_realizePreservesWeight
    , runProp "realization is functorial"                prop_realizeFunctorial
    , runProp "coaction transports (CAD)"                prop_coactionTransports
    , runProp "discontinuity definition"                 prop_discDefinition
    , runProp "discontinuity is first coaction slot"     prop_discFirstSlot
    , runProp "dilog cobracket = log(1-x) /\\ log(x)"    prop_dilogCobracket
    , runProp "Disc_x Li_2(x) = log(1-x)"                prop_dilogDisc
    , runProp "weight-one primitives all primitive"      prop_weightOnePrimitives
    ]
  let n = length oks
      passed = length (filter id oks)
  putStrLn ("  (" ++ show passed ++ "/" ++ show n ++ " properties passed)")
  pure (and oks)

-- | Standalone entry point (compiled as the @props@ binary): exits non-zero if
-- any property fails.
main :: IO ()
main = do
  ok <- runAllProperties
  if ok
    then putStrLn "ALL PROPERTIES PASSED"
    else do putStrLn "SOME PROPERTIES FAILED"; exitFailure
