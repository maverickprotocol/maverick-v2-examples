import { Network } from '../src/constants.js';
import { fetchAllRewardDataForUser } from '../src/rewardPositionInfo.js';

describe('fetch reward positions', () => {
  it('fetches reward positions', async () => {
    const ids = await fetchAllRewardDataForUser(
      Network.MAINNET,
      '0xf4030cd3B27e279D011C88E6073eE6b903b83d36',
    );
    console.log(ids.flat())
  }, 10000);
});
