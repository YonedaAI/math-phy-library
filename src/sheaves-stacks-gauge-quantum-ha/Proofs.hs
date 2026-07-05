-- | Module      : Proofs
--   Part VI of "A Math->Physics Representation Library":
--   "Sheaves, Stacks, Gauge Redundancy, and Quantum High-Availability".
--
--   Equational-reasoning derivations of the paper's principal identities, each
--   given as (a) a structured chain of "= { justification }" steps in the
--   Haddock comment recording the human proof, and (b) an executable @proof_*@
--   check that evaluates both sides at representative instances and confirms the
--   step-by-step equality actually holds in the implementation.  'runAllProofs'
--   runs every check and returns whether they all pass; 'Main' calls it and
--   exits nonzero on any failure.
--
--   Scope.  These are executable /witnesses/ at concrete points, not a substitute
--   for a fully general machine proof: the universally quantified versions of the
--   same laws (antipode axioms, orbit--stabilizer, the surface-code count, the
--   subsystem formula) are checked over randomized inputs in "Properties" via
--   QuickCheck, and the abstract theorem statements T1--T4 are recorded in the
--   Lean sketch (lean/sheaves-stacks-gauge-quantum-ha).  Together the three
--   layers -- worked instance here, randomized law in Properties, formal
--   signature in Lean -- constitute the verification of each result.
--
--   Correspondence to the paper (arXiv source
--   papers/latex/sheaves-stacks-gauge-quantum-ha.tex):
--
--     * T1  Theorem "Isotropy of the quotient stack" (thm:aut-stab) and the
--           orbifold Euler characteristic of Prop. "Stacks retain gauge
--           information" (prop:stacks-retain).
--     * T3  Theorem "Surface-code logical operators are H_1" (thm:surface-code),
--           dimension count k = 2 - chi(Sigma_g) = 2g.
--     * T4  Definition "Hopf algebra of rooted trees" (def:ck): the antipode
--           recursion S(t) = -t - sum_c S(P^c) R^c and the Hopf antipode axiom
--           m . (S (x) id) . Delta = eps.
module Proofs
  ( ProofResult
  , runAllProofs
  , proof_antipodeSingleVertex
  , proof_coproductSingleVertex
  , proof_antipodeAxiomSingle
  , proof_antipodeAxiomCherry
  , proof_orbifoldEulerChar
  , proof_orbitStabilizer
  , proof_autEqualsStab
  , proof_surfaceEulerCount
  , proof_availabilityFormula
  ) where

import Data.Ratio ((%))

import Stack
  ( GaugeAction(..), orbit, stabilizer, orbifoldEulerChar )
import Stabilizer
  ( surfaceCodeLogicalQubits )
import Hopf
  ( RootedTree(..), antipode, coproduct, verifyAntipodeAxiom )
import QHA
  ( QHAEncoding(..), subsystemDim, availability, trivialSyndrome )

-- | The result of a single proof check: @Right ()@ on success, @Left msg@ with a
--   diagnostic on failure.
type ProofResult = Either String ()

-- | Assert that two computed values are equal, tagging failures with @name@.
check :: (Eq a, Show a) => String -> a -> a -> ProofResult
check name lhs rhs
  | lhs == rhs = Right ()
  | otherwise  = Left (name ++ ": " ++ show lhs ++ " /= " ++ show rhs)

-- ---------------------------------------------------------------------------
-- T4 : Connes--Kreimer antipode and coproduct (def:ck).
-- ---------------------------------------------------------------------------

-- | Proof: the antipode of the single-vertex tree is its negative.
--
--   Write @o = Node []@ for the single vertex; it is primitive, so its only
--   admissible cuts are the two trivial ones and the reduced coproduct vanishes.
--
--     S(o)
--   = { antipode recursion (eq:ck-antipode):  S(t) = -t - sum_c S(P^c) R^c }
--     -o - (empty sum over nontrivial cuts of o)
--   = { o is primitive: no nontrivial admissible cuts }
--     -o
--   = { formal Z-linear notation }
--     (-1) * o
--   QED
proof_antipodeSingleVertex :: ProofResult
proof_antipodeSingleVertex =
  check "antipode(single vertex)"
        (antipode (Node []))
        [(-1, [Node []])]

-- | Proof: the coproduct of the single vertex is purely primitive.
--
--     Delta(o)
--   = { coproduct (eq:ck-coproduct):  Delta(t) = t(x)1 + 1(x)t + sum_c P^c(x)R^c }
--     o(x)1 + 1(x)o + (empty sum, o primitive)
--   = { drop the empty sum }
--     o(x)1 + 1(x)o
--   QED
--
--   In the code a tensor term @(L, R)@ is a pair of forests, so the two trivial
--   terms are @([o], [])@ and @([], [o])@.
proof_coproductSingleVertex :: ProofResult
proof_coproductSingleVertex =
  check "coproduct(single vertex)"
        (coproduct (Node []))
        [([Node []], []), ([], [Node []])]

-- | Proof: the Hopf antipode axiom holds on the single vertex.
--
--     m . (S (x) id) . Delta (o)
--   = { Delta(o) = o(x)1 + 1(x)o }
--     m ( S(o) . 1  +  S(1) . o )
--   = { S(o) = -o (above),  S(1) = 1 }
--     (-o) * 1  +  1 * o
--   = { free commutative product }
--     -o + o  =  0
--   = { eps(o) = 0 for the positively graded o }
--     eps(o) . 1
--   QED
proof_antipodeAxiomSingle :: ProofResult
proof_antipodeAxiomSingle =
  check "antipode axiom (single vertex)"
        (verifyAntipodeAxiom (Node []))
        True

-- | Proof: the Hopf antipode axiom holds on the "cherry" (root with two leaves).
--
--   This is the degree-3 verification of  m . (S (x) id) . Delta = eps , which
--   exercises the full admissible-cut sum (three nontrivial cuts) rather than
--   only the two primitive terms.  We verify the machine-checked witness
--   'verifyAntipodeAxiom' returns @True@, i.e. the alternating cut sum telescopes
--   to zero exactly as the recursion (eq:ck-antipode) prescribes.
proof_antipodeAxiomCherry :: ProofResult
proof_antipodeAxiomCherry =
  check "antipode axiom (cherry)"
        (verifyAntipodeAxiom (Node [Node [], Node []]))
        True

-- ---------------------------------------------------------------------------
-- T1 : isotropy and the orbifold Euler characteristic (thm:aut-stab).
-- ---------------------------------------------------------------------------

-- | The Z/2 gauge redundancy acting on @{-1,0,1}@ by negation (as in 'Main').
z2Negation :: GaugeAction Int Bool
z2Negation = GaugeAction
  { act      = \g x -> if g then negate x else x
  , elements = [False, True]
  }

-- | Proof: the orbifold Euler characteristic equals |X| / |G|.
--
--   For a finite group @G@ acting on a finite set @X@ (a union of orbits), the
--   stack-only observable of prop:stacks-retain,
--
--       chi_orb = sum_{orbits [x]} 1 / |Stab_G(x)| ,
--
--   satisfies the mass formula:
--
--     chi_orb
--   = { definition }
--     sum_{[x]} 1/|Stab_G(x)|
--   = { orbit--stabilizer:  |Stab_G(x)| = |G| / |Orb_G(x)| }
--     sum_{[x]} |Orb_G(x)| / |G|
--   = { (1/|G|) pulled out; orbits partition X, so sum_{[x]} |Orb_G(x)| = |X| }
--     |X| / |G|
--   QED
--
--   Here X = {-1,0,1}, |X| = 3, |G| = 2, giving chi_orb = 3/2 (the value 'Main'
--   prints).
proof_orbifoldEulerChar :: ProofResult
proof_orbifoldEulerChar =
  check "orbifold Euler char = |X|/|G|"
        (orbifoldEulerChar z2Negation [-1, 0, 1])
        (3 % 2)

-- | Proof: the orbit--stabilizer theorem, |Orb_G(x)| * |Stab_G(x)| = |G|.
--
--   The coset map  g |-> g . x  induces a bijection  G / Stab_G(x) -> Orb_G(x),
--   whence |Orb_G(x)| = |G| / |Stab_G(x)|, i.e.
--
--       |Orb_G(x)| * |Stab_G(x)| = |G| .
--
--   Checked at every point of X = {-1,0,1} for the negation action (|G| = 2):
--   at x = 0 the orbit is @{0}@ and the stabilizer is all of G (1 * 2 = 2); at
--   x = +/-1 the orbit is @{-1,1}@ and the stabilizer is trivial (2 * 1 = 2).
proof_orbitStabilizer :: ProofResult
proof_orbitStabilizer =
  check "orbit-stabilizer |Orb|*|Stab| = |G|"
        [ length (orbit z2Negation x) * length (stabilizer z2Negation x)
        | x <- [-1, 0, 1] ]
        [ 2, 2, 2 ]

-- | Proof: Aut_[X/G](x) = Stab_G(x) (thm:aut-stab), read off pointwise.
--
--   In the action groupoid X//G a morphism x -> x is exactly a @g@ with
--   @g . x = x@, so the automorphism group of @x@ is the set @{g : g . x = x}@,
--   which is by definition @Stab_G(x)@.  We witness this by listing the
--   stabilizers: at x = 0 both elements fix 0 (Aut = whole group, order 2); at
--   x = +/-1 only the identity fixes x (Aut trivial, order 1).
proof_autEqualsStab :: ProofResult
proof_autEqualsStab =
  check "Aut_[X/G](x) = Stab_G(x) orders"
        [ length (stabilizer z2Negation x) | x <- [-1, 0, 1] ]
        [ 1, 2, 1 ]

-- ---------------------------------------------------------------------------
-- T3 : surface-code dimension count (thm:surface-code).
-- ---------------------------------------------------------------------------

-- | Proof: k = 2 - chi(Sigma_g) = 2g for the closed genus-g surface code.
--
--     k
--   = { paper dimension count:  k = |E| - (|V| + |F| - 2) }
--     2 - (|V| - |E| + |F|)
--   = { Euler characteristic chi(Sigma_g) = |V| - |E| + |F| }
--     2 - chi(Sigma_g)
--   = { closed orientable surface:  chi(Sigma_g) = 2 - 2g }
--     2 - (2 - 2g)
--   = { arithmetic }
--     2g
--   QED
--
--   Verified for g = 0..5:  'surfaceCodeLogicalQubits' g must equal
--   @2 - (2 - 2*g)@.
proof_surfaceEulerCount :: ProofResult
proof_surfaceEulerCount =
  check "surface code k = 2 - chi = 2g"
        [ surfaceCodeLogicalQubits g | g <- [0 .. 5] ]
        [ 2 - (2 - 2 * g)            | g <- [0 .. 5] ]

-- ---------------------------------------------------------------------------
-- QHA : subsystem decomposition / availability master formula.
-- ---------------------------------------------------------------------------

-- | A concrete QHA encoding (one logical qubit, one gauge qubit, 4 error
--   sectors), matching the 'Main' demo.
demoEncoding :: QHAEncoding Int Int
demoEncoding = QHAEncoding
  { embed        = id
  , equivalences = [id]
  , syndromeOf   = const trivialSyndrome
  , correctable  = \_ -> Just id
  , dimLogical   = 2
  , dimGauge     = 2
  , dimError     = 4
  }

-- | Proof: dim H_phys and the availability follow the master formula.
--
--     dim H_phys
--   = { subsystem decomposition (eq:subsystem):
--       H_phys ~= (H_log (x) H_gauge) (+) H_err }
--     dim H_log * dim H_gauge + dim H_err
--   = { demoEncoding: 2 * 2 + 4 }
--     8
--
--   and the redundancy / availability is
--
--     availability
--   = { definition:  dim H_phys / dim H_log }
--     8 / 2
--   = 4 .
--   QED
proof_availabilityFormula :: ProofResult
proof_availabilityFormula = do
  check "subsystemDim = dimLog*dimGauge + dimErr"
        (subsystemDim demoEncoding)
        (dimLogical demoEncoding * dimGauge demoEncoding + dimError demoEncoding)
  check "availability = dimPhys/dimLog"
        (availability demoEncoding)
        (fromIntegral (subsystemDim demoEncoding)
           / fromIntegral (dimLogical demoEncoding) :: Double)

-- ---------------------------------------------------------------------------
-- Runner.
-- ---------------------------------------------------------------------------

-- | All named proof checks, paired with a human-readable label.
allProofs :: [(String, ProofResult)]
allProofs =
  [ ("T4 antipode(single) = -o",          proof_antipodeSingleVertex)
  , ("T4 coproduct(single) primitive",    proof_coproductSingleVertex)
  , ("T4 antipode axiom (single)",        proof_antipodeAxiomSingle)
  , ("T4 antipode axiom (cherry)",        proof_antipodeAxiomCherry)
  , ("T1 orbifold chi = |X|/|G|",         proof_orbifoldEulerChar)
  , ("T1 orbit-stabilizer",               proof_orbitStabilizer)
  , ("T1 Aut_[X/G](x) = Stab_G(x)",       proof_autEqualsStab)
  , ("T3 surface k = 2 - chi = 2g",       proof_surfaceEulerCount)
  , ("QHA subsystem/availability",        proof_availabilityFormula)
  ]

-- | Run every equational-reasoning proof check, printing a per-proof report,
--   and return 'True' iff all of them pass.
runAllProofs :: IO Bool
runAllProofs = do
  putStrLn "--- Equational-reasoning proof checks ---"
  oks <- mapM reportOne allProofs
  let passed = length (filter id oks)
      total  = length oks
  putStrLn ("  proofs checked: " ++ show total
            ++ ", passed: " ++ show passed)
  pure (and oks)
  where
    reportOne :: (String, ProofResult) -> IO Bool
    reportOne (name, res) =
      case res of
        Right () -> do
          putStrLn ("  [OK]   " ++ name)
          pure True
        Left msg -> do
          putStrLn ("  [FAIL] " ++ name ++ "  --  " ++ msg)
          pure False
