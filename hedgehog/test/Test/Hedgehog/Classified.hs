{-# LANGUAGE TemplateHaskell #-}
module Test.Hedgehog.Classified (
    tests
  ) where

import           Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

prop_check_classifiers :: Property
prop_check_classifiers =
  property $ do
    a <- forAll $ Gen.sized $ pure . Range.unSize
    classify (a < 50) "small number"
    classify (a >= 50) "big number"
    success

prop_check_coverage :: Property
prop_check_coverage =
  property $ do
    a <- forAll $ Gen.sized $ pure . Range.unSize
    cover 50 (a < 50) "small number"
    cover 50 (a >= 50) "big number"
    success

tests :: IO Bool
tests =
  checkParallel $$(discover)
