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
1) Set a resonable gas limit on the swap so that the "infinite loop" will terminate before too many iterations.  For example, in solidity, the call would be `pool.swap{gasLimit: 300_000}(recipient, params, data);`.


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

## Contract Addresses

```
ChainId: 11155111
Network: sepolia

WETH_11155111=0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
MaverickV2Factory_11155111=0x1D7472AAfe52e83BA22E707Fc77fF3F3b85551CC
MaverickV2PoolLens_11155111=0x8deC2E5Ba4e26DD2EC19da882976EeA00d03dE88
MaverickV2Quoter_11155111=0xfc201f0f4123bd11429A4d12Fdb6BE7145d55DD5
MaverickV2Router_11155111=0xa5b5EfFeF7C280a297452D87eA4756eDAA52ba68
```

```
ChainId: 84532
Network: baseSepolia

WETH_84532=0x4200000000000000000000000000000000000006
MaverickV2Factory_84532=0x1D7472AAfe52e83BA22E707Fc77fF3F3b85551CC
MaverickV2PoolLens_84532=0x8deC2E5Ba4e26DD2EC19da882976EeA00d03dE88
MaverickV2Quoter_84532=0xfc201f0f4123bd11429A4d12Fdb6BE7145d55DD5
MaverickV2Router_84532=0x77f71FaaE76c4B661B52dD6471aaBE8Dcb632B97
```

```
ChainId: 8453
Network: base

WETH_8453=0x4200000000000000000000000000000000000006
MaverickV2Factory_8453=0x1D7472AAfe52e83BA22E707Fc77fF3F3b85551CC
MaverickV2PoolLens_8453=0x8deC2E5Ba4e26DD2EC19da882976EeA00d03dE88
MaverickV2Quoter_8453=0xfc201f0f4123bd11429A4d12Fdb6BE7145d55DD5
MaverickV2Router_8453=0x77f71FaaE76c4B661B52dD6471aaBE8Dcb632B97
```
