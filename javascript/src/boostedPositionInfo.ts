import { ethers, Contract } from 'ethers';
import MaverickV2BoostedPositionFactoryABI from '../abis/MaverickV2BoostedPositionFactory.json';
import MaverickV2BoostedPositionLensABI from '../abis/MaverickV2BoostedPositionLens.json';

import { CONTRACTS, Network, RPC_URL } from './constants.js';
import { Asset, BoostedPosition } from './types.js';

export function makeAsset(token: string, amount: number): Asset {
  return { token: token, tokenAmount: amount };
}

export async function fetchBoostedPositionDetails(
  network: Network,
  boostedPositionLens: Contract,
  bp: string,
  address: string,
): Promise<BoostedPosition> {
  const bpInfo = await boostedPositionLens.boostedPositionUserInformation(
    bp,
    address,
  );
  const tokenA = bpInfo.info.tokenA;
  const tokenB = bpInfo.info.tokenB;

  let assets: Asset[] = [];
  assets.push(makeAsset(tokenA, bpInfo.userAmountA));
  assets.push(makeAsset(tokenB, bpInfo.userAmountB));

  let ret: BoostedPosition = {
    boostedPosition: bp,
    network: network,
    tokenAssets: assets,
  } as BoostedPosition;

  return ret;
}

export async function fetchAllBoostedPositionDataForUser(
  network: Network,
  address: string,
  startIndex: number = 0,
  endIndex: number = 100,
): Promise<BoostedPosition[]> {
  const provider = new ethers.JsonRpcProvider(RPC_URL[network]);

  const boostedPositionFactory = new ethers.Contract(
    CONTRACTS[network].MaverickV2BoostedPositionFactory,
    MaverickV2BoostedPositionFactoryABI,
    provider,
  );
  const boostedPositionLens = new ethers.Contract(
    CONTRACTS[network].MaverickV2BoostedPositionLens,
    MaverickV2BoostedPositionLensABI,
    provider,
  );

  const bps: string[] = await boostedPositionFactory['lookup(uint256,uint256)'](
    startIndex,
    endIndex,
  );

  return Promise.all(
    bps.map((bp) =>
      fetchBoostedPositionDetails(network, boostedPositionLens, bp, address),
    ),
  );
}
