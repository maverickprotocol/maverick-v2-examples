// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMaverickV2Factory} from "../src/interfaces/IMaverickV2Factory.sol";
import {IMaverickV2Pool} from "../src/interfaces/IMaverickV2Pool.sol";
import {IMaverickV2PoolLens} from "../src/interfaces/IMaverickV2PoolLens.sol";
import {IMaverickV2Position} from "../src/interfaces/IMaverickV2Position.sol";
import {IMaverickV2Quoter} from "../src/interfaces/IMaverickV2Quoter.sol";
import {IMaverickV2Router} from "../src/interfaces/IMaverickV2Router.sol";
import {IMaverickV2RewardRouter} from "../src/interfaces/IMaverickV2RewardRouter.sol";

contract AddToPositionBaseSepolia is Test {
    IMaverickV2Factory public factory;
    IMaverickV2Pool public pool;
    IMaverickV2PoolLens public lens;
    IMaverickV2Position public position;
    IMaverickV2Quoter public quoter;
    IMaverickV2RewardRouter public rewardRouter;
    IERC20 public tokenA;
    IERC20 public tokenB;
    int32 public activeTick;
    address public constant recipient = address(10);
    bytes constant EMPTY_PRICE_BREAKS = hex"010000000000000000000000";

    function setUp() public virtual {
        uint256 forkId = vm.createFork("https://sepolia.base.org/", 10721808);
        vm.selectFork(forkId);

        rewardRouter = IMaverickV2RewardRouter(payable(0x7377d47335AD579a7e0BbeB09350f554c4A1aAeF));
        quoter = IMaverickV2Quoter(0xAc0B678a48c83041a48dd8b810356f167F8D1FcC);
        lens = IMaverickV2PoolLens(0xBC6B06dd675Ac620bD7a7b64bA9C077776a0Fb2a);

        factory = rewardRouter.factory();
        pool = factory.lookup(0, 1)[0];
        tokenA = pool.tokenA();
        tokenB = pool.tokenB();
        activeTick = pool.getState().activeTick;

        deal(address(tokenA), address(this), 10e18);
        deal(address(tokenB), address(this), 10e18);
        tokenA.approve(address(rewardRouter), type(uint256).max);
        tokenB.approve(address(rewardRouter), type(uint256).max);

        position = rewardRouter.position();
    }

    function getAddParams(
        uint128 amount,
        uint8 kind,
        int32 minTick,
        int32 maxTick
    ) public pure returns (IMaverickV2Pool.AddLiquidityParams memory params) {
        uint256 count = uint32(maxTick - minTick + 1);
        params.amounts = new uint128[](count);
        params.ticks = new int32[](count);
        params.kind = kind;
        for (int32 i = minTick; i <= maxTick; i++) {
            params.ticks[uint32(i - minTick)] = i;
            params.amounts[uint32(i - minTick)] = amount * uint32(i - minTick + 10);
        }
    }

    function test_AddWithoutLens() public {
        // make add params in range of ticks
        IMaverickV2Pool.AddLiquidityParams memory params = getAddParams(0.01e18, 0, activeTick - 2, activeTick + 2);
        IMaverickV2Pool.AddLiquidityParams[] memory paramsArray = new IMaverickV2Pool.AddLiquidityParams[](1);
        paramsArray[0] = params;

        // estimate how much A/B we need
        (uint256 amountA, uint256 amountB, ) = quoter.calculateAddLiquidity(pool, params);
        console2.log("quoted amounts   ", amountA, amountB);

        (uint256 tokenAAmount, uint256 tokenBAmount, , uint256 tokenId) = rewardRouter.mintPositionNft(
            pool,
            recipient,
            EMPTY_PRICE_BREAKS,
            rewardRouter.packAddLiquidityArgsArray(paramsArray)
        );
        console2.log("output amounts   ", tokenAAmount, tokenBAmount);

        // call view function to get data about the position nft
        IMaverickV2Position.PositionFullInformation memory output = position.tokenIdPositionInformation(tokenId, 0);
        // amounts may be slightly different as the position owns a pro rata of
        // each bin and there is a rounding operation that dictates the amount
        // the user is entitled to
        console2.log("position amounts ", output.amountA, output.amountB);
        assertEq(position.ownerOf(tokenId), recipient);

        // can't tranfer unless the owner is pranked
        vm.expectRevert();
        position.transferFrom(recipient, address(this), tokenId);

        // transfer position nft
        vm.prank(recipient);
        position.transferFrom(recipient, address(this), tokenId);
        assertEq(position.ownerOf(tokenId), address(this));

        // view function to grab remove parameters
        IMaverickV2Pool.RemoveLiquidityParams memory rParams = position.getRemoveParams(tokenId, 0, 1e18);

        // remove to recipient
        position.removeLiquidity(tokenId, recipient, pool, rParams);

        // values match positionInformation values
        console2.log("recipient amounts", tokenA.balanceOf(recipient), tokenB.balanceOf(recipient));
    }

    function _getTickAndRelativeLiquidity()
        internal
        view
        returns (int32[] memory ticks, uint128[] memory relativeLiquidityAmounts)
    {
        ticks = new int32[](5);
        (ticks[0], ticks[1], ticks[2], ticks[3], ticks[4]) = (
            activeTick - 2,
            activeTick - 1,
            activeTick,
            activeTick + 1,
            activeTick + 2
        );

        // relative liquidity amounts are in the liquidity domain, not the LP
        // balance domain. i.e. these are the values a user might input into
        // the addLiquidity bar-graph screen in the app.mav.xyz app.  the scale
        // is relative, but larger numbers are better as they allow more
        // precision in the deltaLPBalance calculation.
        relativeLiquidityAmounts = new uint128[](5);
        (
            relativeLiquidityAmounts[0],
            relativeLiquidityAmounts[1],
            relativeLiquidityAmounts[2],
            relativeLiquidityAmounts[3],
            relativeLiquidityAmounts[4]
        ) = (1e22, 1e22, 1e22, 1e22, 1e22);
    }

    function test_AddWithLensAndSlippageSupport() public {
        // the lens contract has robust support for computing add liquidity
        // parameters.  a user only needs to specify the ceiling amount they
        // are willing to spend, in either tokenA or tokenB units, as well as
        // the amount of price slippage that can be tolerated, and the lens
        // contract returns add parameters that reflect the user's intent.
        (int32[] memory ticks, uint128[] memory relativeLiquidityAmounts) = _getTickAndRelativeLiquidity();

        uint256 maxAmountA = 1e4;
        uint256 slippageFactor = 0.01e18;
        IMaverickV2PoolLens.AddParamsSpecification memory addSpec = IMaverickV2PoolLens.AddParamsSpecification({
            slippageFactorD18: slippageFactor,
            numberOfPriceBreaksPerSide: 3,
            targetAmount: maxAmountA,
            targetIsA: true
        });
        IMaverickV2PoolLens.AddParamsViewInputs memory params = IMaverickV2PoolLens.AddParamsViewInputs({
            pool: pool,
            kind: 0,
            ticks: ticks,
            relativeLiquidityAmounts: relativeLiquidityAmounts,
            addSpec: addSpec
        });

        // get the paramters for the mint function
        (
            bytes memory packedSqrtPriceBreaks,
            bytes[] memory packedArgs,
            uint88[] memory sqrtPriceBreaks,
            IMaverickV2Pool.AddLiquidityParams[] memory addParams,
            IMaverickV2PoolLens.TickDeltas[] memory tickDeltas
        ) = lens.getAddLiquidityParams(params);

        for (uint256 k; k < tickDeltas.length; k++) {
            console2.log("price break", sqrtPriceBreaks[k]);
        }
        console2.log("max A Amount     ", maxAmountA);
        for (uint256 k; k < tickDeltas.length; k++) {
            console2.log("tickDelta      ", k, tickDeltas[k].deltaAOut, tickDeltas[k].deltaBOut);
        }

        // estimate how much A/B we need; amountA will be less than maxAmountA
        (uint256 amountA, uint256 amountB, ) = quoter.calculateAddLiquidity(pool, addParams[3]);
        console2.log("quoted amounts   ", amountA, amountB);

        // there is no output amount check, so the user should multicall the mint
        // function with the price check function
        bytes[] memory args = new bytes[](2);
        uint256 sqrtPrice = lens.getPoolSqrtPrice(pool);
        args[0] = abi.encodeWithSelector(
            rewardRouter.checkSqrtPrice.selector,
            pool,
            (sqrtPrice * 1e18) / (1e18 + slippageFactor),
            (sqrtPrice * (1e18 + slippageFactor)) / 1e18
        );
        args[1] = abi.encodeWithSelector(
            rewardRouter.mintPositionNft.selector,
            pool,
            recipient,
            packedSqrtPriceBreaks,
            packedArgs
        );

        // call multicall with check and mint
        bytes[] memory results = rewardRouter.multicall(args);
        (uint256 tokenAAmount, uint256 tokenBAmount, , uint256 tokenId) = abi.decode(
            results[1],
            (uint256, uint256, uint32[], uint256)
        );

        console2.log("output amounts   ", tokenAAmount, tokenBAmount);

        // call view function to get data about the position nft
        IMaverickV2Position.PositionFullInformation memory output = position.tokenIdPositionInformation(tokenId, 0);
        // amounts may be slightly different as the position owns a pro rata of
        // each bin and there is a rounding operation that dictates the amount
        // the user is entitled to
        console2.log("position amounts ", output.amountA, output.amountB);
        assertEq(position.ownerOf(tokenId), recipient);

        // view function to grab remove parameters
        IMaverickV2Pool.RemoveLiquidityParams memory rParams = position.getRemoveParams(tokenId, 0, 1e18);

        // remove to recipient
        vm.prank(recipient);
        position.removeLiquidity(tokenId, recipient, pool, rParams);

        // values match positionInformation values
        console2.log("recipient amounts", tokenA.balanceOf(recipient), tokenB.balanceOf(recipient));
    }
}
