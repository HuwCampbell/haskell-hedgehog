{-# OPTIONS_HADDOCK not-home #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ConstraintKinds #-}
module Hedgehog.Internal.HTraversable (
    module Data.Functor.Barbie
  , module GHC.Generics
  ) where


import GHC.Generics (Generic)
import Data.Functor.Barbie (FunctorB(..), TraversableB (..), Rec (..))
