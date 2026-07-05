-- | Module      : Properties
--   Description : QuickCheck properties for the load-bearing theorems of Part III,
--                 "Algebraic Geometry: Spaces of Physical Possibility".
--
--   Each block corresponds to one theorem/proposition of the paper:
--
--     * Section 3      : schemes via the functor of points, on-shell algebra R/I,
--                        and well-formedness of the presented rings/ideals.
--     * Proposition 5.3: Aut_{[X/G]}(x) = Stab_G(x); the group and action axioms
--                        hold; every stabilizer is a genuine subgroup;
--                        orbit-stabilizer (Lagrange).
--     * Theorem 8.3    : the stack is strictly finer iff some stabilizer is
--                        nontrivial.
--     * Theorem 8.1    : Gauss-Manin family realization -- linearity of the
--                        first-order system, the companion matrix realizing the
--                        Picard-Fuchs operator (Example 6.4), a computed Griffiths
--                        transversality check, and a finite-difference test that
--                        the transported period actually solves the ODE.
--     * Theorem 8.5(1) : positive-geometry residues -- the residue drops a pole,
--                        iterated residues commute (Leray), the residue axiom
--                        holds at every interior facet, vertices are 0-forms
--                        (numbers), and the n-simplex tree has (n+1)! leaves.
--     * Theorem 8.7    : the derived critical locus -- Koszul degrees are
--                        nonpositive (no ghosts for a scheme) yet a gauge stack
--                        DOES have ghosts, total rank 2^n, the differential
--                        shifts degree by +1, and the classical truncation is
--                        the on-shell algebra R/(dS).
--
--   Compile & run:
--     ghc -Wall -Wextra -Werror -main-is Properties.runAllProperties \
--         -o props Properties.hs -isrc/... -package QuickCheck
--     ./props
module Properties
  ( runAllProperties
  ) where

import Data.Ratio ((%))
import System.Exit (exitFailure, exitSuccess)
import Test.QuickCheck
-- 'isSuccess' is defined in Test.QuickCheck.Test. Some QuickCheck versions do
-- not re-export it through the Test.QuickCheck umbrella, so we source it
-- explicitly (qualified) to guarantee the module typechecks standalone.
import qualified Test.QuickCheck.Test as QCT

import Scheme
  ( CoordRing(..), Ideal(..), Poly(Poly)
  , onShell, affineLine, dualNumbers, specPoints, massShell, pointsOver
  , wellFormedPoly, wellFormedRing, wellFormedIdeal )
import QuotientStack
  ( GAction(GAction), GroupSpec(GroupSpec), points
  , stabilizer, orbit, mkQuotientStack, autGroup, isStrictlyFiner
  , isGroup, isAction, stabilizerIsSubgroup, z4OnSquare, z4Group )
import Hodge
  ( VHS(..), legendreVHS, flatStep, transportPeriod, transportTrajectory
  , picardFuchsLegendre, griffithsOK, griffithsAt )
import PositiveGeometry
  ( DiffForm(DiffForm, poles, coefficient), PositiveGeometry(canonicalForm)
  , Tree(Node), residueAt, residueTree, treeSize, treeLeaves
  , residueAxiomHolds, allLeavesArePoints, interval, simplex )
import DerivedCritical
  ( DerivedCritical, mkDerivedCriticalSafe
  , koszulDegrees, koszulTotalRank, koszulDifferentialDegree
  , classicalCrit, hasGhosts, hasGhostsStack
  , stackComplexDegrees, antibracketDegree, freeScalar )

-- --------------------------------------------------------------------------
-- Numeric helpers
-- --------------------------------------------------------------------------

-- | Relative approximate equality for the floating Gauss-Manin computations.
approxEqRel :: Double -> Double -> Bool
approxEqRel a b = abs (a - b) <= 1e-6 * (1 + max (abs a) (abs b))

-- | Elementwise approximate equality of equal-length vectors.
vecApproxEq :: [Double] -> [Double] -> Bool
vecApproxEq xs ys = length xs == length ys && and (zipWith approxEqRel xs ys)

-- | Dot product.
dot :: [Double] -> [Double] -> Double
dot xs ys = sum (zipWith (*) xs ys)

-- | Factorial on 'Int' (only used at small arguments).
factInt :: Int -> Int
factInt n = product [1 .. n]

-- | Model of the iterated-residue-tree size for a form with @k@ distinct poles:
--   @tsize 0 = 1@ (the numeric leaf), @tsize k = 1 + k * tsize (k-1)@.
tsizeModel :: Int -> Int
tsizeModel k
  | k <= 0    = 1
  | otherwise = 1 + k * tsizeModel (k - 1)

-- --------------------------------------------------------------------------
-- Generators (using forAll to avoid orphan Arbitrary instances)
-- --------------------------------------------------------------------------

-- | A facet label drawn from a small alphabet so that collisions occur (needed
--   to exercise the iterated-residue commutativity law).
genFacet :: Gen String
genFacet = elements ["a", "b", "c", "d", "e"]

-- | A (possibly repeated, possibly empty) list of facet labels.
genPoles :: Gen [String]
genPoles = do
  k <- choose (0, 6)
  vectorOf k genFacet

-- | A nonzero-denominator rational coefficient.
genCoef :: Gen Rational
genCoef = do
  n <- choose (-20, 20) :: Gen Integer
  d <- choose (1, 20)   :: Gen Integer
  pure (n % d)

-- | A toy canonical form (Definition 7.1 datum).
genForm :: Gen DiffForm
genForm = DiffForm <$> genPoles <*> genCoef

-- | A safe Legendre base point, bounded away from the singular locus {0,1}.
genLamSafe :: Gen Double
genLamSafe = choose (0.2, 0.8)

-- | A 2-vector of moderate magnitude (a period / homology pairing vector).
genVec2 :: Gen [Double]
genVec2 = do
  a <- choose (-10, 10)
  b <- choose (-10, 10)
  pure [a, b]

-- | The coordinate ring @k[x_1,...,x_n]@ of affine n-space.
ringOfDim :: Int -> CoordRing
ringOfDim n = CoordRing { generators = [ "x" ++ show i | i <- [1 .. n] ]
                        , relations  = [] }

-- | A derived critical locus of a random ambient dimension @0..6@ (empty @dS@:
--   we test the Koszul degree/rank bookkeeping, which depends only on @dim X@).
genDerived :: Gen DerivedCritical
genDerived = do
  n <- choose (0, 6)
  maybe genDerived pure (mkDerivedCriticalSafe (ringOfDim n) n (Ideal []))

-- | A random ambient ring together with a random ideal of equations of motion
--   whose variables all lie in the ring, for testing the classical truncation
--   @H^0 = R/(dS)@ and ring/ideal well-formedness.
genRingIdeal :: Gen (CoordRing, Ideal)
genRingIdeal = do
  n <- choose (1, 4)
  k <- choose (0, 3) :: Gen Int
  let r  = ringOfDim n
      gs = generators r
      i  = Ideal [ Poly [ (1, [(gs !! (j `mod` n), 1)]) ] | j <- [0 .. k - 1] ]
  pure (r, i)

-- | The finite action Z/n on {0,...,n-1} (a single free orbit, by rotation)
--   together with an added fixed centre. Vertices have trivial stabilizer;
--   the centre has the full group as stabilizer -- exactly the vertices+centre
--   pattern of 'z4OnSquare' (Section 10.2). The last listed point is the centre.
znAction :: Int -> GAction Int (Either Int ())
znAction n = GAction actFn [0 .. n - 1] pts
  where
    pts = [ Left i | i <- [0 .. n - 1] ] ++ [ Right () ]
    actFn :: Int -> Either Int () -> Either Int ()
    actFn g (Left i)  = Left ((g + i) `mod` n)
    actFn _ (Right _) = Right ()

-- | The cyclic group Z/n as an explicit 'GroupSpec' (addition mod n), the group
--   under which 'znAction' is a lawful action.
znGroup :: Int -> GroupSpec Int
znGroup n =
  GroupSpec 0 (\a b -> (a + b) `mod` n) (\a -> (n - a) `mod` n) [0 .. n - 1]

-- --------------------------------------------------------------------------
-- Section 3: schemes via the functor of points, on-shell algebra R/I
-- --------------------------------------------------------------------------

-- | Section 3: the functor of points detects a first-order (tangent) deformation
--   over the dual numbers @k[e]/(e^2)@ but not over the reduced ring @k[x]@ --
--   the defining difference between a scheme and a variety.
prop_functorOfPoints :: Property
prop_functorOfPoints =
  property $
       length (pointsOver specPoints dualNumbers) == 2
    && length (pointsOver specPoints affineLine)  == 1

-- | Definition 3.1: forming @R/I@ adjoins the constraint generators to the
--   relations of @R@ while keeping its generators, so the number of relations
--   grows by exactly @|I|@.
prop_onShellAdjoins :: Property
prop_onShellAdjoins =
  property $
    let r = CoordRing { generators = ["q", "p", "E"], relations = [] }
        s = onShell r massShell
    in generators s == generators r
       && length (relations s) == length (relations r) + length (idealGens massShell)

-- | Section 3: the presented rings and constraint ideals are well-formed --
--   no negative exponents, duplicate variables, or out-of-ring variables.
prop_wellFormedPresentations :: Property
prop_wellFormedPresentations =
  forAll genRingIdeal $ \(r, i) ->
    property $
         wellFormedRing r
      && wellFormedIdeal r i
      && wellFormedRing dualNumbers
      && wellFormedRing affineLine
      && wellFormedIdeal (CoordRing ["q", "p", "E"] []) massShell

-- | Section 3: the well-formedness validators genuinely REJECT malformed
--   presentations -- duplicate generators, out-of-ring variables, repeated
--   variables in a monomial, negative exponents, and ideals over ill-formed
--   rings.
prop_wellFormedRejects :: Property
prop_wellFormedRejects =
  property $
       not (wellFormedRing (CoordRing ["x", "x"] []))                    -- duplicate generators
    && not (wellFormedPoly ["x"] (Poly [(1, [("y", 1)])]))               -- out-of-ring variable
    && not (wellFormedPoly ["x"] (Poly [(1, [("x", 1), ("x", 1)])]))     -- repeated variable
    && not (wellFormedPoly ["x"] (Poly [(1, [("x", -1)])]))              -- negative exponent
    && not (wellFormedPoly ["x"] (Poly [(1, [("x", 0)])]))               -- zero exponent
    && not (wellFormedIdeal (CoordRing ["x", "x"] []) (Ideal []))        -- ill-formed ring
    && not (wellFormedIdeal (CoordRing ["x"] [])
              (Ideal [Poly [(1, [("z", 1)])]]))                          -- ideal var not in ring

-- --------------------------------------------------------------------------
-- Proposition 5.3 / Theorem 8.3: groups, actions, stabilizers, stacks
-- --------------------------------------------------------------------------

-- | Proposition 5.3 (structure): @Z/n@ really is a group and @znAction@ really
--   is an action of it -- the group and action axioms both hold.
prop_lawfulGroupAction :: Property
prop_lawfulGroupAction =
  forAll (choose (1, 8)) $ \n ->
    property $ isGroup (znGroup n) && isAction (znGroup n) (znAction n)

-- | Proposition 5.3: the validators REJECT malformed structures -- a carrier
--   with a non-closed operation is not a group, and an action whose map escapes
--   the point set is not an action.
prop_groupActionRejects :: Property
prop_groupActionRejects =
  property $
       not (isGroup badGroup)
    && not (isAction (znGroup 3) badAction)
  where
    badGroup :: GroupSpec Int
    badGroup = GroupSpec 0 (+) negate [0, 1, 2]        -- 1+2 = 3 not in carrier
    badAction :: GAction Int Int
    badAction = GAction (+) [0, 1, 2] [0, 1, 2]         -- act 2 2 = 4 escapes points

-- | Proposition 5.3: every stabilizer is a genuine subgroup (contains the unit,
--   closed under the operation and inverses) -- not merely an arbitrary filter.
prop_stabilizerIsSubgroup :: Property
prop_stabilizerIsSubgroup =
  forAll (choose (1, 8)) $ \n ->
    forAll (choose (0, n)) $ \idx ->
      let ga = znAction n
          p  = points ga !! idx
      in property $ stabilizerIsSubgroup (znGroup n) ga p

-- | Proposition 5.3: the automorphism group assigned by the quotient stack is,
--   by construction, exactly the stabilizer @Stab_G(x)@ (a wiring check).
prop_autEqualsStabilizer :: Property
prop_autEqualsStabilizer =
  forAll (choose (1, 10)) $ \n ->
    forAll (choose (0, n)) $ \idx ->
      let ga = znAction n
          qs = mkQuotientStack ga
          p  = points ga !! idx
      in autGroup qs p === stabilizer ga p

-- | Orbit-stabilizer / Lagrange: for a finite group action
--   @|orbit(x)| * |Stab(x)| = |G|@. Here @|G| = n@.
prop_orbitStabilizer :: Property
prop_orbitStabilizer =
  forAll (choose (1, 10)) $ \n ->
    forAll (choose (0, n)) $ \idx ->
      let ga = znAction n
          p  = points ga !! idx
      in length (orbit ga p) * length (stabilizer ga p) === n

-- | Theorem 8.3: the stack is strictly finer than its coarse space iff some
--   point has a nontrivial stabilizer. For @Z/n@+centre this happens iff
--   @n > 1@ (the centre then has stabilizer of order @n@).
prop_strictlyFinerIffNontrivial :: Property
prop_strictlyFinerIffNontrivial =
  forAll (choose (1, 10)) $ \n ->
    isStrictlyFiner (mkQuotientStack (znAction n)) === (n > 1)

-- | Theorem 8.3, concrete witness (Z/4 on the square): Z/4 is a lawful group
--   acting lawfully, the centre has full stabilizer of order 4, the vertices
--   have a free orbit of size 4, and the stack is strictly finer.
prop_z4Witness :: Property
prop_z4Witness =
  property $
       isGroup z4Group
    && isAction z4Group z4OnSquare
    && isStrictlyFiner (mkQuotientStack z4OnSquare)
    && any (\p -> length (stabilizer z4OnSquare p) == 4) (points z4OnSquare)
    && any (\p -> length (orbit z4OnSquare p) == 4)      (points z4OnSquare)

-- --------------------------------------------------------------------------
-- Theorem 8.1: Gauss-Manin family realization
-- --------------------------------------------------------------------------

-- | Theorem 8.1(1): the first-order Gauss-Manin system @dPi = A Pi@ is linear,
--   so its Euler step obeys the superposition principle
--   @step(v+w) = step(v) + step(w)@.
prop_gaussManinLinear :: Property
prop_gaussManinLinear =
  forAll genLamSafe $ \lam ->
  forAll genVec2    $ \v ->
  forAll genVec2    $ \w ->
  forAll (choose (0.1, 1.0)) $ \h ->
    let a   = gaussManin legendreVHS
        lhs = flatStep a h lam (zipWith (+) v w)
        rhs = zipWith (+) (flatStep a h lam v) (flatStep a h lam w)
    in vecApproxEq lhs rhs

-- | Theorem 8.1(1): the connection is a 2x2 companion matrix whose first row is
--   @[0,1]@: the derivative of the first period component is the second.
prop_companionShape :: Property
prop_companionShape =
  forAll genLamSafe $ \lam ->
    let a = gaussManin legendreVHS lam
    in case a of
         [row0, row1] -> row0 === [0, 1] .&&. property (length row1 == 2)
         _            -> property False

-- | Theorem 8.1(2) / Example 6.4: the companion matrix realizes the Legendre
--   Picard-Fuchs operator. With @v = [f, f']@ the second component of @A v@ is
--   @f''@, and @c2 f'' + c1 f' + c0 f = 0@.
prop_companionRealizesPicardFuchs :: Property
prop_companionRealizesPicardFuchs =
  forAll genLamSafe $ \lam ->
  forAll (choose (-10, 10)) $ \f ->
  forAll (choose (-10, 10)) $ \f' ->
    let (c2, c1, c0) = picardFuchsLegendre lam
    in case gaussManin legendreVHS lam of
         [_, row1] ->
           let fpp = row1 `dot` [f, f']   -- second component of A v = f''
           in approxEqRel (c2 * fpp + c1 * f' + c0 * f) 0
         _ -> False

-- | Theorem 8.1(2): the transported period actually solves its Picard-Fuchs
--   equation. Estimating @Pi, Pi', Pi''@ by finite differences of the FIRST
--   component of the transported trajectory (so the whole companion system,
--   including its second row, is exercised), the Picard-Fuchs residual
--   @c2 Pi'' + c1 Pi' + c0 Pi@ vanishes to discretization order. This is a
--   genuine ODE check, not the algebraic companion identity.
prop_transportSolvesODE :: Property
prop_transportSolvesODE =
  forAll (choose (0.25, 0.65)) $ \lam0 ->
    let n            = 8000 :: Int
        lam1         = lam0 + 0.04
        traj         = transportTrajectory legendreVHS lam0 lam1 n [1.0, 0.0]
        h            = (lam1 - lam0) / fromIntegral n
        mid          = n `div` 2
        lamMid       = lam0 + fromIntegral mid * h
        pizero k     = (traj !! k) !! 0        -- Pi sampled from the trajectory
        piMid        = pizero mid
        piP          = (pizero (mid + 1) - pizero (mid - 1)) / (2 * h)
        piPP         = (pizero (mid + 1) - 2 * piMid + pizero (mid - 1)) / (h * h)
        (c2, c1, c0) = picardFuchsLegendre lamMid
        residual     = c2 * piPP + c1 * piP + c0 * piMid
        scl          = 1 + abs (c2 * piPP) + abs (c1 * piP) + abs (c0 * piMid)
    in abs residual <= 1e-2 * scl

-- | Theorem 8.1: the flat transport over a degenerate (zero-length) base
--   interval, and any non-positive step count, is the identity.
prop_transportFixedBase :: Property
prop_transportFixedBase =
  forAll genLamSafe $ \lam ->
  forAll (choose (-5, 50)) $ \n ->
  forAll genVec2 $ \v ->
    transportPeriod legendreVHS lam lam n v === v

-- | Definition 6.2: Griffiths transversality, computed from the actual
--   filtration and connection data (not read off a stored Boolean), holds; and
--   it agrees with the recorded witness.
prop_griffithsComputed :: Property
prop_griffithsComputed =
  forAll genLamSafe $ \lam ->
    property $ griffithsAt legendreVHS lam
             && griffithsAt legendreVHS lam == griffithsOK legendreVHS
             && rank legendreVHS == 2

-- --------------------------------------------------------------------------
-- Theorem 8.5(1): positive-geometry residues
-- --------------------------------------------------------------------------

-- | Definition 7.1 (residue axiom): the residue along a facet removes exactly
--   that pole and preserves the coefficient.
prop_residueDropsPole :: Property
prop_residueDropsPole =
  forAll genForm  $ \df ->
  forAll genFacet $ \f ->
    let df' = residueAt f df
    in property $ f `notElem` poles df' && coefficient df' == coefficient df

-- | Theorem 8.5(1) / Leray: iterated residues commute (the residue along a
--   codimension-two stratum is independent of the order of the two facets).
prop_iteratedResiduesCommute :: Property
prop_iteratedResiduesCommute =
  forAll genForm  $ \df ->
  forAll genFacet $ \f ->
  forAll genFacet $ \g ->
    residueAt f (residueAt g df) === residueAt g (residueAt f df)

-- | Theorem 8.5(1): the residue axiom holds at every interior facet of the
--   built geometries -- each boundary stratum's canonical form IS the residue of
--   its parent's form (the tree is a genuine residue computation, not a copy).
prop_residueAxiomHolds :: Property
prop_residueAxiomHolds =
  forAll (choose (0, 5)) $ \n ->
    property $ residueAxiomHolds (simplex n) && residueAxiomHolds interval

-- | Theorem 8.5(1): the recursion terminates at vertices, which are genuine
--   0-forms (numbers) with no remaining poles.
prop_verticesAreNumbers :: Property
prop_verticesAreNumbers =
  forAll (choose (0, 5)) $ \n ->
    property $ allLeavesArePoints (simplex n) && allLeavesArePoints interval

-- | Definition 7.4: the root of the residue tree is decorated by the canonical
--   form of the geometry.
prop_residueTreeRoot :: Property
prop_residueTreeRoot =
  forAll (choose (0, 4)) $ \n ->
    let Node r _ = residueTree (simplex n)
    in r === canonicalForm (simplex n)

-- | Theorem 8.5(1): the residue tree of the n-simplex has exactly @(n+1)!@
--   leaves (complete flags of facets) and @tsize (n+1)@ nodes.
prop_simplexResidueTree :: Property
prop_simplexResidueTree =
  forAll (choose (0, 5)) $ \n ->
    let t = residueTree (simplex n)
    in length (treeLeaves t) === factInt (n + 1)
       .&&. treeSize t === tsizeModel (n + 1)

-- | Example 7.2: the interval @[a,b]@ (a 2-pole form) has an iterated-residue
--   tree with @2! = 2@ numeric leaves and @tsize 2 = 5@ nodes.
prop_intervalResidueTree :: Property
prop_intervalResidueTree =
  property $
    let t = residueTree interval
    in treeSize t == tsizeModel 2 && length (treeLeaves t) == factInt 2

-- --------------------------------------------------------------------------
-- Theorem 8.7: derived critical locus as BV field/antifield algebra
-- --------------------------------------------------------------------------

-- | Theorem 8.7(2): every generator of @Lambda^bullet T_X@ lives in nonpositive
--   cohomological degree -- there are NO ghosts for a bare scheme.
prop_koszulNoGhosts :: Property
prop_koszulNoGhosts =
  forAll genDerived $ \dc ->
    property $ all (<= 0) (koszulDegrees dc) && not (hasGhosts dc)

-- | Theorem 8.7 (Remark on ghosts): the ghost distinction is NON-vacuous -- a
--   bare scheme has no ghosts, whereas resolving an @m>0@ gauge symmetry via the
--   stack @[X/G]@ introduces positive-degree ghosts.
prop_ghostsDistinguishStack :: Property
prop_ghostsDistinguishStack =
  forAll (choose (0, 4)) $ \n ->
  forAll (choose (1, 5)) $ \m ->
    property $
         not (hasGhosts freeScalar)
      && hasGhostsStack m
      && not (hasGhostsStack 0)          -- no gauge symmetry: no ghosts
      && not (hasGhostsStack (-3))       -- nonsensical gauge dimension: no ghosts
      && any (> 0) (stackComplexDegrees n m)

-- | Theorem 8.7: the validated constructor 'mkDerivedCriticalSafe' accepts a
--   derived critical locus exactly when the smooth dimension is non-negative,
--   and then the Koszul complex has the expected degrees @[0,-1,...,-n]@.
prop_derivedCriticalValidity :: Property
prop_derivedCriticalValidity =
  forAll (choose (-5, 6)) $ \n ->
    case mkDerivedCriticalSafe (ringOfDim (max 0 n)) n (Ideal []) of
      Just dc -> n >= 0 && koszulDegrees dc == [ negate p | p <- [0 .. n] ]
      Nothing -> n < 0

-- | Theorem 8.7(2): the degrees present are @[0,-1,...,-n]@ (top antifield degree
--   @-n = -dim X@); @Lambda^bullet T_X@ has total rank @2^n@; and the Koszul
--   differential @iota_{dS}@ shifts every antifield degree back into the complex.
prop_koszulShape :: Property
prop_koszulShape =
  forAll genDerived $ \dc ->
    let ds      = koszulDegrees dc
        n       = length ds - 1
        shifted = [ d + koszulDifferentialDegree | d <- ds, d < 0 ]
    in property $
         maximum ds == 0
         && minimum ds == negate n
         && koszulTotalRank dc == 2 ^ n
         && all (`elem` ds) shifted

-- | Theorem 8.7(1): the classical truncation @pi_0(dCrit(S)) = Crit(S)@ has
--   coordinate ring @H^0 = R/(dS)@ -- it keeps @R@'s generators and adjoins the
--   equations of motion to its relations (checked via 'Eq', not @show@).
prop_classicalTruncation :: Property
prop_classicalTruncation =
  forAll genRingIdeal $ \(r, i) ->
    case mkDerivedCriticalSafe r (length (generators r)) i of
      Just dc ->
        let c = classicalCrit dc
        in property $
             generators c == generators r
             && relations c == relations r ++ idealGens i
      Nothing -> property False   -- unreachable: dim = #generators >= 0

-- | Theorem 8.7: the BV antibracket sits in cohomological degree @-1@, and the
--   free scalar @S = phi^2/2@ has @Crit(S) = {phi = 0}@ with a rank-2 Koszul
--   complex in degrees @{0,-1}@.
prop_freeScalar :: Property
prop_freeScalar =
  property $
       antibracketDegree == (-1)
    && koszulDegrees freeScalar == [0, -1]
    && koszulTotalRank freeScalar == 2
    && generators (classicalCrit freeScalar) == ["phi"]
    && length (relations (classicalCrit freeScalar)) == 1

-- --------------------------------------------------------------------------
-- Runner
-- --------------------------------------------------------------------------

-- | Run a property at the default 100 tests, reporting success.
run :: Testable prop => String -> prop -> IO Bool
run name prop = do
  putStrLn ("* " ++ name)
  res <- quickCheckResult prop
  pure (QCT.isSuccess res)

-- | Run a property at an elevated test count (used for the core laws).
runN :: Testable prop => Int -> String -> prop -> IO Bool
runN k name prop = do
  putStrLn ("* " ++ name)
  res <- quickCheckWithResult stdArgs { maxSuccess = k } prop
  pure (QCT.isSuccess res)

-- | Run every property; exit nonzero if any fails.
runAllProperties :: IO ()
runAllProperties = do
  putStrLn "=== QuickCheck properties: Algebraic Geometry / Physical Possibility ==="
  results <- sequence
    [ run  "Sec 3   functor of points sees the tangent vector" prop_functorOfPoints
    , run  "Sec 3   R/I adjoins the constraint ideal"          prop_onShellAdjoins
    , run  "Sec 3   presented rings/ideals are well-formed"    prop_wellFormedPresentations
    , run  "Sec 3   validators reject malformed presentations" prop_wellFormedRejects
    , runN 300 "Prop 5.3 Z/n is a group and znAction lawful"   prop_lawfulGroupAction
    , run  "Prop 5.3 validators reject non-group/action"       prop_groupActionRejects
    , runN 300 "Prop 5.3 stabilizer is a subgroup"             prop_stabilizerIsSubgroup
    , runN 500 "Prop 5.3 Aut_{[X/G]}(x) = Stab_G(x)"           prop_autEqualsStabilizer
    , runN 500 "Lagrange |orbit|*|stab| = |G|"                 prop_orbitStabilizer
    , runN 500 "Thm 8.3 stack strictly finer <=> nontrivial"   prop_strictlyFinerIffNontrivial
    , run  "Thm 8.3 Z/4-on-square witness"                     prop_z4Witness
    , runN 500 "Thm 8.1(1) Gauss-Manin step is linear"         prop_gaussManinLinear
    , run  "Thm 8.1(1) connection is a 2x2 companion matrix"   prop_companionShape
    , runN 500 "Thm 8.1(2) companion realizes Picard-Fuchs"    prop_companionRealizesPicardFuchs
    , run  "Thm 8.1(1) transported period solves the ODE"      prop_transportSolvesODE
    , run  "Thm 8.1   flat transport over a point is id"       prop_transportFixedBase
    , run  "Def 6.2   Griffiths transversality (computed)"     prop_griffithsComputed
    , runN 500 "Thm 8.5(1) residue drops a pole"               prop_residueDropsPole
    , runN 500 "Thm 8.5(1) iterated residues commute (Leray)"  prop_iteratedResiduesCommute
    , run  "Thm 8.5(1) residue axiom holds at every edge"      prop_residueAxiomHolds
    , run  "Thm 8.5(1) vertices are 0-forms (numbers)"         prop_verticesAreNumbers
    , run  "Def 7.4   residue-tree root = canonical form"      prop_residueTreeRoot
    , run  "Thm 8.5(1) n-simplex tree has (n+1)! leaves"       prop_simplexResidueTree
    , run  "Ex 7.2    interval residue tree (5 nodes/2 leaves)" prop_intervalResidueTree
    , run  "Thm 8.7(2) Koszul degrees <= 0 (no ghosts)"        prop_koszulNoGhosts
    , run  "Thm 8.7   ghosts distinguish scheme vs stack"      prop_ghostsDistinguishStack
    , run  "Thm 8.7   safe constructor rejects negative dim"   prop_derivedCriticalValidity
    , run  "Thm 8.7(2) Koszul shape, rank 2^n, differential"   prop_koszulShape
    , run  "Thm 8.7(1) classical truncation = R/(dS)"          prop_classicalTruncation
    , run  "Thm 8.7   free scalar / antibracket degree -1"     prop_freeScalar
    ]
  let nTotal  = length results
      nPassed = length (filter id results)
  putStrLn ("=== " ++ show nPassed ++ " / " ++ show nTotal ++ " properties passed ===")
  if nPassed == nTotal then exitSuccess else exitFailure
