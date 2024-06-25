import { ethers } from 'ethers';
import MaverickV2VotingEscrowABI from '../abis/MaverickV2VotingEscrow.json';
import MaverickV2VotingEscrowLensABI from '../abis/MaverickV2VotingEscrowLens.json';

import { Network, RPC_URL, CONTRACTS } from './constants.js';
import { VeLockupInfo, LockupInfo } from './types.js';
import { makeAsset } from './boostedPositionInfo.js';

export async function fetchTotalVotingEscrowAssets(
  network: Network,
  address: string,
  votingEscrowAddress: string,
  startIndex: number = 0,
  endIndex: number = 100,
): Promise<VeLockupInfo> {
  const provider = new ethers.JsonRpcProvider(RPC_URL[network]);

  const veContract = new ethers.Contract(
    votingEscrowAddress,
    MaverickV2VotingEscrowABI,
    provider,
  );

  const veLens = new ethers.Contract(
    CONTRACTS[network].MaverickV2VotingEscrowLens,
    MaverickV2VotingEscrowLensABI,
    provider,
  );

  const token: string = await veContract.baseToken();

  const lockups = await veLens.getLockups(
    votingEscrowAddress,
    address,
    startIndex,
    endIndex,
  );

  let totalAmount: any = 0n;

  let lockupInfos = lockups.map((lockup, index: number) => {
    totalAmount = totalAmount + lockup.amount;
    return {
      lockupId: index,
      tokenAssets: makeAsset(token, lockup.amount),
    } as LockupInfo;
  });

  return {
    votingEscrow: votingEscrowAddress,
    network: network,
    totalTokenAssets: makeAsset(token, totalAmount),
    lockups: lockupInfos,
  } as VeLockupInfo;
}
