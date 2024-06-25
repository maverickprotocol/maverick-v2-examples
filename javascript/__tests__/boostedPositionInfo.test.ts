import { Network } from '../src/constants.js';
import { fetchAllBoostedPositionDataForUser } from '../src/boostedPositionInfo.js';

describe('fetch boosted positions', () => {
  it('fetches boosted positions', async () => {
    const ids = await fetchAllBoostedPositionDataForUser(
      Network.MAINNET,
      '0x665E09ce70c4B15ad159B7Be60DB7EEBbADeE933',
    );
    console.log(ids.map((val) => val.tokenAssets));
  }, 10000);
});
