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

## Contract Addresses

```
ChainId: 11155111
Network: sepolia

WETH_11155111=0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
MaverickV2Factory_11155111=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_11155111=0x56eFfDD51b20705e152CAF482D9A6972e97B571C
MaverickV2Quoter_11155111=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_11155111=0x4563d58D072C3198A66EAfCf3333024330dE9104
MaverickV2Position_11155111=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_11155111=0x018ab609049a3341D51d2919e7e1D510cE149E63
MaverickV2IncentiveMatcherFactory_11155111=0xae338F6Ac0bD95e3F4514D0D17557672e9B2EF5f
MaverickV2VotingEscrowFactory_11155111=0x5c84B3E17e0046888C3C28933e3B59B7407a8F8f
MaverickV2RewardFactory_11155111=0x01c082da273Da86b05D16D4C3CBD6c099EE0867B
MaverickV2RewardRouter_11155111=0xcEC0eA8e399B572fd614eA7A5820E0cB2Cd5e9C5
MaverickV2VotingEscrowLens_11155111=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0
```

```
ChainId: 84532
Network: baseSepolia

WETH_84532=0x4200000000000000000000000000000000000006
MaverickV2Factory_84532=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_84532=0x56eFfDD51b20705e152CAF482D9A6972e97B571C
MaverickV2Quoter_84532=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_84532=0x5eDEd0d7E76C563FF081Ca01D9d12D6B404Df527
MaverickV2Position_84532=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_84532=0x018ab609049a3341D51d2919e7e1D510cE149E63
MaverickV2IncentiveMatcherFactory_84532=0xae338F6Ac0bD95e3F4514D0D17557672e9B2EF5f
MaverickV2VotingEscrowFactory_84532=0x5c84B3E17e0046888C3C28933e3B59B7407a8F8f
MaverickV2RewardFactory_84532=0x01c082da273Da86b05D16D4C3CBD6c099EE0867B
MaverickV2RewardRouter_84532=0xE889c94e233Ca0788E9bc3899cC5BBc5eA1b1053
MaverickV2VotingEscrowLens_84532=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0
```

```
ChainId: 8453
Network: base

WETH_8453=0x4200000000000000000000000000000000000006
MaverickV2Factory_8453=0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e
MaverickV2PoolLens_8453=0x56eFfDD51b20705e152CAF482D9A6972e97B571C
MaverickV2Quoter_8453=0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A
MaverickV2Router_8453=0x5eDEd0d7E76C563FF081Ca01D9d12D6B404Df527
MaverickV2Position_8453=0x116193c58B40D50687c0433B2aa0cC4AE00bC32c
MaverickV2BoostedPositionFactory_8453=0x018ab609049a3341D51d2919e7e1D510cE149E63
MaverickV2IncentiveMatcherFactory_8453=0xE44132ED2660816a92c78BCC6c9A0b8D0f7944b4
MaverickV2VotingEscrowFactory_8453=0x442bB8a0A834f34562c66B7543cD652D5774b2b9
MaverickV2RewardFactory_8453=0x263503113743d60E70515297faFdEF3D6c0f9aBe
MaverickV2RewardRouter_8453=0x8E54B8b8DF3Cd24449D6918440B28C15471C0cF7
MaverickV2VotingEscrowLens_8453=0x102f936B0fc2E74dC34E45B601FaBaA522f381F0
```
