# Maverick V2 Examples

## Listing Pools

For a given chain, there is a deployment of a `MaverickV2Factory` which is used to deploy pools.
To get the listing of pools on the factory, there are two options provided by the `MaverickV2Factory` interface:

1) Paginate through pool addresses for a given token pair
```solidity
function lookup(
    IERC20 _tokenA,
    IERC20 _tokenB,
    uint256 startIndex,
    uint256 endIndex
) external view returns (IMaverickV2Pool[] memory pools);
```
2) Paginate through all pools created by the factory
```solidity
function lookup(
    uint256 startIndex,
    uint256 endIndex
) external view returns (IMaverickV2Pool[] memory pools);
```

In both cases, the function has inputs for start and end indexes allowing for pagination of the pool list in the case that the list is too big to be returned in one call.

Additionally, one can find the address of an already-deployed pool using either this lookup function:
```solidity
function lookup(
    uint256 feeAIn,
    uint256 feeBIn,
    uint256 tickSpacing,
    uint256 lookback,
    IERC20 tokenA,
    IERC20 tokenB,
    uint8 kinds
) external view returns (IMaverickV2Pool);
```

Or by computing the address using the create2 logic (for non-zkSync chains)
```solidity
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

bytes32 poolCodeHash = keccak256(type(MaverickV2Pool).creationCode);
bytes32 salt = keccak256(abi.encode(feeAIn, feeBIn, tickSpacing, lookback, tokenA, tokenB, kinds, address(0)));
IMaverickV2Pool pool = IMaverickV2Pool(Create2.computeAddress(salt, poolCodeHash, address(factory)));
```

See https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-common-contracts/interfaces/imaverickv2factory for more details.

## Pool Parameters

For a given pool, extracting the relevent parameters is straightforward.  Example functions available are:

```solidity
function getState() external view returns (State memory);
function fee(bool tokenAIn) external view returns (uint256);
function tokenA() external view returns (IERC20);
function tokenB() external view returns (IERC20);
```

For instance, `pool.getState().reserveA` and `pool.getState().reserveB` indicate how much reserve of each token is in the pool.

Additionally, the `MaverickV2PoolLens` contract can be used to extract the current price of the pool

```solidity
function getPoolPrice(IMaverickV2Pool pool) external view returns (uint256 price);
```

There are other helper functions on the `MaverickV2PoolLens` that provide pool insights.
For instance, to extract the reserves for the ticks near the active tick, a user can call `lens.getTicksAroundActive`:

```solidity
function getTicksAroundActive(
    IMaverickV2Pool pool,
    int32 tickRadius
) external view returns (int32[] memory ticks, IMaverickV2Pool.TickState[] memory tickStates);
```

The returned tick data can be used to determine the trade depth around the current price.

See https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-common-contracts/interfaces/imaverickv2pool and https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-supplemental-contracts/maverickv2poollens for more details.

## Swapping

There are two options to swap with a pool:
1) Use the `MaverickV2Router` interface.
2) Create your own smart contract to interact with Maverick V2 pools.

The `MaverickV2Router` has several options for swapping and support both single-hop and multi-hop swaps where the user specifies either hte desired input amount they want to spend or the desired output amount they want to receive.

The function for swapping with a single pool by specifying the desired spent amount is:
```solidity
function exactInputSingle(
    address recipient,
    IMaverickV2Pool pool,
    bool tokenAIn,
    uint256 amountIn,
    uint256 amountOutMinimum
) public payable returns (uint256 amountOut);
```

See https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-supplemental-contracts/routerbase/pushoperations and https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-supplemental-contracts/routerbase/callbackoperations for more details.

### Pool Swap

The raw swap interface is

```solidity
struct SwapParams {
    uint256 amount;
    bool tokenAIn;
    bool exactOutput;
    int32 tickLimit;
}

function swap(address recipient, SwapParams memory params, bytes calldata data)
    external
    returns (uint256 amountIn, uint256 amountOut);
```

The swap user has two options for funding their swap.

1) The user can push the input token amount to the pool before calling the swap function. In order to avoid having the pool call the callback, the user should pass a zero-length data bytes object with the swap call, e.g. `data=""`.

2) The user can send the input token amount to the pool when the pool calls the `maverickV2SwapCallback` function on the calling contract. That callback has input parameters that specify the token address of the input token, the input and output amounts, and the bytes data sent to the swap function.  The function signature for the callback is
```solidity
function maverickV2SwapCallback(
    IERC20 tokenIn,
    uint256 amountIn,
    uint256 amountOut,
    bytes calldata data) external;
```

If the users elects to do a callback-based swap, the output assets will be sent before the callback is called, allowing the user to execute flash swaps. However, the pool does have reentrancy protection, so a swapper will not be able to interact with the same pool again while they are in the callback function.

For aggregators executing a multi-hop swap that involves a Maverick V2 pool, it is probably most convient to utilize option 1) where they simply transfer the input assets they wish to swap to the pool and the pool will send the output assets to the `recipient`.



### Pool Tick Limit

The following are considerations for users who want to create their own smart contract to interact with a Maverick V2 pool.  For users swapping through the router, the following low-level considerations are abstracted away.

As a pool completes a swap, it will search through ticks in either ascending order for an `tokenAIn = true` swap or descending order for a `tokenAIn = false` swap.
The starting tick is `pool.getState().activeTick`.

To ensure a swap does not hit the tick limit, define the limit as `tickLimit: tokenAIn ? type(int32).max : type(int32).min`.

If the swap requires more liquidity than the pool has, and the `tickLimit` is set to this max value, then the pool swap function will loop essentially infinitely until it reverts with an `Out of gas` error.

There are two mechanisms to prevent this:
1) Set a resonable gas limit on the swap so that the "infinite loop" will terminate before too many iterations.  For example, in solidity, the call would be `pool.swap{gas: 300_000}(recipient, params, data);`.


2) Define the `tickLimit` to be some small delta from the `activeTick`.  For instance:
```solidity
tokenAIn
    ? pool.getState().activeTick + 30
    : pool.getState().activeTick - 30;
```

The caveat with option 2) is that, once the `tickLimit` is hit, no further liquidity will swap.

So if the swap terminates early on the limit, neither the `exactInput` or `exactOutput` would have been satisfied.

When the user uses the callback to fund the swap, this is no problem as the callback will only ask for as much input as is needed for the swap.

However, when the users funds the swap by first transfering assets to the pool, and then setting a limit, the user will have overpaid for the swap and will have no way to recover their excess payment.

**For this reason, users should be very careful to use the `tickLimit` option without checking that the output of the swap meets their expectations. e.g., `if (amountOut < amountOutMinimum) revert TooLittleReceived(amountOutMinimum, amountOut);`**



## Price Quoting

The `IMaverickV2Quoter` contract provides an interface to get quotes for both swaps and for adding liquidity.

Both multi-hop and single-hop price quotes are supported:
```solidity
function calculateSwap(
    IMaverickV2Pool pool,
    uint128 amount,
    bool tokenAIn,
    bool exactOutput,
    int32 tickLimit
) external returns (uint256 amountIn, uint256 amountOut, uint256 gasEstimate);

function calculateMultiHopSwap(
    bytes memory path,
    uint256 amount,
    bool exactOutput
) external returns (uint256 returnAmount, uint256 gasEstimate);
```

Note that the gas estimate returned is only a rough gas estimate and will not exactly match the gas consumed by a swap.

See https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-supplemental-contracts/maverickv2quoter for more details.

## Adding Liquidity to a Pool

There are three mechanisms to add liquidity to a pool.
- Add liquidity directly to the pool.  This liquidity is non-transferable and only the receipient of the liquidity will be able to remove it.
- Add liquidity through the `MaverickV2Position` ERC-721 contract.  Liquidity is stored with a tokenId an is transferable as an NFT.
- Add liquidity through a Boosted Position (BP) which defines a fixed liquidity distribution and mints users ERC-20 tokens that represent their ownership of the BP.

### Adding to a Position NFT

The `MaverickV2RewardRouter` contract exposes the `mintPositionNft` function:

```solidity
function mintPositionNft(
    IMaverickV2Pool pool,
    address recipient,
    bytes calldata packedSqrtPriceBreaks,
    bytes[] calldata packedArgs
) external payable returns (uint256 tokenAAmount, uint256 tokenBAmount, uint32[] memory binIds, uint256 tokenId);
```
When adding liquidity to a pool, the user specifies the amount of bin LP balance they want to receive through the `packedArgs` parameter.  The units of LP balance are not "liquidity" in the `L^2 = x * y` sense of liquidity, instead they are just an LP unit that tracks a user's ownership of bin liquidity.  Since fees accumulate in bins, the token value of bin LP balance increases as swaps happen in a bin.

Typically a user does not know what value of LP balance they want to buy, instead, a user comes to a pool understanding the maximum amount of tokens they want to spend and the distribution of liquidity (i.e. "L") in ticks they want to end up.  Mapping a user's intent to LP balances is a complicated operation, but there is a straightforward view function on the `MaverickV2Lens` contract that does the mapping from intent to LP balances:

```solidity
function getAddLiquidityParams(
    AddParamsViewInputs memory params
)
    external
    view
    returns (
        bytes memory packedSqrtPriceBreaks,
        bytes[] memory packedArgs,
        uint88[] memory sqrtPriceBreaks,
        IMaverickV2Pool.AddLiquidityParams[] memory addParams,
        IMaverickV2PoolLens.TickDeltas[] memory tickDeltas
    );

struct AddParamsViewInputs {
    IMaverickV2Pool pool;
    uint8 kind;
    int32[] ticks;
    uint128[] relativeLiquidityAmounts;
    AddParamsSpecification addSpec;
}

struct AddParamsSpecification {
    uint256 slippageFactorD18;
    uint256 numberOfPriceBreaksPerSide;
    uint256 targetAmount;
    bool targetIsA;
}
```

With `getAddLiquidityParams` a user can express their objective distrition in the liquidity domain (not the LP balance domain) as well as their ceiling token amount, and a series of slippage breakpoints.   The function returns an array of `AddLiquidityParams`, one element for each price breakpoint.  This feature is nice becuase it keeps price shifts from causing the user to send more of one token or the other than they intended.

For example, for a given `AddLiquidityParams`, if the price moves right, the user will have to send more tokenA value and less tokenB value than they intended.  Other Dexes will just revert in this situation.  But with this price breakpoint list, the `getAddLiquidityParams` does the calculation to ensure that, even with a price movement, the desired amount of tokens will not be exceeded.  So, in the case that the price moves slightly right, the `AddLiquidityParams` at that new price break will have less LP balance per bin specified thereby ensuring that the correct amount of tokens are requested by the pool.

All of this is abstracted away for the user and they simply need to specify the inputs of `getAddLiquidityParams`, call that function off chain to get the `packedSqrtPriceBreaks` and `packedArgs` values which is then passed into the `mintPositionNft` function on chain.

See https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-supplemental-contracts/maverickv2poollens and https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-supplemental-contracts/interfaces/imaverickv2liquiditymanager#addliquidity for more details.  Run `forge test --force --match-test Add -vv` in the solidity folder to see examples of how price movements affect the add amounts.

### Determining the Amounts Needed on an Add

There are two options:
- The output of `getAddLiquidityParams` contains `tickDeltas` which array of structs, one for each price break.  The `TickDelta` struct contains `deltaAOut` and `deltaBOut` parameters that indicate the upper bound token values for that price break.
- Use the `MaverickV2Quoter` contract: `(uint256 amountA, uint256 amountB, ) = quoter.calculateAddLiquidity(pool, addParams);` to find a more precise estimate of the token values required on add.

See https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-supplemental-contracts/interfaces/imaverickv2quoter#calculateaddliquidity for more details.

### Handling Slippage
In addition to the price breakpoint lookup table that is passed in with an add liquidity call, users may also want to ensure the price is in a given range when they add liquidity.  This can be accomplished by multicalling the `checkSqrtPrice` function on the `MaverickV2RewardRouter` along with any add liquidity call:
``` solidity
function checkSqrtPrice(IMaverickV2Pool pool, uint256 minSqrtPrice, uint256 maxSqrtPrice) external payable;
```

See https://docs.mav.xyz/v2-technical-reference/v2-contracts/maverick-v2-supplemental-contracts/base/ichecks for more details.

An example for assembling the multicall is provided in the solidity tests.


## Programmable Pools

This repo contains several examples for programmable pools where the swap fee is modified based on either an accessor manually changing the fee or based on a condition in the swap itself.  To make a programmable pool, a user calls

```solidity
function createPermissioned(
    uint64 feeAIn,
    uint64 feeBIn,
    uint16 tickSpacing,
    uint32 lookback,
    IERC20 tokenA,
    IERC20 tokenB,
    int32 activeTick,
    uint8 kinds,
    address accessor,
    bool permissionedLiquidity,
    bool permissionedSwap
) external returns (IMaverickV2Pool pool);
```

A programmable pool has a "accessor" which is a contract or wallet that can call the permissioned functions.  The accessor is able to call `setFee` on the pool if both fee values are initialized to `0`.  If `permissionedLiquidity` is set to true, then all of the liquidity related functions are only accessable by the accessor. Likewise, if `permissionedSwap` is `true` then only the accessor can access the swap function.  The convention is that, by permissioning functions on the pool, the accessor can insert their custom logic that implements special features such as fee setting or liquidity movement.

In this repo, there are example accessor contracts that set the fee of the pool either 1) asynchronously with other interactions in the pool or 2) as part of pool swaps.  The advantage of 1) is that the pool remains compatible with the `MaverickV2Router` and swappers do not have to pay gas to adjust the fee.  The advantage of 2) is that the fee setting algorithm is updated automatically as swappers swap without a third party having to do anything.  There are use cases for both situations.

## User Assets

There are four mechanisms in Maverick V2 where users can have asset:
- In a pool as a non-transferable raw position
- In the Pool Position contract as a transferable NFT
- In a Boosted Position contract as a transferable ERC-20 LP token
- In a Reward contract where Boosted Position tokens are staked to earn incentives
- In a VotingEscrow contract

The `javascript` folder provides examples using ethers to recover assets for a given user in each of these mechanisms.

### MaverickV2VotingEscrow Contract

The `MaverickV2VotingEscrowFactory` contract lets user create arbitrary ve tokens for any underlying "base" token.  For example, the `Mav` token has a corresponding `veMav` token where `Mav` can be staked to gain voting power and to accumulate rewards.

To find the amount of underlying base token a user has, one must paginate through that user's "lockup" and sum the base token `lockup.amount` across all active lockups.

```solidity
/**
 * @notice This function retrieves paginated lockup information for a specific
 * account and lockup index range within a provided Maverick V2 Voting
 * Escrow (veToken) contract.
 * @param ve The address of the IMaverickV2VotingEscrow contract for which to retrieve lockup information.
 * @param staker The address of the account for which to retrieve lockup information.
 * @param startIndex The starting index for the desired range of lockups.
 * @param endIndex The ending index for the desired range of lockups.
 * @return returnElements An array of `IMaverickV2VotingEscrow.Lockup`
 * structs containing details about the lockups within the specified index
 * range for the account.
 */
function getLockups(
    IMaverickV2VotingEscrow ve,
    address staker,
    uint256 startIndex,
    uint256 endIndex
) external view returns (IMaverickV2VotingEscrow.Lockup[] memory returnElements);

struct Lockup {
    uint128 amount;
    uint128 end;
    uint256 votes;
}
```

### MaverickV2Position Contract

User positions are minted to an NFT and this NFT references a storage mappings of pools and binIds.  A given NFT can store assets on multiple pools, but it is more conventional for each NFT to only reference one pool.

The `tokenIdPositionInformation` function on the MaverickV2Position returns information about a given NFT's assets for a given `pool` index.  Again, the convention is for only `index=0` to have liquidity associated with it.

```solidity
function tokenIdPositionInformation(
    uint256 tokenId,
    uint256 index
) external view returns (PositionFullInformation memory output);
```

```solidity
struct PositionFullInformation {
    PositionPoolBinIds poolBinIds;
    uint256 amountA;
    uint256 amountB;
    uint256[] binAAmounts;
    uint256[] binBAmounts;
    int32[] ticks;
    uint256[] liquidities;
}
```


### MaverickV2BoostedPosition Contract

Pool liquidity can also be stored in a BoostedPosition contract which has an ERC-20 interface where the ERC-20 token represents a user's ownership stake in the BP.  The `MaverickV2BoostedPositionLens` contract has helper functions that return information about a given user's stake in the BP in terms of the underlying `tokenA` and `tokenB` assets.  Specically, `boostedPositionUserInformation`:

```solidity
function boostedPositionUserInformation(
    IMaverickV2BoostedPosition bp,
    address user
) external view returns (BoostedPositionInformation memory info, uint256 userAmountA, uint256 userAmountB);

struct BoostedPositionInformation {
    IMaverickV2Pool pool;
    IERC20 tokenA;
    IERC20 tokenB;
    uint8 kind;
    uint128[] binBalances;
    uint32[] binIds;
    int32[] ticks;
    uint256 amountA;
    uint256 amountB;
    uint256[] binAAmounts;
    uint256[] binBAmounts;
}
```

### MaverickV2Reward Contract

The `MaverickV2Reward` contract allows users to stake their BP tokens in order to earn time-disbursed incentives.  `MaverickV2Reward` positions are not fungible and are represented by transferable NFTs which have an ERC-721 interface.  When staking the `MaverickV2Reward` contract, BP tokens are sent to the contract and are tracked per NFT ID.  To compute a given user's underlying balance, simply multiply the underlying assets the `MaverickV2Reward` contract owns in the BP and pro rate that amount by the user's proportion of the stake balance.

To find a user's underlying balance of the stake token, the follow stake balance function are used:

```solidity
/**
 * @notice Balance of stake for a given `tokenId` account.
 */
function stakeBalanceOf(uint256 tokenId) external view returns (uint256 balance);

/**
 * @notice Sum of all balances across all tokenIds.
 */
function stakeTotalSupply() external view returns (uint256 supply);
```


### Raw Pool Position

A raw pool position occurs on `pool.addLiquidity` and the resulting event is 
```solidity
event PoolAddLiquidity(
    address sender,
    address recipient,
    uint256 subaccount,
    AddLiquidityParams params,
    uint256 tokenAAmount,
    uint256 tokenBAmount,
    uint32[] binIds
);
```

After the liquidity has been added, the recipient's pool ownership in a given bin can be recovered with a call to
```solidity
function balanceOf(
    address user,
    uint256 subaccount,
    uint32 binId
) external view returns (uint128 lpTokenBalance);
```

To find the token balance, we must also collect the tick balance for this bin and the pro rata ownership the bin owns of the tick.

## Contract Addresses


### Testnets

```
ChainId: 11155111
Network: sepolia

WETH_11155111=0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
MaverickV2Factory_11155111=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_11155111=0x3a44e8C8B73E47aEEDF02761988A607FAe2fd929
MaverickV2Quoter_11155111=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_11155111=0x4563d58D072C3198A66EAfCf3333024330dE9104
MaverickV2Position_11155111=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_11155111=0xd94C8f6D13Cf480FfAC686712C63471D1596cc29
MaverickV2BoostedPositionLens_11155111=0x12DD145927CECF616cbD196789c89C2573A53244
MaverickV2IncentiveMatcherFactory_11155111=0x11C0F55102790f84A6F132d8B25FDFe1c96d0992
MaverickV2VotingEscrowFactory_11155111=0x51E4AE1BA70D657eEF8e31a2Cb6a8b9AA61aB84e
MaverickV2RewardFactory_11155111=0x873b272D7493Da5860E9c513cB805Ff3287D8470
MaverickV2RewardRouter_11155111=0x0d17027A98F1396EC2A250d99Dc349e8cf93abb1
MaverickV2VotingEscrowLens_11155111=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0
```

```
ChainId: 421614
Network: arbitrumSepolia

WETH_421614=0x997FE31Adda5c969691768Ad1140273290952333
MaverickV2Factory_421614=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_421614=0x942646b0A8B42Af1e1044439013436a9a3e080b5
MaverickV2Quoter_421614=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_421614=0x9ce6a2Df87Ab67C5C8317418524069793bc13DDc
MaverickV2Position_421614=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_421614=0xd94C8f6D13Cf480FfAC686712C63471D1596cc29
MaverickV2BoostedPositionLens_421614=0x12DD145927CECF616cbD196789c89C2573A53244
MaverickV2IncentiveMatcherFactory_421614=0x7b4F5FA58363c6c38a10ACb0EcBB8C7cFeF41aF4
MaverickV2VotingEscrowFactory_421614=0xFB1EAbBECC59fc531f9c5dCb71cCAADF24CE538a
MaverickV2RewardFactory_421614=0x348c888eB04c0Dd4D44d075C9560be1e80AB4fe9
MaverickV2RewardRouter_421614=0xd487dca6e01C29DA00f5fF1060Ea465675D29B24
MaverickV2VotingEscrowLens_421614=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0
```

```
ChainId: 84532
Network: baseSepolia

WETH_84532=0x4200000000000000000000000000000000000006
MaverickV2Factory_84532=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_84532=0x3a44e8C8B73E47aEEDF02761988A607FAe2fd929
MaverickV2Quoter_84532=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_84532=0x5eDEd0d7E76C563FF081Ca01D9d12D6B404Df527
MaverickV2Position_84532=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_84532=0xd94C8f6D13Cf480FfAC686712C63471D1596cc29
MaverickV2BoostedPositionLens_84532=0x12DD145927CECF616cbD196789c89C2573A53244
MaverickV2IncentiveMatcherFactory_84532=0x11C0F55102790f84A6F132d8B25FDFe1c96d0992
MaverickV2VotingEscrowFactory_84532=0x51E4AE1BA70D657eEF8e31a2Cb6a8b9AA61aB84e
MaverickV2RewardFactory_84532=0x873b272D7493Da5860E9c513cB805Ff3287D8470
MaverickV2RewardRouter_84532=0xd87D5dC4f1a093E02F84d1419F501afe0254CB53
MaverickV2VotingEscrowLens_84532=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0
```

```
ChainId: 300
Network: zkSyncSepolia

WETH_300=0x53F7e72C7ac55b44c7cd73cC13D4EF4b121678e6
MaverickV2Factory_300=0x6D121BcABEf869518414a747e30c4568869aE0B4
MaverickV2PoolLens_300=0xFE52EA02992AA1e9f8f6396926089656e5e1497B
MaverickV2Quoter_300=0x2D2ED310f4ED89c6460154D8f3AA98d1A254cd1e
MaverickV2Router_300=0xC7F2F69C4A07362d1b8144e78564D166f83aFb7A
MaverickV2Position_300=0xD61Fa8Fb76F90ae007E6CeEA4F8FFf7Fcc5BB1C9
MaverickV2BoostedPositionFactory_300=0x4C7A6AE41b51564f579Ce7f86694A9e1e15633D9
MaverickV2BoostedPositionLens_300=0x67E8F8Fa97D528094e24A3b2f5AB0E9B14E2Bc50
MaverickV2IncentiveMatcherFactory_300=0x471199b467b180fFBa5E488b52F8AdFde3A51037
MaverickV2VotingEscrowFactory_300=0x7d88e512949763C4dF1F431E873761cC829B0BF6
MaverickV2RewardFactory_300=0xb1e6BDfd9651c70f390FD7dDdD68b891fAccb470
MaverickV2RewardRouter_300=0x9D4222b09E6f61E572c6D75abD88c8E229AeB6E3
MaverickV2VotingEscrowLens_300=0x852eB4863d5F3c0924fDfeD393E09e32c8e20e4A
```

```
ChainId: 97
Network: bnbt

WETH_97=0xf80880c41ad3f470b9aac9393c4dec82b334b436
MaverickV2Factory_97=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_97=0x3a44e8C8B73E47aEEDF02761988A607FAe2fd929
MaverickV2Quoter_97=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_97=0xCff049230d142965c2c73b1b801557062E824a71
MaverickV2Position_97=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_97=0xd94C8f6D13Cf480FfAC686712C63471D1596cc29
MaverickV2BoostedPositionLens_97=0x12DD145927CECF616cbD196789c89C2573A53244
MaverickV2IncentiveMatcherFactory_97=0x11C0F55102790f84A6F132d8B25FDFe1c96d0992
MaverickV2VotingEscrowFactory_97=0x51E4AE1BA70D657eEF8e31a2Cb6a8b9AA61aB84e
MaverickV2RewardFactory_97=0x873b272D7493Da5860E9c513cB805Ff3287D8470
MaverickV2RewardRouter_97=0x730ee2707C30bE816907d87386ed44C39E45B15b
MaverickV2VotingEscrowLens_97=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0
```

### Mainnets

```
ChainId: 8453
Network: base

WETH_8453=0x4200000000000000000000000000000000000006
MaverickV2Factory_8453=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_8453=0x3a44e8C8B73E47aEEDF02761988A607FAe2fd929
MaverickV2Quoter_8453=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_8453=0x5eDEd0d7E76C563FF081Ca01D9d12D6B404Df527
MaverickV2Position_8453=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_8453=0xd94C8f6D13Cf480FfAC686712C63471D1596cc29
MaverickV2BoostedPositionLens_8453=0x12DD145927CECF616cbD196789c89C2573A53244
MaverickV2IncentiveMatcherFactory_8453=0xa476bb7DfCDD4E59dDaA6Ea9311A24cF28561544
MaverickV2VotingEscrowFactory_8453=0x1dE8C03c2D5DD021bd456bc4bB4F0ecD85f99443
MaverickV2RewardFactory_8453=0x1cdC67950a68256c5157987bBF700e94595807F8
MaverickV2RewardRouter_8453=0xE7c73727c1b67A2fA47E63DCBaa4859777aeF392
MaverickV2VotingEscrowLens_8453=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0

MaverickToken_8453=0x64b88c73A5DfA78D1713fE1b4c69a22d7E0faAa7
LegacyMaverickVe_8453=0xFcCB5263148fbF11d58433aF6FeeFF0Cc49E0EA5

MaverickVeV2_8453=0x05b1b801191B41a21B9C0bFd4c4ef8952eb28cd9
MaverickTokenIncentiveMatcher_8453=
```

```
ChainId: 56
Network: bnb

WETH_56=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
MaverickV2Factory_56=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_56=0x3a44e8C8B73E47aEEDF02761988A607FAe2fd929
MaverickV2Quoter_56=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_56=0x374bFCc264678c67a582D067AD91f1951bC6b20f
MaverickV2Position_56=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_56=0xd94C8f6D13Cf480FfAC686712C63471D1596cc29
MaverickV2BoostedPositionLens_56=0x12DD145927CECF616cbD196789c89C2573A53244
MaverickV2IncentiveMatcherFactory_56=0x53EEE0a9d1D301eA570329C298Af3f19d1D556c7
MaverickV2VotingEscrowFactory_56=0x790d33B4271EDD0a611d91E971F2143D8a7DD936
MaverickV2RewardFactory_56=0x443b1F86D45C1dDC60b355D5A8A931656aB25267
MaverickV2RewardRouter_56=0x5DeB1bAe837374f988d8a30Cc0Fbccbc63892Bb3
MaverickV2VotingEscrowLens_56=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0

MaverickToken_56=0xd691d9a68C887BDF34DA8c36f63487333ACfD103
LegacyMaverickVe_56=0xE6108f1869d37E5076a56168C66A1607EdB10819

MaverickVeV2_56=0x675178AE86A75EE7D7Ef81e30a91E1798306094C
MaverickTokenIncentiveMatcher_56=
```

```
ChainId: 1
Network: ethMainnet

WETH_1=0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
MaverickV2Factory_1=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_1=0x3a44e8C8B73E47aEEDF02761988A607FAe2fd929
MaverickV2Quoter_1=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_1=0x62e31802c6145A2D5E842EeD8efe01fC224422fA
MaverickV2Position_1=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_1=0xd94C8f6D13Cf480FfAC686712C63471D1596cc29
MaverickV2BoostedPositionLens_1=0x12DD145927CECF616cbD196789c89C2573A53244
MaverickV2IncentiveMatcherFactory_1=0x924Dd05c2325829fa4063CAbE1456273084009d7
MaverickV2VotingEscrowFactory_1=0x451d47fd6207781dc053551edFD98De8d5EB4Cda
MaverickV2RewardFactory_1=0x63EF1a657cc53747689B201aa07A76E9ef22f8Fe
MaverickV2RewardRouter_1=0xc0C3BC532690af8922a2f260c6e1dEb6CFaB45A0
MaverickV2VotingEscrowLens_1=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0

MaverickToken_1=0x7448c7456a97769F6cD04F1E83A4a23cCdC46aBD
LegacyMaverickVe_1=0x4949Ac21d5b2A0cCd303C20425eeb29DCcba66D8

MaverickVeV2_1=0xC6addB3327A7D4b3b604227f82A6259Ca7112053
MaverickTokenIncentiveMatcher_1=
```

```
ChainId: 42161
Network: arbitrum

WETH_42161=0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
MaverickV2Factory_42161=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_42161=0x3a44e8C8B73E47aEEDF02761988A607FAe2fd929
MaverickV2Quoter_42161=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_42161=0x5c3b380e5Aeec389d1014Da3Eb372FA2C9e0fc76
MaverickV2Position_42161=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_42161=0xd94C8f6D13Cf480FfAC686712C63471D1596cc29
MaverickV2BoostedPositionLens_42161=0x12DD145927CECF616cbD196789c89C2573A53244
MaverickV2IncentiveMatcherFactory_42161=0x11C0F55102790f84A6F132d8B25FDFe1c96d0992
MaverickV2VotingEscrowFactory_42161=0x51E4AE1BA70D657eEF8e31a2Cb6a8b9AA61aB84e
MaverickV2RewardFactory_42161=0x873b272D7493Da5860E9c513cB805Ff3287D8470
MaverickV2RewardRouter_42161=0x293A7D159C5AD1b36b784998DE5563fe36963460
MaverickV2VotingEscrowLens_42161=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0

MaverickToken_42161=0x7448c7456a97769F6cD04F1E83A4a23cCdC46aBD

MaverickVeV2_42161=0xd5d8cB7569BB843c3b8FA98dBD5960d37E83eA8d
MaverickTokenIncentiveMatcher_42161=
```

```
ChainId: 324
Network: zkSync

WETH_324=0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91
MaverickV2Factory_324=0x7A6902af768a06bdfAb4F076552036bf68D1dc56
MaverickV2PoolLens_324=0xE59cEc900f08Aa9DB295213C4A34df978072914d
MaverickV2Quoter_324=0x3e1c4b57c9d9624f2841f07C6328D3c25ca30C79
MaverickV2Router_324=0xad8262e847676E7eDdAFEe664c4fd492789260ba
MaverickV2Position_324=0x4D93c58B348d99969257cec007cFb31B410b21A0
MaverickV2BoostedPositionFactory_324=0x270a03bfc3EA123c041d4A0c72D30202A514D845
MaverickV2BoostedPositionLens_324=0xd32CE31CaC98CAC0631764B8286358c0606D87F9
MaverickV2IncentiveMatcherFactory_324=0x11244D8b724De7788f62667791e35284E191745F
MaverickV2VotingEscrowFactory_324=0x521B444d5f9bb4B36CDd771f4D85cCd0B291FB92
MaverickV2RewardFactory_324=0xc9e5F0832C96F8E2EEDe472C1B87621Cbb86D7e0
MaverickV2RewardRouter_324=0x432e6791d35dc6c638f44E949A5c0228e4048244
MaverickV2VotingEscrowLens_324=0x74E56528CDd2F831cc4ecc9414bCE9C4d540ceC7

MaverickToken_324=0x787c09494Ec8Bcb24DcAf8659E7d5D69979eE508
LegacyMaverickVe_324=0x7EDcB053d4598a145DdaF5260cf89A32263a2807

MaverickVeV2_324=0xe86151Af9cc43533add87921c381dA11c314DEBf
MaverickTokenIncentiveMatcher_324=0x57FA162aCb48376455c5Ff4D45FE0d36E947D79b
```

```
ChainId: 534352
Network: scroll

WETH_534352=0x5300000000000000000000000000000000000004
MaverickV2Factory_534352=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_534352=0x3a44e8C8B73E47aEEDF02761988A607FAe2fd929
MaverickV2Quoter_534352=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_534352=0x15D5ff975c1181FAf938cd33BD0633435bdfA18d
MaverickV2Position_534352=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_534352=0xd94C8f6D13Cf480FfAC686712C63471D1596cc29
MaverickV2BoostedPositionLens_534352=0x12DD145927CECF616cbD196789c89C2573A53244
MaverickV2IncentiveMatcherFactory_534352=0x11C0F55102790f84A6F132d8B25FDFe1c96d0992
MaverickV2VotingEscrowFactory_534352=0x51E4AE1BA70D657eEF8e31a2Cb6a8b9AA61aB84e
MaverickV2RewardFactory_534352=0x873b272D7493Da5860E9c513cB805Ff3287D8470
MaverickV2RewardRouter_534352=0xd837fcba68A6A5Aa63f791ea51F258d30546d2c1
MaverickV2VotingEscrowLens_534352=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0
```
