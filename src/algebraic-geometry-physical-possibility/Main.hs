-- | Module      : Main
--   Description : Executable demonstrations of the key results of Part III,
--                 "Algebraic Geometry: Spaces of Physical Possibility".
--
--   Part III of the modular series "A Math->Physics Representation Library".
--   Running `main` demonstrates, in order:
--     1. Schemes via the functor of points, and the on-shell algebra R/I
--        (Section 3): the dual numbers make an infinitesimal (tangent)
--        direction visible that a variety cannot see.
--     2. Quotient stacks retain stabiliser data (Proposition 5.3, Theorem 8.3):
--        a fixed point has a nontrivial automorphism group that the coarse
--        quotient forgets.
--     3. The family realization pipeline (Theorem 8.1 / T1): Gauss-Manin flat
--        transport of a Legendre-family period, constrained by Picard-Fuchs.
--     4. Positive-geometry residue trees (Theorem 8.5(1)): the recursive
--        residue decomposition of the interval and the simplex.
module Main (main) where

import System.Exit (exitFailure)

import Scheme
import QuotientStack
import Hodge
import PositiveGeometry
import DerivedCritical
import Proofs (runProofs)

banner :: String -> IO ()
banner s = do
  putStrLn ""
  putStrLn (replicate 68 '=')
  putStrLn s
  putStrLn (replicate 68 '=')

demoSchemes :: IO ()
demoSchemes = do
  banner "1. Schemes as spaces of physical possibility (Section 3)"
  putStrLn "Affine line A^1 = Spec k[x]:"
  putStrLn ("  generators = " ++ show (generators affineLine))
  putStrLn ("  relations  = " ++ show (relations affineLine))
  putStrLn ""
  putStrLn "Points of Spec k[x] over the DUAL NUMBERS k[e]/(e^2):"
  putStrLn ("  " ++ show (pointsOver specPoints dualNumbers))
  putStrLn "  -> the point x = e is a first-order (tangent) deformation,"
  putStrLn "     invisible to the underlying variety. This is why schemes"
  putStrLn "     (not just varieties) model *infinitesimal* possibility."
  putStrLn ""
  let free  = CoordRing { generators = ["q","p","E"], relations = [] }
      shell = onShell free massShell
  putStrLn "On-shell observable algebra R/I (Example 3.2, mass shell):"
  putStrLn ("  R   = " ++ show (generators free))
  putStrLn ("  I   = " ++ show massShell)
  putStrLn ("  R/I relations = " ++ show (relations shell))
  putStrLn "  -> E is no longer independent: it is a function of p on-shell."

demoStacks :: IO ()
demoStacks = do
  banner "2. Moduli stacks retain gauge information (Prop 5.3, Thm 8.3)"
  let ga = z4OnSquare
      qs = mkQuotientStack ga
  putStrLn "Action: Z/4 rotating a square's vertices, fixing the centre."
  putStrLn ""
  putStrLn "Stabiliser (= Aut_{[X/G]}) at each point  [Proposition 5.3]:"
  mapM_ (\x -> putStrLn ("  " ++ show x ++ " : Stab = "
                          ++ show (autGroup qs x)
                          ++ "  (|Stab| = " ++ show (length (autGroup qs x)) ++ ")"))
        (points ga)
  putStrLn ""
  putStrLn ("Coarse quotient X/G (orbits only): "
             ++ show (coarseQuotient ga))
  putStrLn ("Stack strictly finer than coarse space? [Theorem 8.3]: "
             ++ show (isStrictlyFiner qs))
  putStrLn "  -> the centre has automorphism group Z/4 (all of |G|), which the"
  putStrLn "     coarse quotient collapses to a single structureless point."

demoHodge :: IO ()
demoHodge = do
  banner "3. Family realization pipeline: Gauss-Manin transport (Thm 8.1/T1)"
  let vhs = legendreVHS
  putStrLn ("Legendre VHS  R^1 pi_* Q  over P^1 \\ {0,1,oo},  rank = "
             ++ show (rank vhs))
  putStrLn ("Griffiths transversality holds? " ++ show (griffithsOK vhs))
  putStrLn ""
  let (c2, c1, c0) = picardFuchsLegendre 0.5
  putStrLn "Picard-Fuchs operator at lambda = 0.5  (Example 6.4):"
  putStrLn ("  " ++ show c2 ++ " f'' + " ++ show c1 ++ " f' + "
             ++ show c0 ++ " f = 0")
  putStrLn ""
  let v0     = [1.0, 0.0]                 -- an initial period vector
      vEnd   = transportPeriod vhs 0.2 0.6 400 v0
  putStrLn "Flat (Gauss-Manin) transport of a period from lambda=0.2 to 0.6:"
  putStrLn ("  Pi(0.2) = " ++ show v0)
  putStrLn ("  Pi(0.6) ~ " ++ show (map (roundTo 6) vEnd))
  putStrLn "  -> Pi solves the first-order Gauss-Manin system d(Pi) = A Pi; the"
  putStrLn "     flat sections are the Betti cycles, NOT the (non-constant) period."
  putStrLn "     Pi's variation across kinematic space is fixed by Picard-Fuchs."

demoPositiveGeometry :: IO ()
demoPositiveGeometry = do
  banner "4. Positive-geometry residue trees (Theorem 8.5(1))"
  putStrLn "Interval [a,b] in P^1 (Example 7.2): canonical form and residues."
  putStrLn ("  Omega = " ++ show (canonicalForm interval))
  let t1 = residueTree interval
  putStrLn "  residue tree:"
  putStr (indent (show t1))
  putStrLn ("  tree size = " ++ show (treeSize t1)
             ++ ",  leaves (primitive pieces) = "
             ++ show (map show (treeLeaves t1)))
  putStrLn ""
  putStrLn "Standard 2-simplex Delta^2: recursive residue decomposition."
  let t2 = residueTree (simplex 2)
  putStr (indent (show t2))
  putStrLn ("  tree size = " ++ show (treeSize t2)
             ++ ",  leaves = " ++ show (length (treeLeaves t2)))
  putStrLn "  -> the recursive residue tree is the geometric coproduct of"
  putStrLn "     Theorem 8.5(1), conjecturally matching the motivic coaction"
  putStrLn "     tree of Part II (Theorem 8.5(2), status H)."

demoDerived :: IO ()
demoDerived = do
  banner "5. Derived critical locus as BV field/antifield algebra (Thm 8.7)"
  let dc = freeScalar
  putStrLn "Free scalar X = A^1 = Spec k[phi], action S = phi^2/2, dS = (phi):"
  putStrLn ("  Koszul complex Lambda^* T_X in degrees " ++ show (koszulDegrees dc))
  putStrLn ("  graded ranks (Lambda^p T_X)             = " ++ show (koszulTotalRank dc)
             ++ " total (= 2^dim)")
  putStrLn ("  ghosts present? " ++ show (hasGhosts dc)
             ++ "   (False: a bare scheme supplies antifields, not ghosts)")
  putStrLn ("  BV antibracket cohomological degree     = " ++ show antibracketDegree)
  putStrLn ""
  let crit = classicalCrit dc
  putStrLn "Classical truncation pi_0(dCrit S) = Crit(S) = R/(dS)  [Thm 8.7(1)]:"
  putStrLn ("  H^0 generators = " ++ show (generators crit))
  putStrLn ("  H^0 relations  = " ++ show (relations crit))
  putStrLn "  -> H^0 is exactly the on-shell algebra R/I of Section 3."

runProofChecks :: IO ()
runProofChecks = do
  banner "Machine-checked equational proofs (Section 8 identities)"
  ok <- runProofs
  if ok
    then putStrLn "All equational proof checks passed."
    else do
      putStrLn "FAILURE: some equational proof check did not hold."
      exitFailure

-- helpers
roundTo :: Int -> Double -> Double
roundTo n x = fromIntegral (round (x * m) :: Integer) / m
  where m = 10 ^^ n

indent :: String -> String
indent = unlines . map ("    " ++) . lines

main :: IO ()
main = do
  putStrLn "Algebraic Geometry: Spaces of Physical Possibility (Part III)"
  putStrLn "Executable demonstrations of Theorems 8.1, 8.3, 8.5 and Prop 5.3."
  demoSchemes
  demoStacks
  demoHodge
  demoPositiveGeometry
  demoDerived
  runProofChecks
  banner "Done."
