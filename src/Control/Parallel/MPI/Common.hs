module Control.Parallel.MPI.Common
   ( module Datatype
   , module Comm
   , module Status
   , module Tag
   , module Rank
   , module ThreadSupport
   , module Request
   , mpi
   , init
   , initThread
   , finalize
   , commSize
   , commRank
   , probe
   , barrier
   , wait
   , test
   , cancel
   ) where

import Prelude hiding (init)
import C2HS
import qualified Control.Parallel.MPI.Internal as Internal
import Control.Parallel.MPI.Datatype as Datatype
import Control.Parallel.MPI.Comm as Comm
import Control.Parallel.MPI.Request as Request
import Control.Parallel.MPI.Status as Status
import Control.Parallel.MPI.Utils (checkError)
import Control.Parallel.MPI.Tag as Tag
import Control.Parallel.MPI.Rank as Rank
import Control.Parallel.MPI.ThreadSupport as ThreadSupport
import Control.Parallel.MPI.MarshalUtils (enumToCInt, enumFromCInt)
import Control.Applicative ((<$>))

mpi :: IO () -> IO ()
mpi action = init >> action >> finalize

init :: IO ()
init = checkError Internal.init

initThread :: ThreadSupport -> IO ThreadSupport
initThread required = 
  alloca $ \providedPtr -> do
    checkError (Internal.initThread (enumToCInt required) (castPtr providedPtr))
    provided <- peek providedPtr
    return (enumFromCInt provided)

finalize :: IO ()
finalize = checkError Internal.finalize

commSize :: Comm -> IO Int
commSize comm = do
   alloca $ \ptr -> do
      checkError $ Internal.commSize comm ptr
      size <- peek ptr
      return $ cIntConv size

commRank :: Comm -> IO Rank
commRank comm =
   alloca $ \ptr -> do
      checkError $ Internal.commRank comm ptr
      rank <- peek ptr
      return $ toRank rank

probe :: Rank -> Tag -> Comm -> IO Status
probe rank tag comm = do
   let cSource = fromRank rank
       cTag    = fromTag tag
   alloca $ \statusPtr -> do
      checkError $ Internal.probe cSource cTag comm $ castPtr statusPtr
      peek statusPtr

barrier :: Comm -> IO ()
barrier comm = checkError $ Internal.barrier comm

wait :: Request -> IO Status
wait request =
   alloca $ \statusPtr ->
     alloca $ \reqPtr -> do
       poke reqPtr request
       checkError $ Internal.wait reqPtr $ castPtr statusPtr
       peek statusPtr

-- Returns Nothing if the request is not complete, otherwise
-- it returns (Just status).
test :: Request -> IO (Maybe Status)
test request =
    alloca $ \statusPtr ->
       alloca $ \reqPtr ->
          alloca $ \flagPtr -> do
              poke reqPtr request
              checkError $ Internal.test reqPtr (castPtr flagPtr) (castPtr statusPtr)
              flag <- peek flagPtr
              if flag
                 then Just <$> peek statusPtr
                 else return Nothing

cancel :: Request -> IO ()
cancel request =
   alloca $ \reqPtr -> do
       poke reqPtr request
       checkError $ Internal.cancel reqPtr
