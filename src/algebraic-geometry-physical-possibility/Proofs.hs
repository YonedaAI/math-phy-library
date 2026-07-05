-- | Module      : Proofs
--   Description : Equational-reasoning proofs for the load-bearing identities of
--                 Part III, "Algebraic Geometry: Spaces of Physical Possibility".
--
--   Each proof pairs a step-by-step equational derivation
--       lhs = { justification } ... = { justification } rhs
--   (the mathematical content, in the preceding comment) with an executable
--   @proof_*@ term of type @Either String ()@ that WITNESSES the derivation at
--   representative concrete values (@Right ()@ on success, @Left reason@ on
--   failure). The comment carries the universal argument; the term is a machine
--   check that the definitions actually compute as the derivation claims.
--   'runProofs' runs them all; "Main" fails the build if any check returns
--   'Left'.
module Proofs
  ( allProofs
  , runProofs
  , proof_onShellAdjoins
  , proof_lawfulGroupAction
  , proof_autEqualsStabilizer
  , proof_orbitStabilizer
  , proof_iteratedResiduesCommute
  , proof_residueAxiom
  , proof_companionPicardFuchs
  , proof_flatStepZero
  , proof_koszulNoGhosts
  , proof_ghostsDistinguish
  ) where

import Data.Ratio ((%))

import Scheme (CoordRing(..), Ideal(..), onShell, massShell)
import QuotientStack
  ( GAction(..), stabilizer, orbit, mkQuotientStack, autGroup
  , isGroup, isAction, stabilizerIsSubgroup, z4OnSquare, z4Group )
import Hodge (legendreVHS, gaussManin, flatStep, picardFuchsLegendre)
import PositiveGeometry
  ( DiffForm(..), residueAt, residueAxiomHolds, allLeavesArePoints
  , interval, simplex )
import DerivedCritical
  ( freeScalar, koszulDegrees, koszulTotalRank, hasGhosts
  , hasGhostsStack, stackComplexDegrees )

-- --------------------------------------------------------------------------
-- Proof combinators (the Either String () proof monad)
-- --------------------------------------------------------------------------

-- | Assert a Boolean fact, labelled by the reason it should hold.
expect :: Bool -> String -> Either String ()
expect True  _   = Right ()
expect False msg = Left msg

-- | Assert an equality, reporting both sides on failure.
eq :: (Eq a, Show a) => String -> a -> a -> Either String ()
eq name l r
  | l == r    = Right ()
  | otherwise = Left (name ++ ": " ++ show l ++ " /= " ++ show r)

-- | Assert that a floating residual is (numerically) zero.
approxZero :: String -> Double -> Either String ()
approxZero name x
  | abs x <= 1e-9 = Right ()
  | otherwise     = Left (name ++ ": residual " ++ show x)

-- | Dot product (for the Gauss-Manin / Picard-Fuchs check).
dot :: [Double] -> [Double] -> Double
dot xs ys = sum (zipWith (*) xs ys)

-- --------------------------------------------------------------------------
-- Proof: R/I adjoins the constraint ideal (Definition 3.1 / Theorem 8.7(1))
-- --------------------------------------------------------------------------

-- | Definition 3.1 (on-shell algebra), reused as Theorem 8.7(1) (@H^0 = R/(dS)@).
--
--   Claim: @relations (onShell r i) = relations r ++ idealGens i@ and the
--   generators are unchanged.
--
--     relations (onShell r i)
--   = { def. onShell:  onShell r i = r { relations = relations r ++ idealGens i } }
--     relations (r { relations = relations r ++ idealGens i })
--   = { record update selects the updated field }
--     relations r ++ idealGens i
--   QED (and @generators@ is untouched by the update, so it is preserved).
proof_onShellAdjoins :: Either String ()
proof_onShellAdjoins = do
  let r = CoordRing { generators = ["q", "p", "E"], relations = [] }
      s = onShell r massShell
  eq "onShell/generators" (generators s) (generators r)
  eq "onShell/relations"  (relations s)  (relations r ++ idealGens massShell)

-- --------------------------------------------------------------------------
-- Proof: Z/4 is a lawful group acting lawfully (Proposition 5.3 structure)
-- --------------------------------------------------------------------------

-- | Proposition 5.3 (structural prerequisites). The stabilizer construction is
--   only meaningful for a genuine group action, so we first witness that:
--     * @z4Group@ satisfies the group axioms (closure, associativity, identity,
--       inverses);
--     * @z4OnSquare@ satisfies the action axioms (@e . x = x@,
--       @(g h) . x = g . (h . x)@);
--     * every stabilizer is a subgroup (contains @e@, closed under @.@ and
--       inverses).
proof_lawfulGroupAction :: Either String ()
proof_lawfulGroupAction = do
  expect (isGroup z4Group)               "Z/4 fails the group axioms"
  expect (isAction z4Group z4OnSquare)   "the Z/4 action fails the action axioms"
  mapM_ (\x -> expect (stabilizerIsSubgroup z4Group z4OnSquare x)
                      "a stabilizer is not a subgroup")
        (points z4OnSquare)

-- --------------------------------------------------------------------------
-- Proof: Aut_{[X/G]}(x) = Stab_G(x) (Proposition 5.3)
-- --------------------------------------------------------------------------

-- | Proposition 5.3.
--
--     autGroup (mkQuotientStack ga) x
--   = { def. mkQuotientStack:  autGroup := stabilizer ga }
--     stabilizer ga x
--   QED.  Checked over every point of the Z/4-on-square action.
proof_autEqualsStabilizer :: Either String ()
proof_autEqualsStabilizer =
  let ga = z4OnSquare
      qs = mkQuotientStack ga
  in mapM_ (\x -> eq "aut=stab" (autGroup qs x) (stabilizer ga x)) (points ga)

-- --------------------------------------------------------------------------
-- Proof: orbit-stabilizer / Lagrange (Proposition 5.3, corollary)
-- --------------------------------------------------------------------------

-- | Orbit-stabilizer theorem: @|orbit(x)| * |Stab(x)| = |G|@.
--
--   The map @g . Stab(x) |-> g . x@ is a bijection from left cosets of
--   @Stab(x)@ onto @orbit(x)@, so @|G|/|Stab(x)| = |orbit(x)|@; clearing the
--   denominator gives the identity. Checked over every point of Z/4 on the
--   square (@|G| = 4@): the four vertices give @4 * 1@, the centre gives
--   @1 * 4@.
proof_orbitStabilizer :: Either String ()
proof_orbitStabilizer =
  let ga = z4OnSquare
      g  = length (elements ga)
  in mapM_ (\x -> eq "|orbit|*|stab|"
                     (length (orbit ga x) * length (stabilizer ga x)) g)
           (points ga)

-- --------------------------------------------------------------------------
-- Proof: iterated residues commute (Theorem 8.5(1) / Leray)
-- --------------------------------------------------------------------------

-- | Theorem 8.5(1) (Leray): iterated residues are independent of order.
--
--     residueAt f (residueAt g (DiffForm ps c))
--   = { def. residueAt (twice) }
--     DiffForm (filter (/= f) (filter (/= g) ps)) c
--   = { filter (/= f) . filter (/= g) = filter (/= g) . filter (/= f) }
--     DiffForm (filter (/= g) (filter (/= f) ps)) c
--   = { def. residueAt (twice) }
--     residueAt g (residueAt f (DiffForm ps c))
--   QED.  Checked on representative forms (including a repeated pole).
proof_iteratedResiduesCommute :: Either String ()
proof_iteratedResiduesCommute = do
  let df1 = DiffForm ["a", "b", "c"] (3 % 2)
      df2 = DiffForm ["a", "a", "b"] (-1)
  eq "commute (distinct)"
     (residueAt "a" (residueAt "b" df1))
     (residueAt "b" (residueAt "a" df1))
  eq "commute (repeated)"
     (residueAt "a" (residueAt "b" df2))
     (residueAt "b" (residueAt "a" df2))

-- --------------------------------------------------------------------------
-- Proof: residue axiom (Definition 7.1 / Theorem 8.5(1))
-- --------------------------------------------------------------------------

-- | Definition 7.1 (residue axiom): @Res_{facet} Omega = Omega(facet)@, the
--   canonical form of the boundary stratum. The geometries are built by
--   'PositiveGeometry.fromForm', so at EVERY edge @b@ of the tree
--
--     canonicalForm (stratum b)
--   = { def. fromForm:  stratum b = fromForm _ (residueAt (facetLabel b) parent) }
--     residueAt (facetLabel b) (canonicalForm parent)
--
--   holds by construction; and the recursion terminates at numeric 0-forms
--   (@poles = []@). We verify this over the whole constructed geometries
--   ('residueAxiomHolds' quantifies over all edges, 'allLeavesArePoints' over
--   all leaves) rather than at a single sample.
proof_residueAxiom :: Either String ()
proof_residueAxiom = do
  expect (residueAxiomHolds interval)     "interval violates the residue axiom"
  expect (residueAxiomHolds (simplex 3))  "simplex 3 violates the residue axiom"
  expect (allLeavesArePoints interval)    "interval has a non-numeric leaf"
  expect (allLeavesArePoints (simplex 3)) "simplex 3 has a non-numeric leaf"

-- --------------------------------------------------------------------------
-- Proof: companion matrix realizes Picard-Fuchs (Theorem 8.1 / Example 6.4)
-- --------------------------------------------------------------------------

-- | Theorem 8.1(2) / Example 6.4.  For the Legendre companion connection
--   @A(lambda)@ and period vector @v = [f, f']@:
--
--     (A v) row 0
--   = { first row of the companion is [0,1] }
--     f'
--     (A v) row 1
--   = { second row is [ -c0/c2, -c1/c2 ] }
--     -(c0/c2) f - (c1/c2) f'   =:  f''
--   hence  c2 f'' + c1 f' + c0 f = 0,  the Legendre Picard-Fuchs equation.
--   QED.  Checked at @lambda = 2/5@ (where @c1 = 1 - 2*lambda = 1/5 /= 0@, so the
--   @f'@ coefficient path is genuinely exercised) with @v = [2, -1]@.
proof_companionPicardFuchs :: Either String ()
proof_companionPicardFuchs = do
  let lam          = 0.4 :: Double
      (c2, c1, c0) = picardFuchsLegendre lam
      f            = 2.0
      f'           = -1.0
  case gaussManin legendreVHS lam of
    [row0, row1] -> do
      eq "companion row 0" row0 [0, 1]
      let fpp = row1 `dot` [f, f']   -- second component of A v = f''
      approxZero "Picard-Fuchs residual" (c2 * fpp + c1 * f' + c0 * f)
    _ -> Left "companion matrix is not 2x2"

-- --------------------------------------------------------------------------
-- Proof: the zero-length Gauss-Manin step is the identity (Theorem 8.1(1))
-- --------------------------------------------------------------------------

-- | Theorem 8.1(1).  A degenerate Euler step transports nothing:
--
--     flatStep A 0 s v
--   = { def. flatStep:  v + h * (A s . v),  here h = 0 }
--     zipWith (+) v (map (* 0) (matVec (A s) v))
--   = { x * 0 = 0 and v + 0 = v }
--     v
--   QED.
proof_flatStepZero :: Either String ()
proof_flatStepZero =
  let a = gaussManin legendreVHS
      v = [1.0, 0.0]
  in eq "flatStep h=0" (flatStep a 0 0.5 v) v

-- --------------------------------------------------------------------------
-- Proof: no ghosts for a bare scheme (Theorem 8.7(2))
-- --------------------------------------------------------------------------

-- | Theorem 8.7(2).  For the free scalar @X = A^1@ the Koszul complex
--   @Lambda^bullet T_X@ sits in degrees @{0,-1}@ (fields, antifields), all
--   nonpositive, with total rank @2^1 = 2@ and no positive-degree ghosts.
--
--     koszulDegrees freeScalar
--   = { dim X = 1 :  degrees are [0, -1, ..., -n] with n = 1 }
--     [0, -1]
--   all (<= 0),  hence hasGhosts = False.  QED.
proof_koszulNoGhosts :: Either String ()
proof_koszulNoGhosts = do
  let dc = freeScalar
  eq     "Koszul degrees"      (koszulDegrees dc) [0, -1]
  expect (all (<= 0) (koszulDegrees dc)) "positive Koszul degree (unexpected ghost)"
  expect (not (hasGhosts dc))            "hasGhosts True for a bare scheme"
  eq     "Koszul total rank"   (koszulTotalRank dc) 2

-- --------------------------------------------------------------------------
-- Proof: schemes give antifields, stacks give ghosts (Remark on ghosts)
-- --------------------------------------------------------------------------

-- | Theorem 8.7 / Remark on ghosts.  The ghost content genuinely distinguishes a
--   bare scheme from a gauge stack:
--
--     hasGhosts freeScalar          = any (> 0) [0,-1]        = False
--     hasGhostsStack 2              = any (> 0) [1,2]         = True
--     stackComplexDegrees 1 2       = [1,2] ++ [0,-1]         has positive degrees
--
--   so "derived geometry supplies antifields, stacky geometry supplies ghosts".
--   QED.
proof_ghostsDistinguish :: Either String ()
proof_ghostsDistinguish = do
  expect (not (hasGhosts freeScalar)) "bare scheme unexpectedly has ghosts"
  expect (hasGhostsStack 2)           "gauge stack (m=2) has no ghosts"
  expect (any (> 0) (stackComplexDegrees 1 2))
         "stack BV-BRST complex has no positive (ghost) degree"

-- --------------------------------------------------------------------------
-- Registry and runner
-- --------------------------------------------------------------------------

-- | All equational-reasoning proofs, labelled by the paper result they verify.
allProofs :: [(String, Either String ())]
allProofs =
  [ ("Def 3.1 / Thm 8.7(1)  R/I adjoins the constraint ideal", proof_onShellAdjoins)
  , ("Prop 5.3 (structure)  Z/4 is a lawful group action",     proof_lawfulGroupAction)
  , ("Prop 5.3             Aut_{[X/G]}(x) = Stab_G(x)",        proof_autEqualsStabilizer)
  , ("Prop 5.3 (cor.)      |orbit| * |stab| = |G|",            proof_orbitStabilizer)
  , ("Thm 8.5(1) / Leray   iterated residues commute",         proof_iteratedResiduesCommute)
  , ("Def 7.1              residue axiom Res_f = boundary form", proof_residueAxiom)
  , ("Thm 8.1 / Ex 6.4     companion realizes Picard-Fuchs",   proof_companionPicardFuchs)
  , ("Thm 8.1(1)           zero-length Gauss-Manin step = id",  proof_flatStepZero)
  , ("Thm 8.7(2)           no ghosts for a bare scheme",        proof_koszulNoGhosts)
  , ("Thm 8.7 (remark)     schemes -> antifields, stacks -> ghosts", proof_ghostsDistinguish)
  ]

-- | Run every proof check, printing PASS/FAIL, and report overall success.
runProofs :: IO Bool
runProofs = do
  putStrLn "=== Equational-reasoning proof checks ==="
  oks <- mapM report allProofs
  let total  = length oks
      passed = length (filter id oks)
  putStrLn ("=== " ++ show passed ++ " / " ++ show total ++ " proof checks passed ===")
  pure (passed == total)
  where
    report :: (String, Either String ()) -> IO Bool
    report (name, res) = case res of
      Right () -> do putStrLn ("  [PASS] " ++ name); pure True
      Left err -> do putStrLn ("  [FAIL] " ++ name ++ "  --  " ++ err); pure False
