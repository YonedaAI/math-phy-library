-- |
-- Module      : Dagger
-- Description : Dagger-compact structure and the structural no-cloning
--               obstruction (Theorem T3, Section 6.3 of the paper).
--
-- Theorem T3 says: if a symmetric monoidal category admits a uniform natural
-- copying map then its tensor is a categorical product (Fox's theorem). In
-- @FdHilb@ the categorical product/biproduct is the direct sum @(+)@ on
-- dimensions, while the tensor multiplies dimensions. The two disagree, so no
-- uniform cloning exists. This module makes that dimension obstruction
-- executable and provides a genuine cup/cap snake-equation contraction.
--
-- Dimensions are modelled with 'Integer' (not 'Int') so the dimension
-- arithmetic cannot silently overflow: the obstruction @m*n /= m+n@ is a true
-- statement of unbounded-precision arithmetic, matching the mathematics.
module Dagger
  ( tensorDim
  , biproductDim
  , cloningObstruction
  , noUniformCloning
  , snakeStraightens
  , snakeEntry
  ) where

-- | Dimension of a tensor product object @A (x) B@ in FdHilb.
tensorDim :: Integer -> Integer -> Integer
tensorDim m n = m * n

-- | Dimension of the categorical product / biproduct @A (+) B@ in FdHilb.
biproductDim :: Integer -> Integer -> Integer
biproductDim m n = m + n

-- | The obstruction to uniform cloning at dimensions @(m,n)@: the tensor
-- would have to coincide with the product for a natural diagonal to exist.
-- Returns 'True' when they differ (cloning obstructed at those dimensions).
-- Because the arithmetic is over 'Integer', there is no overflow coincidence:
-- for positive dimensions @m*n = m+n@ holds only at @(2,2)@ (equivalently
-- @(m-1)(n-1) = 1@).
cloningObstruction :: Integer -> Integer -> Bool
cloningObstruction m n = tensorDim m n /= biproductDim m n

-- | There is no uniform natural cloning in FdHilb: the tensor differs from the
-- product on some pair of dimensions. We witness this with @(3,3)@: tensor
-- gives @9@ but the biproduct gives @6@. (The coincidence at @(2,2)@, where
-- both equal @4@, is not enough for a /natural/ family.)
noUniformCloning :: Bool
noUniformCloning = cloningObstruction 3 3

-- | Kronecker delta @delta_ij@ (as an 'Integer' coefficient).
kron :: Int -> Int -> Integer
kron i j = if i == j then 1 else 0

-- | Entry @(k,c)@ of the straightened composite for the self-dual object
-- @A = R^d@. With cup @eta = sum_i e_i (x) e_i@ (coefficient @delta_ij@) and
-- cap @eps(e_i (x) e_j) = delta_ij@, the snake composite
-- @(eps (x) 1_A) . (1_A (x) eta) : A -> A@ has matrix entry
--
-- @snakeEntry d k c = sum_{a,b} delta_ab * delta_ak * delta_bc@,
--
-- a genuine double sum over the basis indices (not @delta_kc@ by definition).
snakeEntry :: Int -> Int -> Int -> Integer
snakeEntry d k c =
  sum [ kron a b * kron a k * kron b c
      | a <- [0 .. d - 1], b <- [0 .. d - 1] ]

-- | Snake / zig-zag equation (Eq. (snake)) as an honest contraction. For a
-- positive dimension @d@ the straightened composite must equal the identity on
-- @R^d@, i.e. @snakeEntry d k c == delta_kc@ for every @(k,c)@. Nonpositive
-- dimensions are not valid objects, so 'snakeStraightens' rejects them
-- ('False'); this replaces the earlier tautological @d == d@ bookkeeping.
snakeStraightens :: Int -> Bool
snakeStraightens d
  | d < 1     = False
  | otherwise =
      and [ snakeEntry d k c == kron k c
          | k <- [0 .. d - 1], c <- [0 .. d - 1] ]
