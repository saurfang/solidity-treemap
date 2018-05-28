pragma solidity ^0.4.23;

import "./TreeMap.sol";

/// @title Iterator interface for TreeMap that enables efficient ordered iteration over
///  elements in linear time. The iteration requires a stack with size up to the tree height.
///  Sub-map views of NavigableMap interface is approximated by bounded iterator.
library TreeMapIterator {
  using TreeMap for TreeMap.Map;


}
