-- | Module      : Properties
--   Part VI of "A Math->Physics Representation Library":
--   "Sheaves, Stacks, Gauge Redundancy, and Quantum High-Availability".
--
--   QuickCheck property tests for the paper's principal theorems.  Each property
--   encodes a mathematical claim (not merely an implementation detail); the
--   Haddock note on each gives the corresponding theorem in
--   papers/latex/sheaves-stacks-gauge-quantum-ha.tex.
--
--     T1  Isotropy of the quotient stack (thm:aut-stab): Aut_[X/G](x) = Stab_G(x)
--         is a subgroup, orbit--stabilizer, and the orbifold Euler-char mass
--         formula chi_orb = |X|/|G| (prop:stacks-retain).
--     T3  Surface code (thm:surface-code): logical dimension 2^{2g} with
--         k = rank H_1(Sigma_g; Z_2) = 2g; code-space dimension 2^k; symplectic
--         commutation of Pauli operators.
--     T4  Connes--Kreimer Hopf algebra (def:ck): the antipode axiom
--         m . (S (x) id) . Delta = 0 on positive grading, and grading (loop
--         number) preservation of the coproduct.
--     Gauge <-> QEC redundancy (cor:literal-bridge): the QHA subsystem master
--         formula dim H_phys = dim H_log * dim H_gauge + dim H_err, instantiated
--         at the surface code with logical dimension 2^{2g}.
module Properties
  ( -- * T1 : stacks and isotropy
    prop_orbitStabilizer
  , prop_orbifoldMassFormula
  , prop_stabilizerIsSubgroup
  , prop_freeIffChiEqualsOrbits
    -- * T2 : sheaves and descent
  , prop_compatibleImpliesWellFormed
  , prop_wrongLengthNotCompatible
  , prop_constantSheafSinglePiece
  , prop_constantSeparated
  , prop_gappyNotSheaf
  , prop_inadmissibleValueRejected
    -- * T3 : surface / stabilizer codes
  , prop_surfaceLogicalDim
  , prop_surfaceEulerCount
  , prop_h1EulerCount
  , prop_codeSpaceDim
  , prop_stabilizerHalving
  , prop_codeSpaceDimClamped
  , prop_indepCodeDim
  , prop_pauliCommuteSymmetric
  , prop_pauliSelfCommute
    -- * T4 : Connes--Kreimer Hopf algebra
  , prop_antipodeAxiom
  , prop_rightAntipodeAxiom
  , prop_coassociativity
  , prop_counitLeft
  , prop_counitRight
  , prop_coproductGradingPreserved
  , prop_singleVertexPrimitive
  , prop_nodesPositive
    -- * Gauge <-> QEC redundancy
  , prop_subsystemMasterFormula
  , prop_availabilityDefinition
  , prop_surfaceQHARedundancy
    -- * Edge / invalid-input robustness
  , prop_emptyGroupChiZero
  , prop_availabilityZeroLogical
  , prop_subsystemNonNegative
  , prop_subsystemNoOverflow
    -- * Runner
  , runAllProperties
  , main
  ) where

import Data.Ratio ((%))
import System.Exit (exitFailure)
-- We hide only 'elements' (it clashes with the 'GaugeAction' record field);
-- everything else -- including 'isSuccess' -- is imported from Test.QuickCheck.
import Test.QuickCheck hiding (elements)

import Stack
  ( GaugeAction(..), orbit, stabilizer, isFreeAction, orbifoldEulerChar )
import Stabilizer
  ( Pauli(..), commute
  , StabilizerCode(..), numLogicalQubits, codeSpaceDim
  , surfaceCodeCommuting, surfaceCodeLogicalQubits, h1Rank )
import Hopf
  ( RootedTree(..), Forest, nodes, coproduct, counitPrimitive
  , verifyAntipodeAxiom, verifyRightAntipodeAxiom, verifyCoassociativity )
import QHA
  ( QHAEncoding(..), subsystemDim, availability, trivialSyndrome )
import Sheaf
  ( Cover(..), Presheaf(..), constantPresheaf
  , wellFormedFamily, compatible, isSeparated, glues, isSheafFor )

-- ===========================================================================
-- Generators
-- ===========================================================================

-- | A concrete finite group action of Int-valued group elements on the finite
--   set @{0..n-1}@, packaged so properties can also reference the group's
--   multiplication and identity for the subgroup test.  Two genuine families
--   are generated:
--
--     * cyclic rotation C_n on Z_n by  g . x = (x + g) mod n  (free), and
--     * the C_2 reflection on {0..m-1} by  1 . x = m-1-x  (has a fixed point
--       exactly when m is odd),
--
--   both of which are honest finite group actions by construction.
data ActionModel = ActionModel
  { amTag    :: String                  -- ^ shown for counterexamples
  , amAction :: GaugeAction Int Int
  , amPoints :: [Int]
  , amMul    :: Int -> Int -> Int       -- ^ group multiplication
  , amId     :: Int                     -- ^ group identity
  }

instance Show ActionModel where
  show = amTag

-- | Cyclic rotation action C_n on Z_n.
rotationModel :: Int -> ActionModel
rotationModel n = ActionModel
  { amTag    = "C_" ++ show n ++ " rotation on Z_" ++ show n
  , amAction = GaugeAction { act = \g x -> (x + g) `mod` n
                           , elements = [0 .. n - 1] }
  , amPoints = [0 .. n - 1]
  , amMul    = \g h -> (g + h) `mod` n
  , amId     = 0
  }

-- | C_2 reflection action on {0..m-1}.
reflectionModel :: Int -> ActionModel
reflectionModel m = ActionModel
  { amTag    = "C_2 reflection on {0.." ++ show (m - 1) ++ "}"
  , amAction = GaugeAction { act = \g x -> if g == 1 then m - 1 - x else x
                           , elements = [0, 1] }
  , amPoints = [0 .. m - 1]
  , amMul    = \g h -> (g + h) `mod` 2
  , amId     = 0
  }

instance Arbitrary ActionModel where
  arbitrary = do
    n <- choose (1, 8)
    oneof [ pure (rotationModel n), pure (reflectionModel n) ]

-- | Bits (0/1) of a given length.
genBits :: Int -> Gen [Int]
genBits n = vectorOf n (choose (0, 1))

-- | A pair of Pauli operators on the same number of qubits (so the symplectic
--   product is well defined).
newtype PauliPair = PauliPair (Pauli, Pauli) deriving (Eq, Show)

instance Arbitrary PauliPair where
  arbitrary = do
    n  <- choose (1, 6)
    p  <- Pauli <$> genBits n <*> genBits n
    q  <- Pauli <$> genBits n <*> genBits n
    pure (PauliPair (p, q))

-- | A stabilizer code: @n@ physical qubits with @r <= n@ generators.
newtype CodeGen = CodeGen (Int, [Pauli]) deriving (Eq, Show)

instance Arbitrary CodeGen where
  arbitrary = do
    n    <- choose (1, 6)
    r    <- choose (0, n)
    gens <- vectorOf r (Pauli <$> genBits n <*> genBits n)
    pure (CodeGen (n, gens))

-- | Size-bounded rooted trees for the Hopf-algebra properties.
newtype ArbTree = ArbTree RootedTree deriving (Eq, Show)

genTree :: Int -> Gen RootedTree
genTree budget
  | budget <= 0 = pure (Node [])
  | otherwise   = do
      k  <- choose (0, 3)
      cs <- vectorOf k (genTree (budget `div` (k + 1)))
      pure (Node cs)

instance Arbitrary ArbTree where
  arbitrary = ArbTree <$> sized (\s -> genTree (min s 6))

-- | Uniformly pick an element of a nonempty list (local replacement for the
--   hidden 'Test.QuickCheck.elements').
pick :: [a] -> Gen a
pick xs = (xs !!) <$> choose (0, length xs - 1)

-- | A candidate family of local sections of arbitrary length (0..4) drawn from
--   a two-element value set, used to probe the descent well-formedness guard.
newtype SectionFamily = SectionFamily [String] deriving (Eq, Show)

instance Arbitrary SectionFamily where
  arbitrary = do
    k <- choose (0, 4)
    SectionFamily <$> vectorOf k (pick ["a", "b"])

-- | A possibly over-specified stabilizer code: @r@ may exceed @n@, exercising
--   the @max 0@ clamp in 'numLogicalQubits'.
newtype OverCode = OverCode (Int, [Pauli]) deriving (Eq, Show)

instance Arbitrary OverCode where
  arbitrary = do
    n    <- choose (1, 5)
    r    <- choose (0, n + 3)
    gens <- vectorOf r (Pauli <$> genBits n <*> genBits n)
    pure (OverCode (n, gens))

-- | Parameters @(n, r)@ with @0 <= r <= n@ for a code whose generators are the
--   single-qubit operators @Z_0, ..., Z_{r-1}@ (see 'indepCode').  These
--   generators are genuinely independent (distinct single-qubit supports) and
--   pairwise commuting, so properties over them respect the stabilizer-code
--   semantic assumptions rather than merely counting generators.
newtype IndepCode = IndepCode (Int, Int) deriving (Eq, Show)

instance Arbitrary IndepCode where
  arbitrary = do
    n <- choose (1, 6)
    r <- choose (0, n)
    pure (IndepCode (n, r))

-- | The stabilizer code on @n@ qubits generated by @Z_0, ..., Z_{r-1}@.
indepCode :: Int -> Int -> StabilizerCode
indepCode n r = StabilizerCode
  { numQubits  = n
  , generators = [ zGen i | i <- [0 .. r - 1] ]
  }
  where
    zGen i = Pauli (replicate n 0) [ if j == i then 1 else 0 | j <- [0 .. n - 1] ]

-- ===========================================================================
-- T1 : stacks retain isotropy (thm:aut-stab, prop:stacks-retain)
-- ===========================================================================

-- | Orbit--stabilizer theorem: |Orb_G(x)| * |Stab_G(x)| = |G| for every point.
--   This certifies that 'stabilizer' (= Aut_[X/G](x) by thm:aut-stab) is the
--   correct isotropy group.
prop_orbitStabilizer :: ActionModel -> Property
prop_orbitStabilizer m =
  let ga  = amAction m
      grp = length (elements ga)
  in conjoin
       [ counterexample ("x = " ++ show x)
           (length (orbit ga x) * length (stabilizer ga x) === grp)
       | x <- amPoints m ]

-- | Mass formula for the orbifold Euler characteristic (the stack-only
--   observable of prop:stacks-retain): for a finite group acting on a finite
--   G-closed set, chi_orb = sum_{[x]} 1/|Stab_G(x)| = |X| / |G|.
prop_orbifoldMassFormula :: ActionModel -> Property
prop_orbifoldMassFormula m =
  let ga = amAction m
      x  = length (amPoints m)
      g  = length (elements ga)
  in orbifoldEulerChar ga (amPoints m)
       === (fromIntegral x % fromIntegral g)

-- | Aut_[X/G](x) = Stab_G(x) is a subgroup of G: it contains the identity and
--   is closed under the group multiplication.  This is the group-structure half
--   of thm:aut-stab (composition of automorphisms is group multiplication).
prop_stabilizerIsSubgroup :: ActionModel -> Property
prop_stabilizerIsSubgroup m =
  let ga  = amAction m
      mul = amMul m
      e   = amId m
  in conjoin
       [ counterexample ("x = " ++ show x) $
           let stab = stabilizer ga x
           in conjoin
                ( counterexample "identity in Stab" (e `elem` stab) :
                  [ counterexample (show g ++ "*" ++ show h)
                      (mul g h `elem` stab)
                  | g <- stab, h <- stab ] )
       | x <- amPoints m ]

-- | The action is free iff the orbifold Euler characteristic equals the number
--   of orbits (each 1/|Stab| term equals 1 exactly when the stabilizer is
--   trivial).  This links 'isFreeAction' to the isotropy-weighted observable.
prop_freeIffChiEqualsOrbits :: ActionModel -> Property
prop_freeIffChiEqualsOrbits m =
  let ga        = amAction m
      pts       = amPoints m
      numOrbits = length (orbitReps ga pts)
      chi       = orbifoldEulerChar ga pts
  in isFreeAction ga pts === (chi == fromIntegral numOrbits)

-- | Orbit representatives (one point per orbit), computed via the exported
--   'orbit' function only.
orbitReps :: GaugeAction Int Int -> [Int] -> [Int]
orbitReps _  []       = []
orbitReps ga (y : ys) =
  y : orbitReps ga [ z | z <- ys, z `notElem` orbit ga y ]

-- ===========================================================================
-- T2 : sheaves and descent (Section 3, sheaf condition / equalizer)
-- ===========================================================================

-- | The disjoint two-piece cover {1} u {2} of {1,2}.
twoCover :: Cover
twoCover = Cover [[1], [2]]

-- | The constant presheaf with value set {a,b}.
constPf :: Presheaf String
constPf = constantPresheaf ["a", "b"]

-- | Descent well-formedness: any family the descent check calls /compatible/
--   must supply exactly one section per cover piece.  This is the regression
--   witness for the gluing-soundness fix (a wrong-length family must never be
--   silently accepted by a truncating zip).
prop_compatibleImpliesWellFormed :: SectionFamily -> Property
prop_compatibleImpliesWellFormed (SectionFamily fam) =
  counterexample ("family " ++ show fam)
    (not (compatible constPf twoCover fam) || wellFormedFamily twoCover fam)

-- | A section family whose length differs from the number of cover pieces is
--   rejected as incompatible (never glued).  Directly certifies the guard.
--   Stated in discard-free form: not well-formed implies not compatible.
prop_wrongLengthNotCompatible :: SectionFamily -> Property
prop_wrongLengthNotCompatible (SectionFamily fam) =
  counterexample ("family " ++ show fam)
    (wellFormedFamily twoCover fam || not (compatible constPf twoCover fam))

-- | The constant presheaf on a single-piece cover of a connected open satisfies
--   the sheaf condition: every well-formed local family glues to a global
--   section (there are no overlaps to obstruct descent).
prop_constantSheafSinglePiece :: Property
prop_constantSheafSinglePiece =
  conjoin
    [ counterexample ("value " ++ v)
        (isSheafFor constPf (Cover [[1]]) [[v]])
    | v <- ["a", "b"] ]

-- | The constant presheaf is separated for the two-piece cover: two global
--   sections agreeing on every piece are equal (the left leg of the equalizer
--   is injective).
prop_constantSeparated :: Property
prop_constantSeparated =
  isSeparated constPf twoCover === True

-- | An overlapping cover of a connected base @{1,2,3}@ with a genuine overlap
--   @{2}@.
gappyCover :: Cover
gappyCover = Cover [[1, 2], [2, 3]]

-- | A presheaf that is /not/ a sheaf: the local sections @A,B@ exist over each
--   piece, but the only global section @G@ restricts to @A@ everywhere.  Hence
--   the compatible local family @[B,B]@ (which agrees on the overlap) has no
--   global preimage -- descent fails.  This exhibits an actual gluing
--   obstruction, complementing the well-formedness guard.
gappyPf :: Presheaf String
gappyPf = Presheaf
  { sections = \u -> if u == [1, 2, 3] then ["G"] else ["A", "B"]
  , restrict = \small big s ->
      if big == [1, 2, 3]
        then "A"                                      -- global -> A on any piece
        else if small == [2]
               then if s == "A" then "p" else "q"     -- piece -> overlap value
               else s
  }

-- | Descent genuinely fails for 'gappyPf': the family @[B,B]@ is compatible on
--   the overlap yet does not glue, so the presheaf is not a sheaf.  This is the
--   "compatible but non-gluing" case that a sound descent check must reject.
prop_gappyNotSheaf :: Property
prop_gappyNotSheaf =
       compatible gappyPf gappyCover ["B", "B"] === True
  .&&. glues       gappyPf gappyCover [["B", "B"]] === False
  .&&. isSheafFor  gappyPf gappyCover [["B", "B"]] === False

-- | A local family carrying a value outside the presheaf's section set (here
--   @"z"@, which is not one of the constant presheaf's sections @{a,b}@) is not
--   admissible, hence not compatible: out-of-domain junk cannot masquerade as
--   local data and spuriously make a sheaf appear non-gluing.
prop_inadmissibleValueRejected :: Property
prop_inadmissibleValueRejected =
  compatible constPf twoCover ["z", "z"] === False

-- ===========================================================================
-- T3 : surface codes (thm:surface-code) and stabilizer commutation
-- ===========================================================================

-- | Surface-code logical dimension: k = 2g = rank H_1(Sigma_g; Z_2), so the
--   code space is (C^2)^{(x) 2g}, i.e. dimension 2^{2g} (thm:surface-code (1)).
prop_surfaceLogicalDim :: NonNegative Int -> Property
prop_surfaceLogicalDim (NonNegative g) =
      surfaceCodeLogicalQubits g === 2 * g
  .&&. h1Rank g === 2 * g
  .&&. h1Rank g === surfaceCodeLogicalQubits g
  .&&. (2 :: Integer) ^ surfaceCodeLogicalQubits g === (2 :: Integer) ^ (2 * g)

-- | Euler-characteristic count k = 2 - chi(Sigma_g) with chi = 2 - 2g
--   (thm:surface-code proof); the identity underlying the 2g logical qubits.
prop_surfaceEulerCount :: NonNegative Int -> Property
prop_surfaceEulerCount (NonNegative g) =
  surfaceCodeLogicalQubits g === 2 - (2 - 2 * g)

-- | The homology rank rank H_1(Sigma_g; Z_2) also equals 2 - chi(Sigma_g), so
--   the "logical operators = H_1" identification of thm:surface-code is an
--   equality of two independently Euler-derived quantities, not a coincidence.
prop_h1EulerCount :: NonNegative Int -> Property
prop_h1EulerCount (NonNegative g) =
  h1Rank g === 2 - (2 - 2 * g)

-- | Code-space dimension of a stabilizer code is 2^k with k = n - (#generators)
--   (paper Definition (Stabilizer code)).
prop_codeSpaceDim :: CodeGen -> Property
prop_codeSpaceDim (CodeGen (n, gens)) =
  let c = StabilizerCode { numQubits = n, generators = gens }
  in codeSpaceDim c === (2 :: Integer) ^ numLogicalQubits c

-- | Each independent stabilizer generator halves the physical Hilbert space:
--   for a code whose generators are /genuinely/ independent and commuting (the
--   validated single-qubit @Z_0..Z_{r-1}@ code), dim(code) * 2^r = 2^n, i.e. the
--   code space is a 2^r-fold quotient of the 2^n-dimensional physical space.
--   Halving is asserted only alongside the commutation check, so it is tied to a
--   valid stabilizer code rather than to the raw generator count of an arbitrary
--   (possibly noncommuting or dependent) generator list.
prop_stabilizerHalving :: IndepCode -> Property
prop_stabilizerHalving (IndepCode (n, r)) =
  let c = indepCode n r
  in    surfaceCodeCommuting c === True
   .&&. codeSpaceDim c * (2 :: Integer) ^ r === (2 :: Integer) ^ n

-- | Robustness: an over-specified code (more listed generators than qubits)
--   yields the trivial one-dimensional code space rather than crashing with a
--   negative exponent.  Certifies the 'numLogicalQubits' clamp.
prop_codeSpaceDimClamped :: OverCode -> Property
prop_codeSpaceDimClamped (OverCode (n, gens)) =
  let c = StabilizerCode { numQubits = n, generators = gens }
      r = length gens
  in    property (codeSpaceDim c >= 1)
   .&&. (if r > n
           then codeSpaceDim c === 1
           else codeSpaceDim c === (2 :: Integer) ^ (n - r))

-- | For a code with r genuinely independent commuting generators on n qubits,
--   the code space has the expected dimension 2^{n-r} (so the stabilizer
--   dimension count is exercised on a code that really is independent, not
--   merely on the raw generator count).
prop_indepCodeDim :: IndepCode -> Property
prop_indepCodeDim (IndepCode (n, r)) =
  codeSpaceDim (indepCode n r) === (2 :: Integer) ^ (n - r)

-- | Symplectic commutation is symmetric: [P,Q] = 0 iff [Q,P] = 0, since the
--   symplectic F_2 form is (anti)symmetric.  Commutation governs which Paulis
--   can be simultaneous stabilizers (thm:surface-code, star/plaquette overlap).
prop_pauliCommuteSymmetric :: PauliPair -> Property
prop_pauliCommuteSymmetric (PauliPair (p, q)) =
  commute p q === commute q p

-- | Every Pauli commutes with itself (the symplectic self-product vanishes over
--   F_2), so it can be a stabilizer generator.
prop_pauliSelfCommute :: PauliPair -> Property
prop_pauliSelfCommute (PauliPair (p, _)) =
  commute p p === True

-- ===========================================================================
-- T4 : Connes--Kreimer Hopf algebra (def:ck)
-- ===========================================================================

-- | The Hopf antipode axiom: m . (S (x) id) . Delta (t) = eps(t) . 1 = 0 for
--   every positively graded t.  This simultaneously certifies 'antipode' and
--   'coproduct' (Theorem T4 / def:ck).  Run with extra tests, being the central
--   correctness witness.
prop_antipodeAxiom :: ArbTree -> Property
prop_antipodeAxiom (ArbTree t) =
  verifyAntipodeAxiom t === True

-- | The /right/ antipode axiom m . (id (x) S) . Delta = eps must also hold;
--   verifying it independently of the left axiom is a stronger Hopf-algebra
--   witness (both are required, and neither implies the other a priori).
prop_rightAntipodeAxiom :: ArbTree -> Property
prop_rightAntipodeAxiom (ArbTree t) =
  verifyRightAntipodeAxiom t === True

-- | Coassociativity (the bialgebra axiom):
--   (Delta (x) id) . Delta = (id (x) Delta) . Delta.  Without this the object is
--   not even a coalgebra, so this is a core structural law of def:ck.
prop_coassociativity :: ArbTree -> Property
prop_coassociativity (ArbTree t) =
  verifyCoassociativity t === True

-- | Left counit law: (eps (x) id) . Delta = id.  The counit eps kills every
--   tensor term except the one with empty (grade-0) left factor, whose right
--   factor is exactly t, so the surviving terms are precisely @[[t]]@.
prop_counitLeft :: ArbTree -> Property
prop_counitLeft (ArbTree t) =
  [ r | (l, r) <- coproduct t, null l ] === [[t]]

-- | Right counit law: (id (x) eps) . Delta = id, symmetric to 'prop_counitLeft'.
prop_counitRight :: ArbTree -> Property
prop_counitRight (ArbTree t) =
  [ l | (l, r) <- coproduct t, null r ] === [[t]]

-- | The coproduct preserves the loop-number (vertex-count) grading: every
--   tensor term P^c (x) R^c satisfies |P^c| + |R^c| = |t| (H is graded).
prop_coproductGradingPreserved :: ArbTree -> Property
prop_coproductGradingPreserved (ArbTree t) =
  conjoin
    [ counterexample (show (leftF, rightF))
        (forestNodes leftF + forestNodes rightF === nodes t)
    | (leftF, rightF) <- coproduct t ]

-- | Total vertex count of a forest.
forestNodes :: Forest -> Int
forestNodes = sum . map nodes

-- | The single-vertex tree is primitive: its reduced coproduct vanishes
--   (an "irreducible contribution", def:ck).
prop_singleVertexPrimitive :: Property
prop_singleVertexPrimitive =
  counitPrimitive (Node []) === True

-- | Every rooted tree has at least one vertex (the grading is positive on
--   nonempty trees).
prop_nodesPositive :: ArbTree -> Property
prop_nodesPositive (ArbTree t) =
  property (nodes t >= 1)

-- ===========================================================================
-- Gauge <-> QEC redundancy (cor:literal-bridge, eq:subsystem)
-- ===========================================================================

-- | Build a QHA encoding from subsystem dimensions (unbounded 'Integer').
mkEncoding :: Integer -> Integer -> Integer -> QHAEncoding Int Int
mkEncoding dl dg de = QHAEncoding
  { embed        = id
  , equivalences = [id]
  , syndromeOf   = const trivialSyndrome
  , correctable  = \_ -> Just id
  , dimLogical   = dl
  , dimGauge     = dg
  , dimError     = de
  }

-- | The QHA subsystem master formula (eq:subsystem):
--   dim H_phys = dim H_log * dim H_gauge + dim H_err.
prop_subsystemMasterFormula :: Positive Integer -> Positive Integer
                            -> NonNegative Integer -> Property
prop_subsystemMasterFormula (Positive dl) (Positive dg) (NonNegative de) =
  subsystemDim (mkEncoding dl dg de) === dl * dg + de

-- | Availability (redundancy factor) is dim H_phys / dim H_log.
prop_availabilityDefinition :: Positive Integer -> Positive Integer
                            -> NonNegative Integer -> Property
prop_availabilityDefinition (Positive dl) (Positive dg) (NonNegative de) =
  let e = mkEncoding dl dg de
  in availability e
       === (fromIntegral (subsystemDim e) / fromIntegral dl :: Double)

-- | Gauge redundancy <-> quantum high availability, literal surface-code case
--   (cor:literal-bridge): the logical dimension is 2^{2g} = 2^{rank H_1}, the
--   gauge factor is trivial (dim H_gauge = 1, pure stabilizer code), so
--   dim H_phys = 2^{2g} + dim H_err.  This ties T3's homological logical count
--   to the QHA subsystem decomposition.
prop_surfaceQHARedundancy :: NonNegative Int -> NonNegative Integer -> Property
prop_surfaceQHARedundancy (NonNegative g0) (NonNegative de) =
  let g   = g0 `mod` 5                        -- keep 2^{2g} small
      dl  = 2 ^ h1Rank g :: Integer           -- logical dim = 2^{2g}
      enc = mkEncoding dl 1 de                -- pure stabilizer: gauge factor trivial
  in    dl === (2 :: Integer) ^ surfaceCodeLogicalQubits g
   .&&. subsystemDim enc === dl + de

-- ===========================================================================
-- Edge / invalid-input robustness
-- ===========================================================================

-- | The degenerate action with an empty group yields orbifold Euler
--   characteristic 0 (rather than dividing by a zero-size stabilizer).
prop_emptyGroupChiZero :: NonNegative Int -> Property
prop_emptyGroupChiZero (NonNegative n) =
  let ga = GaugeAction { act = \_ x -> x, elements = [] } :: GaugeAction Int Int
  in orbifoldEulerChar ga [0 .. n] === (0 % 1)

-- | A degenerate encoding with a nonpositive logical dimension has availability
--   0 (rather than NaN/infinity).
prop_availabilityZeroLogical :: Positive Integer -> NonNegative Integer -> Property
prop_availabilityZeroLogical (Positive dg) (NonNegative de) =
  availability (mkEncoding 0 dg de) === (0 :: Double)

-- | Even for arbitrary declared subsystem dimensions -- negative /or/ as large
--   as @maxBound@ -- the reconstructed physical dimension and the availability
--   are never negative: dimensions are unbounded 'Integer' (no fixed-width
--   overflow) and each factor is clamped at 0.
prop_subsystemNonNegative :: Integer -> Integer -> Integer -> Property
prop_subsystemNonNegative dl dg de =
  let e = mkEncoding dl dg de
  in property (subsystemDim e >= 0) .&&. property (availability e >= 0)

-- | Explicit overflow probe (the earlier failing case): with a logical
--   dimension as large as @maxBound :: Int@ and gauge factor 2, the physical
--   dimension is exactly @2 * dimLogical@ and stays positive -- no fixed-width
--   wraparound, because dimensions are 'Integer'.
prop_subsystemNoOverflow :: Property
prop_subsystemNoOverflow =
  let big = fromIntegral (maxBound :: Int) :: Integer
      e   = mkEncoding big 2 0
  in subsystemDim e === 2 * big .&&. property (subsystemDim e > 0)

-- ===========================================================================
-- Runner
-- ===========================================================================

-- | Run a named property (default 100 tests) and report success.
runProp :: Testable p => String -> p -> IO Bool
runProp name p = do
  putStr ("  " ++ name ++ ": ")
  r <- quickCheckResult p
  pure (isSuccess r)

-- | Run a named property with a larger test budget (for the central witnesses).
runPropN :: Testable p => Int -> String -> p -> IO Bool
runPropN n name p = do
  putStr ("  " ++ name ++ ": ")
  r <- quickCheckWithResult stdArgs { maxSuccess = n } p
  pure (isSuccess r)

-- | Run every QuickCheck property and return whether all passed.
runAllProperties :: IO Bool
runAllProperties = do
  putStrLn "--- QuickCheck properties (Part VI, T1/T3/T4 + QHA) ---"
  putStrLn " T1 (stacks / isotropy):"
  a1 <- runProp   "orbit-stabilizer  |Orb|*|Stab| = |G|"  prop_orbitStabilizer
  a2 <- runProp   "orbifold mass formula chi = |X|/|G|"   prop_orbifoldMassFormula
  a3 <- runProp   "Aut_[X/G](x)=Stab_G(x) is a subgroup"  prop_stabilizerIsSubgroup
  a4 <- runProp   "free  <=>  chi = #orbits"              prop_freeIffChiEqualsOrbits
  putStrLn " T2 (sheaves / descent):"
  e1 <- runProp   "compatible => well-formed family"      prop_compatibleImpliesWellFormed
  e2 <- runProp   "wrong-length family not compatible"    prop_wrongLengthNotCompatible
  e3 <- runProp   "constant presheaf sheaf (1 piece)"     prop_constantSheafSinglePiece
  e4 <- runProp   "constant presheaf separated"           prop_constantSeparated
  e5 <- runProp   "gappy presheaf: compatible non-gluing" prop_gappyNotSheaf
  e6 <- runProp   "inadmissible section value rejected"   prop_inadmissibleValueRejected
  putStrLn " T3 (surface / stabilizer codes):"
  b1 <- runProp   "surface logical dim 2^{2g}=2^{rankH1}" prop_surfaceLogicalDim
  b2 <- runProp   "k = 2 - chi(Sigma_g) = 2g"             prop_surfaceEulerCount
  b2h<- runProp   "rank H_1 = 2 - chi(Sigma_g)"           prop_h1EulerCount
  b3 <- runProp   "code-space dim = 2^k"                  prop_codeSpaceDim
  b3h<- runProp   "indep code: commute & dim*2^r = 2^n"   prop_stabilizerHalving
  b3c<- runProp   "over-specified code clamps to dim 1"   prop_codeSpaceDimClamped
  b7 <- runProp   "indep Z-code dim = 2^{n-r}"            prop_indepCodeDim
  b4 <- runProp   "Pauli commutation symmetric"           prop_pauliCommuteSymmetric
  b5 <- runProp   "Pauli self-commute"                    prop_pauliSelfCommute
  putStrLn " T4 (Connes--Kreimer Hopf algebra):"
  c1 <- runPropN 1000 "antipode axiom m(S(x)id)Delta = 0" prop_antipodeAxiom
  c1r<- runPropN 1000 "right antipode m(id(x)S)Delta = 0" prop_rightAntipodeAxiom
  c1c<- runProp   "coassociativity (bialgebra axiom)"     prop_coassociativity
  c1l<- runProp   "left counit law (eps(x)id)Delta = id"  prop_counitLeft
  c1t<- runProp   "right counit law (id(x)eps)Delta = id" prop_counitRight
  c2 <- runProp   "coproduct preserves grading"           prop_coproductGradingPreserved
  c3 <- runProp   "single vertex is primitive"            prop_singleVertexPrimitive
  c4 <- runProp   "nodes >= 1"                            prop_nodesPositive
  putStrLn " Gauge <-> QEC redundancy:"
  d1 <- runProp   "subsystem master formula"              prop_subsystemMasterFormula
  d2 <- runProp   "availability = dimPhys/dimLog"         prop_availabilityDefinition
  d3 <- runProp   "surface-code QHA redundancy"           prop_surfaceQHARedundancy
  putStrLn " Edge / invalid-input robustness:"
  f1 <- runProp   "empty group => chi = 0"                prop_emptyGroupChiZero
  f2 <- runProp   "dimLogical=0 => availability = 0"      prop_availabilityZeroLogical
  f3 <- runProp   "subsystemDim/availability nonneg"      prop_subsystemNonNegative
  f4 <- runProp   "no Int overflow at maxBound"           prop_subsystemNoOverflow
  let results = [ a1,a2,a3,a4, e1,e2,e3,e4,e5,e6
                , b1,b2,b2h,b3,b3h,b3c,b7,b4,b5
                , c1,c1r,c1c,c1l,c1t,c2,c3,c4
                , d1,d2,d3, f1,f2,f3,f4 ]
      nPassed = length (filter id results)
      nTotal  = length results
  putStrLn ("  properties: " ++ show nPassed ++ "/" ++ show nTotal ++ " passed")
  pure (and results)

-- | Standalone entry point: run all properties, exit nonzero on any failure.
main :: IO ()
main = do
  ok <- runAllProperties
  if ok then putStrLn "ALL PROPERTIES PASSED"
        else exitFailure
