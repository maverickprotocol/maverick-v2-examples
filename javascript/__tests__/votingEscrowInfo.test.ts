import { Network } from '../src/constants.js';
import { fetchTotalVotingEscrowAssets } from '../src/votingEscrowInfo.js';

describe('fetch ve lockups', () => {
  it('fetches ve lockups', async () => {
    const data = await fetchTotalVotingEscrowAssets(
      Network.MAINNET,
      '0xeBb8511067a1E3DF8B5fB7F9B6d5676D8D550761',
      '0xC6addB3327A7D4b3b604227f82A6259Ca7112053', //veMav
    );
    console.log(data);
  }, 10000);
});
