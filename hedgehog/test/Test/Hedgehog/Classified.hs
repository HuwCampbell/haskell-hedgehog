{-# LANGUAGE TemplateHaskell #-}
module Test.Hedgehog.Classified (
    tests
  ) where

import           Data.Foldable (for_)

import           Hedgehog

prop_check_classifiers :: Property
prop_check_classifiers =
  withTests 1 . property $ do
    for_ [1 :: Int ..100] $ \a ->
      classify (a < 50) "small number" $
      classify (a >= 50) "big number" success

prop_check_coverage :: Property
prop_check_coverage =
  withTests 1 . property $ do
    for_ [1 :: Int ..100] $ \a ->
      cover 50 (a < 50) "small number" $
      cover 50 (a >= 50) "big number" $
        success

tests :: IO Bool
tests =
  checkParallel $$(discover)
