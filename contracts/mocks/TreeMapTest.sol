pragma solidity ^0.4.23;

import "../../contracts/TreeMap.sol";


library TreeMapTest {
  using TreeMap for TreeMap.Map;

  /// @dev helper function that validate tree integrity: binary search tree and red/black violation.
  ///  function is implemented recursively and should not be used in production contract code.
  ///  Binary search tree: left child < root < right child
  ///  Red violation: red node cannot have red child
  ///  Black violation: each side of a node (path from root to all leaves) must have equal black tree height
  /// @return red-black tree black height (number of black nodes from root to each leaf)
  function checkHeight(TreeMap.Map storage _self, TreeMap.Entry storage _root)
  internal
  view
  returns(uint height)
  {
    if (_root.size == 0) {
      return 0;
    } else {
      TreeMap.Entry storage leftChild = _self._leftChild(_root);
      TreeMap.Entry storage rightChild = _self._rightChild(_root);

      if (TreeMap._isRed(_root)) {
        if (TreeMap._isRed(leftChild) || TreeMap._isRed(rightChild)) {
          revert("Red violation: red entry cannot have red child");
        }
      }

      uint leftHeight = checkHeight(_self, leftChild);
      uint rightHeight = checkHeight(_self, rightChild);

      if (
        (leftChild.size > 0 && leftChild.key >= _root.key) ||
        (rightChild.size > 0 && rightChild.key <= _root.key)
      ) {
        revert("Binary search tree violation: left child < entry < right child does not hold");
      }

      if (leftHeight != 0 && rightHeight != 0) {
        if (leftHeight != rightHeight) {
          revert("Black violation: left side black tree height must equal to right side black tree height");
        }
      }

      if (
        _root.size != leftChild.size + rightChild.size + 1
      ) {
        revert("Order static tree violation: node size = left child size + right child size + 1");
      }

      height = leftHeight > rightHeight ? leftHeight : rightHeight;
      if (!TreeMap._isRed(_root)) {
        height++;
      }
    }
  }
}
