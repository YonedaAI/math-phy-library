{-# LANGUAGE ScopedTypeVariables #-}

-- | Module      : Stabilizer
--   Part VI of "A Math->Physics Representation Library".
--
--   Stabilizer codes and the surface code (Theorem T3).  Pauli operators on
--   @n@ qubits are represented symplectically over F_2 as a pair of bit
--   vectors (X-part, Z-part).  Two Paulis commute iff their symplectic product
--   vanishes.  The code space is the joint (+1)-eigenspace of the stabilizer
--   group (paper Definition (Stabilizer code)).
--
--   For the surface code on a genus-g surface, the number of encoded logical
--   qubits is
--
--       k = |E| - (|V| + |F| - 2) = 2 - chi(Sigma) = 2g ,
--
--   and the logical operators are the classes of H_1(Sigma; Z_2)
--   (paper Theorem, surface-code logical operators are H_1).
module Stabilizer
  ( Pauli(..)
  , commute
  , StabilizerCode(..)
  , numLogicalQubits
  , codeSpaceDim
  , surfaceCodeLogicalQubits
  , surfaceCodeCommuting
  , h1Rank
  ) where

-- | A Pauli operator on n qubits in symplectic form: (xbits, zbits), each a
--   list of 0/1 of length n.  X_j has xbits with a 1 in position j; Z_j has
--   zbits with a 1 in position j.
data Pauli = Pauli { xbits :: [Int], zbits :: [Int] } deriving (Eq, Show)

-- | Symplectic (mod 2) inner product; two Paulis commute iff it is 0.
--   The two operators need not have equal-length bit vectors: the shorter one is
--   zero-extended (this is exactly the embedding of a Pauli on @n@ qubits into a
--   larger register by tensoring identity), so the product is total and never
--   silently truncates a mismatched length.
symplectic :: Pauli -> Pauli -> Int
symplectic (Pauli x1 z1) (Pauli x2 z2) =
  (dot x1 z2 + dot z1 x2) `mod` 2
  where
    n = maximum [length x1, length z1, length x2, length z2]
    padTo m v = v ++ replicate (m - length v) 0
    dot a b   = sum (zipWith (*) (padTo n a) (padTo n b))

-- | Two Pauli operators commute iff their symplectic product is zero.
commute :: Pauli -> Pauli -> Bool
commute p q = symplectic p q == 0

-- | A stabilizer code: number of physical qubits and a list of independent
--   commuting stabilizer generators.
data StabilizerCode = StabilizerCode
  { numQubits   :: Int
  , generators  :: [Pauli]
  }

-- | k = n - (number of independent generators).  Encodes 2^k logical states.
--   The generators are assumed independent and commuting, so their count equals
--   the number of independent stabilizers and never exceeds @n@.  We clamp at
--   0 so that a degenerate over-specified code (more listed generators than
--   qubits) yields the trivial code space rather than a negative exponent.
numLogicalQubits :: StabilizerCode -> Int
numLogicalQubits c = max 0 (numQubits c - length (generators c))

-- | Dimension of the code space = 2^k.
codeSpaceDim :: StabilizerCode -> Integer
codeSpaceDim c = 2 ^ numLogicalQubits c

-- | Surface code on a closed orientable genus-g surface encodes k = 2g logical
--   qubits (Theorem T3, part 1), independent of the cellulation.
surfaceCodeLogicalQubits :: Int -> Int
surfaceCodeLogicalQubits g = 2 * g

-- | Rank of H_1(Sigma_g; Z_2) = 2g; equals the number of logical qubits,
--   giving the literal identification "logical operators = H_1(Sigma; Z_2)".
h1Rank :: Int -> Int
h1Rank g = 2 * g

-- | Sanity check of the dimension count via Euler characteristic:
--   k = |E| - (|V| + |F| - 2) with chi = |V| - |E| + |F| = 2 - 2g.
--   Given (v, e, f) of a cellulation of a genus-g surface, returns 2g.
surfaceCodeFromCellulation :: (Int, Int, Int) -> Int
surfaceCodeFromCellulation (v, e, f) = e - (v + f - 2)

-- | A minimal consistency check that all star/plaquette generators pairwise
--   commute (they always do: any A_v and B_f share an even number of edges).
--   Modeled here by requiring the provided generators to pairwise commute.
surfaceCodeCommuting :: StabilizerCode -> Bool
surfaceCodeCommuting c =
  and [ commute p q | p <- generators c, q <- generators c ]

-- Keep the cellulation helper referenced (documentation / reproducibility).
_cellulationCheck :: Bool
_cellulationCheck = surfaceCodeFromCellulation (2, 4, 2) == 2  -- torus g = 1
