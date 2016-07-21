{-|
Copyright  :  (C) 2013-2016, University of Twente
License    :  BSD2 (see the file LICENSE)
Maintainer :  Christiaan Baaij <christiaan.baaij@gmail.com>
-}

{-# LANGUAGE CPP                   #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DeriveDataTypeable    #-}
{-# LANGUAGE KindSignatures        #-}
{-# LANGUAGE MagicHash             #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}

{-# LANGUAGE Unsafe #-}

{-# OPTIONS_HADDOCK show-extensions #-}

#include "primitive.h"

module CLaSH.Sized.Internal.Index
  ( -- * Datatypes
    Index (..)
    -- * Type classes
    -- ** BitConvert
  , pack#
  , unpack#
    -- ** Eq
  , eq#
  , neq#
    -- ** Ord
  , lt#
  , ge#
  , gt#
  , le#
    -- ** Enum (not synthesisable)
  , enumFrom#
  , enumFromThen#
  , enumFromTo#
  , enumFromThenTo#
    -- ** Bounded
  , maxBound#
    -- ** Num
  , (+#)
  , (-#)
  , (*#)
  , fromInteger#
    -- ** ExtendingNum
  , plus#
  , minus#
  , times#
    -- ** Integral
  , quot#
  , rem#
  , toInteger#
    -- ** Resize
  , resize#
  )
where

import Data.Data                  (Data)
import Data.Default               (Default (..))
import Text.Read                  (Read (..), ReadPrec)
import Language.Haskell.TH        (TypeQ, appT, conT, litT, numTyLit, sigE)
import Language.Haskell.TH.Syntax (Lift(..))
import GHC.TypeLits               (KnownNat, Nat, type (+), type (-), type (*),
                                   natVal)
import GHC.TypeLits.Extra         (CLog)
import Test.QuickCheck.Arbitrary  (Arbitrary (..), CoArbitrary (..),
                                   arbitraryBoundedIntegral,
                                   coarbitraryIntegral, shrinkIntegral)

import CLaSH.Class.BitPack            (BitPack (..))
import CLaSH.Class.Num                (ExtendingNum (..))
import CLaSH.Class.Resize             (Resize (..))
import {-# SOURCE #-} CLaSH.Sized.Internal.BitVector (BitVector (..))

-- | Arbitrary-bounded unsigned integer represented by @ceil(log_2(n))@ bits.
--
-- Given an upper bound @n@, an 'Index' @n@ number has a range of: [0 .. @n@-1]
--
-- >>> maxBound :: Index 8
-- 7
-- >>> minBound :: Index 8
-- 0
-- >>> read (show (maxBound :: Index 8)) :: Index 8
-- 7
-- >>> 1 + 2 :: Index 8
-- 3
-- >>> 2 + 6 :: Index 8
-- *** Exception: CLaSH.Sized.Index: result 8 is out of bounds: [0..7]
-- >>> 1 - 3 :: Index 8
-- *** Exception: CLaSH.Sized.Index: result -2 is out of bounds: [0..7]
-- >>> 2 * 3 :: Index 8
-- 6
-- >>> 2 * 4 :: Index 8
-- *** Exception: CLaSH.Sized.Index: result 8 is out of bounds: [0..7]
newtype Index (n :: Nat) =
    -- | The constructor, 'I', and the field, 'unsafeToInteger', are not
    -- synthesisable.
    I { unsafeToInteger :: Integer }
  deriving Data

instance KnownNat n => BitPack (Index n) where
  type BitSize (Index n) = CLog 2 n
  pack   = pack#
  unpack = unpack#

pack# :: Index n -> BitVector (CLog 2 n)
pack# (I i) = BV i
{-# PRIMITIVE_I pack# #-}

unpack# :: KnownNat n => BitVector (CLog 2 n) -> Index n
unpack# (BV i) = fromInteger_INLINE i
{-# PRIMITIVE_I unpack# #-}

instance Eq (Index n) where
  (==) = eq#
  (/=) = neq#

eq# :: (Index n) -> (Index n) -> Bool
(I n) `eq#` (I m) = n == m
{-# PRIMITIVE_I eq# #-}

neq# :: (Index n) -> (Index n) -> Bool
(I n) `neq#` (I m) = n /= m
{-# PRIMITIVE_I neq# #-}

instance Ord (Index n) where
  (<)  = lt#
  (>=) = ge#
  (>)  = gt#
  (<=) = le#

lt#,ge#,gt#,le# :: Index n -> Index n -> Bool
lt# (I n) (I m) = n < m
{-# PRIMITIVE_I lt# #-}
ge# (I n) (I m) = n >= m
{-# PRIMITIVE_I ge# #-}
gt# (I n) (I m) = n > m
{-# PRIMITIVE_I gt# #-}
le# (I n) (I m) = n <= m
{-# PRIMITIVE_I le# #-}

-- | The functions: 'enumFrom', 'enumFromThen', 'enumFromTo', and
-- 'enumFromThenTo', are not synthesisable.
instance KnownNat n => Enum (Index n) where
  succ           = (+# fromInteger# 1)
  pred           = (-# fromInteger# 1)
  toEnum         = fromInteger# . toInteger
  fromEnum       = fromEnum . toInteger#
  enumFrom       = enumFrom#
  enumFromThen   = enumFromThen#
  enumFromTo     = enumFromTo#
  enumFromThenTo = enumFromThenTo#

enumFrom#       :: KnownNat n => Index n -> [Index n]
enumFromThen#   :: KnownNat n => Index n -> Index n -> [Index n]
enumFromTo#     :: KnownNat n => Index n -> Index n -> [Index n]
enumFromThenTo# :: KnownNat n => Index n -> Index n -> Index n -> [Index n]
enumFrom# x             = map toEnum [fromEnum x ..]
enumFromThen# x y       = map toEnum [fromEnum x, fromEnum y ..]
enumFromTo# x y         = map toEnum [fromEnum x .. fromEnum y]
enumFromThenTo# x1 x2 y = map toEnum [fromEnum x1, fromEnum x2 .. fromEnum y]
{-# PRIMITIVE enumFrom# #-}
{-# PRIMITIVE enumFromThen# #-}
{-# PRIMITIVE enumFromTo# #-}
{-# PRIMITIVE enumFromThenTo# #-}

instance KnownNat n => Bounded (Index n) where
  minBound = fromInteger# 0
  maxBound = maxBound#

maxBound# :: KnownNat n => Index n
maxBound# = let res = I (natVal res - 1) in res
{-# PRIMITIVE_I maxBound# #-}

-- | Operators report an error on overflow and underflow
instance KnownNat n => Num (Index n) where
  (+)         = (+#)
  (-)         = (-#)
  (*)         = (*#)
  negate      = (maxBound# -#)
  abs         = id
  signum i    = if i == 0 then 0 else 1
  fromInteger = fromInteger#

(+#),(-#),(*#) :: KnownNat n => Index n -> Index n -> Index n
(+#) (I a) (I b) = fromInteger_INLINE $ a + b
{-# PRIMITIVE (+#) #-}

(-#) (I a) (I b) = fromInteger_INLINE $ a - b
{-# PRIMITIVE (-#) #-}

(*#) (I a) (I b) = fromInteger_INLINE $ a * b
{-# PRIMITIVE (*#) #-}

fromInteger#,fromInteger_INLINE :: KnownNat n => Integer -> Index n
fromInteger# = fromInteger_INLINE
{-# PRIMITIVE fromInteger# #-}

fromInteger_INLINE i =
  let bound = natVal res
      i'    = i `mod` bound
      err   = error ("CLaSH.Sized.Index: result " ++ show i ++
                     " is out of bounds: [0.." ++ show (bound - 1) ++ "]")
      res   = if i' /= i then err else I i
  in  res
{-# INLINE fromInteger_INLINE #-}

instance ExtendingNum (Index m) (Index n) where
  type AResult (Index m) (Index n) = Index (m + n - 1)
  plus  = plus#
  minus = minus#
  type MResult (Index m) (Index n) = Index (((m - 1) * (n - 1)) + 1)
  times = times#

plus#, minus# :: Index m -> Index n -> Index (m + n - 1)
plus# (I a) (I b) = I (a + b)
{-# PRIMITIVE plus# #-}

minus# (I a) (I b) =
  let z   = a - b
      err = error ("CLaSH.Sized.Index.minus: result " ++ show z ++
                   " is smaller than 0")
      res = if z < 0 then err else I z
  in  res
{-# PRIMITIVE minus# #-}

times# :: Index m -> Index n -> Index (((m - 1) * (n - 1)) + 1)
times# (I a) (I b) = I (a * b)
{-# PRIMITIVE times# #-}

instance KnownNat n => Real (Index n) where
  toRational = toRational . toInteger#

instance KnownNat n => Integral (Index n) where
  quot        = quot#
  rem         = rem#
  div         = quot#
  mod         = rem#
  quotRem n d = (n `quot#` d,n `rem#` d)
  divMod  n d = (n `quot#` d,n `rem#` d)
  toInteger   = toInteger#

quot#,rem# :: Index n -> Index n -> Index n
(I a) `quot#` (I b) = I (a `div` b)
{-# PRIMITIVE quot# #-}
(I a) `rem#` (I b) = I (a `rem` b)
{-# PRIMITIVE rem# #-}

toInteger# :: Index n -> Integer
toInteger# (I n) = n
{-# PRIMITIVE toInteger# #-}

instance Resize Index where
  resize     = resize#
  zeroExtend = resize#
  signExtend = resize#
  truncateB  = resize#

resize# :: KnownNat m => Index n -> Index m
resize# (I i) = fromInteger_INLINE i
{-# PRIMITIVE resize# #-}

instance KnownNat n => Lift (Index n) where
  lift u@(I i) = sigE [| fromInteger# i |] (decIndex (natVal u))

decIndex :: Integer -> TypeQ
decIndex n = appT (conT ''Index) (litT $ numTyLit n)

instance Show (Index n) where
  showsPrec p ix = showsPrec p (toInteger# ix)
  show ix = show (toInteger# ix)
  -- We cannot say:
  --
  -- > show (I i) = show i
  --
  -- Because GHC translates that to a cast from Index to Integer,
  -- which the CLaSH compiler can (currently) not handle.

-- | None of the 'Read' class' methods are synthesisable.
instance KnownNat n => Read (Index n) where
  readPrec = fromIntegral <$> (readPrec :: ReadPrec Word)

instance KnownNat n => Default (Index n) where
  def = fromInteger# 0

instance KnownNat n => Arbitrary (Index n) where
  arbitrary = arbitraryBoundedIntegral
  shrink    = shrinkIndex

shrinkIndex :: KnownNat n => Index n -> [Index n]
shrinkIndex x | natVal x < 3 = case toInteger x of
                                 1 -> [0]
                                 _ -> []
              -- 'shrinkIntegral' uses "`quot` 2", which for 'Index' types with
              -- an upper bound less than 2 results in an error.
              | otherwise    = shrinkIntegral x

instance KnownNat n => CoArbitrary (Index n) where
  coarbitrary = coarbitraryIntegral
