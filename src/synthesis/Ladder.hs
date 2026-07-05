-- | Module      : Ladder
--   Part VII (Synthesis), Part V face plus the modular composition ladder.
--
--   The six faculties form a /thin category/ of rungs
--   @I -> II -> III -> IV -> V -> VI@ (synthesis Sec. "The modular composition
--   ladder", Table "ladder").  A morphism @i -> j@ exists iff @i <= j@ and is
--   the "builds-on" arrow @J_{i,j}@; composition is transitive and strictly
--   associative.  Every rung also carries its central data: the new structure,
--   the spine axiom it touches, the emergent property, and its status
--   contribution.
--
--   Representation entries compose with status @max@-propagation (synthesis
--   PI/T3): the composite of a chain of translations is only as reliable as its
--   weakest link, so the six-faculty composite has status
--   @worstOf [status I, .., status VI]@.
module Ladder
  ( -- * The six rungs
    Rung(..)
  , allRungs
  , rungStatus
  , newStructure
  , emergentProperty
    -- * The thin category of "builds-on" morphisms
  , Mor
  , identityMor
  , buildsOn
  , composeMor
    -- * Realization functor and the commuting triangle
  , realize
  , commutesTriangle
    -- * Representation entries and their composition (PI/T3)
  , RepEntry(..)
  , composeEntries
  , composeChain
  , ladderComposite
  ) where

import Status (Status (..), composeStatus, worstOf)

-- | The six modular faculties, in build order.  The derived 'Ord' is the
--   ladder order @I <= II <= ... <= VI@.
data Rung = I | II | III | IV | V | VI
  deriving (Eq, Ord, Show, Enum, Bounded)

-- | Every rung, in order.
allRungs :: [Rung]
allRungs = [minBound .. maxBound]

-- | The (headline) status contribution of each rung's central realization
--   (synthesis Table "census" / Sec. "Status of the candidate theorems"):
--   the algebro-topological rung (IV) is fully standard; the category/HoTT
--   rung (V) is the most interpretive.
rungStatus :: Rung -> Status
rungStatus I   = H   -- the status calculus PI/T3 is original heuristic
rungStatus II  = S   -- coaction transport for comodules (PII/T1)
rungStatus III = S   -- Gauss--Manin flat sections (PIII/T1)
rungStatus IV  = S   -- TQFT / index theorem (PIV/T1,T3)
rungStatus V   = H   -- physical readings of types/functors are heuristic
rungStatus VI  = S   -- stackification / surface codes (PVI/T1,T3)

-- | The new mathematical structure introduced at each rung.
newStructure :: Rung -> String
newStructure I   = "entries (M,P,tau,sigma); prestack; pipeline; S/H/P calculus"
newStructure II  = "motives; period data; coaction Delta; cobracket delta"
newStructure III = "schemes; moduli stacks [X/G]; VHS; Gauss--Manin"
newStructure IV  = "(co)homology; characteristic classes; bordism; TQFT"
newStructure V   = "functors; naturality; monoidal/dagger; univalence"
newStructure VI  = "sheaves; stacks; [X/G]; QEC codes; Hopf renormalization"

-- | The single emergent property contributed by each rung's composite.
emergentProperty :: Rung -> String
emergentProperty I   = "disciplined translation (syntax/semantics/status as data)"
emergentProperty II  = "coalgebraic anatomy (observables decompose)"
emergentProperty III = "geometric variation (possibilities vary over moduli)"
emergentProperty IV  = "functorial conservation (invariants; realization a functor)"
emergentProperty V   = "universal compositional grammar (equivalence respected)"
emergentProperty VI  = "high availability / fault tolerance (many reps, one content)"

-- | A "builds-on" morphism @J_{i,j} : i -> j@, valid exactly when @i <= j@.
data Mor = Mor Rung Rung
  deriving (Eq, Show)

-- | The identity morphism @J_{i,i}@ on a rung.
identityMor :: Rung -> Mor
identityMor r = Mor r r

-- | Smart constructor for @J_{i,j}@: 'Just' when @i <= j@, else 'Nothing'.
buildsOn :: Rung -> Rung -> Maybe Mor
buildsOn i j
  | i <= j    = Just (Mor i j)
  | otherwise = Nothing

-- | Composition of builds-on morphisms @J_{j,k} . J_{i,j} = J_{i,k}@.
--   Defined when the target of the first equals the source of the second.
composeMor :: Mor -> Mor -> Maybe Mor
composeMor (Mor i j) (Mor j' k)
  | j == j'   = Just (Mor i k)
  | otherwise = Nothing

-- | The global realization functor's target label for each rung's central
--   observable (synthesis Table "framework").  All six factor through the
--   single physical target @Phys@.
realize :: Rung -> String
realize I   = "Phys: observable = Obs . Real_alpha . Phi"
realize II  = "Phys: period per(Pi) = integral over Gamma of omega"
realize III = "Phys: flat section / monodromy"
realize IV  = "Phys: dimension / trace / index"
realize V   = "Phys: term extraction / global sections"
realize VI  = "Phys: syndrome / logical readout"

-- | The master diagram's commuting triangle @Real_{j} . J_{i,j} = Real_i@
--   holds up to the single target @Phys@: realizing at a higher rung and
--   restricting agrees with realizing at the lower rung (synthesis
--   Fig. "master").  Modeled by: both land in @Phys@ for any valid @J_{i,j}@.
commutesTriangle :: Rung -> Rung -> Bool
commutesTriangle i j =
  case buildsOn i j of
    Nothing -> True                          -- vacuously (no such morphism)
    Just _  -> phys (realize i) && phys (realize j)
  where
    phys :: String -> Bool
    phys s = take 5 s == "Phys:"

-- | A representation entry @(M, P, tau, sigma)@ (synthesis Def. "entry"),
--   modeled by its mathematical-source tag, physical-target tag and status.
data RepEntry = RepEntry
  { mathTag     :: String
  , physTag     :: String
  , entryStatus :: Status
  } deriving (Eq, Show)

-- | Composition of compatible entries (synthesis PI/T3): @tau2 . tau1@ is
--   defined when @physTag e1 == mathTag e2@, and the composite status is the
--   @max@ of the two.  Status never improves under composition.
composeEntries :: RepEntry -> RepEntry -> Maybe RepEntry
composeEntries e1 e2
  | physTag e1 == mathTag e2 =
      Just (RepEntry (mathTag e1) (physTag e2)
                     (composeStatus (entryStatus e1) (entryStatus e2)))
  | otherwise = Nothing

-- | Compose a left-to-right chain of entries, if every adjacent pair is
--   composable.
composeChain :: [RepEntry] -> Maybe RepEntry
composeChain []       = Nothing
composeChain (e : es) = foldl step (Just e) es
  where
    step :: Maybe RepEntry -> RepEntry -> Maybe RepEntry
    step acc next = acc >>= \a -> composeEntries a next

-- | The full six-faculty ladder composite: a single entry threading
--   @I -> II -> ... -> VI@ into @Phys@, whose status is
--   @worstOf [rungStatus r | r <- allRungs]@ (synthesis Closure Theorem,
--   status tracking).
ladderComposite :: RepEntry
ladderComposite = RepEntry
  { mathTag     = "Math_I (representation entries)"
  , physTag     = "Phys (logical/observable content)"
  , entryStatus = worstOf (map rungStatus allRungs)
  }
