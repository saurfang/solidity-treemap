pragma solidity ^0.4.23;


/// @title A navigatable sorted map that supports insertion, deletion, single item lookup,
///  and range lookup in logarithmic runtime.
///  Due to lack of generics in Solidity, both key and value are uint. One can trivially use this to
///  store complex values by maintaining an array of said value in the contract and store array indices
///  in the TreeMap instead.
///  TODO: Add example on how to use this library
///
/// @dev The map is implemented as red-black tree with iterative top-down insertion and deletion.
///  References:
///  - http://eternallyconfuzzled.com/tuts/datastructures/jsw_tut_rbtree.aspx
///  - http://adtinfo.org/libavl.html
library TreeMap {
  // Red-black mechanics
  bool private constant RED   = false;
  bool private constant BLACK = true;
  // Link direction for each entry
  uint8 private constant LEFT = 0;
  uint8 private constant RIGHT = 1;

  /// @dev a struct that represents a node in the red-black tree. `links` connect to its left and right child.
  ///  each node is `color`ed either RED or BLACK. `hasData` is used to indicate if the entry is NULL and
  ///  should never be modified by the user directly.
  struct Entry {
    uint key;
    uint value;
    uint[2] links;
    bool color;
    bool hasData;
  }

  /// @dev a struct that encapsulates all state variables of the treemap.
  ///
  ///  Because Solidity cannot have recursive struct. A list of entries are maintained in a dynamically sized array.
  ///  Mapping is used instead of array because our array starts with length of 1 and the 0-th element is reserved
  ///  as a "false root node" in the insertion and deletion algorithm. Use of mapping frees us from an initialization
  ///  function that users could neglect or extensive assertion placed in insert and delete function. Effectively our
  ///  `entries` array is 1-index based.
  ///
  ///  rootIdx simply points to the root node. When unitialized, it evalutes to 0 and points the "false root node".
  struct Data {
    // mapping from storage index to entries
    // 0 is reserved as "NULL" entry should never be used as index for entry that contains data
    mapping(uint => Entry) entries;
    uint entriesLength;
    // index of the root entry
    uint rootIdx;
    // number of key-value mappings stored in the map
    uint size;
  }

  /// @dev check whether a entry is not NULL and its color is RED
  function _isRed(Entry storage entry)
  internal
  view
  returns(bool)
  {
    return entry.hasData && entry.color == RED;
  }

  /// @dev returns an entry's child in a direction
  function _child(Data storage self, Entry storage entry, uint8 direction)
  internal
  view
  returns(Entry storage child)
  {
    return self.entries[entry.links[direction]];
  }

  /// @dev returns an entry's left child
  function _leftChild(Data storage self, Entry storage entry)
  internal
  view
  returns(Entry storage leftChild)
  {
    return _child(self, entry, LEFT);
  }

  /// @dev returns an entry's right child
  function _rightChild(Data storage self, Entry storage entry)
  internal
  view
  returns(Entry storage rightChild)
  {
    return _child(self, entry, RIGHT);
  }

  /// @dev check whether a entry's child is not NULL and its color is RED
  function _isChildRed(Data storage self, Entry storage entry, uint8 direction)
  internal
  view
  returns(bool)
  {
    return _isRed(_child(self, entry, direction));
  }

  /// @dev creates a new entry and put it into `entries`
  /// @param key key with which the specified value is to be associated
  /// @param value value to be associated with the specified key
  /// @return (index of the newly created entry, its storage pointer)
  function _makeEntry(Data storage self, uint key, uint value)
  internal
  returns(uint index, Entry storage entry)
  {
    // protects from index overflow
    if (self.entriesLength == 2**256 - 1) {
      revert("uint overflow: unable insert more entries");
    }

    index = ++self.entriesLength;
    self.entries[index] = Entry(
      key,
      value,
      [uint(0), uint(0)],
      RED,
      true
    );

    entry = self.entries[index];

    self.size++;
  }

  /// @dev single tree rotation around a root node in a specified direction.
  ///  old root is colored red and new root is colored black.
  ///
  ///  Inline code documentation assumes `direction` = `RIGHT` for simplicity
  ///  and one can see both cases are symmetric.
  ///
  ///  Illustration omits color for simplicity:
  ///              3(root)                   1(newRoot)
  ///
  ///            /      \                   /     \
  ///
  ///         1(newRoot) 4(*)  ->         0(*)      3(root)
  ///
  ///      /      \                               /     \
  ///
  ///   0(*)        2(*)                       2(*)      4(*)
  ///  (*) means node preserve its previous children if applicable
  ///
  /// @param root root node to be rotated around
  /// @param rootIdx entry index of the root node
  /// @param direction rotation direction
  /// @return entry index of the new root node
  function _rotateSingle(Data storage self, Entry storage root, uint rootIdx, uint8 direction)
  internal
  returns(uint newRootIdx)
  {
    // make "old root left child" as "new root"
    newRootIdx = root.links[1 - direction];
    Entry storage newRoot = self.entries[newRootIdx];

    // make "new root's right child" as "old root's left child"
    root.links[1 - direction] = newRoot.links[direction];
    // make "old root" as "new root's right child"
    newRoot.links[direction] = rootIdx;

    // apply colors
    root.color = RED;
    newRoot.color = BLACK;
  }

  /// @dev apply tree rotation around a root node in a specified direction twice.
  ///  Inline code documentation assumes `direction` = `RIGHT` for simplicity
  ///  and one can see both cases are symmetric.
  /// @param root root node to be rotated around
  /// @param rootIdx entry index of the root node
  /// @param direction rotation direction
  /// @return entry index of the new root node
  function _rotateDouble(Data storage self, Entry storage root, uint rootIdx, uint8 direction)
  internal
  returns(uint newRootIdx)
  {
    // rotate "root's left child" in the opposite direction first and update "old root" child link
    root.links[1 - direction] = _rotateSingle(
      self,
      self.entries[root.links[1 - direction]],
      root.links[1 - direction],
      1 - direction
    );

    return _rotateSingle(self, root, rootIdx, direction);
  }

  /// @dev set root node to BLACK color
  ///  factored out to avoid `CompilerError: Stack too deep, try removing local variables.`
  function _setRootToBlack(Data storage self)
  internal
  {
    self.entries[self.rootIdx].color = BLACK;
  }

  /// @dev flip color if applicable
  ///  factored out to avoid `CompilerError: Stack too deep, try removing local variables.`
  function _flipColorInProbe(Data storage self, Entry storage current)
  internal
  {
    Entry storage left = _leftChild(self, current);
    Entry storage right = _rightChild(self, current);
    if (_isRed(left) && _isRed(right)) {
      //  color flip that may cause red violation which is addressed below
      //
      //  1,E <-- previous           1,E
      //
      //      \                         \
      //
      //        3,B <-- current becomes  3,R
      //
      //      /     \                   /     \
      //
      //  2,R         4,R           2,B         4,B
      current.color = RED;
      left.color = BLACK;
      right.color = BLACK;
    }
  }

  /// @notice Insert `entry(key, value)` and returns a storage pointer to the `entry` corresponding to `key`.
  ///  If a duplicate key is found, returns a storage pointer to the duplicate without replacement.
  /// @dev New entry is eventaully inserted as `RED` at the bottom of the tree. The insertion never
  ///  triggers a black violation. Color flip, single and double rotation is used to address red
  ///  violation. Color flip guarantees siblings are never both red and enables rotation to fix
  ///  red violation in one go.
  /// @param key key with which the specified value is to be associated
  /// @param value value to be associated with the specified key
  /// @return storage pointer to entry corresponding to the key
  function probe(Data storage self, uint key, uint value)
  internal
  returns(Entry storage entry)
  {
    if (self.rootIdx == 0) {
      // insert into an empty tree
      (self.rootIdx, entry) = _makeEntry(self, key, value);
    } else {
      // false tree root
      // iterator's parent
      uint previousIdx = 0;
      Entry storage previous = self.entries[0];
      previous.links[RIGHT] = self.rootIdx;

      // iterator
      uint currentIdx = self.rootIdx;
      Entry storage current = self.entries[currentIdx];

      // previous' parent and grandParent
      uint parentIdx = 0;
      Entry storage parent = previous;
      Entry storage grandParent = previous;

      // direction from previous (current's parent) to current
      uint8 direction = LEFT;
      // last direction (direction from prvious's parent to previous)
      uint8 lastDirection = LEFT;

      // search down the tree
      while (true) {
        if (!current.hasData) {
          // insert new node at the bottom
          (currentIdx, current) = _makeEntry(self, key, value);
          previous.links[direction] = currentIdx;
          // save inserted element
          entry = current;
        } else {
          _flipColorInProbe(self, current);
        }

        // fix red violation
        if (_isRed(current) && _isRed(previous)) {
          uint8 parentDirection = grandParent.links[LEFT] == parentIdx ? LEFT : RIGHT;

          if (currentIdx == previous.links[lastDirection]) {
            //  single (left) rotation
            //
            //  0,B <-- parent                       1,B(previous)
            //
            //      \                               /     \
            //
            //        1,R <-- previous          0,R(parent)  3,R(current)
            //
            //            \               --->
            //
            //              3,R <-- current
            grandParent.links[parentDirection] = _rotateSingle(self, parent, parentIdx, 1 - lastDirection);
            // fix parent tracking
            parent = grandParent;
          } else {
            //  double (left) rotation
            //
            //        0,B <-- parent                     2,B(current)
            //
            //            \                         /           \
            //
            //              4,R <-- previous    0,R(parent)       4,R(previous)
            //
            //            /              --->       \           /
            //
            //        2,R <-- current                 1,B   3,B
            //
            //      /     \
            //
            //  1,B         3,B
            grandParent.links[parentDirection] = _rotateDouble(self, parent, parentIdx, 1 - lastDirection);
            // fix previous tracking
            // NB: current will traverse without color flip till children of 0 or 4,
            //   correct linkage of parent/grandParent will be established by then.
            previous = grandParent;
          }
        }

        // stop if found
        if (current.key == key) {
          entry = current;
          break;
        }

        // traverse down one level
        lastDirection = direction;
        direction = current.key < key ? RIGHT : LEFT;

        // update helpers
        grandParent = parent;

        parentIdx = previousIdx;
        parent = previous;

        previousIdx = currentIdx;
        previous = current;

        currentIdx = current.links[direction];
        current = self.entries[currentIdx];
      }

      // update root
      self.rootIdx = self.entries[0].links[RIGHT];
    }

    // reset root node to BLACK
    _setRootToBlack(self);
  }

  /// @notice attempt to insert `item(key, value)` and returns `value` associated with `key` after insertion.
  ///  If `key` already existed in the tree, its original value is returned and no replacement of the item occurs.
  /// @param key key with which the specified value is to be associated
  /// @param value value to be associated with the specified key
  /// @return value associated with the specified key
  function putIfAbsent(Data storage self, uint key, uint value)
  internal
  returns(uint newValue)
  {
    Entry storage entry = probe(self, key, value);
    return entry.value;
  }

  /// @notice insert `item(key, value)` and replace any existing value if `key` is already in the tree.
  ///  return whether replacement occurred and value that was replaced.
  /// @param key key with which the specified value is to be associated
  /// @param value value to be associated with the specified key
  /// @return (wether value is replaced, value associated with the key before replacement)
  function put(Data storage self, uint key, uint value)
  internal
  returns(bool replaced, uint oldValue)
  {
    Entry storage entry = probe(self, key, value);
    if (entry.value != value) {
      replaced = true;
      oldValue = entry.value;
      entry.value = value;
    }
  }

  /// @dev apply colors as necessary after rotation in top-down deletion
  ///  factored out to avoid `CompilerError: Stack too deep, try removing local variables.`
  function _applyColorInRemove(
    Data storage self,
    Entry storage current,
    Entry storage grandParent,
    uint8 parentDirection
  )
  internal
  {
    current.color = RED;
    Entry storage newGrandParent = _child(self, grandParent, parentDirection);
    newGrandParent.color = RED;
    _leftChild(self, newGrandParent).color = BLACK;
    _rightChild(self, newGrandParent).color = BLACK;
  }

  /// @notice remove mapping associated with `key` from the map if it is present and returns old `value`
  ///  associated with the `key` if found.
  /// @dev Deletion can be made easy by a few observations:
  ///  1. A RED leaf can be removed without any violations
  ///  2. A RED node can be removed without any violations if it only has at most one branch by attaching that branch
  ///    to the node's parent
  ///  3. If the node to be removed has more than one branch, it can be swapped with an easy-to-remove red node first
  ///
  ///  The swap candidate must be the largest element of left branch or the smallest element of right branch.
  ///  Here we choose to use the largest element of left branch.
  ///  We create a false root node colored RED first and iterate down the tree. We "push" this red color down along
  ///  the iterator such that we guarantee the node to be swapped is colored RED.
  ///
  ///  Inline code documentation assumes `direction` = `RIGHT` for simplicity and one can see both cases are symmetric.
  ///  "RIGHT" is picked also because we are looking for largest element after we found the matching entry.
  ///  The rest of the search always traverse down to the right direction.
  /// @param key key whose mapping is to be removed
  /// @return (whether a mapping has been removed, the value associated with the `key` before removal)
  function remove(Data storage self, uint key)
  internal
  returns(bool removed, uint oldValue)
  {
    if (self.rootIdx != 0) {
      // false root head
      uint currentIdx = 0;
      Entry storage current = self.entries[0];
      current.links[RIGHT] = self.rootIdx;

      // helpers
      uint parentIdx = 0;
      Entry storage parent = current;
      Entry storage grandParent = current;
      Entry storage toReplace = current;

      uint8 direction = RIGHT;
      uint8 lastDirection = direction;

      // search and push a red down
      while (current.links[direction] != 0) {
        // update helper and traverse down
        grandParent = parent;
        parentIdx = currentIdx;
        parent = current;
        currentIdx = current.links[direction];
        current = self.entries[currentIdx];

        lastDirection = direction;
        direction = current.key < key ? RIGHT : LEFT;

        // save found node
        if (current.key == key) {
          toReplace = current;
        }

        // push the red node down
        if (!_isRed(current) && !_isChildRed(self, current, direction)) {
          if (_isChildRed(self, current, 1 - direction)) {
            // the other (left) child is RED, one (right) rotation turns `current` RED
            //       1,B(current)    0,B
            //
            //     /     \              \
            //
            // 0,R         2,B  ->        1,R(current)
            //
            //                                \
            //
            //                                  2,B
            parent.links[lastDirection] = _rotateSingle(self, current, currentIdx, direction);
            parentIdx = parent.links[lastDirection];
            parent = self.entries[parentIdx];
            lastDirection = direction;
          } else {
            // current and both current's children are black

            Entry storage sibling = self.entries[parent.links[1 - lastDirection]];

            // if current doesn't have sibling but neither of its children is red
            // current must have no children at all otherwise it would lead to a black violation
            // and we will terminate at next iteration
            // NB: this normally can't happen because current can't be BLACK if it doesn't have sibling
            // it would be a black violation. it can only happen if current is a BLACK root without children
            if (sibling.hasData) {
              // if both sibling's children are black, color flip does not lead to a red violation on sibling
              if (!_isChildRed(self, sibling, LEFT) && !_isChildRed(self, sibling, RIGHT)) {
                // color flip
                //       1,R                  1,B
                //
                //     /     \      ->      /     \
                //
                // 0,B         2,B      0,R         2,R
                parent.color = BLACK;
                current.color = RED;
                sibling.color = RED;
              } else {
                uint8 parentDirection = grandParent.links[LEFT] == parentIdx ? LEFT : RIGHT;

                // one of the sibling children must have data and is RED
                if (_isChildRed(self, sibling, lastDirection)) {
                  // double roatation
                  //       2,R(parent)                    1,R(newGrandParent)
                  //
                  //     /       \ (lastDirection)    /         \
                  //
                  // 0,B(sibling) 3,B(current)  ->  0,B(sibling) 2,B(parent)
                  //
                  //     \                                           \
                  //
                  //       1,R                                        3,R (current)
                  grandParent.links[parentDirection] = _rotateDouble(self, parent, parentIdx, lastDirection);
                } else if (_isChildRed(self, sibling, 1 - lastDirection)) {
                  // single rotation
                  //           2,R(parent)                    1,R(newGrandParent/sibling)
                  //
                  //         /       \                       /       \
                  //
                  //     1,B(sibling) 3,B(current)  ->    0,B         2,B(parent)
                  //
                  //    /                                                 \
                  //
                  // 0,R                                                    3,R (current)
                  grandParent.links[parentDirection] = _rotateSingle(self, parent, parentIdx, lastDirection);
                }

                // apply colors
                _applyColorInRemove(self, current, grandParent, parentDirection);
              }
            }
          }
        }
      }

      // replace and remove if found
      if (toReplace.hasData) {
        // save old value
        removed = true;
        oldValue = toReplace.value;

        // replace old node with current iterator
        toReplace.key = current.key;
        toReplace.value = current.value;

        // splice remaining subtree of current node to its parent if applicable
        // NB: current.links[direction] has been checked to be empty
        parent.links[lastDirection] = current.links[1 - direction];
        // clean up parent connection to current node
        // parent.links[1 - lastDirection] = 0;

        // delete current node to free storage
        delete self.entries[currentIdx];

        self.size--;
      }

      // update root and make it black
      self.rootIdx = self.entries[0].links[RIGHT];
      _setRootToBlack(self);
    }
  }

  /// @notice find the value to which the `key` is associated, or not found if the map does not contain such mapping
  /// @param key key whose associated value is to be returned
  /// @return (whether a mapping with `key` exists, the value associated with the `key`)
  function get(Data storage self, uint key)
  internal
  view
  returns(bool found, uint value)
  {
    if (self.rootIdx != 0) {
      Entry storage current = self.entries[self.rootIdx];

      while (current.hasData) {
        if (current.key == key) {
          found = true;
          value = current.value;
          break;
        } else if (current.key < key) {
          current = _rightChild(self, current);
        } else {
          current = _leftChild(self, current);
        }
      }
    }
  }

  /// @notice find the value to which the `key` is associated, or `defaultValue` if the map does not contain such mapping
  /// @param key key whose associated value is to be returned
  /// @param defaultValue fallback value to be returned
  /// @return the value associated with the `key` or `defaultValue` if not found
  function getOrDefault(Data storage self, uint key, uint defaultValue)
  internal
  view
  returns(uint value)
  {
    bool found;
    (found, value) = get(self, key);
    if (!found) {
      value = defaultValue;
    }
  }

  /// @notice returns an entry associated with the greatest key less than or equal to the given key
  /// @return whether such entry exists and its key and value
  function floorEntry(Data storage self, uint _key)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage current = self.entries[self.rootIdx];

    while (current.hasData) {
      if (current.key == _key) {
        found = true;
        key = current.key;
        value = current.value;
        break;
      } else if (current.key > _key) {
        current = _leftChild(self, current);
      } else {
        // NB: in iterations, we will only find greater keys than previously seen ones
        found = true;
        key = current.key;
        value = current.value;

        current = _rightChild(self, current);
      }
    }
  }

  /// @notice returns an entry associated with the greatest key less than the given key
  /// @return whether such entry exists and its key and value
  function lowerEntry(Data storage self, uint _key)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage current = self.entries[self.rootIdx];

    while (current.hasData) {
      if (current.key >= _key) {
        current = _leftChild(self, current);
      } else {
        // NB: in iterations, we will only find greater keys than previously seen ones
        found = true;
        key = current.key;
        value = current.value;

        current = _rightChild(self, current);
      }
    }
  }

  /// @notice returns an entry associated with the least key greater than or equal to the given key
  /// @return whether such entry exists and its key and value
  function ceilingEntry(Data storage self, uint _key)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage current = self.entries[self.rootIdx];

    while (current.hasData) {
      if (current.key == _key) {
        found = true;
        key = current.key;
        value = current.value;
        break;
      } else if (current.key < _key) {
        current = _rightChild(self, current);
      } else {
        // NB: in iterations, we will only find lesser keys than previously seen ones
        found = true;
        key = current.key;
        value = current.value;

        current = _leftChild(self, current);
      }
    }
  }

  /// @notice returns an entry associated with the least key greater than the given key
  /// @return whether such entry exists and its key and value
  function higherEntry(Data storage self, uint _key)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage current = self.entries[self.rootIdx];

    while (current.hasData) {
      if (current.key <= _key) {
        current = _rightChild(self, current);
      } else {
        // NB: in iterations, we will only find lesser keys than previously seen ones
        found = true;
        key = current.key;
        value = current.value;

        current = _leftChild(self, current);
      }
    }
  }

  /// @dev helper function that validate tree integrity: binary search tree and red/black violation.
  ///  function is implemented recursively and should not be used in production contract code.
  ///  Binary search tree: left child < root < right child
  ///  Red violation: red node cannot have red child
  ///  Black violation: each side of a node (path from root to all leaves) must have equal black tree height
  /// @return red-black tree height (number of black nodes from root to each leaf)
  function _assert(Data storage self, Entry storage root)
  internal
  view
  returns(uint height)
  {
    uint leftHeight = 0;
    uint rightHeight = 0;

    if (!root.hasData) {
      return 0;
    } else {
      Entry storage leftChild = _leftChild(self, root);
      Entry storage rightChild = _rightChild(self, root);

      if (_isRed(root)) {
        if (_isRed(leftChild) || _isRed(rightChild)) {
          revert("Red violation: red entry cannot have red child");
        }
      }

      leftHeight = _assert(self, leftChild);
      rightHeight = _assert(self, rightChild);

      if (
        (leftChild.hasData && leftChild.key >= root.key) ||
        (rightChild.hasData && rightChild.key <= root.key)
      ) {
        revert("Binary search tree violation: left child < entry < right child does not hold");
      }

      if (leftHeight != 0 && rightHeight != 0) {
        if (leftHeight != rightHeight) {
          revert("Black violation: left side black tree height must equal to right side black tree height");
        }

        return _isRed(root) ? leftHeight : leftHeight + 1;
      }

      return 0;
    }
  }
}
