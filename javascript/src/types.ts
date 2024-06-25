import { BigNumberish } from 'ethers';
import { Network } from './constants.js';

export interface Pool {
  tokenA: string;
  tokenB: string;
  tickSpacing: number;
  lookback: BigNumberish;
  feeAIn: BigNumberish;
  feeBIn: BigNumberish;
  state: {
    reserveA: BigNumberish;
    reserveB: BigNumberish;
    lastTwaD8: BigNumberish;
    lastLogPriceD8: BigNumberish;
    lastTimestamp: number;
    activeTick: number;
    binCounter: number;
    protocolFeeRatioD3: BigNumberish;
  };
  currentTwa: BigNumberish;
}

export interface Asset {
  token: string;
  tokenAmount: number;
}

export interface Position {
  nftId: number;
  network: Network;
  tokenAssets: Asset[];
}

export interface BoostedPosition {
  boostedPosition: string;
  network: Network;
  tokenAssets: Asset[];
}

export interface RewardPosition {
  boostedPosition: BoostedPosition;
  network: Network;
  tokenAssets: Asset[];
}

export interface LockupInfo {
  lockupId: number;
  tokenAssets: Asset;
}

export interface VeLockupInfo {
  votingEscrow: string;
  network: Network;
  totalTokenAssets: Asset;
  lockups: LockupInfo[];
}
