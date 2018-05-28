
// eslint-disable-next-line
import { shuffle, alternatingOutsideInOrder, printMap } from './utils';

const { BigNumber } = web3;
const TreeMapMock = artifacts.require('TreeMapMock');

require('chai')
  .use(require('chai-bignumber')(BigNumber))
  .should();

contract('TreeMapMock', () => {
  let treeMap;
  const keys = [];
  for (let i = 0; i < 8; i += 1) {
    keys.push(i);
  }
  const toValue = i => i * 2;

  beforeEach(async () => {
    treeMap = await TreeMapMock.new();
  });

  describe('simple case', () => {
    it('works for put and get', async () => {
      // get should return not found first
      const [foundBefore] = await treeMap.get(10);
      foundBefore.should.equal(false, 'should not found value');

      // getOrDefault should return default value
      const defaultValue = await treeMap.getOrDefault(10, 101);
      defaultValue.should.be.bignumber.equal(101, 'returns default value');

      // get should return previously put value
      await treeMap.put(10, 100);
      const [found, value] = await treeMap.get(10);
      found.should.equal(true, 'should found value');
      value.should.be.bignumber.equal(100, 'returns value put');

      // getOrDefault should return actual value
      const actualValue = await treeMap.getOrDefault(10, 101);
      actualValue.should.be.bignumber.equal(100, 'returns actual value');

      (await treeMap.size()).should.be.bignumber.equal(1, 'treemap has one entry');
    });

    it('works for remove', async () => {
      // remove should return not found first
      const [removedBefore] = await treeMap.remove.call(10);
      removedBefore.should.equal(false, 'remove should fail on empty tree');

      await treeMap.put(10, 100);

      // remove should return not found on non-existent value
      const [removedNonExistent] = await treeMap.remove.call(11);
      removedNonExistent.should.equal(false, 'remove should fail on non-existent value');

      // remove should remove requested value
      const [removed, value] = await treeMap.remove.call(10);
      removed.should.equal(true, 'remove should succeed');
      value.should.be.bignumber.equal(100);
      // actually execute removal
      await treeMap.remove(10);

      const [found] = await treeMap.get(10);
      found.should.equal(false, 'element should not be found');

      (await treeMap.size()).should.be.bignumber.equal(0, 'treemap is empty');
    });

    it('works for put and putIfAbsent', async () => {
      const [firstReplace] = await treeMap.put.call(10, 100);
      firstReplace.should.equal(false, 'nothing to replace');
      await treeMap.put(10, 100);

      // replace old value
      const [toReplace, oldValue] = await treeMap.put.call(10, 101);
      toReplace.should.equal(true, 'will replace');
      oldValue.should.be.bignumber.equal(100, 'will replace');

      await treeMap.put(10, 101);
      const [, value] = await treeMap.get(10);
      value.should.be.bignumber.equal(101, 'value is replaced');


      (await treeMap.putIfAbsent.call(10, 102)).should.be.bignumber.equal(101, 'will not replace');

      await treeMap.putIfAbsent(10, 102);
      const [, newValue] = await treeMap.get(10);
      newValue.should.be.bignumber.equal(101, 'did not replace');
    });

    it('returns the correct tree height', async () => {
      await treeMap.putAll(keys, keys.map(toValue));
      (await treeMap.size()).should.be.bignumber.equal(keys.length);
      (await treeMap.blackHeight()).should.be.bignumber.equal((await treeMap.checkHeight()));
    });
  });

  describe('insertions should work with', () => {
    async function assertInsertions(input) {
      await treeMap.putAll(input, input.map(toValue));

      const [found, results] = await treeMap.getAll(keys);

      found.forEach(i => i.should.equal(true));
      results.forEach((v, k) => v.should.be.bignumber.equal(toValue(keys[k])));
    }

    it('elements in sorted order', async () => {
      await assertInsertions(keys);
    });

    it('elements in reverse sorted order', async () => {
      await assertInsertions(keys.slice(0).reverse());
    });

    it('elements in alternating outside-in order', async () => {
      const input = alternatingOutsideInOrder(keys.slice(0));
      await assertInsertions(input);
    });

    it('elements in any order', async () => {
      const input = shuffle(keys.slice(0));
      // eslint-disable-next-line
      console.log(input);
      await assertInsertions(input);
    });
  });

  describe('delete should work with', () => {
    async function assertDeletion(input) {
      const insertionInput = shuffle(input.slice(0));
      await treeMap.putAll(insertionInput, insertionInput.map(toValue));

      const [removed, values] = await treeMap.removeAll.call(input);

      removed.forEach((x, i) => x.should.equal(true, `failed to remove ${i}`));
      values.forEach((v, i) => v.should.be.bignumber.equal(toValue(input[i])));

      await treeMap.removeAll(input);

      (await treeMap.isEmpty()).should.equal(true, 'tree should be empty');

      return true;
    }

    it('elements in sorted order', async () => {
      await assertDeletion(keys);
    });

    it('elements in reverse sorted order', async () => {
      const input = keys.slice(0).reverse();
      await assertDeletion(input);
    });

    it('elements in alternating outside-in order', async () => {
      const input = alternatingOutsideInOrder(keys.slice(0));
      await assertDeletion(input);
    });

    it('elements in any order', async () => {
      const input = shuffle(keys.slice(0));
      // eslint-disable-next-line
      console.log(input);
      await assertDeletion(input);
    });

    // it.only('in specific order', async () => {
    //   await treeMap.putAll(keys, keys.map(toValue));

    //   const input = [1, 3, 5, 6, 4, 0, 2, 7];
    //   for (let i = 0; i < input.length; i += 1) {
    //     const k = input[i];
    //     const [removed, value] = await treeMap.remove.call(k);
    //     removed.should.equal(true, `failed to remove ${k}`);
    //     value.should.be.bignumber.equal(toValue(k));

    //     await treeMap.remove(k);

    //     console.log(await printMap(treeMap));
    //     await treeMap.checkHeight();
    //     console.log(`removed ${k}`);
    //   }
    // });
  });

  describe('navigable map', () => {
    it('can find ceiling and floor entries', async () => {
      // 1, 3, 5, ...
      const index = keys.map((x, i) => (i * 2) + 1);
      await treeMap.putAll(index, index.map(toValue));

      const minKey = index[0];
      const maxKey = index[index.length - 1];

      // edge cases where key doesn't exist
      ((await treeMap.floorEntry(minKey - 1))[0]).should.equal(false);
      ((await treeMap.ceilingEntry(maxKey + 1))[0]).should.equal(false);

      // traverse through the tree
      let found; let key; let value;

      [found, key, value] = await treeMap.floorEntry(5);
      found.should.equal(true);
      key.should.be.bignumber.equals(5);
      value.should.be.bignumber.equals(toValue(5));

      [found, key, value] = await treeMap.floorEntry(6);
      found.should.equal(true);
      key.should.be.bignumber.equals(5);
      value.should.be.bignumber.equals(toValue(5));

      [found, key, value] = await treeMap.ceilingEntry(5);
      found.should.equal(true);
      key.should.be.bignumber.equals(5);
      value.should.be.bignumber.equals(toValue(5));

      [found, key, value] = await treeMap.ceilingEntry(6);
      found.should.equal(true);
      key.should.be.bignumber.equals(7);
      value.should.be.bignumber.equals(toValue(7));
    });

    it('can find higher and lower entries', async () => {
      // 1, 3, 5, ...
      const index = keys.map((x, i) => (i * 2) + 1);
      await treeMap.putAll(index, index.map(toValue));

      const minKey = index[0];
      const maxKey = index[index.length - 1];

      // edge cases where key doesn't exist
      ((await treeMap.lowerEntry(minKey))[0]).should.equal(false);
      ((await treeMap.higherEntry(maxKey))[0]).should.equal(false);

      // traverse through the tree
      let found; let key; let value;

      [found, key, value] = await treeMap.lowerEntry(4);
      found.should.equal(true);
      key.should.be.bignumber.equals(3);
      value.should.be.bignumber.equals(toValue(3));

      [found, key, value] = await treeMap.lowerEntry(5);
      found.should.equal(true);
      key.should.be.bignumber.equals(3);
      value.should.be.bignumber.equals(toValue(3));

      [found, key, value] = await treeMap.higherEntry(5);
      found.should.equal(true);
      key.should.be.bignumber.equals(7);
      value.should.be.bignumber.equals(toValue(7));

      [found, key, value] = await treeMap.higherEntry(6);
      found.should.equal(true);
      key.should.be.bignumber.equals(7);
      value.should.be.bignumber.equals(toValue(7));
    });

    it('can find first and last entries', async () => {
      let found; let key; let value;

      // no entries yet
      [found, key, value] = await treeMap.firstEntry();
      found.should.equal(false);
      [found, key, value] = await treeMap.lastEntry();
      found.should.equal(false);


      await treeMap.putAll(keys, keys.map(toValue));

      [found, key, value] = await treeMap.firstEntry();
      found.should.equal(true);
      key.should.be.bignumber.equals(keys[0]);
      value.should.be.bignumber.equals(toValue(keys[0]));

      [found, key, value] = await treeMap.lastEntry();
      found.should.equal(true);
      key.should.be.bignumber.equals(keys[keys.length - 1]);
      value.should.be.bignumber.equals(toValue(keys[keys.length - 1]));
    });
  });

  describe('order static map', () => {
    it('can select entries by index', async () => {
      await treeMap.putAll(keys, keys.map(toValue));

      let found; let key; let value;
      [found, key, value] = await treeMap.selectAll(keys.map((x, i) => i));
      found.forEach(i => i.should.equal(true));
      key.forEach((v, k) => v.should.be.bignumber.equal(keys[k]));
      value.forEach((v, k) => v.should.be.bignumber.equal(toValue(keys[k])));

      // return not found for index out of bound
      [found, key, value] = await treeMap.select(keys.length);
      found.should.equal(false);
    });

    it('can rank entries', async () => {
      const input = keys.map(i => (2 * i) + 1);
      await treeMap.putAll(input, input.map(toValue));

      const testInput = [];
      for (let i = 0; i <= keys.length * 2; i += 1) {
        testInput.push(i);
      }

      const [found, indices] = await treeMap.rankAll(testInput);

      for (let i = 0; i < testInput.length; i += 1) {
        found[i].should.equal(i % 2 === 1);

        indices[i].should.be.bignumber.equal(Math.floor(i / 2));
      }
    });
  });
});
