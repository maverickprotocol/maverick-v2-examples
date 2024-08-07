export enum Network {
  MAINNET = 1,
  SEPOLIA = 11155111,
  BASE = 8453,
  BASE_SEPOLIA = 84532,
  ARBITRUM = 42161,
  ARBITRUM_SEPOLIA = 421614,
  ZKSYNC = 324,
  ZKSYNC_SEPOLIA = 300,
  BNB = 56,
  BNB_TESTNET = 97,
}

export const CONTRACTS = {
  [Network.MAINNET]: {
    WETH: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
    MaverickV2Factory: '0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e',
    MaverickV2PoolLens: '0x6A9EB38DE5D349Fe751E0aDb4c0D9D391f94cc8D',
    MaverickV2Quoter: '0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A',
    MaverickV2Router: '0x62e31802c6145A2D5E842EeD8efe01fC224422fA',
    MaverickV2Position: '0x116193c58B40D50687c0433B2aa0cC4AE00bC32c',
    MaverickV2BoostedPositionFactory:
      '0xd94C8f6D13Cf480FfAC686712C63471D1596cc29',
    MaverickV2BoostedPositionLens: '0x12DD145927CECF616cbD196789c89C2573A53244',
    MaverickV2IncentiveMatcherFactory:
      '0x924Dd05c2325829fa4063CAbE1456273084009d7',
    MaverickV2VotingEscrowFactory: '0x451d47fd6207781dc053551edFD98De8d5EB4Cda',
    MaverickV2RewardFactory: '0x63EF1a657cc53747689B201aa07A76E9ef22f8Fe',
    MaverickV2RewardRouter: '0xc0C3BC532690af8922a2f260c6e1dEb6CFaB45A0',
    MaverickV2VotingEscrowLens: '0x102f936B0fc2E74dC34E45B601FaBaA522f381F0',
    MaverickToken: '0x7448c7456a97769F6cD04F1E83A4a23cCdC46aBD',
    LegacyMaverickVe: '0x4949Ac21d5b2A0cCd303C20425eeb29DCcba66D8',
    MaverickVeV2: '0xC6addB3327A7D4b3b604227f82A6259Ca7112053',
    MaverickTokenIncentiveMatcher: '0x9172a390Cb35a15a890293f59EA5aF250b234D55',
  },
  [Network.SEPOLIA]: {
    WETH: '0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9',
    MaverickV2Factory: '0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e',
    MaverickV2PoolLens: '0x6A9EB38DE5D349Fe751E0aDb4c0D9D391f94cc8D',
    MaverickV2Quoter: '0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A',
    MaverickV2Router: '0x4563d58D072C3198A66EAfCf3333024330dE9104',
    MaverickV2Position: '0x116193c58B40D50687c0433B2aa0cC4AE00bC32c',
    MaverickV2BoostedPositionFactory:
      '0xd94C8f6D13Cf480FfAC686712C63471D1596cc29',
    MaverickV2BoostedPositionLens: '0x12DD145927CECF616cbD196789c89C2573A53244',
    MaverickV2IncentiveMatcherFactory:
      '0x11C0F55102790f84A6F132d8B25FDFe1c96d0992',
    MaverickV2VotingEscrowFactory: '0x51E4AE1BA70D657eEF8e31a2Cb6a8b9AA61aB84e',
    MaverickV2RewardFactory: '0x873b272D7493Da5860E9c513cB805Ff3287D8470',
    MaverickV2RewardRouter: '0x0d17027A98F1396EC2A250d99Dc349e8cf93abb1',
    MaverickV2VotingEscrowLens: '0x102f936B0fc2E74dC34E45B601FaBaA522f381F0',
  },
  [Network.BASE]: {
    WETH: '0x4200000000000000000000000000000000000006',
    MaverickV2Factory: '0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e',
    MaverickV2PoolLens: '0x6A9EB38DE5D349Fe751E0aDb4c0D9D391f94cc8D',
    MaverickV2Quoter: '0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A',
    MaverickV2Router: '0x5eDEd0d7E76C563FF081Ca01D9d12D6B404Df527',
    MaverickV2Position: '0x116193c58B40D50687c0433B2aa0cC4AE00bC32c',
    MaverickV2BoostedPositionFactory:
      '0xd94C8f6D13Cf480FfAC686712C63471D1596cc29',
    MaverickV2BoostedPositionLens: '0x12DD145927CECF616cbD196789c89C2573A53244',
    MaverickV2IncentiveMatcherFactory:
      '0xa476bb7DfCDD4E59dDaA6Ea9311A24cF28561544',
    MaverickV2VotingEscrowFactory: '0x1dE8C03c2D5DD021bd456bc4bB4F0ecD85f99443',
    MaverickV2RewardFactory: '0x1cdC67950a68256c5157987bBF700e94595807F8',
    MaverickV2RewardRouter: '0xE7c73727c1b67A2fA47E63DCBaa4859777aeF392',
    MaverickV2VotingEscrowLens: '0x102f936B0fc2E74dC34E45B601FaBaA522f381F0',
    MaverickToken: '0x64b88c73A5DfA78D1713fE1b4c69a22d7E0faAa7',
    MaverickVeV2: '0x05b1b801191B41a21B9C0bFd4c4ef8952eb28cd9',
    MaverickTokenIncentiveMatcher: '0xc84bDDC0C45FEeFB0F59e1c48332E4d47e29D112',
  },
  [Network.ARBITRUM]: {
    WETH: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
    MaverickV2Factory: '0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e',
    MaverickV2PoolLens: '0x6A9EB38DE5D349Fe751E0aDb4c0D9D391f94cc8D',
    MaverickV2Quoter: '0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A',
    MaverickV2Router: '0x5c3b380e5Aeec389d1014Da3Eb372FA2C9e0fc76',
    MaverickV2Position: '0x116193c58B40D50687c0433B2aa0cC4AE00bC32c',
    MaverickV2BoostedPositionFactory:
      '0xd94C8f6D13Cf480FfAC686712C63471D1596cc29',
    MaverickV2BoostedPositionLens: '0x12DD145927CECF616cbD196789c89C2573A53244',
    MaverickV2IncentiveMatcherFactory:
      '0x11C0F55102790f84A6F132d8B25FDFe1c96d0992',
    MaverickV2VotingEscrowFactory: '0x51E4AE1BA70D657eEF8e31a2Cb6a8b9AA61aB84e',
    MaverickV2RewardFactory: '0x873b272D7493Da5860E9c513cB805Ff3287D8470',
    MaverickV2RewardRouter: '0x293A7D159C5AD1b36b784998DE5563fe36963460',
    MaverickV2VotingEscrowLens: '0x102f936B0fc2E74dC34E45B601FaBaA522f381F0',
    MaverickToken: '0x7448c7456a97769F6cD04F1E83A4a23cCdC46aBD',
    MaverickVeV2: '0xd5d8cB7569BB843c3b8FA98dBD5960d37E83eA8d',
    MaverickTokenIncentiveMatcher: '0xB1F334176AadC61F74afc6381210e8786CcEc37D',
  },
  [Network.ZKSYNC]: {
    WETH: '0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91',
    MaverickV2Factory: '0x7A6902af768a06bdfAb4F076552036bf68D1dc56',
    MaverickV2PoolLens: '0x9439280a7d04FCa28d12a4eB74c92173241d5b2F',
    MaverickV2Quoter: '0x3e1c4b57c9d9624f2841f07C6328D3c25ca30C79',
    MaverickV2Router: '0xad8262e847676E7eDdAFEe664c4fd492789260ba',
    MaverickV2Position: '0x4D93c58B348d99969257cec007cFb31B410b21A0',
    MaverickV2BoostedPositionFactory:
      '0x270a03bfc3EA123c041d4A0c72D30202A514D845',
    MaverickV2BoostedPositionLens: '0xd32CE31CaC98CAC0631764B8286358c0606D87F9',
    MaverickV2IncentiveMatcherFactory:
      '0x11244D8b724De7788f62667791e35284E191745F',
    MaverickV2VotingEscrowFactory: '0x521B444d5f9bb4B36CDd771f4D85cCd0B291FB92',
    MaverickV2RewardFactory: '0xc9e5F0832C96F8E2EEDe472C1B87621Cbb86D7e0',
    MaverickV2RewardRouter: '0x432e6791d35dc6c638f44E949A5c0228e4048244',
    MaverickV2VotingEscrowLens: '0x74E56528CDd2F831cc4ecc9414bCE9C4d540ceC7',
    MaverickToken: '0x787c09494Ec8Bcb24DcAf8659E7d5D69979eE508',
    LegacyMaverickVe: '0x7EDcB053d4598a145DdaF5260cf89A32263a2807',
    MaverickVeV2: '0xe86151Af9cc43533add87921c381dA11c314DEBf',
    MaverickTokenIncentiveMatcher: '0x57FA162aCb48376455c5Ff4D45FE0d36E947D79b',
  },
  [Network.BNB]: {
    WETH: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
    MaverickV2Factory: '0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e',
    MaverickV2PoolLens: '0x6A9EB38DE5D349Fe751E0aDb4c0D9D391f94cc8D',
    MaverickV2Quoter: '0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A',
    MaverickV2Router: '0x374bFCc264678c67a582D067AD91f1951bC6b20f',
    MaverickV2Position: '0x116193c58B40D50687c0433B2aa0cC4AE00bC32c',
    MaverickV2BoostedPositionFactory:
      '0xd94C8f6D13Cf480FfAC686712C63471D1596cc29',
    MaverickV2BoostedPositionLens: '0x12DD145927CECF616cbD196789c89C2573A53244',
    MaverickV2IncentiveMatcherFactory:
      '0x53EEE0a9d1D301eA570329C298Af3f19d1D556c7',
    MaverickV2VotingEscrowFactory: '0x790d33B4271EDD0a611d91E971F2143D8a7DD936',
    MaverickV2RewardFactory: '0x443b1F86D45C1dDC60b355D5A8A931656aB25267',
    MaverickV2RewardRouter: '0x5DeB1bAe837374f988d8a30Cc0Fbccbc63892Bb3',
    MaverickV2VotingEscrowLens: '0x102f936B0fc2E74dC34E45B601FaBaA522f381F0',
    MaverickToken: '0xd691d9a68C887BDF34DA8c36f63487333ACfD103',
    LegacyMaverickVe: '0xE6108f1869d37E5076a56168C66A1607EdB10819',
    MaverickVeV2: '0x675178AE86A75EE7D7Ef81e30a91E1798306094C',
    MaverickTokenIncentiveMatcher: '0x053D0eC15e60c7D8936Ab966A82BB62cCb7E3Ced',
  },
};

export const RPC_URL = {
  [Network.MAINNET]: process.env.RPC_1,
  [Network.BASE]: process.env.RPC_8453,
  [Network.ZKSYNC]: process.env.RPC_324,
  [Network.BNB]: process.env.RPC_56,
  [Network.ARBITRUM]: process.env.RPC_42161,
  [Network.SEPOLIA]: process.env.RPC_11155111,
};
