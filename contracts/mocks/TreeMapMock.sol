pragma solidity ^0.4.23;


import "../../contracts/TreeMap.sol";


contract TreeMapMock {
  using TreeMap for TreeMap.Data;

  TreeMap.Data sortedMap;

  function size()
  public
  view
  returns(uint)
  {
    return sortedMap.size;
  }

  function isEmpty()
  public
  view
  returns(bool)
  {
    return size() == 0;
  }

  function entries()
  public
  view
  returns(uint rootIdx, uint[] keys, uint[] values, uint[] left, uint[] right, bool[] color, bool[] hasData)
  {
    rootIdx = sortedMap.rootIdx;
    keys = new uint[](sortedMap.entriesLength + 1);
    values = new uint[](sortedMap.entriesLength + 1);
    left = new uint[](sortedMap.entriesLength + 1);
    right = new uint[](sortedMap.entriesLength + 1);
    color = new bool[](sortedMap.entriesLength + 1);
    hasData = new bool[](sortedMap.entriesLength + 1);

    for (uint i = 0; i <= sortedMap.entriesLength; i++) {
      TreeMap.Entry storage entry = sortedMap.entries[i];
      keys[i] = entry.key;
      values[i] = entry.value;
      left[i] = entry.links[0];
      right[i] = entry.links[1];
      color[i] = entry.color;
      hasData[i] = entry.hasData;
    }
  }

  function get(uint key)
  public
  view
  returns(bool found, uint value)
  {
    return sortedMap.get(key);
  }

  function getOrDefault(uint key, uint defaultValue)
  public
  view
  returns(uint value)
  {
    return sortedMap.getOrDefault(key, defaultValue);
  }

  function getAll(uint[] keys)
  public
  view
  returns(bool[] found, uint[] values)
  {
    found = new bool[](keys.length);
    values = new uint[](keys.length);
    for (uint i = 0; i < keys.length; i++) {
      (found[i], values[i]) = get(keys[i]);
    }
  }

  function putIfAbsent(uint key, uint value)
  public
  returns(uint newValue)
  {
    return sortedMap.putIfAbsent(key, value);
  }

  function put(uint key, uint value)
  public
  returns(bool replaced, uint oldValue)
  {
    return sortedMap.put(key, value);
  }

  function putAll(uint[] keys, uint[] values)
  public
  returns(bool[] replaced, uint[] oldValues)
  {
    replaced = new bool[](keys.length);
    oldValues = new uint[](keys.length);

    for (uint i = 0; i < keys.length; i++) {
      (replaced[i], oldValues[i]) = put(keys[i], values[i]);
    }
  }

  function remove(uint key)
  public
  returns(bool removed, uint oldValue)
  {
    (removed, oldValue) = sortedMap.remove(key);
  }

  function removeAll(uint[] keys)
  public
  returns(bool[] removed, uint[] oldValues)
  {
    removed = new bool[](keys.length);
    oldValues = new uint[](keys.length);

    for (uint i = 0; i < keys.length; i++) {
      (removed[i], oldValues[i]) = remove(keys[i]);
    }
  }

  function isValid()
  public
  view
  returns(bool)
  {
    sortedMap._assert(sortedMap.entries[sortedMap.rootIdx]);
    return true;
  }
}
