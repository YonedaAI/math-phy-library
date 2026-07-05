-- |
-- Module      : Proofs
-- Description : Equational-reasoning proofs of the key results of the
--               representation-stack foundations (Part I), each with an
--               executable check at concrete values.
--
-- Every proof is written in the standard equational format
-- (@lhs = ... = ... = rhs@) with each step justified by a definition or law,
-- and is accompanied by a @proof_*@ function that checks the equality
-- concretely.  'proofResults' collects them; 'runProofs' reports pass/fail and
-- is invoked by @Main@ (which exits non-zero on any failure).
--
-- Cross-reference to @papers/latex/foundations-representation-stack.tex@:
--
--   * 'proof_statusIdempotent', 'proof_statusUnit', 'proof_statusMonoidLaws' —
--     Theorem "Status calculus", part (1) (@\\label{thm:status}@):
--     @(Sigma, \\/, Std)@ is a commutative, idempotent monoid (checked
--     exhaustively over the three-element domain).
--   * 'proof_candidateHomomorphism' — Definition "Translation strength"
--     (@\\label{def:transl}@): composition degrades candidate strength to the
--     weaker leg.
--   * 'proof_composeStatusIsJoin' — Theorem "Status calculus", part (2):
--     @sigma(E2 . E1) = sigma_1 \\/ sigma_2@.
--   * 'proof_sigmaPreservesIdentity' — Theorem "Status calculus", part (3):
--     @sigma@ is a functor, @sigma(id) = Std@.
--   * 'proof_pipelineComposite' — Proposition "Functoriality of the realization
--     pipeline" (@\\label{thm:functorial}@): @Obs_alpha(M) = Obs(Real(Phi(M)))@.
--   * 'proof_pipelineReliability' — Corollary "Reliability of a pipeline"
--     (@\\label{cor:pipeline-status}@).
--   * 'proof_coarseCollapse' — Corollary "the stack is strictly more
--     informative than its coarse library" (@\\label{cor:stack-informative}@):
--     the gauge orbit collapses under the coarse quotient.
--   * 'proof_coarseDescentFails' — Theorem "Coarse-quotient obstruction"
--     (@\\label{thm:coarse}@): a finite twisted-sector witness that the coarse
--     presheaf fails the sheaf/descent condition.
module Proofs
  ( proof_statusIdempotent
  , proof_statusUnit
  , proof_statusMonoidLaws
  , proof_candidateHomomorphism
  , proof_composeStatusIsJoin
  , proof_sigmaPreservesIdentity
  , proof_pipelineComposite
  , proof_pipelineReliability
  , proof_coarseCollapse
  , proof_coarseDescentFails
  , proofResults
  , runProofs
  ) where

import Control.Monad (forM_)
import Status (Status(..), joinStatus, joinAll)
import RepStack
  ( Translation(..), RepEntry, status, candidateStatus, composeTranslation
  , identityEntry, composeEntry, mkRepEntry )
import Pipeline (Stage(..), Pipeline(..), Channel(..), runPipeline, pipelineStatus)

-- | The three status labels, used to make the status proofs exhaustive (the
-- domain is finite, so enumeration is a complete proof).
allStatuses :: [Status]
allStatuses = [Std, Heur, Spec]

-- | A single executable proof obligation: report the offending values on
-- failure.
check :: (Eq a, Show a) => a -> a -> Either String ()
check lhs rhs
  | lhs == rhs = Right ()
  | otherwise  = Left ("expected " ++ show rhs ++ " but got " ++ show lhs)

-- ==================================================================
-- Theorem "Status calculus", part (1): (Sigma, \/, Std) is a commutative,
-- idempotent monoid with \/ = max under Std < Heur < Spec.
-- ==================================================================

-- | Idempotence, exhaustively over @{Std, Heur, Spec}@.  For any @a@:
--
-- >   joinStatus a a
-- > = { definition of joinStatus, joinStatus = max }
-- >   max a a
-- > = { max is idempotent on a total order }
-- >   a
-- > QED
proof_statusIdempotent :: Either String ()
proof_statusIdempotent =
  forM_ allStatuses $ \a -> check (joinStatus a a) a

-- | 'Std' is the two-sided unit, exhaustively.  For any @a@:
--
-- >   joinStatus Std a
-- > = { definition of joinStatus = max }
-- >   max Std a
-- > = { Std is the least element of (Std < Heur < Spec) }
-- >   a
-- > QED
--
-- and symmetrically @joinStatus a Std = a@.
proof_statusUnit :: Either String ()
proof_statusUnit =
  forM_ allStatuses $ \a -> do
    check (joinStatus Std a) a
    check (joinStatus a Std) a

-- | The remaining monoid laws, checked /exhaustively/ over the finite domain
-- (so this is a complete proof, not a sample): associativity over all
-- @3^3 = 27@ triples and commutativity over all @3^2 = 9@ pairs.
--
-- >   joinStatus (joinStatus a b) c = joinStatus a (joinStatus b c)   -- assoc
-- >   joinStatus a b               = joinStatus b a                   -- comm
--
-- both by @joinStatus = max@ on the total order @Std < Heur < Spec@.
proof_statusMonoidLaws :: Either String ()
proof_statusMonoidLaws = do
  -- commutativity (all 9 pairs)
  forM_ allStatuses $ \a ->
    forM_ allStatuses $ \b ->
      check (joinStatus a b) (joinStatus b a)
  -- associativity (all 27 triples)
  forM_ allStatuses $ \a ->
    forM_ allStatuses $ \b ->
      forM_ allStatuses $ \c ->
        check (joinStatus (joinStatus a b) c) (joinStatus a (joinStatus b c))

-- ==================================================================
-- Definition "Translation strength": composition degrades candidate strength
-- to the weaker (less reliable) leg.  We prove the critical case in which a
-- speculative leg meets an interpretive leg: the composite is speculative.
-- ==================================================================

-- | @candidateStatus@ is a monoid homomorphism from (translations, composition)
-- to the status join monoid: @candidateStatus (t2 . t1) = max (candidateStatus
-- t1) (candidateStatus t2)@.  Since @candidateStatus@ depends only on the
-- /constructor/, four representatives (one per strength) cover all @4 x 4 = 16@
-- constructor pairs, so enumerating them is a complete proof.  The critical
-- case is @(SpeculativeMap, InterpretiveRule)@:
--
-- >   candidateStatus (composeTranslation t2 t1)
-- > = { definition of composeTranslation, case (SpeculativeMap, InterpretiveRule) }
-- >   candidateStatus (SpeculativeMap (\a -> s1 a >>= g2))
-- > = { definition of candidateStatus (SpeculativeMap _) = Spec }
-- >   Spec
-- > = { Spec is the maximum of the reliability order }
-- >   max Spec Heur
-- > = { candidateStatus t1 = Spec, candidateStatus t2 = Heur }
-- >   max (candidateStatus t1) (candidateStatus t2)
-- > QED
proof_candidateHomomorphism :: Either String ()
proof_candidateHomomorphism =
  forM_ reps $ \t1 ->
    forM_ reps $ \t2 ->
      check (candidateStatus (composeTranslation t2 t1))
            (max (candidateStatus t1) (candidateStatus t2))
  where
    -- one representative per translation strength (Int -> Int)
    reps :: [Translation Int Int]
    reps =
      [ FunctorialTranslation (+ 1)
      , NaturalTranslation    (* 2)
      , InterpretiveRule      (\x -> Just (x - 1))
      , SpeculativeMap        (const (Just 0))
      ]

-- ==================================================================
-- Theorem "Status calculus", part (2): sigma(E2 . E1) = sigma_1 \/ sigma_2.
-- ==================================================================

-- | The composite entry status is the join of the two statuses.  We prove it
-- /exhaustively/ over all @3 x 3 = 9@ status pairs, using standard entries
-- @entryWith s@ (a functorial translation, candidate 'Std', so 'mkRepEntry'
-- leaves the assigned status exactly @s@):
--
-- >   status (composeEntry (entryWith s2) (entryWith s1))
-- > = { definition of composeEntry: status = status e1 `joinStatus` status e2 }
-- >   joinStatus s1 s2
-- > = { joinStatus = max on Std < Heur < Spec }
-- >   max s1 s2
-- > QED
--
-- (E.g. @s1 = Std@, @s2 = Heur@ gives @Heur@; a single @Spec@ leg gives @Spec@.)
proof_composeStatusIsJoin :: Either String ()
proof_composeStatusIsJoin =
  forM_ allStatuses $ \s1 ->
    forM_ allStatuses $ \s2 ->
      check (status (composeEntry (entryWith s2) (entryWith s1)))
            (joinStatus s1 s2)
  where
    -- a standard-candidate entry whose assigned status is exactly s
    entryWith :: Status -> RepEntry Int Int
    entryWith = mkRepEntry 0 0 (FunctorialTranslation id)

-- ==================================================================
-- Theorem "Status calculus", part (3): sigma : L -> B(Sigma, \/) is a functor;
-- in particular it preserves identities, sigma(id) = Std.
-- ==================================================================

-- | For the identity entry on any object:
--
-- >   status (identityEntry m)
-- > = { definition of identityEntry: status = Std }
-- >   Std
-- > QED
proof_sigmaPreservesIdentity :: Either String ()
proof_sigmaPreservesIdentity =
  check (status (identityEntry (0 :: Int))) Std

-- ==================================================================
-- Proposition "Functoriality of the realization pipeline":
-- Obs_alpha(M) = Obs(Real_alpha(Phi(M))).
-- ==================================================================

-- | A concrete three-stage pipeline on 'Int'.  For any @x@:
--
-- >   runPipeline p x
-- > = { definition of runPipeline: stageMap obs . stageMap realA . stageMap phi }
-- >   stageMap (obs p) (stageMap (realA p) (stageMap (phi p) x))
-- > = { the three stage maps here }
-- >   ((x + 1) * 2) - 3
-- > QED
proof_pipelineComposite :: Either String ()
proof_pipelineComposite =
  mapM_
    (\x -> check (runPipeline demoPipeline x)
                 (stageMap (obs demoPipeline)
                   (stageMap (realA demoPipeline)
                     (stageMap (phi demoPipeline) x))))
    [0, 1, 2, 5, 10 :: Int]

-- ==================================================================
-- Corollary "Reliability of a pipeline": the pipeline status is the join of
-- its three stage statuses.
-- ==================================================================

-- | For the pipeline @demoPipeline@ (all stages 'Std' except a 'Heur'
-- realization stage):
--
-- >   pipelineStatus p
-- > = { definition: joinAll [sigma(phi), sigma(realA), sigma(obs)] }
-- >   joinAll [Std, Heur, Std]
-- > = { joinAll = fold of joinStatus = max, from the unit Std }
-- >   Heur
-- > QED
proof_pipelineReliability :: Either String ()
proof_pipelineReliability = do
  check (pipelineStatus demoPipeline)
        (joinAll [ stageStatus (phi demoPipeline)
                 , stageStatus (realA demoPipeline)
                 , stageStatus (obs demoPipeline) ])
  check (pipelineStatus demoPipeline) Heur

-- | The concrete pipeline used by the pipeline proofs: @Phi@ adds 1, the
-- (heuristic) realization doubles, @Obs@ subtracts 3.
demoPipeline :: Pipeline Int Int Int Int
demoPipeline = Pipeline
  { channel = Quantum
  , phi   = Stage (+ 1)        Std
  , realA = Stage (* 2)        Heur   -- heuristic realization stage
  , obs   = Stage (subtract 3) Std
  }

-- ==================================================================
-- Theorem "Coarse-quotient obstruction": the coarse quotient identifies each
-- object with its gauge image, so distinct gauge-related objects collapse and
-- automorphism data is lost.  (Toy Z/2 model, mirroring Main.hs.)
-- ==================================================================

-- | For the gauge action @g(Config n) = Config (-n)@ and coarse quotient
-- @Config n |-> abs n@, and any @n@:
--
-- >   coarseClass (gauge (Config n))
-- > = { definition of gauge }
-- >   coarseClass (Config (negate n))
-- > = { definition of coarseClass }
-- >   abs (negate n)
-- > = { abs (negate n) = abs n }
-- >   abs n
-- > = { definition of coarseClass }
-- >   coarseClass (Config n)
-- > QED
--
-- Hence for @n /= 0@ the /distinct/ objects @Config n@ and @gauge (Config n)@
-- have equal coarse class: the quotient is strictly coarser (loses gauge data).
proof_coarseCollapse :: Either String ()
proof_coarseCollapse = do
  mapM_ (\n -> check (coarseClass (gauge (Config n))) (coarseClass (Config n)))
        [-3, -1, 0, 1, 2, 7 :: Integer]
  -- nontrivial orbit: two distinct objects, one coarse class
  check (Config 1 == gauge (Config 1)) False
  check (coarseClass (Config 1) == coarseClass (gauge (Config 1))) True

-- | The coarse presheaf @pi = pi_0(Repphys)@ fails descent (the sheaf axiom),
-- witnessed by a finite \"twisted sector\".  With @Aut(E) = Z/2@ and the two
-- cocycle classes 'Trivial' (@E@) and 'Twisted' (@E^g@) in @H^1({e_i}; Z/2)@:
--
-- >   coverSection Trivial = coverSection Twisted            (same local section over {e_i})
-- >   coarseGlobalClass Trivial /= coarseGlobalClass Twisted (two distinct classes in pi(d))
--
-- The single local section thus has two distinct global preimages in @pi(d)@,
-- so gluing is not unique and @pi@ is not a sheaf (Theorem: coarse-quotient
-- obstruction).
proof_coarseDescentFails :: Either String ()
proof_coarseDescentFails = do
  check (coverSection Trivial == coverSection Twisted)           True
  check (coarseGlobalClass Trivial == coarseGlobalClass Twisted) False

-- Toy Z/2 gauge model (self-contained; mirrors Main.hs and Properties.hs).
newtype Config = Config Integer deriving (Eq, Show)

gauge :: Config -> Config
gauge (Config n) = Config (negate n)

coarseClass :: Config -> Integer
coarseClass (Config n) = abs n

-- Toy Cech 1-cocycle model over a two-set cover (mirrors Properties.hs): the two
-- global entries E (Trivial) and E^g (Twisted) restrict to the same local
-- section but are distinct elements of the coarse set pi(d) = pi_0(Repphys(d)).
data Cocycle = Trivial | Twisted deriving (Eq, Show)

coverSection :: Cocycle -> ()
coverSection _ = ()

coarseGlobalClass :: Cocycle -> Cocycle
coarseGlobalClass = id

-- ==================================================================
-- Runner.
-- ==================================================================

-- | All proof obligations, labelled by the result they verify.
proofResults :: [(String, Either String ())]
proofResults =
  [ ("status calculus (1): idempotence  a \\/ a = a",             proof_statusIdempotent)
  , ("status calculus (1): unit         Std \\/ a = a = a \\/ Std", proof_statusUnit)
  , ("status calculus (1): assoc + comm (all 27/9 cases)",        proof_statusMonoidLaws)
  , ("translation strength: candidate hom (all 16 pairs)",        proof_candidateHomomorphism)
  , ("status calculus (2): sigma(E2.E1)=sigma1 \\/ sigma2 (all 9)", proof_composeStatusIsJoin)
  , ("status calculus (3): sigma(id) = Std",                      proof_sigmaPreservesIdentity)
  , ("functoriality: Obs_a(M) = Obs(Real(Phi(M)))",               proof_pipelineComposite)
  , ("reliability of a pipeline: status = join of stages",        proof_pipelineReliability)
  , ("coarse quotient (corollary): gauge orbit collapses",        proof_coarseCollapse)
  , ("coarse-quotient obstruction: descent gluing non-unique",    proof_coarseDescentFails)
  ]

-- | Print and check every proof obligation; return 'True' iff all pass.
runProofs :: IO Bool
runProofs = do
  putStrLn "--- Equational proof checks: foundations-representation-stack ---"
  oks <- mapM report proofResults
  let passed = length (filter id oks)
  putStrLn $ "Checked " ++ show (length oks) ++ " proofs; " ++ show passed ++ " passed."
  return (and oks)
  where
    report (name, res) = case res of
      Right () -> do putStrLn ("  [OK]   " ++ name); return True
      Left err -> do putStrLn ("  [FAIL] " ++ name ++ " -- " ++ err); return False
