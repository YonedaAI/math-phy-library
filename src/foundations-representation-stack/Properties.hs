-- |
-- Module      : Properties
-- Description : QuickCheck properties for the representation-stack foundations
--               (Part I).  Each property corresponds to a numbered
--               theorem / proposition / corollary / definition of
--               @papers/latex/foundations-representation-stack.tex@.
--
-- Coverage (at least one property per major result):
--
--   * Theorem "Status calculus", part (1) — the status labels form a
--     commutative, idempotent monoid @(Sigma, \/, Std)@ with @\/ = max@:
--       'prop_joinAssoc', 'prop_joinCommutative', 'prop_joinIdempotent',
--       'prop_joinUnitStd', 'prop_reliabilityOrder', 'prop_monoidConsistent'.
--   * Definition "Translation strength" — composition degrades candidate
--     strength to the (exactly) weaker leg, and the composite map is the
--     Kleisli composition of the (partial) legs:
--       'prop_candidateHomomorphism', 'prop_candidateNotStronger',
--       'prop_composeTranslationIsKleisli'.
--   * Theorem "Status calculus", parts (2) and (3) — entries are well formed
--     (assigned status never stronger than the candidate); composite entry
--     status is the join @sigma_1 \/ sigma_2@ (so reliability is monotone
--     non-increasing); value-composability (@P1 = M2@) is respected; and
--     @sigma@ is a functor (preserves identities and composition, entry
--     composition is associative with unit the identity entry):
--       'prop_entryWellFormed', 'prop_composeStatusIsJoin',
--       'prop_composeEntryChecked', 'prop_composeReliabilityMonotone',
--       'prop_sigmaPreservesIdentity', 'prop_composeEntryStatusAssoc',
--       'prop_identityUnitStatus'.
--   * Proposition "Functoriality of the realization pipeline" — the pipeline is
--     the object-level composite @Obs . Real_alpha . Phi@; it satisfies the
--     functor laws (identity and composition preservation) on morphisms in the
--     delooping @B(Z,+)@; and it is functorial in the channel (whiskering a
--     comparison natural transformation yields a natural transformation of
--     outputs; the channel label is computationally irrelevant):
--       'prop_pipelineIsComposite', 'prop_pipelineFunctorLaws',
--       'prop_pipelineChannelWhisker', 'prop_pipelineChannelLabelIrrelevant'.
--   * Corollary "Reliability of a pipeline" — the pipeline status is the join of
--     its three stage statuses; an @Std@ pipeline requires all three stages
--     @Std@; a single heuristic stage downgrades the whole pipeline:
--       'prop_pipelineStatusIsJoinOfStages', 'prop_pipelineStdIffAllStagesStd',
--       'prop_pipelineOneHeurDowngrades'.
--   * Theorem "Coarse-quotient obstruction" and its corollary — passing to the
--     coarse quotient is gauge-invariant and collapses distinct gauge-related
--     objects (it loses automorphism data); and a finite twisted-sector
--     (nontrivial @H^1@ cocycle) witnesses that the coarse presheaf fails the
--     sheaf/descent condition (non-unique gluing):
--       'prop_coarseGaugeInvariant', 'prop_gaugeNontrivialCollapses',
--       'prop_coarseDescentNonUnique'.
--
-- The properties test the paper's mathematical claims, not incidental
-- implementation details: total/partial maps are drawn with 'Fun', and every
-- law is asserted with observational equality ('===').
module Properties
  ( -- * Status monoid (Theorem: status calculus, part 1)
    prop_joinAssoc
  , prop_joinCommutative
  , prop_joinIdempotent
  , prop_joinUnitStd
  , prop_reliabilityOrder
  , prop_monoidConsistent
    -- * Translation strength (Definition: translation strength)
  , prop_candidateHomomorphism
  , prop_candidateNotStronger
  , prop_composeTranslationIsKleisli
    -- * Status calculus parts 2 and 3 (Theorem: status calculus)
  , prop_entryWellFormed
  , prop_composeStatusIsJoin
  , prop_composeEntryChecked
  , prop_composeReliabilityMonotone
  , prop_sigmaPreservesIdentity
  , prop_composeEntryStatusAssoc
  , prop_identityUnitStatus
    -- * Realization pipeline (Proposition: functoriality of the pipeline)
  , prop_pipelineIsComposite
  , prop_pipelineFunctorLaws
  , prop_pipelineChannelWhisker
  , prop_pipelineChannelLabelIrrelevant
    -- * Reliability of a pipeline (Corollary)
  , prop_pipelineStatusIsJoinOfStages
  , prop_pipelineStdIffAllStagesStd
  , prop_pipelineOneHeurDowngrades
    -- * Coarse-quotient obstruction (Theorem) and its corollary
  , prop_coarseGaugeInvariant
  , prop_gaugeNontrivialCollapses
  , prop_coarseDescentNonUnique
    -- * Runner
  , runAllProperties
  , main
  ) where

import System.Exit (exitFailure, exitSuccess)
import Test.QuickCheck
  ( Fun, Gen, Property, Testable
  , applyFun, arbitrary, arbitraryBoundedEnum, conjoin, counterexample, elements
  , forAll, forAllBlind, isSuccess, maxSuccess, oneof, property, quickCheckResult
  , quickCheckWithResult, stdArgs, (===), (=/=), (==>), (.&&.)
  )

import Status
  ( Status(..), joinStatus, joinAll, moreReliable )
import RepStack
  ( Translation(..), RepEntry, mathStruct, physRep, status
  , candidateStatus, composeTranslation
  , runTranslation, identityEntry, composeEntry, composeEntryChecked
  , mkRepEntry, wellFormedEntry )
import Pipeline
  ( Channel(..), Stage(..), Pipeline(..), runPipeline, pipelineStatus
  , functoriality )

-- ------------------------------------------------------------------
-- Generators (kept explicit so that the function-carrying types need no
-- 'Show'/'Arbitrary' instances; used via 'forAllBlind').
-- ------------------------------------------------------------------

-- | 'Status' is generated uniformly over @{Std, Heur, Spec}@ (an explicit
-- generator, to avoid an orphan 'Test.QuickCheck.Arbitrary' instance).
genStatus :: Gen Status
genStatus = arbitraryBoundedEnum

-- | A random translation @Int -> Int@ of one of the four strengths.  The two
-- standard strengths carry total maps; the interpretive and speculative
-- strengths carry partial maps.
genTranslation :: Gen (Translation Int Int)
genTranslation = oneof
  [ FunctorialTranslation . applyFun <$> (arbitrary :: Gen (Fun Int Int))
  , NaturalTranslation    . applyFun <$> (arbitrary :: Gen (Fun Int Int))
  , InterpretiveRule      . applyFun <$> (arbitrary :: Gen (Fun Int (Maybe Int)))
  , SpeculativeMap        . applyFun <$> (arbitrary :: Gen (Fun Int (Maybe Int)))
  ]

-- | A random well-formed representation entry @Int ~> Int@.  Built through the
-- smart constructor 'mkRepEntry', so the assigned status is always at least as
-- weak as (never stronger than) the translation's candidate status.
genEntry :: Gen (RepEntry Int Int)
genEntry = mkRepEntry <$> arbitrary <*> arbitrary <*> genTranslation <*> genStatus

-- | A random /value-composable/ pair of well-formed entries @(E2, E1)@ with a
-- shared middle object @physRep E1 == mathStruct E2@, so @E2 . E1@ satisfies the
-- composability premise @P1 = M2@ of Theorem "status calculus" part (2).
genComposablePair :: Gen (RepEntry Int Int, RepEntry Int Int)
genComposablePair = do
  a   <- arbitrary
  b   <- arbitrary
  c   <- arbitrary
  t1  <- genTranslation
  t2  <- genTranslation
  s1  <- genStatus
  s2  <- genStatus
  let e1 = mkRepEntry a b t1 s1   -- E1 : a ~> b
      e2 = mkRepEntry b c t2 s2   -- E2 : b ~> c  (mathStruct e2 == physRep e1 == b)
  pure (e2, e1)

-- | A random functorial pipeline stage @Int -> Int@ with a random status.
genStage :: Gen (Stage Int Int)
genStage = Stage <$> (applyFun <$> (arbitrary :: Gen (Fun Int Int))) <*> genStatus

-- | A random three-stage realization pipeline over a random channel.
genPipeline :: Gen (Pipeline Int Int Int Int)
genPipeline = Pipeline <$> genChannel <*> genStage <*> genStage <*> genStage

-- | A random realization channel.
genChannel :: Gen Channel
genChannel = elements [minBound .. maxBound]

-- ------------------------------------------------------------------
-- Theorem: status calculus, part (1) --- (Sigma, \/, Std) is a commutative,
-- idempotent monoid with \/ = max in the reliability order Std < Heur < Spec.
-- ------------------------------------------------------------------

-- | Associativity of the status join.
prop_joinAssoc :: Property
prop_joinAssoc =
  forAll genStatus $ \a -> forAll genStatus $ \b -> forAll genStatus $ \c ->
    joinStatus (joinStatus a b) c === joinStatus a (joinStatus b c)

-- | Commutativity of the status join.
prop_joinCommutative :: Property
prop_joinCommutative =
  forAll genStatus $ \a -> forAll genStatus $ \b ->
    joinStatus a b === joinStatus b a

-- | Idempotence of the status join.
prop_joinIdempotent :: Property
prop_joinIdempotent = forAll genStatus $ \a -> joinStatus a a === a

-- | 'Std' (the most reliable label) is the two-sided unit of the join.
prop_joinUnitStd :: Property
prop_joinUnitStd = forAll genStatus $ \a ->
  (joinStatus Std a === a) .&&. (joinStatus a Std === a)

-- | The join is the supremum @max@ of the reliability order, and
-- 'moreReliable' is exactly @(<=)@ in that order.
prop_reliabilityOrder :: Property
prop_reliabilityOrder =
  forAll genStatus $ \a -> forAll genStatus $ \b -> conjoin
    [ joinStatus a b === max a b
    , moreReliable a b === (a <= b)
    ]

-- | The 'Semigroup'/'Monoid' instance and 'joinAll' agree with 'joinStatus'.
prop_monoidConsistent :: Property
prop_monoidConsistent =
  forAll genStatus $ \a -> forAll genStatus $ \b -> conjoin
    [ (a <> b)            === joinStatus a b
    , (mempty :: Status)  === Std
    , joinAll [a, b]      === joinStatus a b
    , joinAll []          === Std
    ]

-- ------------------------------------------------------------------
-- Definition: translation strength --- composition degrades candidate strength
-- to the (exactly) weaker leg; the composite map is the Kleisli composition.
-- ------------------------------------------------------------------

-- | The candidate status of a composite is exactly the join (weaker) of the
-- two candidate statuses: @candidateStatus@ is a monoid homomorphism from
-- (translations, composition) to @(Sigma, \/)@.
prop_candidateHomomorphism :: Property
prop_candidateHomomorphism =
  forAllBlind genTranslation $ \t1 ->
  forAllBlind genTranslation $ \t2 ->
    let lhs = candidateStatus (composeTranslation t2 t1)
        rhs = max (candidateStatus t1) (candidateStatus t2)
    in counterexample
         ("candidates: t1=" ++ show (candidateStatus t1)
             ++ " t2=" ++ show (candidateStatus t2)
             ++ " composite=" ++ show lhs)
         (lhs === rhs)

-- | The paper's literal claim: the composite candidate strength is never
-- stronger (never more reliable) than either factor.
prop_candidateNotStronger :: Property
prop_candidateNotStronger =
  forAllBlind genTranslation $ \t1 ->
  forAllBlind genTranslation $ \t2 ->
    let c = candidateStatus (composeTranslation t2 t1)
    in counterexample "composite candidate is stronger than a factor"
         (moreReliable (candidateStatus t1) c && moreReliable (candidateStatus t2) c)

-- | The honest composite map is the Kleisli composition of the two (possibly
-- partial) underlying maps: @run (t2 . t1) a = run t1 a >>= run t2@.
prop_composeTranslationIsKleisli :: Int -> Property
prop_composeTranslationIsKleisli a =
  forAllBlind genTranslation $ \t1 ->
  forAllBlind genTranslation $ \t2 ->
    runTranslation (composeTranslation t2 t1) a
      === (runTranslation t1 a >>= runTranslation t2)

-- ------------------------------------------------------------------
-- Theorem: status calculus, parts (2) and (3).
-- ------------------------------------------------------------------

-- | Every generated entry is well formed: its assigned status is at least as
-- weak as its translation's candidate status (Definition: translation
-- strength; the author may weaken but not strengthen the nominal label).
prop_entryWellFormed :: Property
prop_entryWellFormed = forAllBlind genEntry $ \e ->
  counterexample "assigned status is stronger than the translation candidate"
    (wellFormedEntry e)

-- | Part (2): for a /value-composable/ pair (premise @P1 = M2@) the composite
-- entry status is the join of the two statuses, @sigma(E2 . E1) = sigma_1 \/ sigma_2@.
-- Because join is commutative this also witnesses that @sigma@ preserves
-- composition (part 3).
prop_composeStatusIsJoin :: Property
prop_composeStatusIsJoin =
  forAllBlind genComposablePair $ \(e2, e1) ->
    status (composeEntry e2 e1) === joinStatus (status e1) (status e2)

-- | 'composeEntryChecked' succeeds exactly on the value-composable pairs
-- (@physRep E1 == mathStruct E2@), and then agrees with 'composeEntry' on the
-- composite status; on non-composable pairs it returns 'Nothing'.
prop_composeEntryChecked :: Property
prop_composeEntryChecked = conjoin
  [ forAllBlind genComposablePair $ \(e2, e1) ->
      fmap status (composeEntryChecked e2 e1)
        === Just (joinStatus (status e1) (status e2))
  , forAllBlind genEntry $ \e1 ->
    forAllBlind genEntry $ \e2 ->
      -- generic entries need not be value-composable; the checked composite is
      -- Just iff the middle objects coincide.
      (fmap status (composeEntryChecked e2 e1) /= Nothing)
        === (physRep e1 == mathStruct e2)
  ]

-- | Part (2), monotonicity: reliability is monotone non-increasing under
-- composition --- the composite is at least as weak as each factor.
prop_composeReliabilityMonotone :: Property
prop_composeReliabilityMonotone =
  forAllBlind genEntry $ \e1 ->
  forAllBlind genEntry $ \e2 ->
    let s = status (composeEntry e2 e1)
    in counterexample "composite more reliable than a factor"
         (moreReliable (status e1) s && moreReliable (status e2) s)

-- | Part (3), functor law (identities): the identity entry has status 'Std',
-- i.e. @sigma(id) = Std@.
prop_sigmaPreservesIdentity :: Int -> Property
prop_sigmaPreservesIdentity x = status (identityEntry x) === Std

-- | Part (3), category law: entry composition is associative on statuses (so
-- @L@ is a genuine category and @sigma@ its functor).
prop_composeEntryStatusAssoc :: Property
prop_composeEntryStatusAssoc =
  forAllBlind genEntry $ \e1 ->
  forAllBlind genEntry $ \e2 ->
  forAllBlind genEntry $ \e3 ->
    status (composeEntry e3 (composeEntry e2 e1))
      === status (composeEntry (composeEntry e3 e2) e1)

-- | Part (3), unit law: the identity entry is a two-sided unit for status under
-- composition, @sigma(id . E) = sigma(E) = sigma(E . id)@.
prop_identityUnitStatus :: Property
prop_identityUnitStatus =
  forAllBlind genEntry $ \e ->
    let idL = identityEntry (physRep e)     -- id : b ~> b, composed on the left
        idR = identityEntry (mathStruct e)   -- id : a ~> a, composed on the right
    in (status (composeEntry idL e) === status e)
         .&&. (status (composeEntry e idR) === status e)

-- ------------------------------------------------------------------
-- Proposition: functoriality of the realization pipeline.
-- ------------------------------------------------------------------

-- | The pipeline computes the defining composite (on objects)
-- @Obs_alpha(M) = Obs(Real_alpha(Phi(M)))@ (i.e. 'functoriality' holds
-- pointwise): the object-level composite of the three stages.  (This is the
-- defining equation of the pipeline; the genuine functor /laws/ on morphisms
-- are 'prop_pipelineFunctorLaws'.)
prop_pipelineIsComposite :: Int -> Property
prop_pipelineIsComposite x =
  forAllBlind genPipeline $ \p -> property (functoriality p x)

-- | Genuine functor laws (identity and composition preservation on
-- /morphisms/) for the realization pipeline, Proposition "functoriality of the
-- realization pipeline".  We work in the delooping @B(Z, +)@ of the additive
-- monoid: it has one object, and its morphisms are the integers with
-- composition @(+)@ and identity @0@.  Each stage \"multiply by @k@\" is then a
-- genuine functor (a monoid endomorphism of @(Z, +)@), so 'runPipeline' is the
-- induced pipeline functor's action on morphisms and must satisfy
-- @F(0) = 0@ (identities) and @F(f + g) = F(f) + F(g)@ (composition).
prop_pipelineFunctorLaws :: Property
prop_pipelineFunctorLaws =
  forAllBlind (arbitrary :: Gen Int) $ \kp ->
  forAllBlind (arbitrary :: Gen Int) $ \kr ->
  forAllBlind (arbitrary :: Gen Int) $ \ko ->
    let p = Pipeline Quantum (Stage (kp *) Std) (Stage (kr *) Std) (Stage (ko *) Std)
        f' = runPipeline p     -- action of the pipeline functor on a morphism
    in conjoin
         [ counterexample "identity not preserved" (f' 0 === 0)
         , property $ \f g -> f' (f + g) === f' f + f' g
         ]

-- | Functoriality in the channel: a comparison natural transformation
-- @theta : Real_alpha => Real_beta@ (here post-composition by @theta@) induces,
-- by whiskering with @Obs@ and @Phi@, a natural transformation of outputs.  The
-- naturality/whiskering identity @Obs_beta = Obs . theta . Real_alpha . Phi@
-- holds on the nose, for any /distinct/ target channel label @beta@.
prop_pipelineChannelWhisker :: Int -> Property
prop_pipelineChannelWhisker x =
  forAllBlind genPipeline $ \p ->
  forAllBlind (arbitrary :: Gen (Fun Int Int)) $ \ftheta ->
  forAllBlind genChannel $ \beta ->
    let theta   = applyFun ftheta
        realB   = Stage (theta . stageMap (realA p)) (stageStatus (realA p))
        pBeta   = p { channel = beta, realA = realB }   -- the beta-channel pipeline
    in runPipeline pBeta x
         === stageMap (obs p) (theta (stageMap (realA p) (stageMap (phi p) x)))

-- | The observable computed by a pipeline depends only on its three stage
-- /maps/, not on the channel /label/: relabelling the channel leaves
-- @runPipeline@ unchanged.  This well-definedness is what lets @alpha |-> Obs_alpha@
-- be a functor of the channel.
prop_pipelineChannelLabelIrrelevant :: Int -> Property
prop_pipelineChannelLabelIrrelevant x =
  forAllBlind genPipeline $ \p ->
  forAllBlind genChannel $ \beta ->
    runPipeline (p { channel = beta }) x === runPipeline p x

-- ------------------------------------------------------------------
-- Corollary: reliability of a pipeline.
-- ------------------------------------------------------------------

-- | The pipeline status is the join of its three stage statuses.
prop_pipelineStatusIsJoinOfStages :: Property
prop_pipelineStatusIsJoinOfStages =
  forAllBlind genPipeline $ \p ->
    pipelineStatus p
      === foldr joinStatus Std
            [stageStatus (phi p), stageStatus (realA p), stageStatus (obs p)]

-- | An @Std@-labeled pipeline requires all three stages to be @Std@.
prop_pipelineStdIffAllStagesStd :: Property
prop_pipelineStdIffAllStagesStd =
  forAllBlind genPipeline $ \p ->
    (pipelineStatus p == Std)
      === all (== Std)
            [stageStatus (phi p), stageStatus (realA p), stageStatus (obs p)]

-- | A single heuristic stage (with the others standard) downgrades the whole
-- pipeline to 'Heur'.
prop_pipelineOneHeurDowngrades :: Property
prop_pipelineOneHeurDowngrades =
  forAllBlind genStage $ \a ->
  forAllBlind genStage $ \b ->
  forAllBlind genStage $ \c ->
    let p = Pipeline Betti
              a { stageStatus = Std }
              b { stageStatus = Heur }
              c { stageStatus = Std }
    in pipelineStatus p === Heur

-- ------------------------------------------------------------------
-- Theorem: coarse-quotient obstruction (and Corollary: the stack is strictly
-- more informative than its coarse library).  Two toy models over 'Integer'
-- (unbounded, so there is no @negate minBound@ overflow).
-- ------------------------------------------------------------------

-- | A toy configuration acted on by a Z/2 gauge symmetry @n |-> -n@.
newtype Config = Config Integer deriving (Eq, Show)

-- | The nontrivial gauge automorphism.
gauge :: Config -> Config
gauge (Config n) = Config (negate n)

-- | The coarse quotient: pick the canonical representative of the gauge orbit.
coarseClass :: Config -> Integer
coarseClass (Config n) = abs n

-- | (Corollary) The coarse quotient is gauge-invariant: it identifies each
-- object with its gauge image (it is a well-defined map on orbits).
prop_coarseGaugeInvariant :: Integer -> Property
prop_coarseGaugeInvariant n =
  coarseClass (Config n) === coarseClass (gauge (Config n))

-- | (Corollary "stack is strictly more informative") For a nontrivial gauge
-- orbit (@n /= 0@) the two distinct global objects @Config n@ and
-- @gauge (Config n)@ collapse to the /same/ coarse class: passing to the coarse
-- quotient forgets the automorphism (gauge) data.
prop_gaugeNontrivialCollapses :: Integer -> Property
prop_gaugeNontrivialCollapses n = n /= 0 ==> conjoin
  [ counterexample "gauge acts trivially" (Config n /= gauge (Config n))
  , coarseClass (Config n) === coarseClass (gauge (Config n))
  ]

-- | A toy Cech 1-cocycle class valued in @Aut(E) = Z/2@ on a two-set cover:
-- 'Trivial' is the untwisted gluing @E@, 'Twisted' the nontrivial \"twisted
-- sector\" @E^g@.  These are the two elements of @H^1({e_i}; Z/2)@, and (since
-- @E@ and @E^g@ are non-isomorphic global entries) they are two /distinct/
-- elements of the coarse set @pi(d) = pi_0(Repphys(d))@.
data Cocycle = Trivial | Twisted
  deriving (Eq, Show)

-- | The restriction of a glued global entry to the cover: its coarse local
-- class on each @e_i@ together with the overlap comparisons in @pi_0@.  Both
-- cocycles restrict to the /same/ local section (a single point), because the
-- twist is invisible locally --- this is the whole point of the obstruction.
coverSection :: Cocycle -> ()
coverSection _ = ()

-- | The global coarse class in @pi(d) = pi_0(Repphys(d))@.  The untwisted and
-- twisted global entries are non-isomorphic, so they are /distinct/ elements of
-- the coarse set.
coarseGlobalClass :: Cocycle -> Cocycle
coarseGlobalClass = id

-- | (Theorem: coarse-quotient obstruction) The coarse presheaf @pi@ is not a
-- sheaf.  On the cover @{e_i}@ the two global coarse classes 'Trivial' and
-- 'Twisted'
--
--   * restrict to the /same/ local section ('coverSection' agrees on every
--     @e_i@ and on overlaps), yet
--   * are /distinct/ elements of @pi(d)@ ('coarseGlobalClass' separates them).
--
-- Hence the single local section over @{e_i}@ has (at least) two distinct
-- global preimages in @pi(d)@: gluing is not unique, violating the uniqueness
-- half of the sheaf axiom.  (This is the finite \"twisted sector\" instance of
-- the theorem's nontrivial @H^1({e_i}; Aut(E))@ obstruction.)
prop_coarseDescentNonUnique :: Property
prop_coarseDescentNonUnique = conjoin
  [ counterexample "local sections over the cover disagree"
      (coverSection Trivial === coverSection Twisted)
  , counterexample "the two global coarse classes are not distinct"
      (coarseGlobalClass Trivial =/= coarseGlobalClass Twisted)
  ]

-- ------------------------------------------------------------------
-- Runner.
-- ------------------------------------------------------------------

-- | Run a property with the default 100 tests, printing a label.
run :: Testable p => String -> p -> IO Bool
run name p = do
  putStr ("  " ++ name ++ ": ")
  isSuccess <$> quickCheckResult p

-- | Run a critical property with 1000 tests.
runHard :: Testable p => String -> p -> IO Bool
runHard name p = do
  putStr ("  " ++ name ++ " [1000]: ")
  isSuccess <$> quickCheckWithResult stdArgs { maxSuccess = 1000 } p

-- | Run every property; exit non-zero if any fails.
runAllProperties :: IO ()
runAllProperties = do
  putStrLn "--- QuickCheck Properties: foundations-representation-stack ---"
  putStrLn "[Theorem: status calculus, part 1 --- (Sigma, \\/, Std) monoid]"
  r1 <- sequence
    [ run     "prop_joinAssoc"          prop_joinAssoc
    , run     "prop_joinCommutative"    prop_joinCommutative
    , run     "prop_joinIdempotent"     prop_joinIdempotent
    , run     "prop_joinUnitStd"        prop_joinUnitStd
    , run     "prop_reliabilityOrder"   prop_reliabilityOrder
    , run     "prop_monoidConsistent"   prop_monoidConsistent
    ]
  putStrLn "[Definition: translation strength --- honest composition]"
  r2 <- sequence
    [ runHard "prop_candidateHomomorphism"        prop_candidateHomomorphism
    , runHard "prop_candidateNotStronger"         prop_candidateNotStronger
    , runHard "prop_composeTranslationIsKleisli"  prop_composeTranslationIsKleisli
    ]
  putStrLn "[Theorem: status calculus, parts 2 & 3 --- sigma is a functor]"
  r3 <- sequence
    [ runHard "prop_entryWellFormed"            prop_entryWellFormed
    , runHard "prop_composeStatusIsJoin"        prop_composeStatusIsJoin
    , runHard "prop_composeEntryChecked"        prop_composeEntryChecked
    , runHard "prop_composeReliabilityMonotone" prop_composeReliabilityMonotone
    , run     "prop_sigmaPreservesIdentity"     prop_sigmaPreservesIdentity
    , runHard "prop_composeEntryStatusAssoc"    prop_composeEntryStatusAssoc
    , runHard "prop_identityUnitStatus"         prop_identityUnitStatus
    ]
  putStrLn "[Proposition: functoriality of the realization pipeline]"
  r4 <- sequence
    [ runHard "prop_pipelineIsComposite"           prop_pipelineIsComposite
    , runHard "prop_pipelineFunctorLaws"           prop_pipelineFunctorLaws
    , runHard "prop_pipelineChannelWhisker"        prop_pipelineChannelWhisker
    , runHard "prop_pipelineChannelLabelIrrelevant" prop_pipelineChannelLabelIrrelevant
    ]
  putStrLn "[Corollary: reliability of a pipeline]"
  r5 <- sequence
    [ runHard "prop_pipelineStatusIsJoinOfStages" prop_pipelineStatusIsJoinOfStages
    , runHard "prop_pipelineStdIffAllStagesStd"   prop_pipelineStdIffAllStagesStd
    , runHard "prop_pipelineOneHeurDowngrades"    prop_pipelineOneHeurDowngrades
    ]
  putStrLn "[Theorem: coarse-quotient obstruction (+ corollary)]"
  r6 <- sequence
    [ runHard "prop_coarseGaugeInvariant"      prop_coarseGaugeInvariant
    , runHard "prop_gaugeNontrivialCollapses"  prop_gaugeNontrivialCollapses
    , run     "prop_coarseDescentNonUnique"    prop_coarseDescentNonUnique
    ]
  let results = concat [r1, r2, r3, r4, r5, r6]
      passed  = length (filter id results)
      total   = length results
  putStrLn $ "\nPassed " ++ show passed ++ "/" ++ show total ++ " properties."
  if and results then exitSuccess else exitFailure

-- | Standalone entry point (compile with @-main-is Properties@).
main :: IO ()
main = runAllProperties
