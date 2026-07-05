-- |
-- Module      : Proofs
-- Description : Equational-reasoning proofs for the theorems of Part IV,
--               "Algebraic Topology: Conserved Global Information".
--
-- Each proof is written in the standard equational format
--
-- >   lhs
-- > = { justification }
-- >   ...
-- > = rhs
--
-- with every step citing a definition or lemma of the companion paper, and is
-- accompanied by an executable @proof_*@ check that verifies the corresponding
-- equality at concrete values.  'allProofs' aggregates the checks; 'Main' runs
-- them and fails the build if any returns 'Left'.
module Proofs
  ( ProofResult
  , proof_boundarySquared
  , proof_boundaryIsCycle
  , proof_eulerPoincare
  , proof_coneContractible
  , proof_dwAbelianT3
  , proof_indexRealization
  , proof_partitionMultiplicative
  , proof_frobeniusAssoc
  , allProofs
  ) where

import ChainComplex
import TQFT
import CharacteristicClass

-- | The result of an executable proof check: @Right ()@ on success, or
-- @Left msg@ with a witness of failure.
type ProofResult = Either String ()

-- | Assert an equality, reporting both sides on failure.
assertEq :: (Eq a, Show a) => String -> a -> a -> ProofResult
assertEq name lhs rhs
  | lhs == rhs = Right ()
  | otherwise  = Left (name ++ ": " ++ show lhs ++ " /= " ++ show rhs)

-- ---------------------------------------------------------------------------
-- Proof 1: partial^2 = 0  (Lemma "Singular boundary squares to zero")
-- ---------------------------------------------------------------------------

-- | Proof (Lemma "Singular boundary squares to zero", eq. (d2)).
--
-- For a simplex @s = [v_0,...,v_k]@ with @partial s = sum_i (-1)^i s_{[i]}@
-- (the @i@-th face omits @v_i@), we compute:
--
--   partial (partial s)
-- = { linearity, definition of partial on each face }
--   sum_i (-1)^i partial (s_{[i]})
-- = { definition of partial }
--   sum_i sum_j (-1)^i (-1)^j (s_{[i]})_{[j]}
-- = { split j<i and j>=i; simplicial identity (s_{[i]})_{[j]}
--     = (s_{[j]})_{[i-1]} for j<i }
--   sum_{j>=i} (-1)^{i+j} (s_{[i]})_{[j]}
--     + sum_{j<i} (-1)^{i+j} (s_{[j]})_{[i-1]}
-- = { reindex the second sum (i,j) -> (j+1, i); signs become opposite }
--   0
-- QED.
--
-- Executable check: @partial^2 = 0@ on every simplex of several complexes
-- (all faces of the tetrahedron and of two glued triangles), not just one.
proof_boundarySquared :: ProofResult
proof_boundarySquared =
  sequence_
    [ assertEq ("d^2 " ++ show s)
        (boundaryChain (boundaryChain (simplexChain s))) []
    | s <- closure [[0,1,2,3]] ++ closure [[0,1,2],[2,3,4]] ]

-- | Proof (Lemma "Boundaries are cycles", @B_n subseteq Z_n@).
--
-- Let @b = partial c in B_n@.  Then
--
--   partial b
-- = { b = partial c }
--   partial (partial c)
-- = { Lemma "Singular boundary squares to zero" }
--   0,
--
-- so @b in ker partial = Z_n@.  Hence @H_n = Z_n / B_n@ is well defined.
--
-- Executable check: @partial (partial c) = 0@ for a boundary @c = partial [0,1,2,3]@.
proof_boundaryIsCycle :: ProofResult
proof_boundaryIsCycle =
  let b = boundaryChain (simplexChain [0,1,2,3])   -- a boundary, b = partial c
  in assertEq "partial b = 0" (boundaryChain b) []

-- ---------------------------------------------------------------------------
-- Proof 2: Euler-Poincare  (chi = sum (-1)^n b_n = sum (-1)^n dim C_n)
-- ---------------------------------------------------------------------------

-- | Proof (Euler-Poincare).  With @b_n = dim C_n - rank d_n - rank d_{n+1}@,
--
--   sum_n (-1)^n b_n
-- = { definition of b_n }
--   sum_n (-1)^n dim C_n - sum_n (-1)^n rank d_n - sum_n (-1)^n rank d_{n+1}
-- = { reindex the last sum m = n+1: sum_n (-1)^n rank d_{n+1}
--     = - sum_m (-1)^m rank d_m (using d_0 = 0) }
--   sum_n (-1)^n dim C_n - sum_n (-1)^n rank d_n + sum_n (-1)^n rank d_n
-- = { the rank sums cancel }
--   sum_n (-1)^n dim C_n
-- QED.
--
-- Executable check on a family of complexes (the paper's Delta-complexes plus
-- several simplicial complexes), and the closed-form values chi(S^2)=2,
-- chi(T^2)=0.
proof_eulerPoincare :: ProofResult
proof_eulerPoincare = do
  sequence_
    [ assertEq ("chi vs alt-dim: " ++ name)
        (eulerCharacteristic cc) (alternatingSumDims cc)
    | (name, cc) <-
        [ ("circle", circle), ("torus", torus), ("sphere2", sphere2)
        , ("point", pointSpace)
        , ("boundary-tetra", fromSimplicialComplex
              (closure [[0,1,2],[0,1,3],[0,2,3],[1,2,3]]))
        , ("filled-tetra", fromSimplicialComplex (closure [[0,1,2,3]]))
        , ("wedge", fromSimplicialComplex (closure [[0,1],[1,2],[0,2],[2,3],[3,4],[2,4]]))
        ] ]
  assertEq "chi(S^2)=2" (eulerCharacteristic sphere2) 2
  assertEq "chi(T^2)=0" (eulerCharacteristic torus)   0

-- ---------------------------------------------------------------------------
-- Proof 3: Homotopy invariance (Theorem "Homotopy invariance of homology")
-- ---------------------------------------------------------------------------

-- | Proof (Theorem "Homotopy invariance of homology", cone corollary).
--
-- The cone @CK@ deformation-retracts onto its apex, so the identity map is
-- homotopic to the constant map at the apex.  By homotopy invariance,
--
--   H_n(CK)
-- = { CK ~ point (contractible) }
--   H_n(point)
-- = { homology of a point }
--   Z    if n = 0,   0 otherwise.
--
-- Hence @Betti(CK) = (1, 0, 0, ...)@.
--
-- Executable check: cone over the boundary of a triangle (a circle) collapses
-- @H_1 = Z@ to @0@.
proof_coneContractible :: ProofResult
proof_coneContractible =
  let circleK = closure [[0,1],[1,2],[0,2]]
      bsCk    = bettiNumbers (fromSimplicialComplex (cone circleK))
  in assertEq "Betti(cone S^1)" bsCk (1 : replicate (length bsCk - 1) 0)

-- ---------------------------------------------------------------------------
-- Proof 4: Dijkgraaf-Witten, abelian 3-torus (Example "G = Z/N, untwisted")
-- ---------------------------------------------------------------------------

-- | Proof (Example "G = Z/N, untwisted": @Z_0(T^3) = N^2@).
--
--   Z_0(T^3)
-- = { untwisted DW state sum, eq. (dw) with omega = 0 }
--   |Hom(pi_1 T^3, Z/N)| / N
-- = { pi_1 T^3 = Z^3, and Hom(Z^3, A) = A^3 for abelian A }
--   |Z/N|^3 / N
-- = { |Z/N| = N }
--   N^3 / N
-- = { arithmetic }
--   N^2
-- QED.
--
-- Executable check: the computed state sum equals @N^2@ for @N = 1..6@.
proof_dwAbelianT3 :: ProofResult
proof_dwAbelianT3 =
  sequence_
    [ assertEq ("Z_0(T^3), Z/" ++ show n)
        (dwUntwistedT3 (zmod n)) (fromIntegral (n * n))
    | n <- [1 .. 6 :: Int] ]

-- ---------------------------------------------------------------------------
-- Proof 5: Index theorem (Theorem "Atiyah-Singer as observable = Real(...)")
-- ---------------------------------------------------------------------------

-- | Proof (Theorem "Atiyah-Singer as observable = Real(abstract structure)",
-- Riemann-Roch surface case).
--
--   ind(dbar_L)                        -- the analytic observable
-- = { Riemann-Roch: h^0(L) - h^1(L) }
--   deg L + 1 - g
-- = { regroup the topological integral: int ch(L) = deg L, int Td(T Sigma) = 1 - g }
--   deg L + (1 - g)                    -- Real(abstract structure)
-- QED: observable = Real(abstract structure).
--
-- Executable check over several @(g, deg L)@.
proof_indexRealization :: ProofResult
proof_indexRealization =
  sequence_
    [ assertEq ("ind Sigma_" ++ show g ++ " degL=" ++ show d)
        (riemannRochIndex (Surface g) d) (d + (1 - g))
    | (g, d) <- [(0,0),(0,3),(1,0),(1,5),(2,4),(3,7)] ]

-- ---------------------------------------------------------------------------
-- Proof 6: TQFT monoidality (Theorem "TQFT ...; monoidality is Decomposition")
-- ---------------------------------------------------------------------------

-- | Proof (Theorem "TQFT realizes the pipeline; monoidality is Decomposition").
--
-- For the 2d TQFT from @k[Z/n]@ (semisimple, @dim = n@), the genus is additive
-- under connected sum of surfaces along a circle, and the functor sends this to
-- multiplication of state-space dimensions:
--
--   Z(genus (g1 + g2))
-- = { partition function of the group-algebra TQFT }
--   n^{g1 + g2}
-- = { exponent law }
--   n^{g1} * n^{g2}
-- = { partition function again }
--   Z(genus g1) * Z(genus g2)
-- QED (this is the Decomposition / monoidality axiom).
--
-- Executable check for several @(n, g1, g2)@.
proof_partitionMultiplicative :: ProofResult
proof_partitionMultiplicative =
  sequence_
    [ assertEq ("Z_" ++ show n ++ " g=" ++ show (g1, g2))
        (partitionSurface fa (g1 + g2))
        (partitionSurface fa g1 * partitionSurface fa g2)
    | n <- [1 .. 4 :: Int], let fa = groupAlgebraZn n
    , g1 <- [0 .. 3], g2 <- [0 .. 3] ]

-- | Proof (Example "A 2d TQFT is a commutative Frobenius algebra").
--
-- The convolution product on @k[Z/n]@ is associative because addition mod @n@
-- is associative:
--
--   (g^i * g^j) * g^k
-- = { convolution: g^i * g^j = g^{(i+j) mod n} }
--   g^{((i+j) + k) mod n}
-- = { associativity of + mod n }
--   g^{(i + (j+k)) mod n}
-- = { convolution }
--   g^i * (g^j * g^k)
-- QED.  Executable check: the associativity law holds on all basis triples.
proof_frobeniusAssoc :: ProofResult
proof_frobeniusAssoc =
  sequence_
    [ if isAssociative fa && isCommutative fa && unitLaws fa
        then Right ()
        else Left ("Frobenius laws fail for k[Z/" ++ show n ++ "]")
    | n <- [1 .. 6 :: Int], let fa = groupAlgebraZn n ]

-- ---------------------------------------------------------------------------
-- Aggregate
-- ---------------------------------------------------------------------------

-- | All proofs, paired with human-readable names, for the driver to run.
allProofs :: [(String, ProofResult)]
allProofs =
  [ ("partial^2 = 0 (Lemma: singular boundary squares to zero)", proof_boundarySquared)
  , ("boundaries are cycles (B_n subseteq Z_n)",                 proof_boundaryIsCycle)
  , ("Euler-Poincare (chi = sum (-1)^n dim C_n)",                proof_eulerPoincare)
  , ("homotopy invariance (cone is contractible)",               proof_coneContractible)
  , ("Dijkgraaf-Witten abelian Z_0(T^3) = N^2",                  proof_dwAbelianT3)
  , ("index theorem (observable = Real(abstract structure))",    proof_indexRealization)
  , ("TQFT monoidality (Z(g1+g2) = Z(g1) Z(g2))",                proof_partitionMultiplicative)
  , ("Frobenius algebra laws (assoc/comm/unit)",                 proof_frobeniusAssoc)
  ]
