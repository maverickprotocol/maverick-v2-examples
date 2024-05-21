import { BigNumberish } from 'ethers';

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
