{-|

Common utilities for hledger data readers, such as the context (state)
that is kept while parsing a journal.

-}

module Hledger.Read.Common
where

import Control.Monad.Error
import Data.List
import Hledger.Data.Types (Journal)
import Text.ParserCombinators.Parsec
import System.Directory (getHomeDirectory)
import System.FilePath(takeDirectory,combine)


-- | A JournalUpdate is some transformation of a "Journal". It can do I/O
-- or raise an error.
type JournalUpdate = ErrorT String IO (Journal -> Journal)

-- | Some context kept during parsing.
data LedgerFileCtx = Ctx {
      ctxYear     :: !(Maybe Integer)  -- ^ the default year most recently specified with Y
    , ctxCommod   :: !(Maybe String)   -- ^ I don't know
    , ctxAccount  :: ![String]         -- ^ the current stack of parent accounts specified by !account
    } deriving (Read, Show)

emptyCtx :: LedgerFileCtx
emptyCtx = Ctx { ctxYear = Nothing, ctxCommod = Nothing, ctxAccount = [] }

setYear :: Integer -> GenParser tok LedgerFileCtx ()
setYear y = updateState (\ctx -> ctx{ctxYear=Just y})

getYear :: GenParser tok LedgerFileCtx (Maybe Integer)
getYear = liftM ctxYear getState

pushParentAccount :: String -> GenParser tok LedgerFileCtx ()
pushParentAccount parent = updateState addParentAccount
    where addParentAccount ctx0 = ctx0 { ctxAccount = normalize parent : ctxAccount ctx0 }
          normalize = (++ ":") 

popParentAccount :: GenParser tok LedgerFileCtx ()
popParentAccount = do ctx0 <- getState
                      case ctxAccount ctx0 of
                        [] -> unexpected "End of account block with no beginning"
                        (_:rest) -> setState $ ctx0 { ctxAccount = rest }

getParentAccount :: GenParser tok LedgerFileCtx String
getParentAccount = liftM (concat . reverse . ctxAccount) getState

expandPath :: (MonadIO m) => SourcePos -> FilePath -> m FilePath
expandPath pos fp = liftM mkRelative (expandHome fp)
  where
    mkRelative = combine (takeDirectory (sourceName pos))
    expandHome inname | "~/" `isPrefixOf` inname = do homedir <- liftIO getHomeDirectory
                                                      return $ homedir ++ drop 1 inname
                      | otherwise                = return inname
