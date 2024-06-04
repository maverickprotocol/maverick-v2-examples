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
    MaverickV2Factory: '0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e',
    MaverickV2PoolLens: '0x56eFfDD51b20705e152CAF482D9A6972e97B571C',
  },
  [Network.SEPOLIA]: {
    MaverickV2Factory: '0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e',
    MaverickV2PoolLens: '0x56eFfDD51b20705e152CAF482D9A6972e97B571C',
  },
};

export const RPC_URL = {
  [Network.MAINNET]: 'https://eth.llamarpc.com',
  [Network.BASE]: 'https://base.llamarpc.com',
  [Network.SEPOLIA]: 'https://ethereum-sepolia-rpc.publicnode.com',
};
