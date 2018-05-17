[![Build Status](https://travis-ci.org/saurfang/solidity-treemap.svg?branch=master)](https://travis-ci.org/saurfang/solidity-treemap)
[![Coverage Status](https://coveralls.io/repos/github/saurfang/solidity-treemap/badge.svg?branch=master)](https://coveralls.io/github/saurfang/solidity-treemap?branch=master)
[![npm version](https://badge.fury.io/js/solidity-treemap.svg)](https://badge.fury.io/js/solidity-treemap)

# solidity-treemap

A work in progress treemap implementation using red-black tree.

## TODO

- [ ] Increase test coverage
  - [ ] Guarantee converage on single and double roration during insertion and deletion in both directions
  - [ ] Test revert cases
- [ ] Prefix all parameters with `_` for readability
- [ ] Refactor test helpers such as `_assert` into its own library or test contract
- [ ] Refactor library into smaller modules. For example, seperate red-black tree and search/zipper code
- [ ] Expand function interface
  - [ ] Enable in-order [iteration](https://github.com/ethereum/dapp-bin/blob/master/library/iterable_mapping.sol) over entries
  - [ ] Implement [Order statistic tree](https://en.wikipedia.org/wiki/Order_statistic_tree)
  - [ ] Complete implementation of all NavigableMap interface
- [ ] Implement more efficient [bulk operations](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree#Set_operations_and_bulk_operations)

## References

[Red Black Trees](http://eternallyconfuzzled.com/tuts/datastructures/jsw_tut_rbtree.aspx) by Eternally Confuzzled

[libavl](http://adtinfo.org/libavl.html/prb.c.txt)

Java [NavigableMap](https://docs.oracle.com/javase/8/docs/api/java/util/NavigableMap.html)

[Iterable mapping](https://github.com/ethereum/dapp-bin/blob/master/library/iterable_mapping.sol)
