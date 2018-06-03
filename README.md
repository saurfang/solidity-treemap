[![Build Status](https://travis-ci.org/saurfang/solidity-treemap.svg?branch=master)](https://travis-ci.org/saurfang/solidity-treemap)
[![Coverage Status](https://coveralls.io/repos/github/saurfang/solidity-treemap/badge.svg?branch=master)](https://coveralls.io/github/saurfang/solidity-treemap?branch=master)
[![npm version](https://badge.fury.io/js/solidity-treemap.svg)](https://badge.fury.io/js/solidity-treemap)

# solidity-treemap

A Solidity library which implements a navigable order static sorted treemap using Red Black Tree.

The treemap enables storage of (uint -> uint) mapping that further provides a total ordering by keys and navigation functions returning closest matches for any given keys.

Such map has a wide range of use cases in smart contracts, for example:

1. Order book matching (by price)
2. Calendar scheduling (by time)
3. TCR reputation ranking (by score)

The map is backed by a Red-Black tree where all lookup operations can be efficiently completed in `O(log n)` time. Due to lack of generics in Solidity, both keys and values take forms in `uint256`. The value class can be easily extended to support any type by mantaining an additional `mapping (uint => myStruct)` at the use site.

## Usage

Install the library code as a regular npm package:

```bash
npm install -save solidity-treemap
```

You can then import the `TreeMap.sol` like so:

```solidity
import "solidity-treemap/contracts/TreeMap.sol";

contract TreeMapMock {
  using TreeMap for TreeMap.Map;

  TreeMap.Map sortedMap1;
  TreeMap.Map sortedMap2;
  ...
}
```

## Features

Because Solidity does not support inheritence between `library`, all functions currently live in the `TreeMap.sol` together. The following documentation group functions logically.

### Sorted Map

- **putIfAbsent**: attempt to insert `item(key, value)` and returns `value` associated with `key` after insertion
- **put**: insert `item(key, value)` and replace any existing value if `key` is already in the tree
- **remove**: remove mapping associated with `key` from the map if it is present
- **get**: find the value to which the `key` is associated, or not found if the map does not contain such mapping
- **getOrDefault**: find the value to which the `key` is associated, or `defaultValue` if the map does not contain such mapping
- **size**: returns the size of the tree

### Navigable Map

- **floorEntry**: returns an entry associated with the greatest key less than or equal to the given key
- **lowerEntry**: returns an entry associated with the greatest key less than the given key
- **ceilingEntry**: returns an entry associated with the least key greater than or equal to the given key
- **higherEntry**: returns an entry associated with the least key greater than the given key
- **firstEntry**: returns the entry associated with the lowest key
- **lastEntry**: returns the entry associated with the highest key


### Order Static Map

- **select**: find the i'th smallest element stored in the tree
- **rank**: find the rank of element x in the tree

### Map Entry Iterator

**This feature is still a work in progress.**

To iterate through all map entries in `O(n)` time, one has to maintain a stack to facilitate the in-order tree traversal.
There are two ways to iterate through map entires: internally in smart contracts and externally using web3.js.

#### web3.js

When using web3.js, one could simply keep track of the state using arrays in Javascript.

TODO: provide an example iterate entires with web3.js

#### Smart Contract

For iteration in smart contract, because memory array is not resizble in Solidity, we need to allocate stack ahead of time.
The `TreeMapIterator.sol` provides a convenient wrapper for such access pattern where stack size is automatically determined and `next()` conforms with the iterator interface.

TODO: finish `TreeMapIterator` implementation.

## Security

The code has reasonably good test coverage but has not been audited. Since the code is provided as a library instead of contract, all operation on the TreeMap is private by default and please exercise good judgement on what mutability you expose externally in the contract. I take no responsibility for your use of this library and any security problem it might expose.

## TODO

- [ ] Enable in-order [iteration](https://github.com/ethereum/dapp-bin/blob/master/library/iterable_mapping.sol) over entries
- [ ] Implement more efficient [bulk operations](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree#Set_operations_and_bulk_operations)

## References

[Red Black Trees](http://eternallyconfuzzled.com/tuts/datastructures/jsw_tut_rbtree.aspx) by Eternally Confuzzled

[libavl](http://adtinfo.org/libavl.html/prb.c.txt)

Java [NavigableMap](https://docs.oracle.com/javase/8/docs/api/java/util/NavigableMap.html)

[Iterable mapping](https://github.com/ethereum/dapp-bin/blob/master/library/iterable_mapping.sol)
