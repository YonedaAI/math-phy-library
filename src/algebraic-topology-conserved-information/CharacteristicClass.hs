-- |
-- Module      : CharacteristicClass
-- Description : Characteristic classes as natural transformations, quantized
--               topological charges, and the index theorem as a realization
--               identity.
--
-- Part IV of "A Math->Physics Representation Library".  Characteristic classes
-- are the module of /quantized/ topological information (Definition
-- "Characteristic class", Proposition "Naturality is conservation").  We model:
--
--   * a characteristic class as a natural transformation @[-,BG] => H^*(-)@,
--     represented as a function from bundle data to an integer/rational class;
--
--   * the first Chern number of a line bundle over a closed surface, with the
--     Gauss-Bonnet instance @\int c_1(T Sigma_g) = 2 - 2g = chi@;
--
--   * the Atiyah-Singer / Riemann-Roch index theorem read as
--     @observable = Real(abstract structure)@ (Theorem "Atiyah-Singer as
--     observable = Real(abstract structure)"): the analytic index equals a purely
--     topological integral.
module CharacteristicClass
  ( -- * Characteristic classes
    CharClass(..)
  , firstChern
  , chernNumberLineBundle
    -- * Surfaces and Gauss-Bonnet
  , Surface(..)
  , mkSurface
  , eulerCharacteristicSurface
  , tangentChernNumber
    -- * Index theorem as a realization identity
  , riemannRochIndex
  , indexEqualsTopological
  ) where

-- | A characteristic class for @G@-bundles: a natural transformation
-- @[-, BG] => H^*(-; R)@.  Concretely, a rule assigning to bundle data @b@ a
-- (numerical) cohomological invariant.  Naturality (@c(g^*P) = g^* c(P)@) is the
-- content of Proposition "Naturality is conservation"; here we expose only the
-- assignment.
newtype CharClass b r = CharClass { applyClass :: b -> r }

-- | The first Chern class functional, represented on line-bundle data by its
-- degree (the integer @\int_Sigma c_1@).
firstChern :: CharClass Int Int
firstChern = CharClass id

-- | The first Chern number @\int_Sigma c_1(L) \in Z@ of a complex line bundle of
-- degree @d@ over a closed oriented surface: the Dirac-quantized total flux.
chernNumberLineBundle :: Int -> Int
chernNumberLineBundle d = applyClass firstChern d

-- | A closed oriented surface, recorded by its genus.  The genus must be
-- nonnegative; use 'mkSurface' for a guarded constructor.
newtype Surface = Surface { genus :: Int } deriving (Eq, Show)

-- | Guarded constructor for a closed oriented surface: the genus must be
-- @>= 0@.
mkSurface :: Int -> Surface
mkSurface g
  | g < 0     = error "mkSurface: genus must be >= 0"
  | otherwise = Surface g

-- | Euler characteristic @chi(Sigma_g) = 2 - 2g@ (genus @>= 0@ required).
eulerCharacteristicSurface :: Surface -> Int
eulerCharacteristicSurface (Surface g)
  | g < 0     = error "eulerCharacteristicSurface: genus must be >= 0"
  | otherwise = 2 - 2 * g

-- | The Gauss-Bonnet instance of Proposition "Naturality is conservation":
-- @\int_Sigma c_1(T Sigma_g) = chi(Sigma_g) = 2 - 2g@.  The first Chern number of
-- the tangent bundle is a conserved topological charge equal to the Euler number.
tangentChernNumber :: Surface -> Int
tangentChernNumber = eulerCharacteristicSurface

-- | Riemann-Roch as the index of the Dolbeault operator twisted by a line bundle
-- of degree @d@ over @Sigma_g@:
--
-- >  ind(dbar_L) = h^0(L) - h^1(L) = deg L + 1 - g.
--
-- This is the surface case of the Atiyah-Singer index theorem
-- @ind(D_E) = \int_X Ahat(X) ch(E)@ (Theorem "Atiyah-Singer as observable =
-- Real(abstract structure)"): the analytic index (left) equals a topological
-- integral (right).
riemannRochIndex :: Surface -> Int -> Int
riemannRochIndex (Surface g) d
  | g < 0     = error "riemannRochIndex: genus must be >= 0"
  | otherwise = d + 1 - g

-- | Verify the index theorem as a realization identity: the analytic observable
-- (the index) equals the topological realization
-- @\int_Sigma (ch(L) . Td(T Sigma)) = deg L + (1 - g)@, where @1 - g@ is the
-- degree-0 Todd contribution @\int Td = 1 - g@ and @deg L@ is @\int ch_1(L)@.
indexEqualsTopological :: Surface -> Int -> Bool
indexEqualsTopological s@(Surface g) d =
  riemannRochIndex s d == d + (1 - g)   -- observable  ==  Real(abstract structure)
