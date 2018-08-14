pragma solidity ^0.4.23;

import "./MathUtil.sol";


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
  ///  each node is `color`ed either RED or BLACK. `size` annotates the number of entries the node and its children
  ///  have.
  struct Entry {
    uint key;
    uint value;
    uint[2] links;
    uint size;
    bool color;
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
  struct Map {
    // mapping from storage index to entries
    // 0 is reserved as "NULL" entry should never be used as index for entry that contains data
    mapping(uint => Entry) entries;
    uint entriesLength;
    // index of the root entry
    uint rootIdx;
  }

  /// @dev check whether a entry is not NULL and its color is RED
  function _isRed(Entry storage _entry)
  internal
  view
  returns(bool)
  {
    return _entry.size > 0 && _entry.color == RED;
  }

  /// @dev returns an entry's child in a direction
  function _child(Map storage _self, Entry storage _entry, uint8 _direction)
  internal
  view
  returns(Entry storage child)
  {
    return _self.entries[_entry.links[_direction]];
  }

  /// @dev returns an entry's left child
  function _leftChild(Map storage _self, Entry storage _entry)
  internal
  view
  returns(Entry storage leftChild)
  {
    return _child(_self, _entry, LEFT);
  }

  /// @dev returns an entry's right child
  function _rightChild(Map storage _self, Entry storage _entry)
  internal
  view
  returns(Entry storage rightChild)
  {
    return _child(_self, _entry, RIGHT);
  }

  /// @dev check whether a entry's child is not NULL and its color is RED
  function _isChildRed(Map storage _self, Entry storage _entry, uint8 _direction)
  internal
  view
  returns(bool)
  {
    return _isRed(_child(_self, _entry, _direction));
  }

  /// @dev creates a new entry and put it into `entries`
  /// @param _key key with which the specified value is to be associated
  /// @param _value value to be associated with the specified key
  /// @return (index of the newly created entry, its storage pointer)
  function _makeEntry(Map storage _self, uint _key, uint _value)
  internal
  returns(uint index, Entry storage entry)
  {
    // protects from index overflow
    if (_self.entriesLength == 2**256 - 1) {
      revert("uint overflow: unable insert more entries");
    }

    index = ++_self.entriesLength;
    _self.entries[index] = Entry(
      _key,
      _value,
      [uint(0), uint(0)],
      1,
      RED
    );

    entry = _self.entries[index];
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
  /// @param _root root node to be rotated around
  /// @param _rootIdx entry index of the root node
  /// @param _direction rotation direction
  /// @return entry index of the new root node
  function _rotateSingle(Map storage _self, Entry storage _root, uint _rootIdx, uint8 _direction)
  internal
  returns(uint newRootIdx)
  {
    // make "old root left child" as "new root"
    newRootIdx = _root.links[1 - _direction];
    Entry storage newRoot = _self.entries[newRootIdx];

    // make "new root's right child" as "old root's left child"
    _root.links[1 - _direction] = newRoot.links[_direction];
    // make "old root" as "new root's right child"
    newRoot.links[_direction] = _rootIdx;

    // apply colors
    _root.color = RED;
    newRoot.color = BLACK;

    // recalculate size
    // TODO: double check if these are required
    require(newRootIdx > 0);
    newRoot.size = _root.size;
    require(_rootIdx > 0);
    _root.size = _leftChild(_self, _root).size + _rightChild(_self, _root).size + 1;
  }

  /// @dev apply tree rotation around a root node in a specified direction twice.
  ///  Inline code documentation assumes `direction` = `RIGHT` for simplicity
  ///  and one can see both cases are symmetric.
  /// @param _root root node to be rotated around
  /// @param _rootIdx entry index of the root node
  /// @param _direction rotation direction
  /// @return entry index of the new root node
  function _rotateDouble(Map storage _self, Entry storage _root, uint _rootIdx, uint8 _direction)
  internal
  returns(uint newRootIdx)
  {
    // rotate "root's left child" in the opposite direction first and update "old root" child link
    uint8 otherDirection = 1 - _direction;
    _root.links[otherDirection] = _rotateSingle(
      _self,
      _self.entries[_root.links[otherDirection]],
      _root.links[otherDirection],
      otherDirection
    );

    return _rotateSingle(_self, _root, _rootIdx, _direction);
  }

  /// @dev increment tree size when new entry is added in `probe`.
  function _incrementTreeSize(Map storage _self, uint _key)
  internal
  {
    uint rootIdx = _self.entries[0].links[RIGHT];
    Entry storage current = _self.entries[rootIdx];
    if (rootIdx == 0 || current.size == 0) {
      revert("increment should not be called on an empty tree");
    }

    while (current.key != _key) {
      current.size++;

      if (current.key < _key) {
        current = _rightChild(_self, current);
      } else {
        current = _leftChild(_self, current);
      }
    }
  }

  /// @dev set root node to BLACK color
  ///  factored out to avoid `CompilerError: Stack too deep, try removing local variables.`
  function _setRootToBlack(Map storage _self)
  internal
  {
    _self.entries[_self.rootIdx].color = BLACK;
  }

  /// @dev flip color if applicable during probe()
  ///  factored out to avoid `CompilerError: Stack too deep, try removing local variables.`
  function _flipColorInProbe(Map storage _self, Entry storage _current)
  internal
  {
    Entry storage left = _leftChild(_self, _current);
    Entry storage right = _rightChild(_self, _current);
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
      _current.color = RED;
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
  /// @param _key key with which the specified value is to be associated
  /// @param _value value to be associated with the specified key
  /// @return storage pointer to entry corresponding to the key
  function probe(Map storage _self, uint _key, uint _value)
  internal
  returns(Entry storage entry)
  {
    // workaround for compilation warning on `entry` potentially be unassigned
    // in reality, it is guranteed to be assigned by the algorithm
    entry = entry;

    if (_self.rootIdx == 0) {
      // insert into an empty tree
      (_self.rootIdx, entry) = _makeEntry(_self, _key, _value);
    } else {
      // false tree root
      // iterator's parent
      uint previousIdx = 0;
      Entry storage previous = _self.entries[0];
      previous.links[RIGHT] = _self.rootIdx;

      // iterator
      uint currentIdx = _self.rootIdx;
      Entry storage current = _self.entries[currentIdx];

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
        if (current.size == 0) {
          // insert new node at the bottom
          (currentIdx, current) = _makeEntry(_self, _key, _value);
          previous.links[direction] = currentIdx;
          // increment all parent entry size
          _incrementTreeSize(_self, _key);
        } else {
          _flipColorInProbe(_self, current);
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
            grandParent.links[parentDirection] = _rotateSingle(_self, parent, parentIdx, 1 - lastDirection);
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
            // unapply optimistic size change
            grandParent.links[parentDirection] = _rotateDouble(_self, parent, parentIdx, 1 - lastDirection);
            // fix previous tracking
            // NB: current will traverse without color flip till children of 0 or 4,
            //   correct linkage of parent/grandParent will be established by then.
            previous = grandParent;
          }
        }

        // stop if found
        if (current.key == _key) {
          entry = current;
          break;
        }

        // traverse down one level
        lastDirection = direction;
        direction = current.key < _key ? RIGHT : LEFT;

        // update helpers
        grandParent = parent;

        parentIdx = previousIdx;
        parent = previous;

        previousIdx = currentIdx;
        previous = current;

        currentIdx = current.links[direction];
        current = _self.entries[currentIdx];
      }

      // update root
      _self.rootIdx = _self.entries[0].links[RIGHT];
      _self.entries[0].links[RIGHT] = 0;
    }

    // reset root node to BLACK
    _setRootToBlack(_self);
  }

  /// @notice attempt to insert `item(key, value)` and returns `value` associated with `key` after insertion.
  ///  If `key` already existed in the tree, its original value is returned and no replacement of the item occurs.
  /// @param _key key with which the specified value is to be associated
  /// @param _value value to be associated with the specified key
  /// @return value associated with the specified key
  function putIfAbsent(Map storage _self, uint _key, uint _value)
  internal
  returns(uint value)
  {
    Entry storage entry = probe(_self, _key, _value);
    return entry.value;
  }

  /// @notice insert `item(key, value)` and replace any existing value if `key` is already in the tree.
  ///  return whether replacement occurred and value that was replaced.
  /// @param _key key with which the specified value is to be associated
  /// @param _value value to be associated with the specified key
  /// @return (wether value is replaced, value associated with the key before replacement)
  function put(Map storage _self, uint _key, uint _value)
  internal
  returns(bool replaced, uint oldValue)
  {
    Entry storage entry = probe(_self, _key, _value);
    if (entry.value != _value) {
      replaced = true;
      oldValue = entry.value;
      entry.value = _value;
    }
  }

  /// @dev apply colors as necessary after rotation in top-down deletion
  ///  factored out to avoid `CompilerError: Stack too deep, try removing local variables.`
  function _applyColorInRemove(
    Map storage _self,
    Entry storage _current,
    Entry storage _grandParent,
    uint8 _parentDirection
  )
  internal
  {
    _current.color = RED;
    Entry storage newGrandParent = _child(_self, _grandParent, _parentDirection);
    newGrandParent.color = RED;
    _leftChild(_self, newGrandParent).color = BLACK;
    _rightChild(_self, newGrandParent).color = BLACK;
  }

  /// @dev decrement tree size when entry is removed in `remove`.
  function _decrementTreeSize(Map storage _self, uint _key)
  internal
  {
    uint rootIdx = _self.entries[0].links[RIGHT];
    Entry storage current = _self.entries[rootIdx];
    if (rootIdx == 0 || current.size == 0) {
      revert("decrement should not be called on an empty tree");
    }

    while (current.key != _key) {
      current.size--;

      if (current.key < _key) {
        current = _rightChild(_self, current);
      } else {
        current = _leftChild(_self, current);
      }
    }
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
  /// @param _key key whose mapping is to be removed
  /// @return (whether a mapping has been removed, the value associated with the `key` before removal)
  function remove(Map storage _self, uint _key)
  internal
  returns(bool removed, uint oldValue)
  {
    if (_self.rootIdx != 0) {
      // false root head
      uint currentIdx = 0;
      Entry storage current = _self.entries[0];
      current.links[RIGHT] = _self.rootIdx;

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
        current = _self.entries[currentIdx];

        lastDirection = direction;
        direction = current.key < _key ? RIGHT : LEFT;

        // save found node
        if (current.key == _key) {
          toReplace = current;
        }

        // push the red node down
        if (!_isRed(current) && !_isChildRed(_self, current, direction)) {
          if (_isChildRed(_self, current, 1 - direction)) {
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
            parent.links[lastDirection] = _rotateSingle(_self, current, currentIdx, direction);
            parentIdx = parent.links[lastDirection];
            parent = _self.entries[parentIdx];
            lastDirection = direction;
          } else {
            // current and both current's children are black

            Entry storage sibling = _self.entries[parent.links[1 - lastDirection]];

            // if current doesn't have sibling but neither of its children is red
            // current must have no children at all otherwise it would lead to a black violation
            // and we will terminate at next iteration
            // NB: this normally can't happen because current can't be BLACK if it doesn't have sibling
            // it would be a black violation. it can only happen if current is a BLACK root without children
            if (sibling.size > 0) {
              // if both sibling's children are black, color flip does not lead to a red violation on sibling
              if (!_isChildRed(_self, sibling, LEFT) && !_isChildRed(_self, sibling, RIGHT)) {
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
                if (_isChildRed(_self, sibling, lastDirection)) {
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
                  grandParent.links[parentDirection] = _rotateDouble(_self, parent, parentIdx, lastDirection);
                } else {
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
                  grandParent.links[parentDirection] = _rotateSingle(_self, parent, parentIdx, lastDirection);
                }

                // apply colors
                _applyColorInRemove(_self, current, grandParent, parentDirection);
              }
            }
          }
        }
      }

      // replace and remove if found
      if (toReplace.size > 0) {
        // save old value
        removed = true;
        oldValue = toReplace.value;

        // reset tree size along the path
        _decrementTreeSize(_self, current.key);

        // replace old node with current iterator
        toReplace.key = current.key;
        toReplace.value = current.value;

        // splice remaining subtree of current node to its parent if applicable
        // NB: current.links[direction] has been checked to be empty
        parent.links[lastDirection] = current.links[1 - direction];
        // delete current node to free storage
        delete _self.entries[currentIdx];
      }

      // update root and make it black
      _self.rootIdx = _self.entries[0].links[RIGHT];
      _self.entries[0].links[RIGHT] = 0;
      _setRootToBlack(_self);
    }
  }

  /// @notice find the value to which the `key` is associated, or not found if the map does not contain such mapping
  /// @param _key key whose associated value is to be returned
  /// @return (whether a mapping with `key` exists, the value associated with the `key`)
  function get(Map storage _self, uint _key)
  internal
  view
  returns(bool found, uint value)
  {
    Entry storage current = _self.entries[_self.rootIdx];

    while (current.size > 0) {
      if (current.key == _key) {
        found = true;
        value = current.value;
        break;
      } else if (current.key < _key) {
        current = _rightChild(_self, current);
      } else {
        current = _leftChild(_self, current);
      }
    }
  }

  /// @notice find the value to which the `key` is associated, or `defaultValue` if the map does not contain such mapping
  /// @param _key key whose associated value is to be returned
  /// @param _defaultValue fallback value to be returned
  /// @return the value associated with the `key` or `defaultValue` if not found
  function getOrDefault(Map storage _self, uint _key, uint _defaultValue)
  internal
  view
  returns(uint value)
  {
    bool found;
    (found, value) = get(_self, _key);
    if (!found) {
      value = _defaultValue;
    }
  }

  /// @notice returns the size of the tree
  /// @dev O(1)
  function size(Map storage _self)
  internal
  view
  returns(uint)
  {
    return _self.entries[_self.rootIdx].size;
  }

  /// @notice returns the black height of the tree: the uniform number of
  ///  black nodes in all paths from root to the leaves.
  /// @dev this is useful to determine the size of stack to allocate for
  ///  iterators implemented in contract since memory array cannot be resized
  ///  NB: RBT guarantees the path from the root to the farthest leaf is no more
  ///  than twice as long as the path from the root to the nearest leaf.
  ///  O(log n)
  function blackHeight(Map storage _self)
  internal
  view
  returns(uint height)
  {
    Entry storage current = _self.entries[_self.rootIdx];

    while (current.size > 0) {
      if (current.color == BLACK) {
        height++;
      }
      current = _leftChild(_self, current);
    }
  }

  /// @notice returns an entry associated with the greatest key less than or equal to the given key
  /// @dev O(log n)
  /// @return whether such entry exists and its key and value
  function floorEntry(Map storage _self, uint _key)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage candidate = _self.entries[0];
    Entry storage current = _self.entries[_self.rootIdx];

    while (current.size > 0) {
      if (current.key == _key) {
        candidate = current;
        break;
      } else if (current.key > _key) {
        current = _leftChild(_self, current);
      } else {
        // NB: in iterations, we will only find greater keys than previously seen ones
        candidate = current;
        current = _rightChild(_self, current);
      }
    }

    if (candidate.size > 0) {
      found = true;
      key = candidate.key;
      value = candidate.value;
    }
  }

  /// @notice returns an entry associated with the greatest key less than the given key
  /// @dev O(log n)
  /// @return whether such entry exists and its key and value
  function lowerEntry(Map storage _self, uint _key)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage candidate = _self.entries[0];
    Entry storage current = _self.entries[_self.rootIdx];

    while (current.size > 0) {
      if (current.key >= _key) {
        current = _leftChild(_self, current);
      } else {
        // NB: in iterations, we will only find greater keys than previously seen ones
        candidate = current;
        current = _rightChild(_self, current);
      }
    }

    if (candidate.size > 0) {
      found = true;
      key = candidate.key;
      value = candidate.value;
    }
  }

  /// @notice returns an entry associated with the least key greater than or equal to the given key
  /// @dev O(log n)
  /// @return whether such entry exists and its key and value
  function ceilingEntry(Map storage _self, uint _key)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage candidate = _self.entries[0];
    Entry storage current = _self.entries[_self.rootIdx];

    while (current.size > 0) {
      if (current.key == _key) {
        candidate = current;
        break;
      } else if (current.key < _key) {
        current = _rightChild(_self, current);
      } else {
        // NB: in iterations, we will only find lesser keys than previously seen ones
        candidate = current;
        current = _leftChild(_self, current);
      }
    }

    if (candidate.size > 0) {
      found = true;
      key = candidate.key;
      value = candidate.value;
    }
  }

  /// @notice returns an entry associated with the least key greater than the given key
  /// @dev O(log n)
  /// @return whether such entry exists and its key and value
  function higherEntry(Map storage _self, uint _key)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage candidate = _self.entries[0];
    Entry storage current = _self.entries[_self.rootIdx];

    while (current.size > 0) {
      if (current.key <= _key) {
        current = _rightChild(_self, current);
      } else {
        candidate = current;
        current = _leftChild(_self, current);
      }
    }

    if (candidate.size > 0) {
      found = true;
      key = candidate.key;
      value = candidate.value;
    }
  }

  /// @notice returns the entry associated with the lowest key
  /// @dev O(log n)
  /// @return whether such entry exists and its key and value
  function firstEntry(Map storage _self)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage previous = _self.entries[_self.rootIdx];
    Entry storage current = _leftChild(_self, previous);

    while (current.size > 0) {
      previous = current;
      current = _leftChild(_self, current);
    }

    if (previous.size > 0) {
      found = true;
      key = previous.key;
      value = previous.value;
    }
  }

  /// @notice returns the entry associated with the highest key
  /// @dev O(log n)
  /// @return whether such entry exists and its key and value
  function lastEntry(Map storage _self)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    Entry storage previous = _self.entries[_self.rootIdx];
    Entry storage current = _rightChild(_self, previous);

    while (current.size > 0) {
      previous = current;
      current = _rightChild(_self, current);
    }

    if (previous.size > 0) {
      found = true;
      key = previous.key;
      value = previous.value;
    }
  }

  /// @notice find the i'th smallest element stored in the tree
  function select(Map storage _self, uint _i)
  internal
  view
  returns(bool found, uint key, uint value)
  {
    uint i = _i;
    Entry storage current = _self.entries[_self.rootIdx];
    Entry storage leftChild = _leftChild(_self, current);
    while (current.size > i) {
      if (leftChild.size == i) {
        return (true, current.key, current.value);
      } else if (i < leftChild.size) {
        current = leftChild;
      } else {
        current = _rightChild(_self, current);
        i -= leftChild.size + 1;
      }

      leftChild = _leftChild(_self, current);
    }
  }

  /// @notice find the rank of element x in the tree,
  ///  i.e. its index in the sorted list of elements of the tree
  /// @return whether `_key` already existed in the map and its index (or insertion index if not found)
  function rank(Map storage _self, uint _key)
  internal
  view
  returns(bool found, uint index)
  {
    Entry storage current = _self.entries[_self.rootIdx];
    while (current.size > 0) {
      if (current.key == _key) {
        index += _leftChild(_self, current).size;
        found = true;
        break;
      } else if (current.key < _key) {
        index += _leftChild(_self, current).size + 1;
        current = _rightChild(_self, current);
      } else {
        current = _leftChild(_self, current);
      }
    }
  }
}
