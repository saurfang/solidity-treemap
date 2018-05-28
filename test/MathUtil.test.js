import EVMRevert from 'openzeppelin-solidity/test/helpers/EVMRevert';

const { BigNumber } = web3;
const MathUtilTest = artifacts.require('MathUtilTest');

require('chai')
  .use(require('chai-bignumber')(BigNumber))
  .use(require('chai-as-promised'))
  .should();


contract('MathUtilTest', () => {
  let mathUtil;

  beforeEach(async () => {
    mathUtil = await MathUtilTest.new();
  });

  describe('ceilLog2', () => {
    it('throws for 0', async () => {
      await mathUtil.ceilLog2(0).should.be.rejectedWith(EVMRevert);
    });

    describe('works for', () => {
      it('1', async () => {
        (await mathUtil.ceilLog2(1)).should.be.bignumber.equal(0);
      });

      it('2 to 16', async () => {
        const numbers = [];
        for (let i = 2; i <= 16; i += 1) {
          numbers.push(i);
        }
        await Promise.all(numbers
          .map(async (i) => {
            const expected = Math.ceil(Math.log2(i));
            return (await mathUtil.ceilLog2(i)).should.be.bignumber.equal(expected, `log2(${i})`);
          }));
      });

      it('2**(4 to 256) +- 1', async () => {
        const numbers = [];
        for (let i = 4; i <= 255; i += 1) {
          const x = (new BigNumber(2)).pow(i);
          numbers.push([i, x.minus(1)]);
          numbers.push([i, x]);
          numbers.push([i + 1, x.plus(1)]);
        }
        numbers.push([256, (new BigNumber(2)).pow(256).minus(1)]);

        await Promise.all(numbers
          .map(async ([expected, i]) =>
            (await mathUtil.ceilLog2(i)).should.be.bignumber.equal(expected)));
      });
    });
  });
});
