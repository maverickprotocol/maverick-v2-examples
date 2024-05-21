export enum Network {
  MAINNET = 1,
  BASE = 8453,
  SEPOLIA = 11155111,
}

export const CONTRACTS = {
  [Network.MAINNET]: {
    MaverickV2Factory: '',
    MaverickV2PoolLens: '',
  },
  [Network.BASE]: {
    MaverickV2Factory: '0x1D7472AAfe52e83BA22E707Fc77fF3F3b85551CC',
    MaverickV2PoolLens: '0x8deC2E5Ba4e26DD2EC19da882976EeA00d03dE88',
  },
  [Network.SEPOLIA]: {
    MaverickV2Factory: '0x1D7472AAfe52e83BA22E707Fc77fF3F3b85551CC',
    MaverickV2PoolLens: '0x8deC2E5Ba4e26DD2EC19da882976EeA00d03dE88',
  },
};

export const RPC_URL = {
  [Network.MAINNET]: 'https://eth.llamarpc.com',
  [Network.BASE]: 'https://base.llamarpc.com',
  [Network.SEPOLIA]: 'https://ethereum-sepolia-rpc.publicnode.com',
};
