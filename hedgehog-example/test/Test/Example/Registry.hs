--
-- Translated from https://github.com/rjmh/registry/blob/master/registry_eqc.erl
--
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE TemplateHaskell #-}
module Test.Example.Registry where

import           Control.Monad (when)
import           Control.Monad.IO.Class (MonadIO(..))

import           Data.Foldable (traverse_)
import qualified Data.HashTable.IO as HashTable
import           Data.IORef (IORef)
import qualified Data.IORef as IORef
import           Data.Map (Map)
import qualified Data.Map.Strict as Map
import           Data.Maybe (isJust, isNothing)
import           Data.Set (Set)
import qualified Data.Set as Set

import           Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import           System.IO.Unsafe (unsafePerformIO)

------------------------------------------------------------------------
-- %% state
--
-- -record(state,{pids=[],regs=[]}).
--
-- initial_state() ->
--   #state{}.
--

data Pid v =
  Pid (Instantiation v Int)
  deriving (Eq, Ord, Show)

data Name =
  Name String
  deriving (Eq, Ord, Show)

data State v =
  State {
      statePids :: Set (Pid v)
    , stateRegs :: Map Name (Pid v)
    } deriving (Eq, Show)

initialState :: State v
initialState =
  State Set.empty Map.empty

instance HTraversable Pid where
  htraverse f (Pid v) =
    fmap Pid (f v)

------------------------------------------------------------------------
-- %% spawn
--
-- spawn_args(_) ->
--   [].
--
-- spawn() ->
--   spawn_link(timer,sleep,[5000]).
--
-- spawn_next(S,Pid,[]) ->
--   S#state{pids=S#state.pids++[Pid]}.
--

data Spawn (v :: Representation) =
  Spawn
  deriving (Eq, Show)

instance HTraversable Spawn where
  htraverse _ Spawn =
    pure Spawn

spawn :: Monad m => Command m IO State
spawn =
  let
    gen _ =
      Just $
        pure Spawn

    execute _ =
      liftIO ioSpawn
  in
    Command gen execute [
        Update $ \s _i o ->
          s {
            statePids =
              Set.insert (Pid o) (statePids s)
          }
      ]

------------------------------------------------------------------------
-- %% register
--
-- register_pre(S) ->
--   S#state.pids /= [].
--
-- register_args(S) ->
--   [name(),elements(S#state.pids)].
--
-- register(Name,Pid) ->
--   erlang:register(Name,Pid).
--
-- register_next(S,_,[Name,Pid]) ->
--   S#state{regs=S#state.regs++[{Name,Pid}]}.
--
-- register_pre(S,[Name,Pid]) ->
--   not lists:keymember(Name,1,S#state.regs)
--   andalso
--   not lists:keymember(Pid,2,S#state.regs).
--

data Register (v :: Representation) =
  Register Name (Pid v)
  deriving (Eq, Show)

instance HTraversable Register where
  htraverse f (Register name pid) =
    Register
      <$> pure name
      <*> htraverse f pid

genName :: Monad m => Gen m Name
genName =
  Name <$> Gen.element ["a", "b", "c", "d"]

register :: Monad m => Command m IO State
register =
  let
    gen s =
      case Set.toList (statePids s) of
        [] ->
          Nothing
        xs ->
          Just $
            Register
              <$> genName
              <*> Gen.element xs

    execute :: Register 'Concrete -> Test IO ()
    execute (Register (Name name) (Pid (CI pid))) =
      liftIO $ ioRegister name pid
  in
    Command gen execute [
        Require $ \s (Register name _) ->
          Map.notMember name (stateRegs s)

      , Require $ \s (Register _ pid) ->
          notElem pid $ Map.elems (stateRegs s)

      , Update $ \s (Register name pid) _o ->
          s {
            stateRegs =
              Map.insert name pid (stateRegs s)
          }
      ]

------------------------------------------------------------------------
-- %% unregister
--
-- unregister_args(_) ->
--   [name()].
--
-- unregister(Name) ->
--   erlang:unregister(Name).
--
-- unregister_pre(S,[Name]) ->
--   lists:keymember(Name,1,S#state.regs).
--
-- unregister_next(S,_,[Name]) ->
--   S#state{regs=lists:keydelete(Name,1,S#state.regs)}.
--

data Unregister (v :: Representation) =
  Unregister Name
  deriving (Eq, Show)

instance HTraversable Unregister where
  htraverse _ (Unregister name) =
    Unregister <$> pure name

unregister :: Monad m => Command m IO State
unregister =
  let
    gen _ =
      Just $
        Unregister <$> genName

    execute :: Unregister 'Concrete -> Test IO ()
    execute (Unregister (Name name)) =
      liftIO $ ioUnregister name
  in
    Command gen execute [
        Require $ \s (Unregister name) ->
          Map.member name (stateRegs s)

      , Update $ \s (Unregister name) _o ->
          s {
            stateRegs =
              Map.delete name (stateRegs s)
          }
      ]

------------------------------------------------------------------------
-- Fake Process Registry
--
-- /These are global to simulate some kind of external system we're testing./
--

type ProcessTable = HashTable.CuckooHashTable String Int

pidRef :: IORef Int
pidRef =
  unsafePerformIO $ IORef.newIORef 0
{-# NOINLINE pidRef #-}

procTable :: ProcessTable
procTable =
  unsafePerformIO $ HashTable.new
{-# NOINLINE procTable #-}

ioReset :: IO ()
ioReset = do
  IORef.writeIORef pidRef 0
  ks <- fmap fst <$> HashTable.toList procTable
  traverse_ (HashTable.delete procTable) ks

ioSpawn :: IO Int
ioSpawn = do
  pid <- IORef.readIORef pidRef
  IORef.writeIORef pidRef (pid + 1)
  pure pid

ioRegister :: String -> Int -> IO ()
ioRegister name pid = do
  m <- HashTable.lookup procTable name

  when (isJust m) $
    fail "ioRegister: already registered"

  HashTable.insert procTable name pid

ioUnregister :: String -> IO ()
ioUnregister name = do
  m <- HashTable.lookup procTable name

  when (isNothing m) $
    fail "ioUnregister: not registered"

  -- Uncomment to fix implementation
  --HashTable.delete procTable name

------------------------------------------------------------------------

prop_registry :: Property
prop_registry =
  property $ do
    actions <- forAll $
      Gen.actions (Range.linear 1 100) initialState [spawn, register, unregister]

    liftCatchIO ioReset
    executeSequential initialState actions

------------------------------------------------------------------------

return []
tests :: IO Bool
tests =
  checkParallel $$(discover)
