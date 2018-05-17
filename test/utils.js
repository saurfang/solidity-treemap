/**
 * Shuffles array in place. ES6 version
 * https://stackoverflow.com/questions/6274339/how-can-i-shuffle-an-array
 * @param {Array} a items An array containing the items.
 */
export function shuffle(a) {
  for (let i = a.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]]; // eslint-disable-line no-param-reassign
  }
  return a;
}

export function alternatingOutsideInOrder(a) {
  const b = [];
  for (let i = 0; i < a.length / 2; i += 1) {
    b.push(a[i]);
  }
  for (let i = a.length - 1; i >= a.length / 2; i -= 1) {
    b.splice(((a.length - i) * 2) - 1, 0, a[i]);
  }

  return b;
}

export async function printMap(treeMap) {
  return (await treeMap.entries()).map((arr) => {
    if (arr.toNumber) {
      return arr.toNumber();
    }

    if (arr[0].toNumber) {
      return arr.map(x => x.toNumber());
    }

    return arr;
  });
}
