-- |
-- Module      : Proofs
-- Description : Equational-reasoning proofs for Part V (Category Theory and
--               HoTT: Composition and Identity), with executable certificates.
--
-- The mathematical content of each result is the human-readable equational
-- derivation in the Haddock comment: it follows the format
-- @lhs = ... = ... = rhs@, and every step cites the definition or law of
-- @papers/latex/category-theory-hott-composition.tex@ that justifies it.
--
-- The accompanying @proof_*@ functions are /executable certificates/: they
-- evaluate both sides of the derived equation at concrete data and return
-- @Right ()@ on agreement or @Left msg@ on mismatch, so 'runAllProofs' can
-- witness each derivation at runtime and drive a nonzero exit on any failure.
-- They are checks against counterexamples, not a substitute for the derivation
-- (which quantifies over all inputs). Fully machine-checked proofs of the
-- headline theorems live in the Lean sketch
-- @lean/category-theory-hott-composition/CategoryHoTT.lean@: T1
-- (@univalence_respects_realization@, by @cases@) and T3
-- (@no_uniform_cloning@, by @decide@).
module Proofs
  ( proof_leftUnit
  , proof_rightUnit
  , proof_assoc
  , proof_functorComp
  , proof_functorId
  , proof_naturality
  , proof_noCloning
  , proof_eckmannHilton
  , proof_groupoidRetainsStabilizer
  , runAllProofs
  ) where

import RepCat (Fn(..), identity, compose, component, safeHead)
import Dagger (tensorDim, biproductDim)
import Quotient
  ( FiniteGroup(..), GroupAction(..), cyclicGroup, groupoidAutomorphisms
  , isActionOf, isGroup, orbitStabilizerHolds, orbitsPartition, stabilizer )

-- | Generic equality check at a concrete point, with a diagnostic message.
checkEq :: (Eq b, Show b) => String -> b -> b -> Either String ()
checkEq name lhs rhs
  | lhs == rhs = Right ()
  | otherwise  =
      Left (name ++ ": " ++ show lhs ++ " /= " ++ show rhs)

-- | Assert a Boolean certificate, failing with the given message otherwise.
ensure :: String -> Bool -> Either String ()
ensure _   True  = Right ()
ensure msg False = Left msg

-- ---------------------------------------------------------------------------
-- Category unit laws (Definition 3.1, Eq. (unit))
-- ---------------------------------------------------------------------------

-- | Proof: left unit law @identity . f = f@ (Eq. (unit)).
--
-- For all @x@:
--
-- >   runFn (compose identity f) x
-- > = { definition of compose in the Fn instance }
-- >   runFn identity (runFn f x)
-- > = { definition of identity :: Fn a a = Fn (\y -> y) }
-- >   runFn f x
-- > QED
--
-- Executable check at a sample of inputs.
proof_leftUnit :: (Eq b, Show b) => Fn a b -> [a] -> Either String ()
proof_leftUnit f xs =
  mapM_ (\x -> checkEq "leftUnit"
                 (runFn (compose identity f) x)
                 (runFn f x))
        xs

-- | Proof: right unit law @f . identity = f@ (Eq. (unit)).
--
-- >   runFn (compose f identity) x
-- > = { definition of compose }
-- >   runFn f (runFn identity x)
-- > = { definition of identity }
-- >   runFn f x
-- > QED
proof_rightUnit :: (Eq b, Show b) => Fn a b -> [a] -> Either String ()
proof_rightUnit f xs =
  mapM_ (\x -> checkEq "rightUnit"
                 (runFn (compose f identity) x)
                 (runFn f x))
        xs

-- ---------------------------------------------------------------------------
-- Category associativity (Eq. (assoc))
-- ---------------------------------------------------------------------------

-- | Proof: associativity @h . (g . f) = (h . g) . f@ (Eq. (assoc)).
--
-- >   runFn (compose h (compose g f)) x
-- > = { definition of compose (outer) }
-- >   runFn h (runFn (compose g f) x)
-- > = { definition of compose (inner) }
-- >   runFn h (runFn g (runFn f x))
-- > = { definition of compose (re-associate; function application is assoc.) }
-- >   runFn (compose h g) (runFn f x)
-- > = { definition of compose (outer, other bracketing) }
-- >   runFn (compose (compose h g) f) x
-- > QED
proof_assoc
  :: (Eq d, Show d) => Fn c d -> Fn b c -> Fn a b -> [a] -> Either String ()
proof_assoc h g f xs =
  mapM_ (\x -> checkEq "assoc"
                 (runFn (compose h (compose g f)) x)
                 (runFn (compose (compose h g) f) x))
        xs

-- ---------------------------------------------------------------------------
-- Functor laws (Definition 3.2, Eq. (functor-laws))
-- ---------------------------------------------------------------------------

-- | Proof: @Maybe@ preserves composition, @fmap (g . f) = fmap g . fmap f@
-- (Eq. (functor-laws)). By the two constructors of @Maybe@:
--
-- Case @Nothing@:
--
-- >   fmap (g . f) Nothing
-- > = { fmap _ Nothing = Nothing }
-- >   Nothing
-- > = { fmap g Nothing = Nothing, backwards }
-- >   fmap g (fmap f Nothing)
--
-- Case @Just a@:
--
-- >   fmap (g . f) (Just a)
-- > = { fmap h (Just a) = Just (h a) }
-- >   Just ((g . f) a)
-- > = { definition of (.) }
-- >   Just (g (f a))
-- > = { fmap g (Just b) = Just (g b), backwards }
-- >   fmap g (fmap f (Just a))
-- > QED
proof_functorComp
  :: (Eq c, Show c)
  => (b -> c) -> (a -> b) -> [Maybe a] -> Either String ()
proof_functorComp g f ms =
  mapM_ (\m -> checkEq "functorComp"
                 (fmap (g . f) m)
                 ((fmap g . fmap f) m))
        ms

-- | Proof: @Maybe@ preserves identities, @fmap id = id@ (Eq. (functor-laws)).
--
-- Case @Nothing@: @fmap id Nothing = Nothing = id Nothing@.
-- Case @Just a@:  @fmap id (Just a) = Just (id a) = Just a = id (Just a)@.
-- QED
proof_functorId :: (Eq a, Show a) => [Maybe a] -> Either String ()
proof_functorId ms =
  mapM_ (\m -> checkEq "functorId" (fmap id m) m) ms

-- ---------------------------------------------------------------------------
-- Naturality (Definition 3.5, Eq. (naturality))
-- ---------------------------------------------------------------------------

-- | Proof: naturality of @safeHead : [] => Maybe@ (Eq. (naturality)),
-- @fmap f . eta = eta . fmap f@ where @eta = component safeHead@.
--
-- Case @[]@:
--
-- >   fmap f (eta [])
-- > = { eta [] = Nothing }
-- >   fmap f Nothing = Nothing
-- > = { map f [] = [], then eta [] = Nothing }
-- >   eta (map f [])
--
-- Case @(y:ys)@:
--
-- >   fmap f (eta (y:ys))
-- > = { eta (y:ys) = Just y }
-- >   fmap f (Just y) = Just (f y)
-- > = { eta (f y : map f ys) = Just (f y), backwards }
-- >   eta (f y : map f ys)
-- > = { map f (y:ys) = f y : map f ys, backwards }
-- >   eta (map f (y:ys))
-- > QED
proof_naturality
  :: (Eq c, Show c) => (a -> c) -> [[a]] -> Either String ()
proof_naturality f xss =
  mapM_ (\xs -> checkEq "naturality"
                  (fmap f (eta xs))
                  (eta (fmap f xs)))
        xss
  where eta = runFn (component safeHead)

-- ---------------------------------------------------------------------------
-- T3: structural no-cloning (Section 6.3; Fox's theorem)
-- ---------------------------------------------------------------------------

-- | Proof: no uniform cloning in FdHilb (Thm. T3). A uniform natural diagonal
-- would make @(x)@ the categorical product, hence force the tensor dimension to
-- equal the biproduct dimension for all objects. We derive the contradiction at
-- @(3,3)@:
--
-- >   tensorDim 3 3
-- > = { tensorDim m n = m * n }
-- >   3 * 3 = 9
-- >
-- >   biproductDim 3 3
-- > = { biproductDim m n = m + n }
-- >   3 + 3 = 6
-- >
-- >   9 /= 6
-- > = { tensor (x) is not the categorical product (x) as bifunctors }
-- >   no natural family of diagonals exists   (contradiction with Fox)
-- > QED
--
-- The executable check confirms @tensorDim 3 3 /= biproductDim 3 3@ while also
-- recording the accidental coincidence @tensorDim 2 2 == biproductDim 2 2@ that
-- makes a /single/ dimension pair insufficient.
proof_noCloning :: Either String ()
proof_noCloning = do
  -- the obstruction at (3,3): 9 /= 6
  if tensorDim 3 3 /= biproductDim 3 3
    then Right ()
    else Left ("noCloning: tensorDim 3 3 == biproductDim 3 3 = "
               ++ show (tensorDim 3 3))
  -- the coincidence at (2,2): 4 == 4 (why one pair does not suffice)
  checkEq "noCloning/coincidence" (tensorDim 2 2) (biproductDim 2 2)

-- ---------------------------------------------------------------------------
-- Eckmann--Hilton (Proposition, Section 3): two unital ops sharing a unit and
-- satisfying interchange coincide, are associative, and are commutative.
-- ---------------------------------------------------------------------------

-- | Proof (Eckmann--Hilton). Let @S@ carry two binary operations @(.*)@ and
-- @(.+)@ sharing unit @e@ and satisfying interchange
-- @(a .+ b) .* (c .+ d) = (a .* c) .+ (b .* d)@. Then:
--
-- >   a .+ b
-- > = { unit: a = a .* e and b = e .* b }
-- >   (a .* e) .+ (e .* b)
-- > = { interchange (read right-to-left) }
-- >   (a .+ e) .* (e .+ b)
-- > = { unit for (.+) }
-- >   a .* b
-- > QED (the two operations coincide)
--
-- and, writing @x = a .* b = a .+ b@,
--
-- >   a .* b
-- > = { unit: a = e .+ a, b = b .+ e }
-- >   (e .+ a) .* (b .+ e)
-- > = { interchange }
-- >   (e .* b) .+ (a .* e)
-- > = { unit }
-- >   b .* a
-- > QED (the operation is commutative)
--
-- We witness the implication on the concrete model @S = Z@ with two /distinct/
-- presentations @op1 a b = a + b@ and @op2 a b = b + a@. The check has two
-- halves that mirror the theorem: first we verify the /hypotheses/ hold on the
-- model (shared unit @0@; and the middle-four interchange law relating @op1@ and
-- @op2@); then we verify the /conclusion/ (the two operations coincide and are
-- commutative). The interchange and coincidence checks are non-degenerate: they
-- reduce to genuine associativity/commutativity rearrangements of @(+)@, not to
-- reflexivity.
proof_eckmannHilton :: [Int] -> Either String ()
proof_eckmannHilton vals = do
  -- Hypothesis 1: shared two-sided unit e = 0 for both operations.
  mapM_ (\a -> checkEq "EH/unit-op1-L" (op1 e a) a) vals
  mapM_ (\a -> checkEq "EH/unit-op1-R" (op1 a e) a) vals
  mapM_ (\a -> checkEq "EH/unit-op2-L" (op2 e a) a) vals
  mapM_ (\a -> checkEq "EH/unit-op2-R" (op2 a e) a) vals
  -- Hypothesis 2: the interchange law
  --   (a `op2` b) `op1` (c `op2` d) = (a `op1` c) `op2` (b `op1` d).
  mapM_ (\(a, b, c, d) ->
           checkEq "EH/interchange"
             ((a `op2` b) `op1` (c `op2` d))
             ((a `op1` c) `op2` (b `op1` d)))
        quad
  -- Conclusion 1: the two operations coincide (op1 a b = op2 a b).
  mapM_ (\(a, b) -> checkEq "EH/coincide" (op1 a b) (op2 a b)) grid
  -- Conclusion 2: the (common) operation is commutative.
  mapM_ (\(a, b) -> checkEq "EH/commute"  (op1 a b) (op1 b a)) grid
  where
    -- Two distinct presentations of the same monoid operation on Z, sharing the
    -- unit 0 and satisfying interchange because (+) is associative+commutative.
    op1, op2 :: Int -> Int -> Int
    op1 a b = a + b
    op2 a b = b + a
    e :: Int
    e = 0
    -- Keep the 4-tuple grid small to bound the cost of the interchange check.
    small = take 3 vals
    grid  = [ (a, b)       | a <- vals,  b <- vals ]
    quad  = [ (a, b, c, d) | a <- small, b <- small, c <- small, d <- small ]

-- ---------------------------------------------------------------------------
-- T4: groupoid quotient retains the stabilizer the set quotient forgets
-- (Section 6.4)
-- ---------------------------------------------------------------------------

-- | Proof: for a group action, the groupoid quotient retains
-- @Aut_{X//G}(x) ~ Stab_G(x)@ at each point (Thm. T4(a)), while the set
-- quotient @X/G@ keeps only orbits, forgetting the loops (Thm. T4(b),(c)).
--
-- >   |Aut_{X//G}(x)|
-- > = { T4(a): Omega_x (X//G) ~ Stab_G(x) }
-- >   |Stab_G(x)| = |{ g | g . x = x }|
-- >
-- >   loops kept by X/G at [x]
-- > = { T4(b): X/G = || X//G ||_0 collapses all parallel paths }
-- >   1   (only reflexivity survives)
-- >
-- > whenever |Stab_G(x)| > 1 the two disagree, so X//G is strictly finer
-- > (T4(c)).
-- > QED
--
-- The executable certificate runs over a lawful finite group @grp@ acting on a
-- carrier @xs@ (both laws are /validated/, not assumed) and checks, at the
-- point @x@: that the retained automorphism count equals @|Stab_G(x)|@ (T4(a));
-- the orbit-stabilizer identity @|G| = |orbit(x)| * |Stab(x)|@; and that the
-- orbits genuinely partition @xs@, so @X/G@ is a well-defined set quotient
-- (T4(b)).
proof_groupoidRetainsStabilizer
  :: (Eq g, Ord x)
  => FiniteGroup g -> GroupAction g x -> [x] -> x -> Either String ()
proof_groupoidRetainsStabilizer grp ga xs x = do
  -- Hypotheses: G is a group and the action is lawful.
  ensure "T4/hyp: G is not a group"    (isGroup grp)
  ensure "T4/hyp: not a lawful action" (isActionOf grp ga xs)
  -- T4(a): the groupoid quotient's automorphism count is |Stab_G(x)|.
  checkEq "T4(a)/Aut=Stab"
    (groupoidAutomorphisms ga x)
    (length (stabilizer ga x))
  -- Orbit-stabilizer: |G| = |orbit(x)| * |Stab(x)|.
  ensure "T4/orbit-stabilizer |G| /= |orbit|*|stab|"
    (orbitStabilizerHolds ga x)
  -- T4(b): the orbits partition the carrier (0-truncation is well-defined).
  ensure "T4(b)/orbits do not partition the carrier"
    (orbitsPartition ga xs)

-- ---------------------------------------------------------------------------
-- Runner
-- ---------------------------------------------------------------------------

-- | A lawful @Z/2@ action on @{0,1,2}@: the nonidentity element swaps
-- @0 <-> 1@ and fixes @2@. It has a free point (@0@) and a fixed point (@2@),
-- so the T4 certificate exercises a genuinely nontrivial stabilizer over a
-- multi-point carrier.
z2OnThree :: GroupAction Int Int
z2OnThree = GroupAction { elements = [0, 1], act = step }
  where
    step 0 x = x
    step _ 0 = 1
    step _ 1 = 0
    step _ x = x

-- | Run every equational proof check at concrete data and report the outcome.
-- Returns 'True' iff all derivations verified.
runAllProofs :: IO Bool
runAllProofs = do
  putStrLn "--- Equational Reasoning Proof Checks (Part V) ---"
  let sample  = [-5 .. 5] :: [Int]
      f       = Fn (\x -> x + (1 :: Int))
      g       = Fn (\x -> x * (2 :: Int))
      h       = Fn (\x -> x - (3 :: Int))
      maybes  = [Nothing, Just 0, Just 7] :: [Maybe Int]
      lists   = [[], [1], [1, 2, 3], [9, 8]] :: [[Int]]
      results =
        [ ("leftUnit  (identity . f = f)        [Eq.(unit)]",
             proof_leftUnit f sample)
        , ("rightUnit (f . identity = f)        [Eq.(unit)]",
             proof_rightUnit f sample)
        , ("assoc     (h.(g.f) = (h.g).f)       [Eq.(assoc)]",
             proof_assoc h g f sample)
        , ("functorComp (F(g.f) = Fg.Ff)        [Def.3.2]",
             proof_functorComp (* (2 :: Int)) (+ 1) maybes)
        , ("functorId   (F id = id)             [Def.3.2]",
             proof_functorId maybes)
        , ("naturality  (fmap f . eta = eta . fmap f) [Def.3.5]",
             proof_naturality (show :: Int -> String) lists)
        , ("T3 no-cloning (9 /= 6, coincidence 4=4) [Thm.T3]",
             proof_noCloning)
        , ("Eckmann-Hilton (ops coincide+commute)   [Prop.]",
             proof_eckmannHilton sample)
        , ("T4 groupoid retains Stab_G(x) (fixed pt) [Thm.T4]",
             proof_groupoidRetainsStabilizer (cyclicGroup 2) z2OnThree [0, 1, 2] 2)
        , ("T4 orbit-stabilizer at free point       [Thm.T4]",
             proof_groupoidRetainsStabilizer (cyclicGroup 2) z2OnThree [0, 1, 2] 0)
        ]
  oks <- mapM report results
  let ok = and oks
  putStrLn ("--- Proofs: "
            ++ show (length (filter id oks)) ++ "/"
            ++ show (length oks) ++ " derivations verified ---")
  pure ok
  where
    report :: (String, Either String ()) -> IO Bool
    report (name, res) = case res of
      Right () -> putStrLn ("  [PASS] " ++ name) >> pure True
      Left msg -> putStrLn ("  [FAIL] " ++ name ++ "  (" ++ msg ++ ")")
                    >> pure False
