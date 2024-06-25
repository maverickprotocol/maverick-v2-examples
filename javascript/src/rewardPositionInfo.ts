import { ethers, Contract } from 'ethers';
import MaverickV2RewardFactoryABI from '../abis/MaverickV2RewardFactory.json';
import MaverickV2RewardABI from '../abis/MaverickV2Reward.json';
import MaverickV2BoostedPositionLensABI from '../abis/MaverickV2BoostedPositionLens.json';

import {
  fetchBoostedPositionDetails,
  makeAsset,
} from './boostedPositionInfo.js';

import { CONTRACTS, Network, RPC_URL } from './constants.js';
import { RewardPosition } from './types.js';

async function fetchRewardPositionDetails(
  network: Network,
  reward: Contract,
  nftId: number,
): Promise<RewardPosition> {
  const provider = new ethers.JsonRpcProvider(RPC_URL[network]);
  const boostedPositionLens = new ethers.Contract(
    CONTRACTS[network].MaverickV2BoostedPositionLens,
    MaverickV2BoostedPositionLensABI,
    provider,
  );

  const bpInfo = await fetchBoostedPositionDetails(
    network,
    boostedPositionLens,
    await reward.stakingToken(),
    await reward.getAddress(),
  );

  const userStakeBalance = await reward.stakeBalanceOf(nftId);
  const userTotalSupply = await reward.stakeTotalSupply();

  let ret: RewardPosition = {
    boostedPosition: bpInfo,
    network: network,
    tokenAssets: bpInfo.tokenAssets.map((asset) => {
      return makeAsset(
        asset.token,
        (asset.tokenAmount * userStakeBalance) / userTotalSupply,
      );
    }),
  } as RewardPosition;

  return ret;
}

export async function fetchRewardPositionNftIdDataForUser(
  network: Network,
  rewardAddress: string,
  address: string,
): Promise<RewardPosition[]> {
  const provider = new ethers.JsonRpcProvider(RPC_URL[network]);

  const rewardContract = new ethers.Contract(
    rewardAddress,
    MaverickV2RewardABI,
    provider,
  );

  const nftIds = await rewardContract.tokenIdsOfOwner(address);

  return Promise.all(
    nftIds.map((nftId) =>
      fetchRewardPositionDetails(network, rewardContract, nftId),
    ),
  );
}

export async function fetchAllRewardDataForUser(
  network: Network,
  address: string,
  startIndex: number = 0,
  endIndex: number = 100,
): Promise<RewardPosition[][]> {
  const provider = new ethers.JsonRpcProvider(RPC_URL[network]);

  const rewardFactory = new ethers.Contract(
    CONTRACTS[network].MaverickV2RewardFactory,
    MaverickV2RewardFactoryABI,
    provider,
  );
  const rewards: string[] = await rewardFactory.rewards(startIndex, endIndex);

  return Promise.all(
    rewards.map((reward) =>
      fetchRewardPositionNftIdDataForUser(network, reward, address),
    ),
  );
}
