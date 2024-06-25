import { ethers } from 'ethers';
import MaverickV2FactoryABI from '../abis/MaverickV2Factory.json';
import MaverickV2PoolABI from '../abis/MaverickV2Pool.json';
import MaverickV2PoolLensABI from '../abis/MaverickV2PoolLens.json';

import { CONTRACTS, Network, RPC_URL } from './constants.js';
import { Multicall } from 'ethereum-multicall';
import { Pool } from './types.js';

export async function fetchPoolDetails(network: Network, poolAddress: string) {
  const multicall = new Multicall({
    nodeUrl: RPC_URL[network],
    tryAggregate: true,
  });
  const lensContract = new ethers.Contract(
    CONTRACTS[network].MaverickV2PoolLens,
    MaverickV2PoolLensABI,
    new ethers.JsonRpcProvider(RPC_URL[network]),
  );
  const calls = [
    { methodName: 'tokenA', reference: 'tokenA', methodParameters: [] },
    { methodName: 'tokenB', reference: 'tokenB', methodParameters: [] },
    {
      methodName: 'tickSpacing',
      reference: 'tickSpacing',
      methodParameters: [],
    },
    { methodName: 'lookback', reference: 'lookback', methodParameters: [] },
    { methodName: 'fee(bool)', reference: 'fee', methodParameters: [true] },
    { methodName: 'fee(bool)', reference: 'fee', methodParameters: [false] },
    { methodName: 'getState', reference: 'getState', methodParameters: [] },
    {
      methodName: 'getCurrentTwa',
      reference: 'getCurrentTwa',
      methodParameters: [],
    },
  ];

  const result = await multicall.call({
    reference: 'result0',
    contractAddress: poolAddress,
    abi: MaverickV2PoolABI,
    calls: calls,
  });

  const sqrtPrice = await lensContract.getPoolSqrtPrice(poolAddress);

  const resultList = result.results.result0.callsReturnContext;

  return {
    tokenA: resultList[0].returnValues[0],
    tokenB: resultList[1].returnValues[0],
    tickSpacing: resultList[2].returnValues[0],
    lookback: resultList[3].returnValues[0],
    feeAIn: resultList[4].returnValues[0],
    feeBIn: resultList[5].returnValues[0],
    state: {
      reserveA: resultList[6].returnValues[0],
      reserveB: resultList[6].returnValues[1],
      lastTwaD8: resultList[6].returnValues[2],
      lastLogPriceD8: resultList[6].returnValues[3],
      lastTimestamp: resultList[6].returnValues[4],
      activeTick: resultList[6].returnValues[5],
      isLocked: resultList[6].returnValues[6],
      binCounter: resultList[6].returnValues[7],
      protocolFeeRatioD3: resultList[6].returnValues[8],
    },
    currentTwa: resultList[7].returnValues[0],
    price: BigInt(sqrtPrice * sqrtPrice) / BigInt(1e18),
  };
}

export async function fetchAllPools(network: Network): Promise<Pool[]> {
  const provider = new ethers.JsonRpcProvider(RPC_URL[network]);

  const factoryContract = new ethers.Contract(
    CONTRACTS[network].MaverickV2Factory,
    MaverickV2FactoryABI,
    provider,
  );

  const poolAddresses = await factoryContract.lookup(0, 10);

  return Promise.all(
    poolAddresses.map((poolAddress) => fetchPoolDetails(network, poolAddress)),
  );
}
