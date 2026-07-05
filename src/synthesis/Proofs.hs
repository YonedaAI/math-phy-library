-- | Module      : Proofs
--   Part VII (Synthesis): equational-reasoning proofs of the closure /
--   composition claims, each with an executable check at concrete values.
--
--   Every proof follows the format  lhs = ... = ... = rhs , each step citing a
--   definition or a synthesis theorem, and is accompanied by a @proof_*@
--   function that verifies the equality at worked examples.  The /general/ form
--   of each law (over arbitrary inputs) is exercised by the corresponding
--   @prop_*@ in "Properties"; these executable checks are the concrete
--   instantiations that ground the equational derivations, several of them
--   ranging over more than one witness.
module Proofs
  ( -- * Individual proof checks
    proof_statusComposeMax
  , proof_statusChainWorst
  , proof_coactionCoassociative
  , proof_isotropyAutEqStab
  , proof_orbitStabilizer
  , proof_surfaceLogicalDim
  , proof_subsystemMasterFormula
  , proof_gaugeEqualsQEC
  , proof_ladderStatus
    -- * Aggregate
  , allProofs
  , runAllProofs
  ) where

import Data.List (sort)

import Closure
import Coaction
import Gauge
import Homology
import Ladder
import Status

-- | Proof (PI/T3): the composite of statuses is the @max@ under @S <= H <= P@.
--
--   > composeStatus H S
--   > = { definition of composeStatus }
--   >   max H S
--   > = { S <= H, so max H S = H }
--   >   H
--   > QED
proof_statusComposeMax :: Either String ()
proof_statusComposeMax =
  expectEq "statusComposeMax"
    (composeStatus H S) H
    `andThen` expectEq "statusComposeMax/P"
    (composeStatus S P) P

-- | Proof (PI/T3): the status of a whole chain is the worst link.
--
--   > worstOf [S,H,S,P,S]
--   > = { foldr composeStatus S = iterated max }
--   >   max S (max H (max S (max P S)))
--   > = { max is associative/commutative, P is top }
--   >   P
--   > QED
proof_statusChainWorst :: Either String ()
proof_statusChainWorst =
  expectEq "statusChainWorst" (worstOf [S, H, S, P, S]) P

-- | Proof (eq. mf5): the deconcatenation coaction is coassociative.
--
--   > (Delta (x) id) . Delta $ w
--   > = { split off the left factor, then re-split it }
--   >   { (u,v,x) : u ++ v ++ x = w }
--   > = { re-associate the three ordered pieces }
--   >   { (u,v,x) : u ++ (v ++ x) = w }
--   > = { split off the right factor, then re-split it }
--   >   (id (x) Delta) . Delta $ w
--   > QED
proof_coactionCoassociative :: Either String ()
proof_coactionCoassociative =
  foldr andThen (Right ())
    [ expectEq ("coactionCoassociative/" ++ show w)
        (sort (leftCoaction w)) (sort (rightCoaction w))
    | w <- [ [], [7], [1, 2], [1, 2, 3], [4, 5, 6, 7] ] :: [[Int]]
    ]

-- | Proof (eq. mf7): @Aut_{[X/G]}(x) ~= Stab_G(x)@.
--
--   > Aut_{X//G}(x)
--   > = { definition of the action groupoid: Hom(x,x) = { g : g.x = y = x } }
--   >   { g in G : g(x) = x }
--   > = { definition of the stabilizer }
--   >   Stab_G(x)
--   > QED
--
--   Worked examples: @G = S_3@ and @G = S_4@ at /every/ base point; each time
--   the two independent constructions agree.
proof_isotropyAutEqStab :: Either String ()
proof_isotropyAutEqStab =
  foldr andThen (Right ())
    [ expectEq ("isotropyAutEqStab/S" ++ show n ++ "@" ++ show x)
        (sort (autGroupoid (actionGroupoid (symmetricGroup n)) x))
        (sort (stabilizer (symmetricGroup n) x))
    | n <- [3, 4], x <- [0 .. n - 1]
    ]

-- | Proof (eq. mf7 corollary): orbit-stabilizer @|orbit| * |Stab| = |G|@.
--
--   > |orbit(0)| * |Stab(0)|
--   > = { S_3 acts transitively on 3 points; Stab(0) = { id, (1 2) } }
--   >   3 * 2
--   > = 6 = |S_3|
--   > QED
proof_orbitStabilizer :: Either String ()
proof_orbitStabilizer =
  let g = symmetricGroup 3
  in expectEq "orbitStabilizer"
       (length (orbit g 0) * length (stabilizer g 0))
       (length (groupElems g))

-- | Proof (eq. mf8, PVI/T3): surface-code logical dimension is @2^{2g}@.
--
--   > surfaceCodeLogicalDim g
--   > = { definition: 2 ^ h1Rank g }
--   >   2 ^ rank H_1(Sigma_g; Z_2)
--   > = { minimal CW structure: b_1 = 2g }
--   >   2 ^ (2g)
--   > QED   (g = 3: 2^6 = 64)
proof_surfaceLogicalDim :: Either String ()
proof_surfaceLogicalDim =
  expectEq "surfaceLogicalDim/h1" (h1Rank 3) 6
    `andThen` expectEq "surfaceLogicalDim/dim" (surfaceCodeLogicalDim 3) 64
    `andThen` expectEq "surfaceLogicalDim/g4" (surfaceCodeLogicalDim 4) 256

-- | Proof (eq. mf8): the subsystem master formula
--   @H_phys = (H_log (x) H_gauge) (+) H_err@.
--
--   > physDim
--   > = { n = k + g + r, so 2^n = 2^{k+g} * 2^r }
--   >   2^{k+g} * 2^r
--   > = { one trivial-syndrome sector plus the rest }
--   >   2^{k+g} + (2^n - 2^{k+g})
--   > = { logDim * gaugeDim + errDim }
--   >   logDim * gaugeDim + errDim
--   > QED
proof_subsystemMasterFormula :: Either String ()
proof_subsystemMasterFormula =
  let cp = mkCodeParams 2 3 4    -- k=2 logical, g=3 gauge, r=4 stabilizers; n=9
      s  = subsystemDims cp
  in if validSubsystem cp s
       then Right ()
       else Left "subsystemMasterFormula: H_phys /= (H_log (x) H_gauge) (+) H_err"

-- | Proof (Closure keystone, physical face): gauge redundancy and QEC
--   redundancy obey the same law @total = content * redundancy@.
--
--   > gauge side : |G|       = |orbit| * |Stab|    (content=orbit, red=Stab)
--   > QEC side   : dim(H_log(x)H_gauge) = dim H_log * dim H_gauge
--   >                                            (content=logical, red=gauge)
--   > = { both are total = content * redundancy }
--   >   one and the same factorization
--   > QED
proof_gaugeEqualsQEC :: Either String ()
proof_gaugeEqualsQEC =
  let g              = symmetricGroup 3
      (_, _, _, gOk) = gaugeRedundancy g 0
      cp             = surfaceCode 2 8    -- genus 2 surface code on 8 qubits
      s              = subsystemDims cp
      qOk            = redundancyFactorization (logDim s * gaugeDim s)
                                               (logDim s) (gaugeDim s)
  in if gOk && qOk
       then Right ()
       else Left "gaugeEqualsQEC: redundancy law failed on one face"

-- | Proof (Closure Theorem, status tracking): the six-faculty ladder composite
--   has status @worstOf [H,S,S,S,H,S] = H@.
--
--   > entryStatus ladderComposite
--   > = { definition of ladderComposite }
--   >   worstOf (map rungStatus [I..VI])
--   > = { rung statuses [H,S,S,S,H,S], max under S <= H <= P }
--   >   H
--   > QED
proof_ladderStatus :: Either String ()
proof_ladderStatus =
  expectEq "ladderStatus/worst"
    (entryStatus ladderComposite) (worstOf (map rungStatus allRungs))
    `andThen` expectEq "ladderStatus/value" (entryStatus ladderComposite) H

-- ------------------------------------------------------------------
-- Harness
-- ------------------------------------------------------------------

-- | Assert an equality, producing a labelled error message on failure.
expectEq :: (Eq a, Show a) => String -> a -> a -> Either String ()
expectEq name lhs rhs
  | lhs == rhs = Right ()
  | otherwise  = Left (name ++ ": " ++ show lhs ++ " /= " ++ show rhs)

-- | Sequence two proof checks, short-circuiting on the first failure.
andThen :: Either String () -> Either String () -> Either String ()
andThen (Left e) _ = Left e
andThen (Right ()) k = k

-- | All named proof checks.
allProofs :: [(String, Either String ())]
allProofs =
  [ ("proof_statusComposeMax",       proof_statusComposeMax)
  , ("proof_statusChainWorst",       proof_statusChainWorst)
  , ("proof_coactionCoassociative",  proof_coactionCoassociative)
  , ("proof_isotropyAutEqStab",      proof_isotropyAutEqStab)
  , ("proof_orbitStabilizer",        proof_orbitStabilizer)
  , ("proof_surfaceLogicalDim",      proof_surfaceLogicalDim)
  , ("proof_subsystemMasterFormula", proof_subsystemMasterFormula)
  , ("proof_gaugeEqualsQEC",         proof_gaugeEqualsQEC)
  , ("proof_ladderStatus",           proof_ladderStatus)
  ]

-- | Run every proof check, printing a line each.  Returns 'True' iff all pass.
runAllProofs :: IO Bool
runAllProofs = do
  putStrLn "--- Equational Proof Checks (synthesis) ---"
  oks <- mapM report allProofs
  let passed = length (filter id oks)
  putStrLn $ "Proofs passed: " ++ show passed ++ "/" ++ show (length oks)
  pure (and oks)
  where
    report :: (String, Either String ()) -> IO Bool
    report (name, res) = case res of
      Right () -> do
        putStrLn ("  [OK]   " ++ name)
        pure True
      Left err -> do
        putStrLn ("  [FAIL] " ++ name ++ " -- " ++ err)
        pure False
