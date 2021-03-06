{-# language BangPatterns #-}
{-# language FlexibleInstances #-}
{-# language LambdaCase #-}
{-# language MagicHash #-}
{-# language RankNTypes #-}
{-# language ScopedTypeVariables #-}
{-# language TypeFamilies #-}
{-# language TypeFamilyDependencies #-}
{-# language UnboxedTuples #-}

-- | The contiguous typeclass parameterises over a contiguous array type.
--   This allows us to have a common API to a number of contiguous
--   array types and their mutable counterparts.
module Data.Primitive.Contiguous
  (
    -- * Accessors
    -- ** Length Information
    size
  , sizeMutable
  , null
    -- ** Indexing
  , index
  , index#
  , read
    -- ** Monadic indexing
  , indexM

    -- * Construction
    -- ** Initialisation
  , empty
  , new
  , singleton
  , doubleton
  , tripleton
  , replicate
  , replicateMutable
  , generate
  , generateM
  , generateMutable
  , iterateN
  , iterateMutableN
  , write
    -- ** Running
  , run
    -- ** Monadic initialisation
  , replicateMutableM
  , generateMutableM
  , iterateMutableNM
  , create
  , createT
    -- ** Unfolding
  , unfoldr
  , unfoldrN
  , unfoldrMutable
    -- ** Enumeration
  , enumFromN
  , enumFromMutableN
    -- ** Concatenation
  , append
    -- ** Splitting and Splicing
  , insertAt
  , insertSlicing
    -- * Modifying arrays
  , replaceAt
  , modifyAt
  , modifyAtF
    -- ** Permutations
  , reverse
  , reverseMutable
  , reverseSlice

    -- ** Resizing
  , resize

    -- * Elementwise operations
    -- ** Mapping
  , map
  , map'
  , mapMutable
  , mapMutable'
  , imap
  , imap'
  , imapMutable
  , imapMutable'
  , modify
  , modify'
  , mapMaybe

    -- ** Zipping
  , zip
  , zipWith
  , izipWith

    -- ** Specific elements
  , swap

    -- * Working with predicates
    -- ** Filtering
  , filter
  , ifilter
  , catMaybes
  , lefts
  , rights
  , partitionEithers
    -- ** Searching
  , find
  , findIndex
  , elem
  , maximum
  , minimum
  , maximumBy
  , minimumBy
    -- ** Comparing for equality
  , equals
  , equalsMutable
  , same

    -- * Folds
  , foldl
  , foldl'
  , foldr
  , foldr'
  , foldMap
  , foldMap'
  , foldlMap'
  , ifoldl'
  , ifoldr'
  , ifoldlMap'
  , ifoldlMap1'
  , foldlM'
  , asum
  , all
  , any
    -- ** Zipping Folds
  , foldrZipWith
  , ifoldrZipWith

    -- * Traversals
  , traverse
  , traverse_
  , itraverse
  , itraverse_
  , traverseP
  , mapM
  , forM
  , mapM_
  , forM_
  , for
  , for_
  , sequence
  , sequence_

    -- * Typeclass method defaults
  , (<$)
  , ap

    -- * Prefix sums (scans)
  , scanl
  , scanl'
  , iscanl
  , iscanl'
  , prescanl
  , prescanl'
  , iprescanl
  , iprescanl'
  --, postscanl
  --, ipostscanl

    -- * Conversions
    -- ** Lists
  , fromList
  , fromListN
  , fromListMutable
  , fromListMutableN
  , unsafeFromListN
  , unsafeFromListReverseN
  , unsafeFromListReverseMutableN
  , toList
  , toListMutable
    -- ** Other array types
  , convert
  , lift
  , unlift
    -- ** Between mutable and immutable variants
  , clone
  , cloneMutable
  , copy
  , copyMutable
  , freeze
  , thaw
  , unsafeFreeze

    -- * Hashing
  , liftHashWithSalt

    -- * Forcing an array and its contents
  , rnf

    -- * Classes
  , Contiguous(Mutable,Element)
  , Always

    -- * Re-Exports
  , Array
  , MutableArray
  , SmallArray
  , SmallMutableArray
  , PrimArray
  , MutablePrimArray
  , UnliftedArray
  , MutableUnliftedArray
  ) where

import Control.Monad.Primitive
import Data.Primitive hiding (fromList,fromListN)
import Data.Primitive.Unlifted.Array
import Prelude hiding (map,all,any,foldr,foldMap,traverse,read,filter,replicate,null,reverse,foldl,foldr,zip,zipWith,scanl,(<$),elem,maximum,minimum,mapM,mapM_,sequence,sequence_)

import Control.Applicative (liftA2)
import Control.DeepSeq (NFData)
import Control.Monad (when)
import Control.Monad.ST (runST,ST)
import Control.Monad.ST.Run (runPrimArrayST,runSmallArrayST,runUnliftedArrayST,runArrayST)
import Data.Bits (xor)
import Data.Coerce (coerce)
import Data.Kind (Type)
import Data.Primitive.Unlifted.Class (PrimUnlifted)
import Data.Semigroup (First(..))
import Data.Word (Word8)
import GHC.Base (build)
import GHC.Exts (MutableArrayArray#,ArrayArray#,Constraint,sizeofByteArray#,sizeofArray#,sizeofArrayArray#,unsafeCoerce#,sameMutableArrayArray#,isTrue#,dataToTag#,Int(..))

import qualified Control.Applicative as A
import qualified Control.DeepSeq as DS
import qualified Prelude

-- | A typeclass that is satisfied by all types. This is used
-- used to provide a fake constraint for 'Array' and 'SmallArray'.
class Always a
instance Always a

-- | The 'Contiguous' typeclass as an interface to a multitude of
--   contiguous structures.
class Contiguous (arr :: Type -> Type) where
  -- | The Mutable counterpart to the array.
  type family Mutable arr = (r :: Type -> Type -> Type) | r -> arr
  -- | The constraint needed to store elements in the array.
  type family Element arr :: Type -> Constraint
  -- | The empty array.
  empty :: arr a
  -- | Test whether the array is empty.
  null :: arr b -> Bool
  -- | Allocate a new mutable array of the given size.
  new :: (PrimMonad m, Element arr b) => Int -> m (Mutable arr (PrimState m) b)
  -- | @'replicateMutable' n x@ is a mutable array of length @n@ with @x@ the value of every element.
  replicateMutable :: (PrimMonad m, Element arr b) => Int -> b -> m (Mutable arr (PrimState m) b)
  -- | Index into an array at the given index.
  index :: Element arr b => arr b -> Int -> b
  -- | Index into an array at the given index, yielding an unboxed one-tuple of the element.
  index# :: Element arr b => arr b -> Int -> (# b #)
  -- | Indexing in a monad.
  --
  --   The monad allows operations to be strict in the array
  --   when necessary. Suppose array copying is implemented like this:
  --
  --   > copy mv v = ... write mv i (v ! i) ...
  --
  --   For lazy arrays, @v ! i@ would not be not be evaluated,
  --   which means that @mv@ would unnecessarily retain a reference
  --   to @v@ in each element written.
  --
  --   With 'indexM', copying can be implemented like this instead:
  --
  --   > copy mv v = ... do
  --   >   x <- indexM v i
  --   >   write mv i x
  --
  --   Here, no references to @v@ are retained because indexing
  --   (but /not/ the elements) is evaluated eagerly.
  indexM :: (Element arr b, Monad m) => arr b -> Int -> m b
  -- | Read a mutable array at the given index.
  read :: (PrimMonad m, Element arr b) => Mutable arr (PrimState m) b -> Int -> m b
  -- | Write to a mutable array at the given index.
  write :: (PrimMonad m, Element arr b) => Mutable arr (PrimState m) b -> Int -> b -> m ()
  -- | Resize an array into one with the given size.
  resize :: (PrimMonad m, Element arr b) => Mutable arr (PrimState m) b -> Int -> m (Mutable arr (PrimState m) b)
  -- | The size of the array
  size :: Element arr b => arr b -> Int
  -- | The size of the mutable array
  sizeMutable :: (PrimMonad m, Element arr b) => Mutable arr (PrimState m) b -> m Int
  -- | Turn a mutable array into an immutable one without copying.
  --   The mutable array should not be used after this conversion.
  unsafeFreeze :: PrimMonad m => Mutable arr (PrimState m) b -> m (arr b)
  -- | Turn a mutable array into an immutable one with copying, using a slice of the mutable array.
  freeze :: (PrimMonad m, Element arr b)
    => Mutable arr (PrimState m) b
    -> Int -- ^ offset into the array
    -> Int -- ^ length of the slice
    -> m (arr b)
  -- | Copy a slice of an immutable array into a new mutable array.
  thaw :: (PrimMonad m, Element arr b)
    => arr b
    -> Int -- ^ offset into the array
    -> Int -- ^ length of the slice
    -> m (Mutable arr (PrimState m) b)
  -- | Copy a slice of an array into a mutable array.
  copy :: (PrimMonad m, Element arr b)
    => Mutable arr (PrimState m) b -- ^ destination array
    -> Int -- ^ offset into destination array
    -> arr b -- ^ source array
    -> Int -- ^ offset into source array
    -> Int -- ^ number of elements to copy
    -> m ()
  -- | Copy a slice of a mutable array into another mutable array.
  --   In the case that the destination and source arrays are the
  --   same, the regions may overlap.
  copyMutable :: (PrimMonad m, Element arr b)
    => Mutable arr (PrimState m) b -- ^ destination array
    -> Int -- ^ offset into destination array
    -> Mutable arr (PrimState m) b -- ^ source array
    -> Int -- ^ offset into source array
    -> Int -- ^ number of elements to copy
    -> m ()
  -- | Clone a slice of an array.
  clone :: Element arr b
    => arr b -- ^ Array to copy a slice of
    -> Int -- ^ Offset into the array
    -> Int -- ^ Length of the slice
    -> arr b
  -- | Clone a slice of a mutable array.
  cloneMutable :: (PrimMonad m, Element arr b)
    => Mutable arr (PrimState m) b -- ^ Array to copy a slice of
    -> Int -- ^ Offset into the array
    -> Int -- ^ Length of the slice
    -> m (Mutable arr (PrimState m) b)
  -- | Copy a slice of an array an then insert an element into that array.
  --
  -- The default implementation performs a memset which would be unnecessary
  -- except that the garbage collector might trace the uninitialized array.
  insertSlicing :: Element arr b
    => arr b -- ^ array to copy a slice from
    -> Int -- ^ offset into source array
    -> Int -- ^ length of the slice
    -> Int -- ^ index in the output array to insert at
    -> b -- ^ element to insert
    -> arr b
  insertSlicing src off len0 i x = run $ do
    dst <- replicateMutable (len0 + 1) x
    copy dst 0 src off i
    copy dst (i + 1) src (off + i) (len0 - i)
    unsafeFreeze dst
  {-# inline insertSlicing #-}
  -- | Test the two arrays for equality.
  equals :: (Element arr b, Eq b) => arr b -> arr b -> Bool
  -- | Test the two mutable arrays for pointer equality.
  --   Does not check equality of elements.
  equalsMutable :: Mutable arr s a -> Mutable arr s a -> Bool
  -- | Unlift an array into an 'ArrayArray#'.
  unlift :: arr b -> ArrayArray#
  -- | Lift an 'ArrayArray#' into an array.
  lift :: ArrayArray# -> arr b
  -- | Create a singleton array.
  singleton :: Element arr a => a -> arr a
  -- | Create a doubleton array.
  doubleton :: Element arr a => a -> a -> arr a
  -- | Create a tripleton array.
  tripleton :: Element arr a => a -> a -> a -> arr a
  -- | Reduce the array and all of its elements to WHNF.
  rnf :: (NFData a, Element arr a) => arr a -> ()
  -- | Run an effectful computation that produces an array.
  run :: (forall s. ST s (arr a)) -> arr a

instance Contiguous SmallArray where
  type Mutable SmallArray = SmallMutableArray
  type Element SmallArray = Always
  empty = mempty
  new n = newSmallArray n errorThunk
  index = indexSmallArray
  indexM = indexSmallArrayM
  index# = indexSmallArray##
  read = readSmallArray
  write = writeSmallArray
  null a = case sizeofSmallArray a of
    0 -> True
    _ -> False
  freeze = freezeSmallArray
  size = sizeofSmallArray
  sizeMutable = (\x -> pure $! sizeofSmallMutableArray x)
  unsafeFreeze = unsafeFreezeSmallArray
  thaw = thawSmallArray
  equals = (==)
  equalsMutable = (==)
  singleton a = runST $ do
    marr <- newSmallArray 1 errorThunk
    writeSmallArray marr 0 a
    unsafeFreezeSmallArray marr
  doubleton a b = runST $ do
    m <- newSmallArray 2 errorThunk
    writeSmallArray m 0 a
    writeSmallArray m 1 b
    unsafeFreezeSmallArray m
  tripleton a b c = runST $ do
    m <- newSmallArray 3 errorThunk
    writeSmallArray m 0 a
    writeSmallArray m 1 b
    writeSmallArray m 2 c
    unsafeFreezeSmallArray m
  rnf !ary =
    let !sz = sizeofSmallArray ary
        go !ix = if ix < sz
          then
            let !(# x #) = indexSmallArray## ary ix
             in DS.rnf x `seq` go (ix + 1)
          else ()
     in go 0
  clone = cloneSmallArray
  cloneMutable = cloneSmallMutableArray
  lift x = SmallArray (unsafeCoerce# x)
  unlift (SmallArray x) = unsafeCoerce# x
  copy = copySmallArray
  copyMutable = copySmallMutableArray
  replicateMutable = replicateSmallMutableArray
  resize = resizeSmallArray
  run = runSmallArrayST
  {-# inline empty #-}
  {-# inline null #-}
  {-# inline new #-}
  {-# inline replicateMutable #-}
  {-# inline index #-}
  {-# inline index# #-}
  {-# inline indexM #-}
  {-# inline read #-}
  {-# inline write #-}
  {-# inline resize #-}
  {-# inline size #-}
  {-# inline sizeMutable #-}
  {-# inline unsafeFreeze #-}
  {-# inline freeze #-}
  {-# inline thaw #-}
  {-# inline copy #-}
  {-# inline copyMutable #-}
  {-# inline clone #-}
  {-# inline cloneMutable #-}
  {-# inline equals #-}
  {-# inline equalsMutable #-}
  {-# inline unlift #-}
  {-# inline lift #-}
  {-# inline singleton #-}
  {-# inline doubleton #-}
  {-# inline tripleton #-}
  {-# inline rnf #-}
  {-# inline run #-}

instance Contiguous PrimArray where
  type Mutable PrimArray = MutablePrimArray
  type Element PrimArray = Prim
  empty = mempty
  new = newPrimArray
  replicateMutable = replicateMutablePrimArray
  index = indexPrimArray
  index# arr ix = (# indexPrimArray arr ix #)
  indexM arr ix = pure (indexPrimArray arr ix)
  read = readPrimArray
  write = writePrimArray
  resize = resizeMutablePrimArray
  size = sizeofPrimArray
  sizeMutable = getSizeofMutablePrimArray
  freeze = freezePrimArrayShim
  unsafeFreeze = unsafeFreezePrimArray
  thaw = thawPrimArray
  copy = copyPrimArray
  copyMutable = copyMutablePrimArray
  clone = clonePrimArrayShim
  cloneMutable = cloneMutablePrimArrayShim
  equals = (==)
  unlift (PrimArray x) = unsafeCoerce# x
  lift x = PrimArray (unsafeCoerce# x)
  null (PrimArray a) = case sizeofByteArray# a of
    0# -> True
    _ -> False
  equalsMutable = sameMutablePrimArray
  rnf (PrimArray !_) = ()
  singleton a = runPrimArrayST $ do
    marr <- newPrimArray 1
    writePrimArray marr 0 a
    unsafeFreezePrimArray marr
  doubleton a b = runPrimArrayST $ do
    m <- newPrimArray 2
    writePrimArray m 0 a
    writePrimArray m 1 b
    unsafeFreezePrimArray m
  tripleton a b c = runPrimArrayST $ do
    m <- newPrimArray 3
    writePrimArray m 0 a
    writePrimArray m 1 b
    writePrimArray m 2 c
    unsafeFreezePrimArray m
  insertSlicing src off len0 i x = runPrimArrayST $ do
    dst <- new (len0 + 1)
    copy dst 0 src off i
    write dst i x
    copy dst (i + 1) src (off + i) (len0 - i)
    unsafeFreeze dst
  run = runPrimArrayST
  {-# inline empty #-}
  {-# inline null #-}
  {-# inline new #-}
  {-# inline replicateMutable #-}
  {-# inline index #-}
  {-# inline index# #-}
  {-# inline indexM #-}
  {-# inline read #-}
  {-# inline write #-}
  {-# inline resize #-}
  {-# inline size #-}
  {-# inline sizeMutable #-}
  {-# inline unsafeFreeze #-}
  {-# inline freeze #-}
  {-# inline thaw #-}
  {-# inline copy #-}
  {-# inline copyMutable #-}
  {-# inline clone #-}
  {-# inline cloneMutable #-}
  {-# inline insertSlicing #-}
  {-# inline equals #-}
  {-# inline equalsMutable #-}
  {-# inline unlift #-}
  {-# inline lift #-}
  {-# inline singleton #-}
  {-# inline doubleton #-}
  {-# inline tripleton #-}
  {-# inline rnf #-}
  {-# inline run #-}

instance Contiguous Array where
  type Mutable Array = MutableArray
  type Element Array = Always
  empty = mempty
  new n = newArray n errorThunk
  replicateMutable = newArray
  index = indexArray
  index# = indexArray##
  indexM = indexArrayM
  read = readArray
  write = writeArray
  resize = resizeArray
  size = sizeofArray
  sizeMutable = (\x -> pure $! sizeofMutableArray x)
  freeze = freezeArray
  unsafeFreeze = unsafeFreezeArray
  thaw = thawArray
  copy = copyArray
  copyMutable = copyMutableArray
  clone = cloneArray
  cloneMutable = cloneMutableArray
  equals = (==)
  unlift (Array x) = unsafeCoerce# x
  lift x = Array (unsafeCoerce# x)
  null (Array a) = case sizeofArray# a of
    0# -> True
    _ -> False
  equalsMutable = sameMutableArray
  rnf !ary =
    let !sz = sizeofArray ary
        go !i
          | i == sz = ()
          | otherwise =
              let !(# x #) = indexArray## ary i
               in DS.rnf x `seq` go (i+1)
     in go 0
  singleton a = runArrayST (newArray 1 a >>= unsafeFreezeArray)
  doubleton a b = runArrayST $ do
    m <- newArray 2 a
    writeArray m 1 b
    unsafeFreezeArray m
  tripleton a b c = runArrayST $ do
    m <- newArray 3 a
    writeArray m 1 b
    writeArray m 2 c
    unsafeFreezeArray m
  run = runArrayST
  {-# inline empty #-}
  {-# inline null #-}
  {-# inline new #-}
  {-# inline replicateMutable #-}
  {-# inline index #-}
  {-# inline index# #-}
  {-# inline indexM #-}
  {-# inline read #-}
  {-# inline write #-}
  {-# inline resize #-}
  {-# inline size #-}
  {-# inline sizeMutable #-}
  {-# inline unsafeFreeze #-}
  {-# inline freeze #-}
  {-# inline thaw #-}
  {-# inline copy #-}
  {-# inline copyMutable #-}
  {-# inline clone #-}
  {-# inline cloneMutable #-}
  {-# inline equals #-}
  {-# inline equalsMutable #-}
  {-# inline unlift #-}
  {-# inline lift #-}
  {-# inline singleton #-}
  {-# inline doubleton #-}
  {-# inline tripleton #-}
  {-# inline rnf #-}
  {-# inline run #-}

instance Contiguous UnliftedArray where
  type Mutable UnliftedArray = MutableUnliftedArray
  type Element UnliftedArray = PrimUnlifted
  empty = emptyUnliftedArray
  new = unsafeNewUnliftedArray
  replicateMutable = newUnliftedArray
  index = indexUnliftedArray
  index# arr ix = (# indexUnliftedArray arr ix #)
  indexM arr ix = pure (indexUnliftedArray arr ix)
  read = readUnliftedArray
  write = writeUnliftedArray
  resize = resizeUnliftedArray
  size = sizeofUnliftedArray
  sizeMutable = pure . sizeofMutableUnliftedArray
  freeze = freezeUnliftedArray
  unsafeFreeze = unsafeFreezeUnliftedArray
  thaw = thawUnliftedArray
  copy = copyUnliftedArray
  copyMutable = copyMutableUnliftedArray
  clone = cloneUnliftedArray
  cloneMutable = cloneMutableUnliftedArray
  equals = (==)
  unlift (UnliftedArray x) = x
  lift x = UnliftedArray x
  null (UnliftedArray a) = case sizeofArrayArray# a of
    0# -> True
    _ -> False
  equalsMutable = sameMutableUnliftedArray
  rnf !ary =
    let !sz = sizeofUnliftedArray ary
        go !i
          | i == sz = ()
          | otherwise =
              let x = indexUnliftedArray ary i
               in DS.rnf x `seq` go (i+1)
     in go 0
  singleton a = runUnliftedArrayST (newUnliftedArray 1 a >>= unsafeFreezeUnliftedArray)
  doubleton a b = runUnliftedArrayST $ do
    m <- newUnliftedArray 2 a
    writeUnliftedArray m 1 b
    unsafeFreezeUnliftedArray m
  tripleton a b c = runUnliftedArrayST $ do
    m <- newUnliftedArray 3 a
    writeUnliftedArray m 1 b
    writeUnliftedArray m 2 c
    unsafeFreezeUnliftedArray m
  run = runUnliftedArrayST
  {-# inline empty #-}
  {-# inline null #-}
  {-# inline new #-}
  {-# inline replicateMutable #-}
  {-# inline index #-}
  {-# inline index# #-}
  {-# inline indexM #-}
  {-# inline read #-}
  {-# inline write #-}
  {-# inline resize #-}
  {-# inline size #-}
  {-# inline sizeMutable #-}
  {-# inline unsafeFreeze #-}
  {-# inline freeze #-}
  {-# inline thaw #-}
  {-# inline copy #-}
  {-# inline copyMutable #-}
  {-# inline clone #-}
  {-# inline cloneMutable #-}
  {-# inline equals #-}
  {-# inline equalsMutable #-}
  {-# inline unlift #-}
  {-# inline lift #-}
  {-# inline singleton #-}
  {-# inline doubleton #-}
  {-# inline tripleton #-}
  {-# inline rnf #-}
  {-# inline run #-}

errorThunk :: a
errorThunk = error "Contiguous typeclass: unitialized element"
{-# noinline errorThunk #-}

freezePrimArrayShim :: (PrimMonad m, Prim a) => MutablePrimArray (PrimState m) a -> Int -> Int -> m (PrimArray a)
freezePrimArrayShim !src !off !len = do
  dst <- newPrimArray len
  copyMutablePrimArray dst 0 src off len
  unsafeFreezePrimArray dst
{-# inline freezePrimArrayShim #-}

resizeArray :: PrimMonad m => MutableArray (PrimState m) a -> Int -> m (MutableArray (PrimState m) a)
resizeArray !src !sz = do
  dst <- newArray sz errorThunk
  copyMutableArray dst 0 src 0 (min sz (sizeofMutableArray src))
  pure dst
{-# inline resizeArray #-}

resizeSmallArray :: PrimMonad m => SmallMutableArray (PrimState m) a -> Int -> m (SmallMutableArray (PrimState m) a)
resizeSmallArray !src !sz = do
  dst <- newSmallArray sz errorThunk
  copySmallMutableArray dst 0 src 0 (min sz (sizeofSmallMutableArray src))
  pure dst
{-# inline resizeSmallArray #-}

resizeUnliftedArray :: (PrimMonad m, PrimUnlifted a) => MutableUnliftedArray (PrimState m) a -> Int -> m (MutableUnliftedArray (PrimState m) a)
resizeUnliftedArray !src !sz = do
  dst <- unsafeNewUnliftedArray sz
  copyMutableUnliftedArray dst 0 src 0 (min sz (sizeofMutableUnliftedArray src))
  pure dst
{-# inline resizeUnliftedArray #-}

-- | Append two arrays.
append :: (Contiguous arr, Element arr a) => arr a -> arr a -> arr a
append !a !b = run $ do
  let !szA = size a
  let !szB = size b
  m <- new (szA + szB)
  copy m 0 a 0 szA
  copy m szA b 0 szB
  unsafeFreeze m
{-# inline append #-}

-- | Insert an element into an array at the given index.
insertAt :: (Contiguous arr, Element arr a) => arr a -> Int -> a -> arr a
insertAt src i x = insertSlicing src 0 (size src) i x

-- | Create a copy of an array except the element at the index is replaced with
--   the given value.
replaceAt :: (Contiguous arr, Element arr a) => arr a -> Int -> a -> arr a
replaceAt src i x = create $ do
  dst <- thaw src 0 (size src)
  write dst i x
  pure dst
{-# inline replaceAt #-}

modifyAt :: (Contiguous arr, Element arr a)
  => (a -> a) -> arr a -> Int -> arr a
modifyAt f src i = replaceAt src i $ f (index src i)
{-# inline modifyAt #-}

modifyAtF :: (Contiguous arr, Element arr a, Functor f)
  => (a -> f a) -> arr a -> Int -> f (arr a)
modifyAtF f src i = replaceAt src i <$> f (index src i)
{-# inline modifyAtF #-}

-- | Map over the elements of an array with the index.
imap :: (Contiguous arr1, Element arr1 b, Contiguous arr2, Element arr2 c) => (Int -> b -> c) -> arr1 b -> arr2 c
imap f a = run $ do
  mb <- new (size a)
  let go !i
        | i == size a = pure ()
        | otherwise = do
            x <- indexM a i
            write mb i (f i x)
            go (i+1)
  go 0
  unsafeFreeze mb
{-# inline imap #-}

-- | Map strictly over the elements of an array with the index.
--
--   Note that because a new array must be created, the resulting
--   array type can be /different/ than the original.
imap' :: (Contiguous arr1, Element arr1 b, Contiguous arr2, Element arr2 c) => (Int -> b -> c) -> arr1 b -> arr2 c
imap' f a = run $ do
  mb <- new (size a)
  let go !i
        | i == size a = pure ()
        | otherwise = do
            x <- indexM a i
            let !b = f i x
            write mb i b
            go (i + 1)
  go 0
  unsafeFreeze mb
{-# inline imap' #-}

-- | Map over the elements of an array.
--
--   Note that because a new array must be created, the resulting
--   array type can be /different/ than the original.
map :: (Contiguous arr1, Element arr1 b, Contiguous arr2, Element arr2 c) => (b -> c) -> arr1 b -> arr2 c
map f a = run $ do
  mb <- new (size a)
  let go !i
        | i == size a = pure ()
        | otherwise = do
            x <- indexM a i
            write mb i (f x)
            go (i+1)
  go 0
  unsafeFreeze mb
{-# inline map #-}

-- | Map strictly over the elements of an array.
--
--   Note that because a new array must be created, the resulting
--   array type can be /different/ than the original.
map' :: (Contiguous arr1, Element arr1 b, Contiguous arr2, Element arr2 c) => (b -> c) -> arr1 b -> arr2 c
map' f a = run $ do
  mb <- new (size a)
  let go !i
        | i == size a = pure ()
        | otherwise = do
            x <- indexM a i
            let !b = f x
            write mb i b
            go (i+1)
  go 0
  unsafeFreeze mb
{-# inline map' #-}

-- | Convert one type of array into another.
convert :: (Contiguous arr1, Element arr1 b, Contiguous arr2, Element arr2 b) => arr1 b -> arr2 b
convert a = map id a
{-# inline convert #-}

-- | Right fold over the element of an array.
foldr :: (Contiguous arr, Element arr a) => (a -> b -> b) -> b -> arr a -> b
{-# inline foldr #-}
foldr f z = \arr ->
  let !sz = size arr
      go !ix = if sz > ix
        then case index# arr ix of
          (# x #) -> f x (go (ix + 1))
        else z
  in go 0

-- | Strict right fold over the elements of an array.
foldr' :: (Contiguous arr, Element arr a) => (a -> b -> b) -> b -> arr a -> b
foldr' f !z = \arr ->
  let go !ix !acc = if ix == -1
        then acc
        else case index# arr ix of
          (# x #) -> go (ix - 1) (f x acc)
  in go (size arr - 1) z
{-# inline foldr' #-}

-- | Left fold over the elements of an array.
foldl :: (Contiguous arr, Element arr a) => (b -> a -> b) -> b -> arr a -> b
foldl f z = \arr ->
  let !sz = size arr
      go !ix acc = if ix == sz
        then acc
        else case index# arr ix of
          (# x #) -> go (ix + 1) (f acc x)
  in go 0 z
{-# inline foldl #-}

-- | Strict left fold over the elements of an array.
foldl' :: (Contiguous arr, Element arr a) => (b -> a -> b) -> b -> arr a -> b
foldl' f !z = \arr ->
  let !sz = size arr
      go !ix !acc = if ix == sz
        then acc
        else case index# arr ix of
          (# x #) -> go (ix + 1) (f acc x)
  in go 0 z
{-# inline foldl' #-}

-- | Strict left fold over the elements of an array, where the accumulating
--   function cares about the index of the element.
ifoldl' :: (Contiguous arr, Element arr a) => (b -> Int -> a -> b) -> b -> arr a -> b
ifoldl' f !z = \arr ->
  let !sz = size arr
      go !ix !acc = if ix == sz
        then acc
        else case index# arr ix of
          (# x #) -> go (ix + 1) (f acc ix x)
  in go 0 z
{-# inline ifoldl' #-}

-- | Strict right fold over the elements of an array, where the accumulating
--   function cares about the index of the element.
ifoldr' :: (Contiguous arr, Element arr a) => (Int -> a -> b -> b) -> b -> arr a -> b
ifoldr' f !z = \arr ->
  let !sz = size arr
      go !ix !acc = if ix == (-1)
        then acc
        else case index# arr ix of
          (# x #) -> go (ix - 1) (f ix x acc)
  in go (sz - 1) z
{-# inline ifoldr' #-}

-- | Monoidal fold over the element of an array.
foldMap :: (Contiguous arr, Element arr a, Monoid m) => (a -> m) -> arr a -> m
foldMap f = \arr ->
  let !sz = size arr
      go !ix = if sz > ix
        then case index# arr ix of
          (# x #) -> mappend (f x) (go (ix + 1))
        else mempty
  in go 0
{-# inline foldMap #-}

-- | Strict monoidal fold over the elements of an array.
foldMap' :: (Contiguous arr, Element arr a, Monoid m)
  => (a -> m) -> arr a -> m
foldMap' f = \arr ->
  let !sz = size arr
      go !ix !acc = if ix == sz
        then acc
        else case index# arr ix
          of (# x #) -> go (ix + 1) (mappend acc (f x))
  in go 0 mempty
{-# inline foldMap' #-}

-- | Strict left monoidal fold over the elements of an array.
foldlMap' :: (Contiguous arr, Element arr a, Monoid m)
  => (a -> m) -> arr a -> m
foldlMap' = foldMap'
{-# inline foldlMap' #-}

-- | Strict monoidal fold over the elements of an array.
ifoldlMap' :: (Contiguous arr, Element arr a, Monoid m)
  => (Int -> a -> m)
  -> arr a
  -> m
ifoldlMap' f = \arr ->
  let !sz = size arr
      go !ix !acc = if ix == sz
        then acc
        else case index# arr ix of
          (# x #) -> go (ix + 1) (mappend acc (f ix x))
  in go 0 mempty
{-# inline ifoldlMap' #-}

-- | Strict monoidal fold over the elements of an array.
ifoldlMap1' :: (Contiguous arr, Element arr a, Semigroup m)
  => (Int -> a -> m)
  -> arr a
  -> m
ifoldlMap1' f = \arr ->
  let !sz = size arr
      go !ix !acc = if ix == sz
        then acc
        else case index# arr ix of
          (# x #) -> go (ix + 1) (acc <> f ix x)
      !(# e0 #) = index# arr 0
  in go 1 (f 0 e0)
{-# inline ifoldlMap1' #-}

-- | Strict left monadic fold over the elements of an array.
foldlM' :: (Contiguous arr, Element arr a, Monad m) => (b -> a -> m b) -> b -> arr a -> m b
foldlM' f z0 = \arr ->
  let !sz = size arr
      go !ix !acc1 = if ix < sz
        then do
          let (# x #) = index# arr ix
          acc2 <- f acc1 x
          go (ix + 1) acc2
        else pure acc1
  in go 0 z0
{-# inline foldlM' #-}

-- | Drop elements that do not satisfy the predicate.
filter :: (Contiguous arr, Element arr a)
  => (a -> Bool)
  -> arr a
  -> arr a
filter p arr = ifilter (const p) arr
{-# inline filter #-}

-- | Drop elements that do not satisfy the predicate which
--   is applied to values and their indices.
ifilter :: (Contiguous arr, Element arr a)
  => (Int -> a -> Bool)
  -> arr a
  -> arr a
ifilter p arr = run $ do
  marr :: MutablePrimArray s Word8 <- newPrimArray sz
  let go1 :: Int -> Int -> ST s Int
      go1 !ix !numTrue = if ix < sz
        then do
          atIx <- indexM arr ix
          let !keep = p ix atIx
          let !keepTag = I# (dataToTag# keep)
          writePrimArray marr ix (fromIntegral keepTag)
          go1 (ix + 1) (numTrue + keepTag)
        else pure numTrue
  numTrue <- go1 0 0
  if numTrue == sz
    then pure arr
    else do
      marrTrues <- new numTrue
      let go2 !ixSrc !ixDst = when (ixDst < numTrue) $ do
            atIxKeep <- readPrimArray marr ixSrc
            if isTrue atIxKeep
              then do
                atIxVal <- indexM arr ixSrc
                write marrTrues ixDst atIxVal
                go2 (ixSrc + 1) (ixDst + 1)
              else go2 (ixSrc + 1) ixDst
      go2 0 0
      unsafeFreeze marrTrues
  where
    !sz = size arr
{-# inline ifilter #-}

-- | The 'mapMaybe' function is a version of 'map' which can throw out elements.
--   In particular, the functional arguments returns something of type @'Maybe' b@.
--   If this is 'Nothing', no element is added on to the result array. If it is
--   @'Just' b@, then @b@ is included in the result array.
mapMaybe :: forall arr1 arr2 a b. (Contiguous arr1, Element arr1 a, Contiguous arr2, Element arr2 b)
  => (a -> Maybe b)
  -> arr1 a
  -> arr2 b
mapMaybe f arr = run $ do
  let !sz = size arr
  let go :: Int -> Int -> [b] -> ST s ([b],Int)
      go !ix !numJusts justs = if ix < sz
        then do
          atIx <- indexM arr ix
          case f atIx of
            Nothing -> go (ix+1) numJusts justs
            Just x -> go (ix+1) (numJusts+1) (x:justs)
        else pure (justs,numJusts)
  !(bs,!numJusts) <- go 0 0 []
  !marr <- unsafeFromListReverseMutableN numJusts bs
  unsafeFreeze marr
{-# inline mapMaybe #-}

{-# inline isTrue #-}
isTrue :: Word8 -> Bool
isTrue 0 = False
isTrue _ = True

-- | The 'catMaybes' function takes a list of 'Maybe's and returns a
--   list of all the 'Just' values.
catMaybes :: (Contiguous arr, Element arr a, Element arr (Maybe a))
  => arr (Maybe a)
  -> arr a
catMaybes = mapMaybe id
{-# inline catMaybes #-}

thawPrimArray :: (PrimMonad m, Prim a) => PrimArray a -> Int -> Int -> m (MutablePrimArray (PrimState m) a)
thawPrimArray !arr !off !len = do
  marr <- newPrimArray len
  copyPrimArray marr 0 arr off len
  pure marr
{-# inline thawPrimArray #-}

clonePrimArrayShim :: Prim a => PrimArray a -> Int -> Int -> PrimArray a
clonePrimArrayShim !arr !off !len = runPrimArrayST $ do
  marr <- newPrimArray len
  copyPrimArray marr 0 arr off len
  unsafeFreezePrimArray marr
{-# inline clonePrimArrayShim #-}

cloneMutablePrimArrayShim :: (PrimMonad m, Prim a) => MutablePrimArray (PrimState m) a -> Int -> Int -> m (MutablePrimArray (PrimState m) a)
cloneMutablePrimArrayShim !arr !off !len = do
  marr <- newPrimArray len
  copyMutablePrimArray marr 0 arr off len
  pure marr
{-# inline cloneMutablePrimArrayShim #-}

-- | @'replicate' n x@ is an array of length @n@ with @x@ the value of every element.
replicate :: (Contiguous arr, Element arr a) => Int -> a -> arr a
replicate n x = create (replicateMutable n x)
{-# inline replicate #-}

-- | @'replicateMutableM' n act@ performs the action n times, gathering the results.
replicateMutableM :: (PrimMonad m, Contiguous arr, Element arr a)
  => Int
  -> m a
  -> m (Mutable arr (PrimState m) a)
replicateMutableM len act = do
  marr <- new len
  let go !ix = when (ix < len) $ do
        x <- act
        write marr ix x
        go (ix + 1)
  go 0
  pure marr
{-# inline replicateMutableM #-}

replicateMutablePrimArray :: (PrimMonad m, Prim a)
  => Int -- ^ length
  -> a -- ^ element
  -> m (MutablePrimArray (PrimState m) a)
replicateMutablePrimArray len a = do
  marr <- newPrimArray len
  setPrimArray marr 0 len a
  pure marr
{-# inline replicateMutablePrimArray #-}

replicateSmallMutableArray :: (PrimMonad m)
  => Int
  -> a
  -> m (SmallMutableArray (PrimState m) a)
replicateSmallMutableArray len a = do
  marr <- newSmallArray len errorThunk
  let go !ix = when (ix < len) $ do
        writeSmallArray marr ix a
        go (ix + 1)
  go 0
  pure marr
{-# inline replicateSmallMutableArray #-}

-- | Create an array from a list. If the given length does
-- not match the actual length, this function has undefined
-- behavior.
unsafeFromListN :: (Contiguous arr, Element arr a)
  => Int -- ^ length of list
  -> [a] -- ^ list
  -> arr a
unsafeFromListN n l = create (unsafeFromListMutableN n l)
{-# inline unsafeFromListN #-}

unsafeFromListMutableN :: (Contiguous arr, Element arr a, PrimMonad m)
  => Int
  -> [a]
  -> m (Mutable arr (PrimState m) a)
unsafeFromListMutableN n l = do
  m <- new n
  let go !_ [] = pure m
      go !ix (x : xs) = do
        write m ix x
        go (ix+1) xs
  go 0 l
{-# inline unsafeFromListMutableN #-}

-- | Create a mutable array from a list, reversing the order of
--   the elements. If the given length does not match the actual length,
--   this function has undefined behavior.
unsafeFromListReverseMutableN :: (Contiguous arr, Element arr a, PrimMonad m)
  => Int
  -> [a]
  -> m (Mutable arr (PrimState m) a)
unsafeFromListReverseMutableN n l = do
  m <- new n
  let go !_ [] = pure m
      go !ix (x : xs) = do
        write m ix x
        go (ix-1) xs
  go (n - 1) l
{-# inline unsafeFromListReverseMutableN #-}

-- | Create an array from a list, reversing the order of the
-- elements. If the given length does not match the actual length,
-- this function has undefined behavior.
unsafeFromListReverseN :: (Contiguous arr, Element arr a)
  => Int
  -> [a]
  -> arr a
unsafeFromListReverseN n l = create (unsafeFromListReverseMutableN n l)
{-# inline unsafeFromListReverseN #-}

-- | Map over a mutable array, modifying the elements in place.
mapMutable :: (Contiguous arr, Element arr a, PrimMonad m)
  => (a -> a)
  -> Mutable arr (PrimState m) a
  -> m ()
mapMutable f !marr = do
  !sz <- sizeMutable marr
  let go !ix = when (ix < sz) $ do
        a <- read marr ix
        write marr ix (f a)
        go (ix + 1)
  go 0
{-# inline mapMutable #-}

-- | Strictly map over a mutable array, modifying the elements in place.
mapMutable' :: (PrimMonad m, Contiguous arr, Element arr a)
  => (a -> a)
  -> Mutable arr (PrimState m) a
  -> m ()
mapMutable' f !marr = do
  !sz <- sizeMutable marr
  let go !ix = when (ix < sz) $ do
        a <- read marr ix
        let !b = f a
        write marr ix b
        go (ix + 1)
  go 0
{-# inline mapMutable' #-}

-- | Map over a mutable array with indices, modifying the elements in place.
imapMutable :: (Contiguous arr, Element arr a, PrimMonad m)
  => (Int -> a -> a)
  -> Mutable arr (PrimState m) a
  -> m ()
imapMutable f !marr = do
  !sz <- sizeMutable marr
  let go !ix = when (ix < sz) $ do
        a <- read marr ix
        write marr ix (f ix a)
        go (ix + 1)
  go 0
{-# inline imapMutable #-}

-- | Strictly map over a mutable array with indices, modifying the elements in place.
imapMutable' :: (PrimMonad m, Contiguous arr, Element arr a)
  => (Int -> a -> a)
  -> Mutable arr (PrimState m) a
  -> m ()
imapMutable' f !marr = do
  !sz <- sizeMutable marr
  let go !ix = when (ix < sz) $ do
        a <- read marr ix
        let !b = f ix a
        write marr ix b
        go (ix + 1)
  go 0
{-# inline imapMutable' #-}

-- | Map each element of the array to an action, evaluate these
--   actions from left to right, and collect the results in a
--   new array.
traverseP :: (PrimMonad m, Contiguous arr1, Contiguous arr2, Element arr1 a, Element arr2 b)
  => (a -> m b)
  -> arr1 a
  -> m (arr2 b)
traverseP f !arr = do
  let !sz = size arr
  !marr <- new sz
  let go !ix = when (ix < sz) $ do
        a <- indexM arr ix
        b <- f a
        write marr ix b
        go (ix + 1)
  go 0
  unsafeFreeze marr
{-# inline traverseP #-}

newtype STA v a = STA {_runSTA :: forall s. Mutable v s a -> ST s (v a)}

runSTA :: (Contiguous v, Element v a) => Int -> STA v a -> v a
runSTA !sz (STA m) = runST $ new sz >>= m
{-# inline runSTA #-}

-- | Map each element of the array to an action, evaluate these
--   actions from left to right, and collect the results.
--   For a version that ignores the results, see 'traverse_'.
traverse ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  , Applicative f
  )
  => (a -> f b)
  -> arr1 a
  -> f (arr2 b)
traverse f = itraverse (const f)
{-# inline traverse #-}

-- | Map each element of the array to an action, evaluate these
--   actions from left to right, and ignore the results.
--   For a version that doesn't ignore the results, see 'traverse'.
traverse_ ::
     (Contiguous arr, Element arr a, Applicative f)
  => (a -> f b)
  -> arr a
  -> f ()
traverse_ f = itraverse_ (const f)

-- | Map each element of the array and its index to an action,
--   evaluating these actions from left to right.
itraverse ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  , Applicative f
  )
  => (Int -> a -> f b)
  -> arr1 a
  -> f (arr2 b)
itraverse f = \arr ->
  let !sz = size arr
      go !ix = if ix == sz
        then pure (STA unsafeFreeze)
        else case index# arr ix of
          (# x #) -> liftA2
            (\b (STA m) -> STA $ \marr -> do
              write marr ix b
              m marr
            )
            (f ix x)
            (go (ix + 1))
  in if sz == 0
    then pure empty
    else runSTA sz <$> go 0
{-# inline itraverse #-}

-- | Map each element of the array and its index to an action,
--   evaluate these actions from left to right, and ignore the results.
--   For a version that doesn't ignore the results, see 'itraverse'.
itraverse_ ::
     (Contiguous arr, Element arr a, Applicative f)
  => (Int -> a -> f b)
  -> arr a
  -> f ()
itraverse_ f = \arr ->
  let !sz = size arr
      go !ix = when (ix < sz) $
        f ix (index arr ix) *> go (ix + 1)
  in go 0
{-# inline itraverse_ #-}

-- | 'for' is 'traverse' with its arguments flipped. For a version
--   that ignores the results see 'for_'.
for ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  , Applicative f
  )
  => arr1 a
  -> (a -> f b)
  -> f (arr2 b)
for = flip traverse
{-# inline for #-}

-- | 'for_' is 'traverse_' with its arguments flipped. For a version
--   that doesn't ignore the results see 'for'.
--
--   >>> for_ (C.fromList [1..4] :: PrimArray Int) print
--   1
--   2
--   3
--   4
for_ :: (Contiguous arr, Element arr a, Applicative f)
  => arr a
  -> (a -> f b)
  -> f ()
for_ = flip traverse_
{-# inline for_ #-}

-- | Map each element of a structure to a monadic action,
--   evaluate these actions from left to right, and collect
--   the results. for a version that ignores the results see
--   'mapM_'.
mapM ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  , Monad m
  ) => (a -> m b)
    -> arr1 a
    -> m (arr2 b)
mapM f arr =
  let !sz = size arr
  in generateM sz $ \ix -> indexM arr ix >>= f
{-# inline mapM #-}

-- | Map each element of a structure to a monadic action,
--   evaluate these actions from left to right, and ignore
--   the results. For a version that doesn't ignore the results
--   see 'mapM'.
--
--   'mapM_' = 'traverse_'
mapM_ :: (Contiguous arr, Element arr a, Element arr b, Applicative f)
  => (a -> f b)
  -> arr a
  -> f ()
mapM_ = traverse_
{-# inline mapM_ #-}

-- | 'forM' is 'mapM' with its arguments flipped. For a version that
--   ignores its results, see 'forM_'.
forM ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  , Monad m
  ) => arr1 a
    -> (a -> m b)
    -> m (arr2 b)
forM = flip mapM
{-# inline forM #-}

-- | 'forM_' is 'mapM_' with its arguments flipped. For a version that
--   doesn't ignore its results, see 'forM'.
forM_ :: (Contiguous arr, Element arr a, Element arr b, Applicative f)
  => (a -> f b)
  -> arr a
  -> f ()
forM_ = traverse_
{-# inline forM_ #-}

-- | Evaluate each action in the structure from left to right
--   and collect the results. For a version that ignores the
--   results see 'sequence_'.
sequence ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 (f a)
  , Element arr2 a
  , Applicative f
  ) => arr1 (f a) -> f (arr2 a)
sequence = traverse id
{-# inline sequence #-}

-- | Evaluate each action in the structure from left to right
--   and ignore the results. For a version that doesn't ignore
--   the results see 'sequence'.
sequence_ ::
  ( Contiguous arr
  , Element arr (f a)
  , Applicative f
  ) => arr (f a) -> f ()
sequence_ = foldr (*>) (pure ())
{-# inline sequence_ #-}

-- | The sum of a collection of actions, generalizing 'concat'.
--
--   >>> asum (C.fromList ['Just' "Hello", 'Nothing', Just "World"] :: Array String)
--   Just "Hello"
asum ::
  ( Contiguous arr
  , Element arr (f a)
  , A.Alternative f
  ) => arr (f a) -> f a
asum = foldr (A.<|>) A.empty
{-# inline asum #-}

-- | Construct an array of the given length by applying
--   the function to each index.
generate :: (Contiguous arr, Element arr a)
  => Int
  -> (Int -> a)
  -> arr a
generate len f = create (generateMutable len f)
{-# inline generate #-}

-- | Construct an array of the given length by applying
--   the monadic action to each index.
generateM :: (Contiguous arr, Element arr a, Monad m)
  => Int
  -> (Int -> m a)
  -> m (arr a)
generateM !sz f =
  let go !ix = if ix < sz
        then liftA2
          (\b (STA m) -> STA $ \marr -> do
              write marr ix b
              m marr
          )
          (f ix)
          (go (ix + 1))
        else pure $ STA unsafeFreeze
  in if sz == 0
    then pure empty
    else runSTA sz <$> go 0

-- | Construct a mutable array of the given length by applying
--   the function to each index.
generateMutable :: (Contiguous arr, Element arr a, PrimMonad m)
  => Int
  -> (Int -> a)
  -> m (Mutable arr (PrimState m) a)
generateMutable len f = generateMutableM len (pure . f)
{-# inline generateMutable #-}

-- | Construct a mutable array of the given length by applying
--   the monadic action to each index.
generateMutableM :: (Contiguous arr, Element arr a, PrimMonad m)
  => Int
  -> (Int -> m a)
  -> m (Mutable arr (PrimState m) a)
generateMutableM !len f = do
  marr <- new len
  let go !ix = when (ix < len) $ do
        x <- f ix
        write marr ix x
        go (ix + 1)
  go 0
  pure marr
{-# inline generateMutableM #-}

-- | Apply a function @n@ times to a value and construct an array
--   where each consecutive element is the result of an additional
--   application of this function. The zeroth element is the original value.
--
--   @'iterateN' 5 ('+' 1) 0 = 'fromListN' 5 [0,1,2,3,4]@
iterateN :: (Contiguous arr, Element arr a)
  => Int
  -> (a -> a)
  -> a
  -> arr a
iterateN len f z0 = runST (iterateMutableN len f z0 >>= unsafeFreeze)
{-# inline iterateN #-}

-- | Apply a function @n@ times to a value and construct a mutable array
--   where each consecutive element is the result of an additional
--   application of this function. The zeroth element is the original value.
iterateMutableN :: (Contiguous arr, Element arr a, PrimMonad m)
  => Int
  -> (a -> a)
  -> a
  -> m (Mutable arr (PrimState m) a)
iterateMutableN len f z0 = iterateMutableNM len (pure . f) z0
{-# inline iterateMutableN #-}

-- | Apply a monadic function @n@ times to a value and construct a mutable array
--   where each consecutive element is the result of an additional
--   application of this function. The zeroth element is the original value.
iterateMutableNM :: (Contiguous arr, Element arr a, PrimMonad m)
  => Int
  -> (a -> m a)
  -> a
  -> m (Mutable arr (PrimState m) a)
iterateMutableNM !len f z0 = do
  marr <- new len
  -- we are strict in the accumulator because
  -- otherwise we could build up a ton of `f (f (f (f .. (f a))))`
  -- thunks for no reason.
  let go !ix !acc
        | ix <= 0 = write marr ix z0 >> go (ix + 1) z0
        | ix == len = pure ()
        | otherwise = do
            a <- f acc
            write marr ix a
            go (ix + 1) a
  go 0 z0
  pure marr
{-# inline iterateMutableNM #-}

-- | Execute the monad action and freeze the resulting array.
create :: (Contiguous arr, Element arr a)
  => (forall s. ST s (Mutable arr s a))
  -> arr a
create x = run (unsafeFreeze =<< x)
{-# inline create #-}

-- | Execute the monadic action and freeze the resulting array.
createT :: (Contiguous arr, Element arr a, Traversable f)
  => (forall s. ST s (f (Mutable arr s a)))
  -> f (arr a)
createT p = runST (Prelude.mapM unsafeFreeze =<< p)
{-# inline createT #-}

-- | Construct an array by repeatedly applying a generator
--   function to a seed. The generator function yields 'Just' the
--   next element and the new seed or 'Nothing' if there are no more
--   elements.
--
-- >>> unfoldr (\n -> if n == 0 then Nothing else Just (n,n-1) 10
--     <10,9,8,7,6,5,4,3,2,1>

-- Unfortunately, because we don't know ahead of time when to stop,
-- we need to construct a list and then turn it into an array.
unfoldr :: (Contiguous arr, Element arr a)
  => (b -> Maybe (a,b))
  -> b
  -> arr a
unfoldr f z0 = create (unfoldrMutable f z0)
{-# inline unfoldr #-}

-- | Construct a mutable array by repeatedly applying a generator
--   function to a seed. The generator function yields 'Just' the
--   next element and the new seed or 'Nothing' if there are no more
--   elements.
--
-- >>> unfoldrMutable (\n -> if n == 0 then Nothing else Just (n,n-1) 10
--     <10,9,8,7,6,5,4,3,2,1>

-- Unfortunately, because we don't know ahead of time when to stop,
-- we need to construct a list and then turn it into an array.
unfoldrMutable :: (Contiguous arr, Element arr a, PrimMonad m)
  => (b -> Maybe (a,b))
  -> b
  -> m (Mutable arr (PrimState m) a)
unfoldrMutable f z0 = do
  let go !sz s !xs = case f s of
        Nothing -> pure (sz,xs)
        Just (x,s') -> go (sz + 1) s' (x : xs)
  (sz,xs) <- go 0 z0 []
  unsafeFromListReverseMutableN sz xs
{-# inline unfoldrMutable #-}

-- | Construct an array with at most n elements by repeatedly
--   applying the generator function to a seed. The generator function
--   yields 'Just' the next element and the new seed or 'Nothing' if
--   there are no more elements.
unfoldrN :: (Contiguous arr, Element arr a)
  => Int
  -> (b -> Maybe (a, b))
  -> b
  -> arr a
unfoldrN maxSz f z0 = create (unfoldrMutableN maxSz f z0)
{-# inline unfoldrN #-}

-- | Construct a mutable array with at most n elements by repeatedly
--   applying the generator function to a seed. The generator function
--   yields 'Just' the next element and the new seed or 'Nothing' if
--   there are no more elements.
unfoldrMutableN :: (Contiguous arr, Element arr a, PrimMonad m)
  => Int
  -> (b -> Maybe (a, b))
  -> b
  -> m (Mutable arr (PrimState m) a)
unfoldrMutableN !maxSz f z0 = do
  m <- new maxSz
  let go !ix s = if ix < maxSz
        then case f s of
          Nothing -> pure ix
          Just (x,s') -> do
            write m ix x
            go (ix + 1) s'
        else pure ix
  sz <- go 0 z0
  case compare maxSz sz of
    EQ -> pure m
    GT -> resize m sz
    LT -> error "Data.Primitive.Contiguous.unfoldrMutableN: internal error"
{-# inline unfoldrMutableN #-}

-- | Convert an array to a list.
toList :: (Contiguous arr, Element arr a)
  => arr a
  -> [a]
toList arr = build (\c n -> foldr c n arr)
{-# inline toList #-}

-- | Convert a mutable array to a list.

-- I don't think this can be expressed in terms of foldr/build,
-- so we just loop through the array.
toListMutable :: (Contiguous arr, Element arr a, PrimMonad m)
  => Mutable arr (PrimState m) a
  -> m [a]
toListMutable marr = do
  sz <- sizeMutable marr
  let go !ix !acc = if ix >= 0
        then do
          x <- read marr ix
          go (ix - 1) (x : acc)
        else pure acc
  go (sz - 1) []
{-# inline toListMutable #-}

-- | Given an 'Int' that is representative of the length of
--   the list, convert the list into a mutable array of the
--   given length.
--
--   /Note/: calls 'error' if the given length is incorrect.
fromListMutableN :: (Contiguous arr, Element arr a, PrimMonad m)
  => Int
  -> [a]
  -> m (Mutable arr (PrimState m) a)
fromListMutableN len vs = do
  marr <- new len
  let go [] !ix = if ix == len
        then pure ()
        else error "Data.Primitive.Contiguous.fromListN: list length less than specified size."
      go (a:as) !ix = if ix < len
        then do
          write marr ix a
          go as (ix + 1)
        else error "Data.Primitive.Contiguous.fromListN: list length greater than specified size."
  go vs 0
  pure marr
{-# inline fromListMutableN #-}

-- | Convert a list into a mutable array of the given length.
fromListMutable :: (Contiguous arr, Element arr a, PrimMonad m)
  => [a]
  -> m (Mutable arr (PrimState m) a)
fromListMutable xs = fromListMutableN (length xs) xs
{-# inline fromListMutable #-}

-- | Given an 'Int' that is representative of the length of
--   the list, convert the list into a mutable array of the
--   given length.
--
--   /Note/: calls 'error' if the given length is incorrect.
fromListN :: (Contiguous arr, Element arr a)
  => Int
  -> [a]
  -> arr a
fromListN len vs = create (fromListMutableN len vs)
{-# inline fromListN #-}

-- | Convert a list into an array.
fromList :: (Contiguous arr, Element arr a)
  => [a]
  -> arr a
fromList vs = create (fromListMutable vs)
{-# inline fromList #-}

-- | Modify the elements of a mutable array in-place.
modify :: (Contiguous arr, Element arr a, PrimMonad m)
  => (a -> a)
  -> Mutable arr (PrimState m) a
  -> m ()
modify f marr = do
  !sz <- sizeMutable marr
  let go !ix = when (ix < sz) $ do
        x <- read marr ix
        write marr ix (f x)
        go (ix + 1)
  go 0
{-# inline modify #-}

-- | Strictly modify the elements of a mutable array in-place.
modify' :: (Contiguous arr, Element arr a, PrimMonad m)
  => (a -> a)
  -> Mutable arr (PrimState m) a
  -> m ()
modify' f marr = do
  !sz <- sizeMutable marr
  let go !ix = when (ix < sz) $ do
        x <- read marr ix
        let !y = f x
        write marr ix y
        go (ix + 1)
  go 0
{-# inline modify' #-}

-- | Yield an array of the given length containing the values
--   @x, 'succ' x, 'succ' ('succ' x)@ etc.
enumFromN :: (Contiguous arr, Element arr a, Enum a)
  => a
  -> Int
  -> arr a
enumFromN z0 sz = create (enumFromMutableN z0 sz)
{-# inline enumFromN #-}

-- | Yield a mutable array of the given length containing the values
--   @x, 'succ' x, 'succ' ('succ' x)@ etc.
enumFromMutableN :: (Contiguous arr, Element arr a, PrimMonad m, Enum a)
  => a
  -> Int
  -> m (Mutable arr (PrimState m) a)
enumFromMutableN z0 !sz = do
  m <- new sz
  let go !ix z = if ix < sz
        then do
          write m ix z
          go (ix + 1) (succ z)
        else pure m
  go 0 z0
{-# inline enumFromMutableN #-}

-- | Lift an accumulating hash function over the elements of the array,
--   returning the final accumulated hash.
liftHashWithSalt :: (Contiguous arr, Element arr a)
  => (Int -> a -> Int)
  -> Int
  -> arr a
  -> Int
liftHashWithSalt f s0 arr = go 0 s0 where
  sz = size arr
  go !ix !s = if ix < sz
    then
      let !(# x #) = index# arr ix
       in go (ix + 1) (f s x)
    else hashIntWithSalt s ix
{-# inline liftHashWithSalt #-}

-- | Reverse the elements of an array.
reverse :: (Contiguous arr, Element arr a)
  => arr a
  -> arr a
reverse arr = run $ do
  marr <- new sz
  copy marr 0 arr 0 sz
  reverseMutable marr
  unsafeFreeze marr
  where
    !sz = size arr
{-# inline reverse #-}

-- | Reverse the elements of a mutable array, in-place.
reverseMutable :: (Contiguous arr, Element arr a, PrimMonad m)
  => Mutable arr (PrimState m) a
  -> m ()
reverseMutable marr = do
  !sz <- sizeMutable marr
  reverseSlice marr 0 (sz - 1)
{-# inline reverseMutable #-}

-- | Reverse the elements of a slice of a mutable array, in-place.
reverseSlice :: (Contiguous arr, Element arr a, PrimMonad m)
  => Mutable arr (PrimState m) a
  -> Int -- ^ start index
  -> Int -- ^ end index
  -> m ()
reverseSlice !marr !start !end = do
  let go !s !e = if s >= e
        then pure ()
        else do
          tmp <- read marr s
          write marr s =<< read marr e
          write marr e tmp
          go (s+1) (e-1)
  go start end
{-# inline reverseSlice #-}

-- | This function does not behave deterministically. Optimization level and
-- inlining can affect its results. However, the one thing that can be counted
-- on is that if it returns 'True', the two immutable arrays are definitely the
-- same. This is useful as shortcut for equality tests. However, keep in mind
-- that a result of 'False' tells us nothing about the arguments.
same :: Contiguous arr => arr a -> arr a -> Bool
same a b = isTrue# (sameMutableArrayArray# (unsafeCoerce# (unlift a) :: MutableArrayArray# s) (unsafeCoerce# (unlift b) :: MutableArrayArray# s))

hashIntWithSalt :: Int -> Int -> Int
hashIntWithSalt salt x = salt `combine` x
{-# inline hashIntWithSalt #-}

combine :: Int -> Int -> Int
combine h1 h2 = (h1 * 16777619) `xor` h2
{-# inline combine #-}

-- | Does the element occur in the structure?
elem :: (Contiguous arr, Element arr a, Eq a) => a -> arr a -> Bool
elem a !arr =
  let !sz = size arr
      go !ix
        | ix < sz = case index# arr ix of
            !(# x #) -> if a == x
              then True
              else go (ix + 1)
        | otherwise = False
  in go 0
{-# inline elem #-}

-- | The largest element of a structure.
maximum :: (Contiguous arr, Element arr a, Ord a) => arr a -> Maybe a
maximum = maximumBy compare
{-# inline maximum #-}

-- | The least element of a structure.
minimum :: (Contiguous arr, Element arr a, Ord a) => arr a -> Maybe a
minimum = minimumBy compare
{-# inline minimum #-}

-- | The largest element of a structure with respect to the
--   given comparison function.
maximumBy :: (Contiguous arr, Element arr a)
  => (a -> a -> Ordering)
  -> arr a
  -> Maybe a
maximumBy f arr =
  let !sz = size arr
      go !ix o = if ix < sz
        then case index# arr ix of
          !(# x #) -> go (ix + 1) (case f x o of { GT -> x; _ -> o; })
        else o
  in if sz == 0
    then Nothing
    else Just (go 0 (index arr 0))
{-# inline maximumBy #-}

-- | The least element of a structure with respect to the
--   given comparison function.
minimumBy :: (Contiguous arr, Element arr a)
  => (a -> a -> Ordering)
  -> arr a
  -> Maybe a
minimumBy f arr =
  let !sz = size arr
      go !ix o = if ix < sz
        then case index# arr ix of
          !(# x #) -> go (ix + 1) (case f x o of { GT -> o; _ -> x; })
        else o
  in if sz == 0
    then Nothing
    else Just (go 0 (index arr 0))
{-# inline minimumBy #-}

-- | 'find' takes a predicate and an array, and returns the leftmost
--   element of the array matching the prediate, or 'Nothing' if there
--   is no such element.
find :: (Contiguous arr, Element arr a)
  => (a -> Bool)
  -> arr a
  -> Maybe a
find p = coerce . (foldMap (\x -> if p x then Just (First x) else Nothing))
{-# inline find #-}

-- | 'findIndex' takes a predicate and an array, and returns the index of
--   the leftmost element of the array matching the prediate, or 'Nothing'
--   if there is no such element.
findIndex :: (Contiguous arr, Element arr a)
  => (a -> Bool)
  -> arr a
  -> Maybe Int
findIndex p xs = loop 0
  where
  loop i
    | i < size xs = if p (index xs i) then Just i else loop (i + 1)
    | otherwise = Nothing
{-# inline findIndex #-}

-- | Swap the elements of the mutable array at the given indices.
swap :: (Contiguous arr, Element arr a, PrimMonad m)
  => Mutable arr (PrimState m) a
  -> Int
  -> Int
  -> m ()
swap !marr !ix1 !ix2 = do
  atIx1 <- read marr ix1
  atIx2 <- read marr ix2
  write marr ix1 atIx2
  write marr ix2 atIx1
{-# inline swap #-}

-- | Extracts from an array of 'Either' all the 'Left' elements.
-- All the 'Left' elements are extracted in order.
lefts :: forall arr a b.
  ( Contiguous arr
  , Element arr a
  , Element arr (Either a b)
  ) => arr (Either a b)
    -> arr a
lefts !arr = create $ do
  let !sz = size arr
      go :: Int -> [a] -> Int -> ST s (Int, [a])
      go !ix !as !acc = if ix < sz
        then do
          indexM arr ix >>= \case
            Left a -> go (ix + 1) (a:as) (acc + 1)
            Right _ -> go (ix + 1) as acc
        else pure (acc, as)
  (len, as) <- go 0 [] 0
  unsafeFromListReverseMutableN len as
{-# inline lefts #-}

-- | Extracts from an array of 'Either' all the 'Right' elements.
-- All the 'Right' elements are extracted in order.
rights :: forall arr a b.
  ( Contiguous arr
  , Element arr b
  , Element arr (Either a b)
  ) => arr (Either a b)
    -> arr b
rights !arr = create $ do
  let !sz = size arr
      go :: Int -> [b] -> Int -> ST s (Int, [b])
      go !ix !bs !acc = if ix < sz
        then do
          indexM arr ix >>= \case
            Left _ -> go (ix + 1) bs acc
            Right b -> go (ix + 1) (b:bs) (acc + 1)
        else pure (acc, bs)
  (len, bs) <- go 0 [] 0
  unsafeFromListReverseMutableN len bs
{-# inline rights #-}

-- | Partitions an array of 'Either' into two arrays.
-- All the 'Left' elements are extracted, in order, to the first
-- component of the output. Similarly the 'Right' elements are extracted
-- to the second component of the output.
partitionEithers :: forall arr a b.
  ( Contiguous arr
  , Element arr a
  , Element arr b
  , Element arr (Either a b)
  ) => arr (Either a b)
    -> (arr a, arr b)
partitionEithers !arr = runST $ do
  let !sz = size arr
      go :: Int -> [a] -> [b] -> Int -> Int -> ST s (Int, Int, [a], [b])
      go !ix !as !bs !accA !accB = if ix < sz
        then do
          indexM arr ix >>= \case
            Left a -> go (ix + 1) (a:as) bs (accA + 1) accB
            Right b -> go (ix + 1) as (b:bs) accA (accB + 1)
          else pure (accA, accB, as, bs)
  (lenA, lenB, as, bs) <- go 0 [] [] 0 0
  arrA <- unsafeFreeze =<< unsafeFromListReverseMutableN lenA as
  arrB <- unsafeFreeze =<< unsafeFromListReverseMutableN lenB bs
  pure (arrA, arrB)
{-# inline partitionEithers #-}

-- | 'scanl' is similar to 'foldl', but returns an array of
--   successive reduced values from the left:
--
--   > scanl f z [x1, x2, ...] = [z, f z x1, f (f z x1) x2, ...]
--
--   Note that
--
--   > last (toList (scanl f z xs)) == foldl f z xs.
scanl ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
scanl f = iscanl (const f)
{-# inline scanl #-}

-- | A variant of 'scanl' whose function argument takes the current
--   index as an argument.
iscanl ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (Int -> b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
iscanl f q as = internalScanl (size as + 1) f q as
{-# inline iscanl #-}

-- | A strictly accumulating version of 'scanl'.
scanl' ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
scanl' f = iscanl' (const f)
{-# inline scanl' #-}

-- | A strictly accumulating version of 'iscanl'.
iscanl' ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (Int -> b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
iscanl' f !q as = internalScanl' (size as + 1) f q as
{-# inline iscanl' #-}

-- Internal only. The first argument is the size of the array
-- argument. This function helps prevent duplication.
internalScanl ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => Int
    -> (Int -> b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
internalScanl !sz f !q as = create $ do
  !marr <- new sz
  let go !ix acc = when (ix < sz) $ do
        write marr ix acc
        x <- indexM as ix
        go (ix + 1) (f ix acc x)
  go 0 q
  pure marr
{-# inline internalScanl #-}

-- Internal only. The first argument is the size of the array
-- argument. This function helps prevent duplication.
internalScanl' ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => Int
    -> (Int -> b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
internalScanl' !sz f !q as = create $ do
  !marr <- new sz
  let go !ix !acc = when (ix < sz) $ do
        write marr ix acc
        x <- indexM as ix
        go (ix + 1) (f ix acc x)
  go 0 q
  pure marr
{-# inline internalScanl' #-}

-- | A prescan.
--
--   @prescanl f z = init . scanl f z@
--
--   Example: @prescanl (+) 0 \<1,2,3,4\> = \<0,1,3,6\>@
prescanl ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
prescanl f = iprescanl (const f)
{-# inline prescanl #-}

-- | A variant of 'prescanl' where the function argument takes
--   the current index of the array as an additional argument.
iprescanl ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (Int -> b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
iprescanl f q as = internalScanl (size as) f q as
{-# inline iprescanl #-}

-- | Like 'prescanl', but with a strict accumulator.
prescanl' ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
prescanl' f = iprescanl (const f)
{-# inline prescanl' #-}

-- | Like 'iprescanl', but with a strict accumulator.
iprescanl' ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (Int -> b -> a -> b)
    -> b
    -> arr1 a
    -> arr2 b
iprescanl' f !q as = internalScanl' (size as) f q as
{-# inline iprescanl' #-}

-- | 'zipWith' generalises 'zip' by zipping with the function
--   given as the first argument, instead of a tupling function.
--   For example, 'zipWith' (+) is applied to two arrays to produce
--   an array of the corresponding sums.
zipWith ::
  ( Contiguous arr1
  , Contiguous arr2
  , Contiguous arr3
  , Element arr1 a
  , Element arr2 b
  , Element arr3 c
  ) => (a -> b -> c)
    -> arr1 a
    -> arr2 b
    -> arr3 c
zipWith f = izipWith (\_ a b -> f a b)
{-# inline zipWith #-}

-- | Variant of 'zipWith' that provides the index of each pair of elements.
izipWith ::
  ( Contiguous arr1
  , Contiguous arr2
  , Contiguous arr3
  , Element arr1 a
  , Element arr2 b
  , Element arr3 c
  ) => (Int -> a -> b -> c)
    -> arr1 a
    -> arr2 b
    -> arr3 c
izipWith f as bs = create $ do
  let !sz = min (size as) (size bs)
  !marr <- new sz
  let go !ix = when (ix < sz) $ do
        a <- indexM as ix
        b <- indexM bs ix
        let !g = f ix a b
        write marr ix g
        go (ix + 1)
  go 0
  pure marr
{-# inline izipWith #-}

-- | Variant of 'zipWith' that accepts an accumulator, performing a lazy
-- right fold over both arrays.
foldrZipWith ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (a -> b -> c -> c)
    -> c
    -> arr1 a
    -> arr2 b
    -> c
foldrZipWith f = ifoldrZipWith (\_ x y c -> f x y c)
{-# inline foldrZipWith #-}

-- | Variant of 'foldrZipWith' that provides the index of each pair of elements.
ifoldrZipWith ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 a
  , Element arr2 b
  ) => (Int -> a -> b -> c -> c)
    -> c
    -> arr1 a
    -> arr2 b
    -> c
ifoldrZipWith f z = \arr1 arr2 ->
  let !sz = min (size arr1) (size arr2)
      go !ix = if sz > ix
        then case index# arr1 ix of
          (# x #) -> case index# arr2 ix of
            (# y #) -> f ix x y (go (ix + 1))
        else z
  in go 0
{-# inline ifoldrZipWith #-}

-- | 'zip' takes two arrays and returns an array of
--   corresponding pairs.
--
--   > zip [1, 2] ['a', 'b'] = [(1, 'a'), (2, 'b')]
--
--   If one input array is shorter than the other, excess
--   elements of the longer array are discarded:
--
--   > zip [1] ['a', 'b'] = [(1, 'a')]
--   > zip [1, 2] ['a'] = [(1, 'a')]
--
zip ::
  ( Contiguous arr1
  , Contiguous arr2
  , Contiguous arr3
  , Element arr1 a
  , Element arr2 b
  , Element arr3 (a, b)
  ) => arr1 a
    -> arr2 b
    -> arr3 (a, b)
zip = zipWith (,)
{-# inline zip #-}

-- | Replace all locations in the input with the same value.
--
--   Equivalent to Data.Functor.'Data.Functor.<$'.
(<$) ::
  ( Contiguous arr1
  , Contiguous arr2
  , Element arr1 b
  , Element arr2 a
  ) => a -> arr1 b -> arr2 a
a <$ barr = create (replicateMutable (size barr) a)
{-# inline (<$) #-}

-- | Sequential application.
--
--   Equivalent to Control.Applicative.'Control.Applicative.<*>'.
ap ::
  ( Contiguous arr1
  , Contiguous arr2
  , Contiguous arr3
  , Element arr1 (a -> b)
  , Element arr2 a
  , Element arr3 b
  ) => arr1 (a -> b) -> arr2 a -> arr3 b
ap fs xs = create $ do
  marr <- new (szfs * szxs)
  let go1 !ix = when (ix < szfs) $ do
        f <- indexM fs ix
        go2 (ix * szxs) f 0
        go1 (ix + 1)
      go2 !off f !j = when (j < szxs) $ do
        x <- indexM xs j
        write marr (off + j) (f x)
        go2 off f (j + 1)
  go1 0
  pure marr
  where
    !szfs = size fs
    !szxs = size xs
{-# inline ap #-}

all :: (Contiguous arr, Element arr a) => (a -> Bool) -> arr a -> Bool
all f = foldr (\x acc -> f x && acc) True
{-# inline all #-}

any :: (Contiguous arr, Element arr a) => (a -> Bool) -> arr a -> Bool
any f = foldr (\x acc -> f x || acc) False
{-# inline any #-}
