pragma solidity ^0.4.23;

import "../../contracts/TreeMap.sol";

library TreeMapTest {
  using TreeMap for TreeMap.Data;

  /// @dev helper function that validate tree integrity: binary search tree and red/black violation.
  ///  function is implemented recursively and should not be used in production contract code.
  ///  Binary search tree: left child < root < right child
  ///  Red violation: red node cannot have red child
  ///  Black violation: each side of a node (path from root to all leaves) must have equal black tree height
  /// @return red-black tree height (number of black nodes from root to each leaf)
  function _assert(TreeMap.Data storage _self, TreeMap.Entry storage _root)
  internal
  view
  returns(uint height)
  {
    uint leftHeight = 0;
    uint rightHeight = 0;

    if (!_root.hasData) {
      return 0;
    } else {
      TreeMap.Entry storage leftChild = _self._leftChild(_root);
      TreeMap.Entry storage rightChild = _self._rightChild(_root);

      if (TreeMap._isRed(_root)) {
        if (TreeMap._isRed(leftChild) || TreeMap._isRed(rightChild)) {
          revert("Red violation: red entry cannot have red child");
        }
      }

      leftHeight = _assert(_self, leftChild);
      rightHeight = _assert(_self, rightChild);

      if (
        (leftChild.hasData && leftChild.key >= _root.key) ||
        (rightChild.hasData && rightChild.key <= _root.key)
      ) {
        revert("Binary search tree violation: left child < entry < right child does not hold");
      }

      if (leftHeight != 0 && rightHeight != 0) {
        if (leftHeight != rightHeight) {
          revert("Black violation: left side black tree height must equal to right side black tree height");
        }

        return TreeMap._isRed(_root) ? leftHeight : leftHeight + 1;
      }

      return 0;
    }
  }
}
