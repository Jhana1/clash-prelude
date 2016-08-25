{-|
  Copyright   :  (C) 2013-2016, University of Twente
  License     :  BSD2 (see the file LICENSE)
  Maintainer  :  Christiaan Baaij <christiaan.baaij@gmail.com>

  CλaSH (pronounced ‘clash’) is a functional hardware description language that
  borrows both its syntax and semantics from the functional programming language
  Haskell. The merits of using a functional language to describe hardware comes
  from the fact that combinational circuits can be directly modeled as
  mathematical functions and that functional languages lend themselves very well
  at describing and (de-)composing mathematical functions.

  This package provides:

  * Prelude library containing datatypes and functions for circuit design

  To use the library:

  * Import "CLaSH.Prelude"
  * Additionally import "CLaSH.Prelude.Explicit" if you want to design
    explicitly clocked circuits in a multi-clock setting

  For now, "CLaSH.Prelude" is also the best starting point for exploring the
  library. A preliminary version of a tutorial can be found in "CLaSH.Tutorial".
  Some circuit examples can be found in "CLaSH.Examples".
-}

{-# LANGUAGE CPP              #-}
{-# LANGUAGE DataKinds        #-}
{-# LANGUAGE ImplicitParams   #-}
{-# LANGUAGE MagicHash        #-}
{-# LANGUAGE TypeOperators    #-}

{-# LANGUAGE Unsafe #-}

{-# OPTIONS_HADDOCK show-extensions #-}

module CLaSH.Prelude
  ( -- * Creating synchronous sequential circuits
    mealy
  , mealyB
  , (<^>)
  , moore
  , mooreB
  , registerB
    -- * ROMs
  , asyncRom
  , asyncRomPow2
  , rom
  , romPow2
    -- ** ROMs initialised with a data file
  , asyncRomFile
  , asyncRomFilePow2
  , romFile
  , romFilePow2
    -- * RAM primitives with a combinational read port
  , asyncRam
  , asyncRamPow2
    -- * BlockRAM primitives
  , blockRam
  , blockRamPow2
    -- ** BlockRAM primitives initialised with a data file
  , blockRamFile
  , blockRamFilePow2
    -- ** BlockRAM read/write conflict resolution
  , readNew
    -- * Utility functions
  , window
  , windowD
  , isRising
  , isFalling
    -- * Testbench functions
  , assert
  , stimuliGenerator
  , outputVerifier
    -- ** Clocks & Resets
  , clockGen
  , asyncResetGen
  , syncResetGen
    -- ** Stop the HDL simulator
  , hdlSimFinish
    -- * Exported modules
    -- ** Synchronous signals
  , module CLaSH.Signal
  , module CLaSH.Signal.Delayed
    -- ** DataFlow interface
  , module CLaSH.Prelude.DataFlow
    -- ** Datatypes
    -- *** Bit vectors
  , module CLaSH.Sized.BitVector
  , module CLaSH.Prelude.BitIndex
  , module CLaSH.Prelude.BitReduction
    -- *** Arbitrary-width numbers
  , module CLaSH.Sized.Signed
  , module CLaSH.Sized.Unsigned
  , module CLaSH.Sized.Index
    -- *** Fixed point numbers
  , module CLaSH.Sized.Fixed
    -- *** Fixed size vectors
  , module CLaSH.Sized.Vector
    -- *** Perfect depth trees
  , module CLaSH.Sized.RTree
    -- ** Annotations
  , module CLaSH.Annotations.TopEntity
    -- ** FPGA Clock & Reset sources
  , module CLaSH.TopEntity
    -- ** Type-level natural numbers
  , module GHC.TypeLits
  , module GHC.TypeLits.Extra
  , module CLaSH.Promoted.Nat
  , module CLaSH.Promoted.Nat.Literals
  , module CLaSH.Promoted.Nat.TH
    -- ** Template Haskell
  , Lift (..)
    -- ** Type classes
    -- *** CLaSH
  , module CLaSH.Class.BitPack
  , module CLaSH.Class.Num
  , module CLaSH.Class.Resize
    -- *** Other
  , module Control.Applicative
  , module Data.Bits
  , module Data.Default
    -- ** Exceptions
  , module CLaSH.XException
    -- ** Haskell Prelude
    -- $hiding
  , module Prelude
  )
where

import Control.Applicative
import Data.Bits
import Data.Default
import GHC.Stack                   (HasCallStack)
import GHC.TypeLits
import GHC.TypeLits.Extra
import Language.Haskell.TH.Syntax  (Lift(..))
import Prelude                     hiding ((++), (!!), concat, drop, foldl,
                                           foldl1, foldr, foldr1, head, init,
                                           iterate, last, length, map, repeat,
                                           replicate, reverse, scanl, scanr,
                                           splitAt, tail, take, unzip, unzip3,
                                           zip, zip3, zipWith, zipWith3)

import CLaSH.Annotations.TopEntity
import CLaSH.Class.BitPack
import CLaSH.Class.Num
import CLaSH.Class.Resize
import CLaSH.Prelude.BitIndex
import CLaSH.Prelude.BitReduction
import CLaSH.Prelude.BlockRam.File (blockRamFile, blockRamFilePow2)
import CLaSH.Prelude.DataFlow
import CLaSH.Prelude.Explicit      (window#, windowD#)
import CLaSH.Prelude.ROM.File      (asyncRomFile,asyncRomFilePow2,romFile,
                                    romFilePow2)
import CLaSH.Prelude.Safe
import CLaSH.Prelude.Testbench     (assert, asyncResetGen, clockGen,
                                    hdlSimFinish, syncResetGen, outputVerifier,
                                    stimuliGenerator )
import CLaSH.Promoted.Nat
import CLaSH.Promoted.Nat.TH
import CLaSH.Promoted.Nat.Literals
import CLaSH.Sized.BitVector
import CLaSH.Sized.Fixed
import CLaSH.Sized.Index
import CLaSH.Sized.RTree
import CLaSH.Sized.Signed
import CLaSH.Sized.Unsigned
import CLaSH.Sized.Vector
import CLaSH.Signal
import CLaSH.Signal.Delayed
import CLaSH.TopEntity
import CLaSH.XException

{- $setup
>>> :set -XDataKinds -XImplicitParams
>>> let window4 = window :: (?res :: Reset res dom, ?clk :: Clock clk dom) => Signal dom Int -> Vec 4 (Signal dom Int)
>>> let windowD3 = windowD :: (?res :: Reset res dom, ?clk :: Clock clk dom) => Signal dom Int -> Vec 3 (Signal dom Int)
>>> let rP = registerB (8,8)
-}

{- $hiding
"CLaSH.Prelude" re-exports most of the Haskell "Prelude" with the exception of
the following: (++), (!!), concat, drop, foldl, foldl1, foldr, foldr1, head,
init, iterate, last, length, map, repeat, replicate, reverse, scanl, scanr,
splitAt, tail, take, unzip, unzip3, zip, zip3, zipWith, zipWith3.

It instead exports the identically named functions defined in terms of
'CLaSH.Sized.Vector.Vec' at "CLaSH.Sized.Vector".
-}

{-# INLINE window #-}
-- | Give a window over a 'Signal'
--
-- > window4 :: (?res :: Reset res dom, ?clk :: Clock clk dom)
-- >         => Signal dom Int -> Vec 4 (Signal dom Int)
-- > window4 = window
--
-- >>> simulateB window4 [1::Int,2,3,4,5] :: [Vec 4 Int]
-- [<1,0,0,0>,<2,1,0,0>,<3,2,1,0>,<4,3,2,1>,<5,4,3,2>...
-- ...
window :: (HasCallStack, KnownNat n, Default a,
           ?res :: Reset res dom, ?clk :: Clock clk dom)
       => Signal dom a               -- ^ Signal to create a window over
       -> Vec (n + 1) (Signal dom a) -- ^ Window of at least size 1
window = window# ?res ?clk

{-# INLINE windowD #-}
-- | Give a delayed window over a 'Signal'
--
-- > windowD3 :: (?res :: Reset res dom, ?clk :: Clock clk dom)
-- >          => Signal dom Int -> Vec 3 (Signal dom Int)
-- > windowD3 = windowD
--
-- >>> simulateB windowD3 [1::Int,2,3,4] :: [Vec 3 Int]
-- [<0,0,0>,<1,0,0>,<2,1,0>,<3,2,1>,<4,3,2>...
-- ...
windowD :: (HasCallStack, KnownNat n, Default a,
            ?res :: Reset res dom, ?clk :: Clock clk dom)
        => Signal dom a               -- ^ Signal to create a window over
        -> Vec (n + 1) (Signal dom a) -- ^ Window of at least size 1
windowD = windowD# ?res ?clk
