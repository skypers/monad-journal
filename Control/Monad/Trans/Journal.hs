{-# LANGUAGE GeneralizedNewtypeDeriving, TypeFamilies, UndecidableInstances #-}
{-# OPTIONS_HADDOCK prune #-}

-----------------------------------------------------------------------------
-- |
-- Copyright   :  (C) Dimitri Sabadie
-- License     :  BSD3
-- 
-- Maintainer  :  dimitri.sabadie@gmail.com
-- Stability   :  stable
-- Portability :  portable
--
-----------------------------------------------------------------------------
--
module Control.Monad.Trans.Journal (
    -- * JournalT monad transformer
    JournalT
  , runJournalT
  , evalJournalT
  , execJournalT
  , module Control.Monad.Journal.Class
  ) where

import Control.Applicative ( Applicative, Alternative )
import Control.Monad ( MonadPlus, liftM )
import Control.Monad.Base ( MonadBase, liftBase, liftBaseDefault )
import Control.Monad.Error.Class ( MonadError(..) )
import Control.Monad.Journal.Class
import Control.Monad.Reader.Class ( MonadReader(..) )
import Control.Monad.State.Class  ( MonadState )
import Control.Monad.Trans ( MonadTrans, MonadIO, lift )
import Control.Monad.Trans.State ( StateT(..), evalStateT, execStateT, get
                                 , modify, put, runStateT )
import Control.Monad.Trans.Control ( MonadTransControl(..)
                                   , MonadBaseControl(..), ComposeSt
                                   , defaultLiftBaseWith, defaultRestoreM )
import Control.Monad.Writer.Class ( MonadWriter(..) )
import Data.Monoid ( Monoid(..) )
import qualified Control.Monad.State.Class as MS ( MonadState(..) )

newtype JournalT w m a = JournalT (StateT w m a)
    deriving ( Applicative
             , Alternative
             , Functor
             , Monad
             , MonadError e
             , MonadIO
             , MonadPlus
             , MonadReader r
             , MonadTrans
             , MonadWriter w'
             )

instance (Monoid w,Monad m) => MonadJournal w (JournalT w m) where
  journal !w = JournalT . modify $ flip mappend w
  history = JournalT get
  clear   = JournalT (put mempty)

instance MonadState s m => MonadState s (JournalT w m) where
    get = lift MS.get
    put = lift . MS.put
    state = lift . MS.state

instance Monoid w => MonadTransControl (JournalT w) where
    newtype StT (JournalT w) a = StJournal {unStJournal :: (a, w)}
    liftWith f = JournalT $ StateT $ \w ->
                   liftM (\x -> (x, w))
                     (f $ \t -> liftM StJournal $ runJournalT (journal w >> t))
    restoreT = JournalT . StateT . const . liftM unStJournal
    {-# INLINE liftWith #-}
    {-# INLINE restoreT #-}

instance (MonadBase b m) => MonadBase b (JournalT w m) where
    liftBase = liftBaseDefault

instance (Monoid w,MonadBaseControl b m) => MonadBaseControl b (JournalT w m) where
    newtype StM (JournalT w m) a =
        StMJournal { unStMJournal :: ComposeSt (JournalT w) m a }
    liftBaseWith = defaultLiftBaseWith StMJournal
    restoreM     = defaultRestoreM   unStMJournal
    {-# INLINE liftBaseWith #-}
    {-# INLINE restoreM #-}

-- |Retrieve the value and the log history.
runJournalT :: (Monoid w,Monad m) => JournalT w m a -> m (a,w)
runJournalT (JournalT s) = runStateT s mempty

-- |Only retrieve the value.
evalJournalT :: (Monoid w,Monad m) => JournalT w m a -> m a
evalJournalT (JournalT s) = evalStateT s mempty

-- |Only retrieve the log history.
execJournalT :: (Monoid w,Monad m) => JournalT w m a -> m w
execJournalT (JournalT s) = execStateT s mempty
