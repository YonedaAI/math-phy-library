{-# LANGUAGE RankNTypes #-}

-- |
-- Module      : Properties
-- Description : QuickCheck properties for Part V (Category Theory and HoTT:
--               Composition and Identity). Each property corresponds to a
--               named law/theorem of
--               @papers/latex/category-theory-hott-composition.tex@.
--
-- Coverage (grouped by paper result):
--
--   * category laws     : 'prop_leftUnit', 'prop_rightUnit' (Eq. (unit)),
--                         'prop_assoc' (Eq. (assoc)); Definition 3.1.
--   * functor laws      : 'prop_functorComp', 'prop_functorId'
--                         (Def. 3.2, Eq. (functor-laws)),
--                         'prop_functorCompositionIsFunctor'
--                         (functors compose, Sec. 2 / T2).
--   * naturality        : 'prop_naturality', 'prop_naturalityMaybeToList'
--                         (Def. 3.5, Eq. (naturality)) via the /generic/
--                         checker 'naturalitySquare', tested on two distinct
--                         natural transformations.
--   * T3 no-cloning     : 'prop_noCloningDimension' (dimension obstruction over
--                         'Integer', overflow-free), 'prop_snake'
--                         (genuine cup/cap contraction, Eq. (snake)).
--   * T4 quotients      : 'prop_cyclicGroupIsLawful' (group axioms),
--                         'prop_regularActionFree' (lawful free+transitive
--                         action, orbit-stabilizer, partition),
--                         'prop_groupoidFinerThanSet' (trivial Z/n),
--                         'prop_z2OnThreeFiner' (lawful mixed action with a
--                         free and a fixed point); Thm. T4, Sec. 6.4.
--
-- Random functions are drawn with 'Fun'; every law is asserted with
-- observational equality ('===') or a certified Boolean. The category/functor/
-- naturality properties are concrete executable witnesses of the laws in the
-- ambient function category (a stand-in for @Set@/@Hask@), not a model of the
-- full realization pipeline.
module Properties
  ( -- * Category laws (Definition 3.1)
    prop_leftUnit
  , prop_rightUnit
  , prop_assoc
    -- * Functor laws (Definition 3.2, pipeline theorem)
  , prop_functorComp
  , prop_functorId
  , prop_functorCompositionIsFunctor
    -- * Naturality (Definition 3.5)
  , naturalitySquare
  , prop_naturality
  , prop_naturalityMaybeToList
    -- * T3: structural no-cloning (Section 6.3)
  , prop_noCloningDimension
  , prop_snake
    -- * T4: groupoid vs set quotient (Section 6.4)
  , prop_cyclicGroupIsLawful
  , prop_regularActionFree
  , prop_groupoidFinerThanSet
  , prop_z2OnThreeFiner
  , prop_rejectsMalformed
    -- * Runner
  , runAllProperties
  , main
  ) where

import Data.Maybe (maybeToList)
import System.Exit (exitFailure, exitSuccess)
import Test.QuickCheck
  ( Fun, Positive(..), Property, Result, Testable, applyFun, conjoin, classify
  , counterexample, isSuccess, once, property, quickCheckResult
  , quickCheckWithResult, stdArgs, maxSuccess, (===)
  )

import RepCat
  ( Fn(..), identity, compose
  , component, safeHead
  )
import Dagger
  ( cloningObstruction, snakeStraightens )
import Quotient
  ( FiniteGroup(..), GroupAction(..)
  , cyclicGroup, groupoidAutomorphisms, isActionOf, isGroup, orbitStabilizerHolds
  , orbitsPartition, regularAction, retainsGaugeInfo, setQuotient, stabilizer
  )

-- ---------------------------------------------------------------------------
-- Category laws (Definition 3.1: associativity + unit; Eqs. (assoc),(unit))
-- ---------------------------------------------------------------------------

-- | Left unit law @identity . f == f@ (Eq. (unit)). Holds for every random
-- morphism @f@ in the function category 'Fn' at every input.
prop_leftUnit :: Fun Int Int -> Int -> Property
prop_leftUnit f x =
  let g = Fn (applyFun f)
  in runFn (compose identity g) x === runFn g x

-- | Right unit law @f . identity == f@ (Eq. (unit)).
prop_rightUnit :: Fun Int Int -> Int -> Property
prop_rightUnit f x =
  let g = Fn (applyFun f)
  in runFn (compose g identity) x === runFn g x

-- | Associativity @h . (g . f) == (h . g) . f@ (Eq. (assoc)).
prop_assoc :: Fun Int Int -> Fun Int Int -> Fun Int Int -> Int -> Property
prop_assoc f g h x =
  let ff = Fn (applyFun f)
      gg = Fn (applyFun g)
      hh = Fn (applyFun h)
  in runFn (compose hh (compose gg ff)) x
       === runFn (compose (compose hh gg) ff) x

-- ---------------------------------------------------------------------------
-- Functor laws (Definition 3.2; Eq. (functor-laws))
-- ---------------------------------------------------------------------------

-- | A functor preserves composition: @F (g . f) == F g . F f@ with @F = Maybe@
-- (Eq. (functor-laws), first clause).
prop_functorComp :: Fun Int Int -> Fun Int Int -> Maybe Int -> Property
prop_functorComp f g m =
  let ff = applyFun f
      gg = applyFun g
  in fmap (gg . ff) m === (fmap gg . fmap ff) m

-- | A functor preserves identities: @F id == id@ with @F = Maybe@
-- (Eq. (functor-laws), second clause).
prop_functorId :: Maybe Int -> Property
prop_functorId m = fmap id m === m

-- | Functors compose to a functor (Thm. "the pipeline is a composite of
-- functors", Sec. 2 / T2): the composite endofunctor @Maybe . Maybe@ still
-- preserves composition, @(F.F)(g.f) == (F.F) g . (F.F) f@. This is a concrete
-- executable witness that @G . F@ is a functor whenever @F@ and @G@ are (it is
-- not a model of the paper's pseudofunctorial realization pipeline).
prop_functorCompositionIsFunctor
  :: Fun Int Int -> Fun Int Int -> Maybe (Maybe Int) -> Property
prop_functorCompositionIsFunctor f g m =
  let ff = applyFun f
      gg = applyFun g
  in fmap (fmap (gg . ff)) m
       === (fmap (fmap gg) . fmap (fmap ff)) m

-- ---------------------------------------------------------------------------
-- Naturality (Definition 3.5; Eq. (naturality))
-- ---------------------------------------------------------------------------

-- | Generic naturality square (Eq. (naturality)) for /any/ natural
-- transformation @eta : F => G@ between Haskell functors: it checks
-- @fmap f . eta == eta . fmap f@. The component @eta@ is taken as a rank-2
-- argument so the checker is not tied to a single transformation.
naturalitySquare
  :: (Functor f, Functor g, Eq (g c))
  => (forall x. f x -> g x) -> (a -> c) -> f a -> Bool
naturalitySquare eta f xs = fmap f (eta xs) == eta (fmap f xs)

-- | @safeHead@ (the polymorphic component of the natural transformation
-- @[] => Maybe@) as a plain rank-1 function.
safeHeadFn :: [x] -> Maybe x
safeHeadFn = runFn (component safeHead)

-- | Naturality of @safeHead : [] => Maybe@ for every random @f@ and list,
-- checked through the generic 'naturalitySquare'.
prop_naturality :: Fun Int Int -> [Int] -> Property
prop_naturality f xs =
  property (naturalitySquare safeHeadFn (applyFun f) xs)

-- | Naturality of a /different/ natural transformation, @maybeToList :
-- Maybe => []@, through the /same/ generic checker -- evidence that the
-- naturality test is not hardcoded to one transformation.
prop_naturalityMaybeToList :: Fun Int Int -> Maybe Int -> Property
prop_naturalityMaybeToList f m =
  property (naturalitySquare maybeToList (applyFun f) m)

-- ---------------------------------------------------------------------------
-- T3: structural no-cloning (Section 6.3; Fox's theorem, dimension obstruction)
-- ---------------------------------------------------------------------------

-- | Structural no-cloning (Thm. T3). In FdHilb the tensor multiplies
-- dimensions while the categorical product/biproduct adds them; a uniform
-- natural cloning would force the two to agree as bifunctors. Over 'Integer'
-- (so there is no machine-word overflow), @m*n = m+n@ holds for positive
-- dimensions /only/ at the accidental coincidence @(2,2)@ and disagrees
-- everywhere else, so no natural family of diagonals can exist. The property
-- asserts @cloningObstruction m n  <=>  (m,n) /= (2,2)@ for all positive
-- @m,n :: Integer@.
prop_noCloningDimension :: Positive Integer -> Positive Integer -> Property
prop_noCloningDimension (Positive m) (Positive n) =
  classify (m == 2 && n == 2) "accidental coincidence (2,2)" $
    cloningObstruction m n === not (m == 2 && n == 2)

-- | Snake / zig-zag equation (Eq. (snake)) via the exported 'snakeStraightens',
-- which reconstructs the identity on @R^d@ by an explicit cup/cap tensor
-- contraction. The property checks straightening for positive @d@ and also that
-- a nonpositive (invalid) dimension is rejected.
prop_snake :: Positive Int -> Property
prop_snake (Positive d0) =
  let d = 1 + (d0 `mod` 6)   -- keep the d x d contraction small (1..6)
  in conjoin
       [ counterexample ("snake failed to straighten at d=" ++ show d)
           (snakeStraightens d)
       , counterexample "snake must reject the invalid dimension d=0"
           (not (snakeStraightens 0))
       ]

-- ---------------------------------------------------------------------------
-- T4: groupoid quotient finer than set quotient (Section 6.4)
-- ---------------------------------------------------------------------------

-- | The cyclic group @Z/n@ satisfies the group axioms (validated by 'isGroup')
-- for every small @n >= 1@. This certifies the group data used by the T4
-- properties is genuinely a group.
prop_cyclicGroupIsLawful :: Positive Int -> Property
prop_cyclicGroupIsLawful (Positive n0) =
  let n = 1 + (n0 `mod` 8)
  in counterexample ("Z/" ++ show n ++ " failed the group axioms")
       (isGroup (cyclicGroup n))

-- | The regular action of @Z/n@ on itself is a lawful, free, transitive action
-- (Thm. T4, extreme case). It certifies:
--
--   * the action axioms hold ('isActionOf');
--   * the orbits partition the carrier ('orbitsPartition');
--   * the orbit-stabilizer theorem @|G| = |orbit(x)| * |Stab(x)|@ at every
--     point;
--   * transitivity: exactly one orbit;
--   * freeness: no point retains gauge information, so here @X//G@ and @X/G@
--     agree (the boundary of T4(c)).
prop_regularActionFree :: Positive Int -> Property
prop_regularActionFree (Positive n0) =
  let n  = 1 + (n0 `mod` 8)
      g  = cyclicGroup n
      ga = regularAction n
      xs = [0 .. n - 1]
  in conjoin
       [ counterexample "regular action is not a lawful action"
           (isActionOf g ga xs)
       , counterexample "orbits do not partition the carrier"
           (orbitsPartition ga xs)
       , counterexample "orbit-stabilizer |G|=|orbit|*|stab| failed"
           (conjoin [ property (orbitStabilizerHolds ga x) | x <- xs ])
       , counterexample "transitive action should have exactly one orbit"
           (length (setQuotient ga xs) === 1)
       , counterexample "free action must retain no gauge info"
           (conjoin [ property (not (retainsGaugeInfo ga x)) | x <- xs ])
       ]

-- | The trivial action of @Z/n@ on the one-point set: @n@ group elements, all
-- acting as the identity, so the single point has full stabilizer @Z/n@.
znTrivial :: Int -> GroupAction Int ()
znTrivial n = GroupAction { elements = [0 .. n - 1], act = \_ _ -> () }

-- | Groupoid quotient strictly finer than the set quotient (Thm. T4). For the
-- trivial @Z/n@ action on a point:
--
--   (a) @Aut_{X//G}(x) ~ Stab_G(x)@ has cardinality @n@;
--   (b) the set quotient @X/G@ is a single orbit (0-truncation forgets loops);
--   (c) @X//G@ is strictly finer iff the stabilizer is nontrivial (@n > 1@).
prop_groupoidFinerThanSet :: Positive Int -> Property
prop_groupoidFinerThanSet (Positive n0) =
  let n  = 1 + (n0 `mod` 8)
      ga = znTrivial n
  in conjoin
       [ counterexample "T4(a): |Aut(x)| /= |Stab_G(x)|"
           (groupoidAutomorphisms ga () === n)
       , counterexample "T4(a): |Stab_G(x)| /= n"
           (length (stabilizer ga ()) === n)
       , counterexample "T4(b): set quotient not a single orbit"
           (length (setQuotient ga [()]) === 1)
       , counterexample "T4(c): finer-iff-nontrivial-stabilizer failed"
           (retainsGaugeInfo ga () === (n > 1))
       ]

-- | A lawful @Z/2@ action on @{0,1,2}@: the nonidentity element swaps @0 <-> 1@
-- and fixes @2@. This is a genuine action (validated by 'isActionOf') with a
-- free point (@0@) and a fixed point (@2@).
z2OnThree :: GroupAction Int Int
z2OnThree = GroupAction { elements = [0, 1], act = step }
  where
    step 0 x = x     -- identity element acts trivially
    step _ 0 = 1     -- s : 0 |-> 1
    step _ 1 = 0     -- s : 1 |-> 0
    step _ x = x     -- s fixes 2 (and any other point)

-- | Thm. T4 on the lawful mixed action 'z2OnThree'. It certifies group and
-- action laws, orbit partition, the orbit-stabilizer theorem at both a free and
-- a fixed point, and that @X//G@ is strictly finer than @X/G@ exactly at the
-- fixed point (nontrivial stabilizer). Run 'once': it is a closed statement.
prop_z2OnThreeFiner :: Property
prop_z2OnThreeFiner = once $
  let g  = cyclicGroup 2
      ga = z2OnThree
      xs = [0, 1, 2]
  in conjoin
       [ counterexample "Z/2 failed the group axioms" (isGroup g)
       , counterexample "z2OnThree is not a lawful action"
           (isActionOf g ga xs)
       , counterexample "orbits do not partition {0,1,2}"
           (orbitsPartition ga xs)
       , counterexample "should be two orbits {0,1} and {2}"
           (length (setQuotient ga xs) === 2)
       , counterexample "orbit-stabilizer failed at fixed point 2"
           (property (orbitStabilizerHolds ga 2))
       , counterexample "orbit-stabilizer failed at free point 0"
           (property (orbitStabilizerHolds ga 0))
       , counterexample "fixed point 2 must retain a gauge loop (|Stab|=2)"
           (groupoidAutomorphisms ga 2 === 2)
       , counterexample "free point 0 must have trivial stabilizer (|Stab|=1)"
           (groupoidAutomorphisms ga 0 === 1)
       , counterexample "X//G must be strictly finer at 2 but not at 0"
           (property (retainsGaugeInfo ga 2 && not (retainsGaugeInfo ga 0)))
       ]

-- | @Z/3@ with a deliberately broken inverse table (@inv = id@): @1@ has no
-- inverse since @1 * 1 = 2 /= 0@, so 'isGroup' must reject it.
badGroup :: FiniteGroup Int
badGroup = (cyclicGroup 3) { gInv = id }

-- | The 'z2OnThree' action with a stale 'elements' list that drops the
-- nonidentity element; it must fail 'isActionOf' (carrier mismatch).
staleElementsAction :: GroupAction Int Int
staleElementsAction = z2OnThree { elements = [0] }

-- | A @Z/2@ "action" whose nonidentity element sends carrier points outside the
-- carrier (@x |-> x + 10@); it must fail 'isActionOf' (closure violated).
nonClosedAction :: GroupAction Int Int
nonClosedAction =
  GroupAction { elements = [0, 1], act = \g x -> if g == 0 then x else x + 10 }

-- | Negative regression (Thm. T4 hypotheses): the law-validators must /reject/
-- malformed groups and actions, not just accept lawful ones. Without this, a
-- vacuously-true validator would let unsound T4 certificates through.
prop_rejectsMalformed :: Property
prop_rejectsMalformed = once $
  conjoin
    [ counterexample "badGroup (broken inverse) should be rejected by isGroup"
        (property (not (isGroup badGroup)))
    , counterexample "stale-elements action should be rejected by isActionOf"
        (property (not (isActionOf (cyclicGroup 2) staleElementsAction [0, 1, 2])))
    , counterexample "non-closed action should be rejected by isActionOf"
        (property (not (isActionOf (cyclicGroup 2) nonClosedAction [0, 1])))
    ]

-- ---------------------------------------------------------------------------
-- Runner
-- ---------------------------------------------------------------------------

-- | Run every property (critical laws at 1000 tests) and report whether they
-- all succeeded.
runAllProperties :: IO Bool
runAllProperties = do
  putStrLn "--- QuickCheck Properties (Part V: Category Theory and HoTT) ---"
  results <-
    sequence
      [ labelled "category: left unit  (identity . f == f)   [Eq.(unit)]"
          (many prop_leftUnit)
      , labelled "category: right unit (f . identity == f)   [Eq.(unit)]"
          (many prop_rightUnit)
      , labelled "category: associativity h.(g.f)==(h.g).f   [Eq.(assoc)]"
          (many prop_assoc)
      , labelled "functor: preserves composition F(g.f)=Fg.Ff [Def.3.2]"
          (one prop_functorComp)
      , labelled "functor: preserves identity  F id == id     [Def.3.2]"
          (one prop_functorId)
      , labelled "functors compose (pipeline is a functor)    [Thm.2 / T2]"
          (one prop_functorCompositionIsFunctor)
      , labelled "naturality: safeHead   [] => Maybe          [Def.3.5]"
          (one prop_naturality)
      , labelled "naturality: maybeToList Maybe => []         [Def.3.5]"
          (one prop_naturalityMaybeToList)
      , labelled "T3: no-cloning dimension obstruction        [Thm.T3]"
          (many prop_noCloningDimension)
      , labelled "T3: snake equation straightens wire         [Eq.(snake)]"
          (many prop_snake)
      , labelled "T4: cyclic group Z/n satisfies group axioms [Thm.T4]"
          (many prop_cyclicGroupIsLawful)
      , labelled "T4: regular action free (orbit-stabilizer)  [Thm.T4]"
          (many prop_regularActionFree)
      , labelled "T4: groupoid finer than set quotient (Z/n)  [Thm.T4]"
          (many prop_groupoidFinerThanSet)
      , labelled "T4: lawful mixed Z/2 action retains stab.   [Thm.T4]"
          (one prop_z2OnThreeFiner)
      , labelled "T4: validators reject malformed group/action [Thm.T4]"
          (one prop_rejectsMalformed)
      ]
  let ok = all isSuccess results
  putStrLn ("--- QuickCheck: "
            ++ show (length (filter isSuccess results)) ++ "/"
            ++ show (length results) ++ " properties passed ---")
  pure ok
  where
    one :: Testable prop => prop -> IO Result
    one = quickCheckResult
    many :: Testable prop => prop -> IO Result
    many = quickCheckWithResult stdArgs { maxSuccess = 1000 }
    labelled :: String -> IO Result -> IO Result
    labelled name act = putStrLn ("  * " ++ name) >> act

-- | Standalone entry point (built via @-main-is Properties@).
main :: IO ()
main = do
  ok <- runAllProperties
  if ok then exitSuccess else exitFailure
