pragma solidity ^0.4.23;


import "../../contracts/TreeMap.sol";
import "../../contracts/mocks/TreeMapTest.sol";


contract TreeMapMock {
  using TreeMap for TreeMap.Map;
  using TreeMapTest for TreeMap.Map;

  TreeMap.Map sortedMap;

  function size()
  public
  view
  returns(uint)
  {
    return sortedMap.size();
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
  returns(uint rootIdx, uint[] keys, uint[] values, uint[] lefts, uint[] rights, bool[] colors, uint[] sizes)
  {
    rootIdx = sortedMap.rootIdx;
    keys = new uint[](sortedMap.entriesLength + 1);
    values = new uint[](sortedMap.entriesLength + 1);
    lefts = new uint[](sortedMap.entriesLength + 1);
    rights = new uint[](sortedMap.entriesLength + 1);
    colors = new bool[](sortedMap.entriesLength + 1);
    sizes = new uint[](sortedMap.entriesLength + 1);

    for (uint i = 0; i <= sortedMap.entriesLength; i++) {
      TreeMap.Entry storage entry = sortedMap.entries[i];
      keys[i] = entry.key;
      values[i] = entry.value;
      lefts[i] = entry.links[0];
      rights[i] = entry.links[1];
      colors[i] = entry.color;
      sizes[i] = entry.size;
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
    newValue = sortedMap.putIfAbsent(key, value);
    checkHeight();
  }

  function put(uint key, uint value)
  public
  returns(bool replaced, uint oldValue)
  {
    (replaced, oldValue) = sortedMap.put(key, value);
    checkHeight();
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
    // checkHeight();
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

  function floorEntry(uint _key)
  public
  view
  returns(bool found, uint key, uint value)
  {
    return sortedMap.floorEntry(_key);
  }

  function ceilingEntry(uint _key)
  public
  view
  returns(bool found, uint key, uint value)
  {
    return sortedMap.ceilingEntry(_key);
  }

  function higherEntry(uint _key)
  public
  view
  returns(bool found, uint key, uint value)
  {
    return sortedMap.higherEntry(_key);
  }

  function lowerEntry(uint _key)
  public
  view
  returns(bool found, uint key, uint value)
  {
    return sortedMap.lowerEntry(_key);
  }

  function firstEntry()
  public
  view
  returns(bool found, uint key, uint value)
  {
    return sortedMap.firstEntry();
  }

  function lastEntry()
  public
  view
  returns(bool found, uint key, uint value)
  {
    return sortedMap.lastEntry();
  }

  function checkHeight()
  public
  view
  returns(uint)
  {
    return sortedMap.checkHeight(sortedMap.entries[sortedMap.rootIdx]);
  }

  function blackHeight()
  public
  view
  returns(uint)
  {
    return sortedMap.blackHeight();
  }

  function select(uint i)
  public
  view
  returns(bool found, uint key, uint value)
  {
    return sortedMap.select(i);
  }

  function selectAll(uint[] indices)
  public
  view
  returns(bool[] found, uint[] keys, uint[] values)
  {
    found = new bool[](indices.length);
    keys = new uint[](indices.length);
    values = new uint[](indices.length);

    for (uint i = 0; i < indices.length; i++) {
      (found[i], keys[i], values[i]) = select(indices[i]);
    }
  }

  function rank(uint key)
  public
  view
  returns(bool found, uint index)
  {
    return sortedMap.rank(key);
  }

  function rankAll(uint[] keys)
  public
  view
  returns(bool[] found, uint[] indices)
  {
    found = new bool[](keys.length);
    indices = new uint[](keys.length);

    for (uint i = 0; i < keys.length; i++) {
      (found[i], indices[i]) = rank(keys[i]);
    }
  }
}
