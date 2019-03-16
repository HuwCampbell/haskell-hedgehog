{-# LANGUAGE TemplateHaskell #-}
module Test.Hedgehog.Classified (
    tests
  ) where

import           Data.Foldable (for_)

import           Hedgehog

prop_check_classifiers :: Property
prop_check_classifiers =
  withTests 1 . property $ do
    for_ [1 :: Int ..50] $ \a ->
      classify (a < 25) "small number" $
      classify (a >= 25) "big number" success

tests :: IO Bool
tests =
  checkParallel $$(discover)
