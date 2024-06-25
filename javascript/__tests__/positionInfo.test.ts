import { Network } from '../src/constants.js';
import {  fetchAllPositionNftIdDataForUser} from '../src/positionInfo.js';

describe('fetch positions', () => {
  it('fetches positions', async () => {
    const ids = await fetchAllPositionNftIdDataForUser(
      Network.MAINNET,
      '0xfcF069D51559C68E34Ed47E3cc15Cb18792f115e',
    );
    console.log(ids.map((val) => val.tokenAssets));
  }, 10000);
});
