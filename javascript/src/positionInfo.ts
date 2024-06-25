import { ethers, Contract } from 'ethers';
import MaverickV2PositionABI from '../abis/MaverickV2Position.json';
import MaverickV2PoolABI from '../abis/MaverickV2Pool.json';

import { CONTRACTS, Network, RPC_URL } from './constants.js';
import { Asset, Position } from './types.js';

function makeAsset(token: string, amount: number): Asset {
  return { token: token, tokenAmount: amount };
}

async function fetchAllPositionNftIdDetails(
  network: Network,
  positionContract: Contract,
  nftId: number,
): Promise<Position> {
  const provider = new ethers.JsonRpcProvider(RPC_URL[network]);
  const info = await positionContract[
    'tokenIdPositionInformation(uint256,uint256)'
  ](nftId, 0);

  const pool = new ethers.Contract(
    info.poolBinIds.pool,
    MaverickV2PoolABI,
    provider,
  );
  const tokenA = await pool.tokenA();
  const tokenB = await pool.tokenB();

  let assets: Asset[] = [];
  assets.push(makeAsset(tokenA, info.amountA));
  assets.push(makeAsset(tokenB, info.amountB));

  let ret: Position = {
    nftId: nftId,
    network: network,
    tokenAssets: assets,
  } as Position;

  return ret;
}

export async function fetchAllPositionNftIdDataForUser(
  network: Network,
  address: string,
): Promise<Position[]> {
  const provider = new ethers.JsonRpcProvider(RPC_URL[network]);

  const positionContract = new ethers.Contract(
    CONTRACTS[network].MaverickV2Position,
    MaverickV2PositionABI,
    provider,
  );

  const nftIds = await positionContract.tokenIdsOfOwner(address);

  return Promise.all(
    nftIds.map((nftId) =>
      fetchAllPositionNftIdDetails(network, positionContract, nftId),
    ),
  );
}
