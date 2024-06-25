import { Network } from '../src/constants.js';
import { fetchAllPools } from '../src/poolInfo.js';

describe('fetch pools', () => {
  it('fetches all of the pools', async () => {
    const pools = await fetchAllPools(Network.BASE);
    console.log(pools);
  }, 10000);
});
