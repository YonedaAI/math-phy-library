-- |
-- Module      : Properties
-- Description : QuickCheck properties for the theorems of Part IV,
--               "Algebraic Topology: Conserved Global Information".
--
-- Each property corresponds to a named result of the companion paper.  Where a
-- theorem is a universally quantified algebraic identity we test it on randomly
-- generated inputs; where it is a statement about a class of spaces we test it
-- on randomly generated abstract simplicial complexes (built from random
-- "maximal faces" and closed downward, so that they are always valid complexes).
--
--   * @prop_boundarySquared@         Lemma "Singular boundary squares to zero"
--                                    (@partial^2 = 0@), simplicial form.
--   * @prop_dSquaredMatrices@        @partial^2 = 0@ at the incidence-matrix level.
--   * @prop_boundaryIsCycle@         Lemma "Boundaries are cycles" (@B_n <= Z_n@).
--   * @prop_coneContractible@        Thm. "Homotopy invariance of homology":
--                                    a cone is contractible, so @H_* = H_*(pt)@.
--   * @prop_eulerPoincare@           Euler-Poincare: @sum (-1)^n b_n = sum (-1)^n dim C_n@.
--   * @prop_knownBetti@ / @prop_paperBetti@   Betti numbers of standard spaces.
--   * @prop_poincareDuality@         Thm. "Poincare duality": @b_k = b_{n-k}@ on
--                                    closed oriented surfaces.
--   * @prop_frobenius*@              Example "A 2d TQFT is a commutative
--                                    Frobenius algebra" (assoc/comm/unit laws).
--   * @prop_partition*@             Thm. "TQFT ...; monoidality is Decomposition"
--                                    (@Z(genus g) = |G|^g@, multiplicativity).
--   * @prop_amplitude*@             Monoidality axioms for a concrete TQFT.
--   * @prop_dw*@                    Thm. "DW instantiates Locality/descent",
--                                    Example "G = Z/N": @Z_0(T^2)=N@, @Z_0(T^3)=N^2@.
--   * @prop_index*@                 Thm. "Atiyah-Singer as observable =
--                                    Real(abstract structure)" (Riemann-Roch).
module Properties
  ( -- * Generators
    SmallComplex(..)
  , Genus(..)
  , SmallN(..)
    -- * Runner
  , runAllProperties
  ) where

import Data.List (sort)
import Test.QuickCheck

import ChainComplex
import TQFT
import CharacteristicClass

-- ---------------------------------------------------------------------------
-- Generators
-- ---------------------------------------------------------------------------

-- | A random (nonempty) abstract simplicial complex on a small vertex set,
-- presented by its full, downward-closed face list.
newtype SmallComplex = SmallComplex { getComplex :: [Simplex] }
  deriving (Eq, Show)

instance Arbitrary SmallComplex where
  arbitrary = do
    nverts <- choose (1, 5)
    let verts = [0 .. nverts - 1]
    nmax <- choose (1, 4)
    maxs <- vectorOf nmax $ do
      k    <- choose (1, min 4 nverts)
      vs   <- shuffle verts
      pure (sort (take k vs))
    pure (SmallComplex (closure maxs))

-- | A random surface genus @g in [0,4]@.
newtype Genus = Genus Int deriving (Eq, Show)

instance Arbitrary Genus where
  arbitrary = Genus <$> choose (0, 4)

-- | A random small positive integer @n in [1,6]@ (a group order / algebra
-- dimension).
newtype SmallN = SmallN Int deriving (Eq, Show)

instance Arbitrary SmallN where
  arbitrary = SmallN <$> choose (1, 6)

-- | A random small rectangular integer matrix (0..4 rows/cols, entries in
-- @[-3,3]@) for exercising 'rankQ'.
newtype SmallMatrix = SmallMatrix Matrix deriving (Eq, Show)

instance Arbitrary SmallMatrix where
  arbitrary = do
    r    <- choose (0, 4)
    c    <- choose (0, 4)
    rows <- vectorOf r (vectorOf c (choose (-3, 3)))
    pure (SmallMatrix rows)

-- | A random simplicial chain: a formal integer combination of small simplices,
-- with nonzero coefficients (duplicates allowed, so 'normalizeChain' is really
-- exercised).
newtype SmallChain = SmallChain IntChain deriving (Eq, Show)

instance Arbitrary SmallChain where
  arbitrary = do
    t     <- choose (0, 5)
    terms <- vectorOf t $ do
      a  <- choose (-4, 4) `suchThat` (/= 0)
      k  <- choose (1, 4)
      vs <- shuffle [0 .. 5]
      pure (a, sort (take k vs))
    pure (SmallChain terms)

-- | A "tame" amplitude: a small integer value.  Multiplication of such values
-- is exactly associative and commutative in 'Double' (no overflow to Infinity
-- or @NaN@), so the monoidal laws hold on the nose rather than only up to
-- floating-point drift.
newtype TameAmp = TameAmp Amplitude deriving (Eq, Show)

instance Arbitrary TameAmp where
  arbitrary = do
    k <- choose (-8, 8) :: Gen Int
    pure (TameAmp (Amplitude (fromIntegral k)))

-- ---------------------------------------------------------------------------
-- 1. partial^2 = 0  (Lemma "Singular boundary squares to zero", Lemma
--    "Boundaries are cycles")
-- ---------------------------------------------------------------------------

-- | Simplicial @partial^2 = 0@: for every simplex of the complex, applying the
-- alternating-face boundary twice yields the zero chain.  Corresponds to
-- Lemma "Singular boundary squares to zero" specialized to simplices.
prop_boundarySquared :: SmallComplex -> Property
prop_boundarySquared (SmallComplex fs) =
  conjoin
    [ counterexample ("simplex " ++ show s)
        (boundaryChain (boundaryChain (simplexChain s)) === [])
    | s <- fs ]

-- | The incidence-matrix boundary maps of a simplicial complex satisfy
-- @d_{k-1} . d_k = 0@ (the same lemma, at the level of the presentation used to
-- compute homology).
prop_dSquaredMatrices :: SmallComplex -> Property
prop_dSquaredMatrices (SmallComplex fs) =
  property (dSquaredIsZero (fromSimplicialComplex fs))

-- | Lemma "Boundaries are cycles": every boundary is a cycle, i.e. the boundary
-- of any chain is annihilated by the boundary operator.  (This is @partial^2=0@
-- read as @B_n subseteq Z_n@.)
prop_boundaryIsCycle :: SmallComplex -> Property
prop_boundaryIsCycle (SmallComplex fs) =
  conjoin
    [ boundaryChain (boundaryChain (simplexChain s)) === []
    | s <- fs, length s >= 2 ]

-- ---------------------------------------------------------------------------
-- 2. Homotopy invariance (Theorem "Homotopy invariance of homology")
-- ---------------------------------------------------------------------------

-- | The simplicial cone on any complex is contractible, so all reduced homology
-- vanishes: @H_0 = Z@ (one component) and @H_k = 0@ for @k > 0@.  This is a
-- computational instance of Theorem "Homotopy invariance of homology" (a
-- deformation retraction to the apex conserves only @H_0@).
prop_coneContractible :: SmallComplex -> Property
prop_coneContractible (SmallComplex fs) =
  let bs = bettiNumbers (fromSimplicialComplex (cone fs))
  in counterexample ("Betti(cone) = " ++ show bs)
       (bs === 1 : replicate (length bs - 1) 0)

-- ---------------------------------------------------------------------------
-- 3. Euler-Poincare and Betti numbers
-- ---------------------------------------------------------------------------

-- | Euler-Poincare theorem: the Euler characteristic computed as the alternating
-- sum of Betti numbers equals the alternating sum of the dimensions,
-- @sum (-1)^n b_n = sum (-1)^n dim C_n@.  A conserved topological invariant
-- independent of the chosen cycles/boundaries.
prop_eulerPoincare :: SmallComplex -> Property
prop_eulerPoincare (SmallComplex fs) =
  let cc = fromSimplicialComplex fs
  in eulerCharacteristic cc === alternatingSumDims cc

-- | Betti numbers of standard simplicial models match the textbook values
-- (Definition "Homology"): boundary of a triangle is @S^1@ with @b=(1,1)@;
-- boundary of a tetrahedron is @S^2@ with @b=(1,0,1)@; a filled triangle is
-- contractible with @b=(1,0,0)@; and two isolated points have @b=(2)@.
prop_knownBetti :: Property
prop_knownBetti = conjoin
  [ named "S^1 (boundary of triangle)"
      (bettiNumbers (fromSimplicialComplex (closure [[0,1],[1,2],[0,2]])) === [1,1])
  , named "S^2 (boundary of tetrahedron)"
      (bettiNumbers (fromSimplicialComplex
         (closure [[0,1,2],[0,1,3],[0,2,3],[1,2,3]])) === [1,0,1])
  , named "point (filled triangle)"
      (bettiNumbers (fromSimplicialComplex (closure [[0,1,2]])) === [1,0,0])
  , named "two points"
      (bettiNumbers (fromSimplicialComplex [[0],[1]]) === [2])
  ]
  where named s = counterexample s

-- | The paper's Delta-complex examples reproduce their advertised Betti numbers
-- (Section "(Co)homology as conserved global information").
prop_paperBetti :: Property
prop_paperBetti = conjoin
  [ bettiNumbers circle     === [1,1]
  , bettiNumbers torus      === [1,2,1]
  , bettiNumbers sphere2    === [1,0,1]
  , bettiNumbers pointSpace === [1]
  ]

-- ---------------------------------------------------------------------------
-- 4. Poincare duality (Theorem "Poincare duality")
-- ---------------------------------------------------------------------------

-- | Poincare duality on closed oriented @n@-manifolds forces the Betti vector to
-- be palindromic, @b_k = b_{n-k}@.  We check this on our closed oriented
-- surfaces @S^2@ (genus 0) and @T^2@ (genus 1).
prop_poincareDuality :: Property
prop_poincareDuality = conjoin
  [ counterexample "S^2" (isPalindrome (bettiNumbers sphere2))
  , counterexample "T^2" (isPalindrome (bettiNumbers torus))
  ]
  where isPalindrome xs = xs === reverse xs

-- ---------------------------------------------------------------------------
-- 5. 2d TQFT = commutative Frobenius algebra
--    (Example "A 2d TQFT is a commutative Frobenius algebra")
-- ---------------------------------------------------------------------------

-- | The group algebra @k[Z/n]@ is associative, commutative, and unital -- the
-- Frobenius-algebra laws underlying a 2d TQFT's gluing axioms.
prop_frobeniusLaws :: SmallN -> Property
prop_frobeniusLaws (SmallN n) =
  let fa = groupAlgebraZn n
  in conjoin
       [ counterexample "assoc" (property (isAssociative fa))
       , counterexample "comm"  (property (isCommutative fa))
       , counterexample "unit"  (property (unitLaws fa))
       , counterexample "all"   (property (frobeniusLawsHold fa))
       ]

-- | The genus-@g@ partition function of @k[Z/n]@ is @n^g@ (dimension of the
-- state space raised to the genus): the closed-form value of Theorem "TQFT
-- realizes the pipeline" for the group-algebra 2d TQFT.
prop_partitionValue :: SmallN -> Genus -> Property
prop_partitionValue (SmallN n) (Genus g) =
  partitionSurface (groupAlgebraZn n) g === fromIntegral n ^^ g

-- | Gluing / monoidality of the partition function:
-- @Z(genus (g1+g2)) = Z(genus g1) * Z(genus g2)@ up to the shared cap factor.
-- For @k[Z/n]@ this is @n^(g1+g2) = n^{g1} n^{g2}@ (Decomposition axiom).
prop_partitionMultiplicative :: SmallN -> Genus -> Genus -> Property
prop_partitionMultiplicative (SmallN n) (Genus g1) (Genus g2) =
  let fa = groupAlgebraZn n
  in partitionSurface fa (g1 + g2)
       === partitionSurface fa g1 * partitionSurface fa g2

-- ---------------------------------------------------------------------------
-- 6. Monoidality axioms of a concrete TQFT
--    (Theorem "TQFT ...; monoidality is the Decomposition axiom")
-- ---------------------------------------------------------------------------

-- | Disjoint union -> tensor is associative for the amplitude TQFT.
prop_amplitudeAssoc :: TameAmp -> TameAmp -> TameAmp -> Property
prop_amplitudeAssoc (TameAmp a) (TameAmp b) (TameAmp c) =
  fTensor (fTensor a b) c =~= fTensor a (fTensor b c)

-- | The empty manifold is a two-sided unit for disjoint union.
prop_amplitudeUnit :: TameAmp -> Property
prop_amplitudeUnit (TameAmp a) =
  (fTensor fUnit a =~= a) .&&. (fTensor a fUnit =~= a)

-- | Symmetry: disjoint union is commutative (a symmetric monoidal functor).
prop_amplitudeSymmetric :: TameAmp -> TameAmp -> Property
prop_amplitudeSymmetric (TameAmp a) (TameAmp b) =
  fTensor a b =~= fTensor b a

-- | Approximate equality of amplitudes.
(=~=) :: Amplitude -> Amplitude -> Property
Amplitude x =~= Amplitude y =
  counterexample (show x ++ " /~ " ++ show y) (abs (x - y) < 1e-9)
infix 4 =~=

-- ---------------------------------------------------------------------------
-- 7. Dijkgraaf-Witten state sums
--    (Theorem "DW instantiates Locality/descent", Example "G = Z/N")
-- ---------------------------------------------------------------------------

-- | Untwisted DW on the 2-torus for @Z/n@: @Z_0(T^2) = |Hom(Z^2, Z/n)|/n = n@.
prop_dwT2_Zn :: SmallN -> Property
prop_dwT2_Zn (SmallN n) =
  dwUntwistedT2 (zmod n) === fromIntegral n

-- | Untwisted DW on the 3-torus for @Z/n@: @Z_0(T^3) = |Hom(Z^3, Z/n)|/n = n^2@
-- (Example "G = Z/N, untwisted": ground-state degeneracy @N^2@).
prop_dwT3_Zn :: SmallN -> Property
prop_dwT3_Zn (SmallN n) =
  dwUntwistedT3 (zmod n) === fromIntegral (n * n)

-- | The DW partition function is a nonnegative integer for any finite group:
-- @Z_0(T^2)@ counts conjugacy classes (Burnside) and @Z_0(T^3)@ is a
-- (normalized) count of commuting triples; both must be whole numbers.
prop_dwInteger :: SmallN -> Property
prop_dwInteger (SmallN n) =
  let g  = zmod n
      z2 = dwUntwistedT2 g
      z3 = dwUntwistedT3 g
  in counterexample (show (z2, z3))
       (isWhole z2 .&&. isWhole z3)
  where isWhole x = property (abs (x - fromIntegral (round x :: Integer)) < 1e-9)

-- | The nonabelian group @S_3@ has @Z_0(T^2) = 3@ (its number of conjugacy
-- classes) and @Z_0(T^3) = 8@.
prop_dwS3 :: Property
prop_dwS3 = conjoin
  [ counterexample "T^2" (dwUntwistedT2 symmetric3 === 3)
  , counterexample "T^3" (dwUntwistedT3 symmetric3 === 8)
  ]

-- ---------------------------------------------------------------------------
-- 8. Index theorem (Theorem "Atiyah-Singer as observable = Real(...)")
-- ---------------------------------------------------------------------------

-- | Riemann-Roch / Dolbeault index: the analytic index equals the topological
-- expression, @ind(dbar_L) = deg L + 1 - g = deg L + (1 - g)@.  This is the
-- "observable = Real(abstract structure)" identity.
prop_indexRealization :: Genus -> Int -> Property
prop_indexRealization (Genus g) d =
  conjoin
    [ riemannRochIndex (Surface g) d === d + 1 - g
    , property (indexEqualsTopological (Surface g) d)
    ]

-- | Gauss-Bonnet instance of naturality-as-conservation: the tangent Chern
-- number equals the Euler characteristic, @int c_1(T Sigma_g) = 2 - 2g@.
prop_gaussBonnet :: Genus -> Property
prop_gaussBonnet (Genus g) =
  tangentChernNumber (Surface g) === 2 - 2 * g

-- | The first Chern number of a line bundle equals its degree (the represented
-- characteristic class is faithful): @int c_1(L) = deg L@.
prop_chernDegree :: Int -> Property
prop_chernDegree d = chernNumberLineBundle d === d

-- ---------------------------------------------------------------------------
-- 9. Robustness / coverage (soundness of the homology machinery itself)
-- ---------------------------------------------------------------------------

-- | Every simplicial complex yields a /well-formed/ chain complex: rectangular
-- boundary matrices of the shape dictated by the dimensions, with conformable
-- consecutive maps.  Betti numbers and @d^2=0@ are then meaningful.
prop_wellFormed :: SmallComplex -> Property
prop_wellFormed (SmallComplex fs) =
  property (wellFormed (fromSimplicialComplex fs))

-- | Malformed complexes are never certified.  Neither a non-conformable
-- presentation, nor a conformable-but-wrongly-shaped one, nor one with negative
-- dimensions may pass 'dSquaredIsZero' or 'wellFormed'.
prop_rejectsMalformed :: Property
prop_rejectsMalformed =
  conjoin
    [ rejects "non-conformable (d1 1x1, should be 1x2)"
        (ChainComplex [1,2,1] [[[0]], [[1],[1]]])
    , rejects "conformable but wrong shape vs dims"
        (ChainComplex [2,2,2] [[[0]], [[0]]])
    , rejects "negative dimension"
        (ChainComplex [-1] [])
    ]
  where
    rejects name cc =
      counterexample name
        (property (not (dSquaredIsZero cc)) .&&. property (not (wellFormed cc)))

-- | 'rankQ' is exact: the @n x n@ identity has rank @n@ and the @n x n@ zero
-- matrix has rank @0@.
prop_rankIdentityZero :: SmallN -> Property
prop_rankIdentityZero (SmallN n) =
  conjoin
    [ rankQ [ [ if i == j then 1 else 0 | j <- [1..n] ] | i <- [1..n] ] === n
    , rankQ (replicate n (replicate n 0)) === 0
    ]

-- | Rank is bounded by the matrix dimensions and is invariant under scaling
-- every entry by a nonzero constant (exact rational arithmetic, no rounding).
prop_rankBoundScale :: SmallMatrix -> Property
prop_rankBoundScale (SmallMatrix m) =
  conjoin
    [ property (rankQ m <= min (numRows m) (numCols m))
    , rankQ m === rankQ (map (map (* 2)) m)
    ]

-- | @partial^2 = 0@ on an /arbitrary/ chain (not just single simplices):
-- linearity of the boundary plus the simplex identity forces every double
-- boundary to normalize to the zero chain.
prop_arbitraryChainBoundary :: SmallChain -> Property
prop_arbitraryChainBoundary (SmallChain c) =
  boundaryChain (boundaryChain c) === []

-- | The chain complex of a simplicial complex depends only on its underlying
-- set of faces: duplicating and reordering the presenting face list leaves the
-- Betti numbers unchanged (the construction normalizes its input).
prop_complexPermInvariant :: SmallComplex -> Property
prop_complexPermInvariant (SmallComplex fs) =
  forAll (shuffle (fs ++ fs)) $ \fs' ->
    bettiNumbers (fromSimplicialComplex fs')
      === bettiNumbers (fromSimplicialComplex fs)

-- | The Frobenius trace form of @k[Z/n]@ is nondegenerate (the defining
-- condition of a Frobenius algebra), verified via the rank of its Gram matrix.
prop_frobeniusNondegenerate :: SmallN -> Property
prop_frobeniusNondegenerate (SmallN n) =
  property (frobeniusFormNondegenerate (groupAlgebraZn n))

-- ---------------------------------------------------------------------------
-- Runner
-- ---------------------------------------------------------------------------

-- | Run every property.  Critical algebraic identities use @maxSuccess = 1000@.
runAllProperties :: IO ()
runAllProperties = do
  putStrLn "--- QuickCheck Properties (Algebraic Topology: Conserved Information) ---"

  putStrLn "\n[1] partial^2 = 0 / boundaries-are-cycles"
  quickCheck prop_boundarySquared
  quickCheck prop_dSquaredMatrices
  quickCheck prop_boundaryIsCycle

  putStrLn "\n[2] Homotopy invariance (cone is contractible)"
  quickCheck prop_coneContractible

  putStrLn "\n[3] Euler-Poincare and Betti numbers"
  quickCheck prop_eulerPoincare
  quickCheck (once prop_knownBetti)
  quickCheck (once prop_paperBetti)

  putStrLn "\n[4] Poincare duality (palindromic Betti)"
  quickCheck (once prop_poincareDuality)

  putStrLn "\n[5] Frobenius algebra / partition function"
  quickCheck prop_frobeniusLaws
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_partitionValue
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_partitionMultiplicative

  putStrLn "\n[6] TQFT monoidality axioms"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_amplitudeAssoc
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_amplitudeUnit
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_amplitudeSymmetric

  putStrLn "\n[7] Dijkgraaf-Witten state sums"
  quickCheck prop_dwT2_Zn
  quickCheck prop_dwT3_Zn
  quickCheck prop_dwInteger
  quickCheck (once prop_dwS3)

  putStrLn "\n[8] Index theorem (observable = Real(abstract structure))"
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_indexRealization
  quickCheck prop_gaussBonnet
  quickCheck prop_chernDegree

  putStrLn "\n[9] Robustness / soundness of the homology machinery"
  quickCheck prop_wellFormed
  quickCheck (once prop_rejectsMalformed)
  quickCheck prop_rankIdentityZero
  quickCheckWith stdArgs { maxSuccess = 1000 } prop_rankBoundScale
  quickCheckWith stdArgs { maxSuccess = 500 } prop_arbitraryChainBoundary
  quickCheck prop_complexPermInvariant
  quickCheck prop_frobeniusNondegenerate

  putStrLn "\nAll QuickCheck properties passed."
