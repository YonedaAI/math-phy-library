-- | Module      : Main
--   Part VII (Synthesis) of "A Math->Physics Representation Library":
--   "A Modular Representation Synthesis".
--
--   Demonstrates the modular composition ladder (Parts I--VI), the Closure
--   Theorem keystone (isotropy correspondence @Aut_{[X/G]}(x) ~= Stab_G(x)@,
--   synthesis eq. mf7), and its physical face /gauge redundancy = quantum high
--   availability/ with the surface-code decomposition
--   @H_phys ~= (H_log (x) H_gauge) (+) H_err@ (eq. mf8).  It then runs every
--   equational proof check and QuickCheck property, exiting non-zero on any
--   failure.
module Main (main) where

import Numeric.Natural   (Natural)
import System.Exit       (exitFailure)

import Closure
import Coaction
import Gauge
import Homology
import Ladder
import Properties        (runAllProperties)
import Proofs            (runAllProofs)

-- | Program entry point.
main :: IO ()
main = do
  putStrLn "=================================================================="
  putStrLn " A Modular Representation Synthesis (Part VII) -- verification run"
  putStrLn "=================================================================="

  demoLadder
  demoCoaction
  demoIsotropyKeystone
  demoGaugeEqualsQEC
  demoComposition

  putStrLn ""
  proofsOk <- runAllProofs
  putStrLn ""
  propsOk  <- runAllProperties

  putStrLn ""
  putStrLn "------------------------------------------------------------------"
  if proofsOk && propsOk
    then putStrLn "ALL CHECKS PASSED: closure + composition verified."
    else do
      putStrLn "FAILURE: some proof or property check did not pass."
      exitFailure

-- | The six-rung ladder: new structure, emergent property, status per rung.
demoLadder :: IO ()
demoLadder = do
  putStrLn ""
  putStrLn "[1] The modular composition ladder (Parts I -> VI):"
  mapM_ line allRungs
  where
    line :: Rung -> IO ()
    line r = putStrLn $
      "    " ++ pad 4 (show r) ++ " status=" ++ show (rungStatus r)
        ++ "  emergent: " ++ emergentProperty r

-- | Part II face: the deconcatenation coaction of a symbol decomposes it.
demoCoaction :: IO ()
demoCoaction = do
  putStrLn ""
  putStrLn "[2] Coalgebraic anatomy (Part II): coaction of the symbol [1,2,3]:"
  let w = [1, 2, 3 :: Int]
  putStrLn $ "    Delta(w) = " ++ show (coproduct w)
  putStrLn $ "    coassociative? "
    ++ show (sortT (leftCoaction w) == sortT (rightCoaction w))
  where
    sortT :: Ord a => [a] -> [a]
    sortT = foldr insrt []
    insrt :: Ord a => a -> [a] -> [a]
    insrt y []       = [y]
    insrt y (z : zs) = if y <= z then y : z : zs else z : insrt y zs

-- | The isotropy keystone worked example: @S_3@ acting on @{0,1,2}@ at @0@.
demoIsotropyKeystone :: IO ()
demoIsotropyKeystone = do
  putStrLn ""
  putStrLn "[3] Isotropy keystone (eq. mf7): S_3 acting on {0,1,2}, x = 0:"
  let g   = symmetricGroup 3
      aut = autGroupoid (actionGroupoid g) 0
      st  = stabilizer g 0
  putStrLn $ "    Aut_{X//G}(0) = " ++ show aut
  putStrLn $ "    Stab_G(0)     = " ++ show st
  putStrLn $ "    Aut ~= Stab ? " ++ show (isotropy g 0)
  putStrLn $ "    orbit-stabilizer |orbit|*|Stab|=|G| ? "
    ++ show (orbitStabilizer g 0)
    ++ "  (" ++ show (length (orbit g 0)) ++ "*"
    ++ show (length st) ++ "=" ++ show (length (groupElems g)) ++ ")"

-- | Gauge redundancy = QEC redundancy, with surface-code logical dims.
demoGaugeEqualsQEC :: IO ()
demoGaugeEqualsQEC = do
  putStrLn ""
  putStrLn "[4] Gauge redundancy = quantum high availability (eq. mf8):"
  let g4 = symmetricGroup 4
      (tot, con, red, ok) = gaugeRedundancy g4 0
  putStrLn $ "    gauge face  : |G|=" ++ show tot ++ " = |orbit|*|Stab| = "
    ++ show con ++ "*" ++ show red ++ "  ok=" ++ show ok
  putStrLn "    QEC face (surface codes): logical dim = 2^{2g}"
  mapM_ surfaceLine [0 .. 4]
  where
    surfaceLine :: Natural -> IO ()
    surfaceLine g = do
      let cp = surfaceCode g (2 * g + 3)
          s  = subsystemDims cp
      putStrLn $ "      g=" ++ show g
        ++ ": rank H_1 = " ++ pad 2 (show (h1Rank g))
        ++ ", dim H_log = 2^" ++ pad 2 (show (h1Rank g))
        ++ " = " ++ pad 6 (show (surfaceCodeLogicalDim g))
        ++ ", subsystem valid = " ++ show (validSubsystem cp s)

-- | The six faculties compose into a single status-graded representation entry.
demoComposition :: IO ()
demoComposition = do
  putStrLn ""
  putStrLn "[5] The faculties compose (Grothendieck construction, PI/T3):"
  let chain =
        [ RepEntry "Math_I"   "Info_II"  (rungStatus I)
        , RepEntry "Info_II"  "Geom_III" (rungStatus II)
        , RepEntry "Geom_III" "Top_IV"   (rungStatus III)
        , RepEntry "Top_IV"   "Cat_V"    (rungStatus IV)
        , RepEntry "Cat_V"    "Stk_VI"   (rungStatus V)
        , RepEntry "Stk_VI"   "Phys"     (rungStatus VI)
        ]
  case composeChain chain of
    Nothing -> putStrLn "    (chain not composable -- unexpected)"
    Just e  -> putStrLn $
      "    composite: " ++ mathTag e ++ " ~> " ++ physTag e
        ++ "  status=" ++ show (entryStatus e)
        ++ "  (= worstOf, PI/T3 status cannot improve)"
  putStrLn $ "    ladderComposite status = "
    ++ show (entryStatus ladderComposite)
    ++ " = worstOf " ++ show (map rungStatus allRungs)

-- | Right-pad a string to a fixed width.
pad :: Int -> String -> String
pad n s = s ++ replicate (max 0 (n - length s)) ' '
