{-# LANGUAGE CPP #-}
module Jenga.Cabal
  ( dependencyName
  , readPackageDependencies
  ) where

-- You would thing that since the Cabal file exposes its cabal parser you would
-- think it would be a simple matter to extract the list of dependencies.
-- Unfortunately its much more work than it should be. See:
-- https://hackage.haskell.org/package/Cabal-1.24.2.0/docs/Distribution-PackageDescription.html#v:buildDepends

import qualified Data.Map.Strict as DM
import           Data.Text (Text)
import qualified Data.Text as T

import           Distribution.Package (Dependency (..), PackageIdentifier (..), unPackageName)
import           Distribution.PackageDescription
                    ( Benchmark, CondTree (..), ConfVar, Executable, GenericPackageDescription (..)
                    , PackageDescription (..), Library, TestSuite
                    )
#if MIN_VERSION_Cabal (2,0,0)
import           Distribution.PackageDescription.Parse (readGenericPackageDescription)
#else
import           Distribution.PackageDescription.Parse (readPackageDescription)
import           Distribution.Verbosity (Verbosity)
#endif
import           Distribution.Verbosity (normal)

readPackageDependencies :: FilePath -> IO [Dependency]
readPackageDependencies fpath = do
  genpkg <- readGenericPackageDescription normal fpath
  pure
    $ sortNubByName
    $ filterPackageName (package $ packageDescription genpkg)
    $ extractLibraryDeps (condLibrary genpkg)
        ++ extractExecutableDeps (condExecutables genpkg)
        ++ extractTestSuiteDeps (condTestSuites genpkg)
        ++ extractBenchmarkDeps (condBenchmarks genpkg)


sortNubByName :: [Dependency] -> [Dependency]
sortNubByName = fmap toDep . DM.toList . DM.fromList . fmap fromDep
  where
    fromDep (Dependency n v) = (n, v)
    toDep (n, v) = Dependency n v

filterPackageName :: PackageIdentifier -> [Dependency] -> [Dependency]
filterPackageName (PackageIdentifier pname _) =
  filter (\dep -> pname /= packageName dep )
  where
    packageName (Dependency pn _) = pn

dependencyName :: Dependency -> Text
dependencyName (Dependency name _) = T.pack $ unPackageName name


extractLibraryDeps :: Maybe (CondTree ConfVar [Dependency] Library) -> [Dependency]
extractLibraryDeps Nothing = []
extractLibraryDeps (Just x) = condTreeConstraints x

extractExecutableDeps :: [(a, CondTree ConfVar [Dependency] Executable)] -> [Dependency]
extractExecutableDeps = concatMap (condTreeConstraints . snd)

extractTestSuiteDeps :: [(a, CondTree ConfVar [Dependency] TestSuite)] -> [Dependency]
extractTestSuiteDeps = concatMap (condTreeConstraints . snd)

extractBenchmarkDeps :: [(a, CondTree ConfVar [Dependency] Benchmark)] -> [Dependency]
extractBenchmarkDeps = concatMap (condTreeConstraints . snd)

#if MIN_VERSION_Cabal (2,0,0)
#else
readGenericPackageDescription :: Verbosity -> FilePath -> IO GenericPackageDescription
readGenericPackageDescription = readPackageDescription
#endif
