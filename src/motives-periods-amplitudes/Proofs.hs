-- |
-- Module      : Proofs
-- Description : Equational-reasoning proofs of the model-level theorems of
--               Part II ("Motives, Periods, and Amplitudes"), each backed by
--               an executable @proof_*@ check that verifies the identity at
--               concrete values.
--
-- Every proof block is written in the standard equational-reasoning format
--   lhs = { justification } ... = { justification } rhs
-- and cites the definition or paper theorem that licenses each step.  The
-- accompanying @proof_*@ function checks the corresponding equality and
-- returns @Right ()@ on success or @Left msg@ on failure, so that 'Main' can
-- gate its exit status on the proofs.
module Proofs
  ( proofEq
  , proof_weightAdditive
  , proof_reducedWellDefined
  , proof_coassoc
  , proof_primitiveWeight
  , proof_anatomyDepth
  , proof_cobracketAntisym
  , proof_cobracketExterior
  , referenceExterior
  , proof_cobracketExteriorReference
  , proof_cadNaturality
  , proof_periodMultiplicative
  , proof_periodAdditive
  , proof_dilogCobracket
  , proof_dilogDisc
  , runAllProofs
  ) where

import Data.List (nub, sort)
import Coalgebra
import Period
import Amplitude
import Goncharov

-- | Generic equality checker used by every proof: returns @Right ()@ when the
-- two sides coincide and a diagnostic @Left@ otherwise.
proofEq :: (Eq a, Show a) => String -> a -> a -> Either String ()
proofEq name lhs rhs
  | lhs == rhs = Right ()
  | otherwise  = Left (name ++ ": " ++ show lhs ++ " /= " ++ show rhs)

-- | Proof: the deconcatenation coproduct is weight-graded.
--
-- For every split @(a, b) = (take k w, drop k w)@ of a word @w@:
--
--   weight a + weight b
-- = { definition of @weight@ (word length) }
--   length (take k xs) + length (drop k xs)
-- = { @take k xs ++ drop k xs = xs@ and @length (p ++ q) = length p + length q@ }
--   length xs
-- = { definition of @weight@ }
--   weight w
-- QED.
--
-- This is the grading used throughout the paper (weight = transcendentality);
-- it is what makes the reduced coproduct of Eq. (reduced) land in positive
-- weight ⊗ positive weight (Prop. Termination).
proof_weightAdditive :: Word' g -> Either String ()
proof_weightAdditive w =
  case [ () | (a, b) <- coproduct w, weight a + weight b /= weight w ] of
    [] -> Right ()
    bad -> Left ("weight not additive at " ++ show (length bad) ++ " split(s)")

-- | Proof: the reduced coproduct is well defined (Eq. reduced,
-- @Δ'(x) = Δ(x) − x⊗1 − 1⊗x@ on the augmentation ideal).
--
-- For a word @w@ of weight @n ≥ 1@:
--
--   coproduct w
-- = { definition: splits at every @k ∈ [0..n]@ }
--   (1 ⊗ w) : (rest) ++ (w ⊗ 1)                      -- k = 0 and k = n terms
-- = { the two boundary splits are exactly @x⊗1@ and @1⊗x@ }
--   (1 ⊗ w) : (w ⊗ 1) : [ split | 0 < k < n ]
-- = { definition of @reducedCoproduct@: keep both-positive-weight splits }
--   (emptyWord, w) : (w, emptyWord) : reducedCoproduct w      (as a multiset)
-- QED.
--
-- Connectedness (@Zmot_0 = Q·1@) is what forces every non-boundary term to
-- have both tensor factors of positive weight — the point flagged after
-- Eq. (reduced) in the paper.  We restrict to weight ≥ 1 because on the counit
-- (empty word) the two boundary terms coincide.
proof_reducedWellDefined :: (Ord g, Show g) => Word' g -> Either String ()
proof_reducedWellDefined w
  | weight w < 1 = Right ()
  | otherwise =
      proofEq "reduced-well-defined"
        (sort (coproduct w))
        (sort ((emptyWord, w) : (w, emptyWord) : reducedCoproduct w))

-- | Proof: coassociativity of the coaction (Def. coalgebra;
-- @(Δ⊗id)Δ = (id⊗Δ)Δ@).
--
--   (Δ ⊗ id) Δ w
-- = { definition of @coproductLeft@ }
--   { (take j (take k xs), drop j (take k xs), drop k xs) | k, j ≤ k }
-- = { for j ≤ k: @take j (take k xs) = take j xs@, @drop j (take k xs)
--     = take (k−j) (drop j xs)@; reindex the split points as 0 ≤ i ≤ j ≤ n }
--   { (take i xs, take (j−i) (drop i xs), drop j xs) | 0 ≤ i ≤ j ≤ n }
-- = { definition of @coproductRight@ under the same reindexing }
--   (id ⊗ Δ) Δ w
-- QED (as multisets; checked by 'coassocHolds').
proof_coassoc :: (Ord g, Show g) => Word' g -> Either String ()
proof_coassoc w =
  proofEq "coassoc" (sort (coproductLeft w)) (sort (coproductRight w))

-- | Proof: primitivity is exactly weight ≤ 1 (Prop. Termination /
-- Generation theorem (b)).
--
--   isPrimitive w
-- = { definition }
--   null (reducedCoproduct w)
-- = { reducedCoproduct keeps splits with @0 < k < |w|@ }
--   null [ k | k ∈ [0..n], 0 < k < n ]
-- = { the interval @(0, n)@ is empty iff @n ≤ 1@ }
--   (n ≤ 1)
-- = { n = weight w }
--   weight w ≤ 1
-- QED.
proof_primitiveWeight :: Word' g -> Either String ()
proof_primitiveWeight w =
  proofEq "primitive<=>weight<=1" (isPrimitive w) (weight w <= 1)

-- | Proof: the anatomy depth of a weight-@n@ object is @max 0 (n−1)@
-- (Prop. Termination: iterated reduced coaction terminates after @≤ n@ steps).
--
--   anatomyDepth w
-- = { for weight ≤ 1, w is primitive, depth 0 }             (base case)
--   0                                                        (= max 0 (n−1))
--   -- for weight n ≥ 2:
--   anatomyDepth w
-- = { one reduced-coaction step + recurse on the heaviest child }
--   1 + max over children (anatomyDepth child)
-- = { each split of a weight-n word yields children of weights p, q ≥ 1 with
--     p + q = n; the heaviest reachable child has weight n−1 (split 1 | n−1) }
--   1 + (n − 1 − 1)
-- = { arithmetic }
--   n − 1
-- QED (by induction on weight; matches Prop. Termination's bound n−1).
proof_anatomyDepth :: Word' g -> Either String ()
proof_anatomyDepth w =
  proofEq "anatomy-depth" (anatomyDepth w) (max 0 (weight w - 1))

-- | Proof: the cobracket is antisymmetric (Def. Cobracket;
-- @δ = π∘Δ'@ with @π(a⊗b) = ½(a∧b)@).
--
--   cobracket w
-- = { definition: the signed antisymmetrization of Δ' }
--   [ (a, b, +1) | (a,b) ∈ Δ' w ] ++ [ (b, a, −1) | (a,b) ∈ Δ' w ]
-- = { swap the two slots and negate every coefficient }
--   [ (b, a, −1) | (a,b) ∈ Δ' w ] ++ [ (a, b, +1) | (a,b) ∈ Δ' w ]
-- = { list concatenation is commutative up to multiset equality }
--   { (b, a, negate c) | (a, b, c) ∈ cobracket w }
-- QED (as multisets): applying (swap, negate) is an involution fixing the
-- multiset, i.e. δ takes values in the exterior square Λ²L.
proof_cobracketAntisym :: (Ord g, Show g) => Word' g -> Either String ()
proof_cobracketAntisym w =
  proofEq "cobracket-antisymmetry"
    (sort (cobracket w))
    (sort [ (b, a, negate c) | (a, b, c) <- cobracket w ])

-- | Proof: the normalized cobracket is a sound element of @Lambda^2 L@
-- (Def. Cobracket; the exterior-algebra quotient, not merely the formal signed
-- sum).
--
--   cobracketExterior w
-- = { collapse like terms of pi(Delta' w); a /\ b = -(b /\ a), a /\ a = 0 }
--   canonical wedges a /\ b (a < b) with net coefficient #(a,b) - #(b,a)
-- Two soundness consequences are checked directly:
--   (1) no diagonal term @a /\ a@ survives; every wedge has a < b;
--   (2) repeated-letter words cancel, e.g.
--         cobracketExterior (Word' "aa")  = []      (a /\ a = 0)
--         cobracketExterior (Word' "aaa") = []      (a /\ aa - aa /\ a = 0)
--       whereas the formal 'cobracket' would leave four cancelling terms.
-- QED (soundness in the exterior quotient).
proof_cobracketExterior :: (Ord g, Show g) => Word' g -> Either String ()
proof_cobracketExterior w =
  case [ (a, b, c) | (a, b, c) <- cobracketExterior w, a >= b || c == 0 ] of
    [] -> Right ()
    bad -> Left ("non-canonical or zero wedge survived: " ++ show bad)

-- | An /independent/ reference normalization of the reduced coproduct into the
-- exterior square @Lambda^2 L@, computed by a different route than
-- 'cobracketExterior' (accumulating signed @canon@ contributions and summing
-- them, rather than the @occ@-difference construction).  Each reduced split
-- @(a,b)@ contributes @a /\ b@; diagonal splits contribute @0@; orientation is
-- normalized to @a < b@ with the appropriate sign.  Used to cross-check that
-- 'cobracketExterior' really computes the exterior-quotient element (a check
-- that a trivial @const []@ implementation would fail on @"ab"@\/@"ba"@).
referenceExterior :: Ord g => Word' g -> [(Word' g, Word' g, Rational)]
referenceExterior w =
  [ (a, b, c)
  | (a, b) <- nub (map fst contribs)
  , let c = sum [ s | ((p, q), s) <- contribs, (p, q) == (a, b) ]
  , c /= 0
  ]
  where
    contribs = [ canon a b | (a, b) <- reducedCoproduct w, a /= b ]
    canon a b
      | a < b     = ((a, b), 1 :: Rational)
      | otherwise = ((b, a), -1)

-- | Proof: 'cobracketExterior' agrees with the independent 'referenceExterior'
-- normalization (soundness of the @Lambda^2 L@ computation, not merely
-- diagonal-freeness).
--
--   cobracketExterior w
-- = { both sides collapse pi(Delta' w) into canonical wedges a /\ b (a < b)
--     with net coefficient #(a,b) - #(b,a), computed by two different routines }
--   referenceExterior w                                    (as sorted lists)
-- QED.  This distinguishes the real implementation from a trivial one: e.g.
-- @cobracketExterior "ab" = [(a,b,+1)]@ and @cobracketExterior "ba" = [(a,b,-1)]@.
proof_cobracketExteriorReference
  :: (Ord g, Show g) => Word' g -> Either String ()
proof_cobracketExteriorReference w =
  proofEq "cobracketExterior=reference"
    (sort (cobracketExterior w))
    (sort (referenceExterior w))

-- | Proof: the coaction transports through a realization channel
-- (Thm. Conditional Amplitude Decomposition; naturality square Eq. (compat)).
--
-- Let @f@ be the letterwise realization and @Real = realizeWord f@.
--
--   Δ' (Real w)
-- = { Real is monoidal on words: @Real (take k w) = take k (Real w)@ and
--     @Real (drop k w) = drop k (Real w)@, since @map f (take k) = take k (map f)@ }
--   [ (Real a, Real b) | (a, b) ∈ Δ' w ]        -- weights are preserved by Real
-- = { (Real ⊗ Real) applied to each reduced-coproduct term }
--   (Real ⊗ Real) (Δ' w)
-- QED (as multisets): the naturality square commutes on the free model, which
-- is exactly the model-level content of Thm. CAD.
proof_cadNaturality
  :: (Ord b, Show b) => (g -> b) -> Word' g -> Either String ()
proof_cadNaturality f w =
  proofEq "CAD-naturality"
    (sort (reducedCoproduct (realizeWord f w)))
    (sort [ (realizeWord f a, realizeWord f b) | (a, b) <- reducedCoproduct w ])

-- | Proof: multiplicativity of the period pairing (Thm. Multiplicativity (ii);
-- the analytic shadow of Künneth).
--
--   per (Pi_1 ⊗ Pi_2)
-- = { definition of @per@ (@= pdValue@) }
--   pdValue (tensorDatum a b)
-- = { definition of @tensorDatum@: @pdValue = pdValue a * pdValue b@ }
--   pdValue a * pdValue b
-- = { definition of @per@ }
--   per a * per b
-- QED.
proof_periodMultiplicative
  :: PeriodDatum -> PeriodDatum -> Either String ()
proof_periodMultiplicative a b =
  proofEq "period-multiplicative" (per (tensorDatum a b)) (per a * per b)

-- | Proof: additivity of the period pairing (Thm. Multiplicativity (i);
-- disjoint cycles).
--
--   per (Pi_1 ⊔ Pi_2)
-- = { definition of @per@ }
--   pdValue (directSumDatum a b)
-- = { definition of @directSumDatum@: @pdValue = pdValue a + pdValue b@ }
--   pdValue a + pdValue b
-- = { definition of @per@ }
--   per a + per b
-- QED.
proof_periodAdditive :: PeriodDatum -> PeriodDatum -> Either String ()
proof_periodAdditive a b =
  proofEq "period-additive" (per (directSumDatum a b)) (per a + per b)

-- | Proof: the cobracket of the motivic dilogarithm is @log(1−x) ∧ log(x)@
-- (Goncharov Lie coalgebra; Example: Symbol of the dilogarithm,
-- @S(Li_2(x)) = −(1−x) ⊗ x@).
--
--   cobracket (Word' [(1−x), x])
-- = { reducedCoproduct of a weight-2 word has the single split ((1−x), x) }
--   [ ((1−x), x, +1) ] ++ [ (x, (1−x), −1) ]
-- = { this is precisely the wedge @log(1−x) ∧ log(x)@ }
--   { ((1−x), x, +1), (x, (1−x), −1) }
-- QED.
proof_dilogCobracket :: Either String ()
proof_dilogCobracket =
  proofEq "dilog-cobracket"
    (sort dilogCobracket)
    (sort [ (Word' [OneMinusX], Word' [X], 1)
          , (Word' [X], Word' [OneMinusX], -1) ])

-- | Proof: the discontinuity across @x = 0@ of @Li_2(x)@ is @log(1−x)@
-- (Prop. Discontinuity computes the first coaction slot).
--
--   Disc_x Li_2(x)
-- = { pick first-slot factors of Δ' whose second slot is the letter x }
--   discAcross X (Word' [(1−x), x])
-- = { the unique reduced split is ((1−x), x), so the first slot is (1−x) }
--   [ (1−x) ]
-- QED (the @2πi@ prefactor is tracked separately in the paper).
proof_dilogDisc :: Either String ()
proof_dilogDisc =
  proofEq "dilog-discontinuity"
    (discAcross X dilogSymbol)
    [Word' [OneMinusX]]

-- | A concrete alphabet for the structural proofs (words over 'Char').
wordOf :: String -> Word' Char
wordOf = Word'

-- | Run every equational proof at a spread of concrete inputs, printing the
-- result of each and returning 'True' iff all pass.  'Main' gates its exit
-- status on this value.
runAllProofs :: IO Bool
runAllProofs = do
  putStrLn "--- Equational-reasoning proof checks ---"
  let ws :: [Word' Char]
      ws = map wordOf ["", "a", "ab", "abc", "abcd", "aab", "abab", "abcde"]
      up c
        | c >= 'a' && c <= 'z' = toEnum (fromEnum c - 32)
        | otherwise            = c
      p2 = kummerLog 2
      p3 = kummerLog 3
      checks =
        concat
          [ [ ("weight-additive "     ++ show w, proof_weightAdditive w)     | w <- ws ]
          , [ ("reduced-well-defined " ++ show w, proof_reducedWellDefined w) | w <- ws ]
          , [ ("coassoc "             ++ show w, proof_coassoc w)            | w <- ws ]
          , [ ("primitive<=>wt<=1 "   ++ show w, proof_primitiveWeight w)    | w <- ws ]
          , [ ("anatomy-depth "       ++ show w, proof_anatomyDepth w)       | w <- ws ]
          , [ ("cobracket-antisym "   ++ show w, proof_cobracketAntisym w)   | w <- ws ]
          , [ ("cobracket-exterior "  ++ show w, proof_cobracketExterior w)  | w <- ws ]
          , [ ("cobracket-exterior=ref " ++ show w, proof_cobracketExteriorReference w) | w <- ws ]
          , [ ("CAD-naturality "      ++ show w, proof_cadNaturality up w)   | w <- ws ]
          , [ ("cobracket-exterior aa cancels",
                proofEq "cobracketExterior aa" (cobracketExterior (wordOf "aa")) [])
            , ("cobracket-exterior aaa cancels",
                proofEq "cobracketExterior aaa" (cobracketExterior (wordOf "aaa")) [])
            , ("cobracket-exterior ab nonzero",
                proofEq "cobracketExterior ab"
                  (cobracketExterior (wordOf "ab"))
                  [(wordOf "a", wordOf "b", 1)])
            , ("cobracket-exterior ba nonzero (sign flip)",
                proofEq "cobracketExterior ba"
                  (cobracketExterior (wordOf "ba"))
                  [(wordOf "a", wordOf "b", -1)])
            , ("period-multiplicative", proof_periodMultiplicative p2 p3)
            , ("period-additive",       proof_periodAdditive p2 p3)
            , ("dilog-cobracket",       proof_dilogCobracket)
            , ("dilog-discontinuity",   proof_dilogDisc)
            ]
          ]
  oks <- mapM report checks
  let n = length oks
      passed = length (filter id oks)
  putStrLn ("  (" ++ show passed ++ "/" ++ show n ++ " proof checks passed)")
  return (and oks)
  where
    report (name, res) = case res of
      Right () -> do putStrLn ("  [PASS] " ++ name); return True
      Left err -> do putStrLn ("  [FAIL] " ++ name ++ " -- " ++ err); return False
