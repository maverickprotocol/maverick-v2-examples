// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IMaverickV2Factory} from "../src/interfaces/IMaverickV2Factory.sol";
import {IMaverickV2Pool} from "../src/interfaces/IMaverickV2Pool.sol";
import {IMaverickV2Quoter} from "../src/interfaces/IMaverickV2Quoter.sol";
import {IMaverickV2Router} from "../src/interfaces/IMaverickV2Router.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapBaseSepolia is Test {
    IMaverickV2Factory public factory;
    IMaverickV2Pool public pool;
    IMaverickV2Quoter public quoter;
    IMaverickV2Router public router;
    address public constant recipient = address(10);

    function setUp() public virtual  {
        uint256 forkId = vm.createFork("https://sepolia.base.org/", 10236804);
        vm.selectFork(forkId);

        factory = IMaverickV2Factory(
            0x1D7472AAfe52e83BA22E707Fc77fF3F3b85551CC
        );
        pool = factory.lookup(0, 1)[0];

        deal(address(pool.tokenA()), recipient, 10e18);
        deal(address(pool.tokenB()), recipient, 10e18);
        quoter = IMaverickV2Quoter(0xfc201f0f4123bd11429A4d12Fdb6BE7145d55DD5);
        router = IMaverickV2Router(
            payable(0x77f71FaaE76c4B661B52dD6471aaBE8Dcb632B97)
        );
    }

    function estimateSwap(
        uint128 amountIn,
        bool tokenAIn,
        bool exactOut
    ) internal returns (uint256 returnedAmountIn, uint256 returnedAmountOut) {
        int32 tickLimit = tokenAIn
            ? pool.getState().activeTick + 10
            : pool.getState().activeTick - 10;
        (returnedAmountIn, returnedAmountOut, ) = quoter.calculateSwap(
            pool,
            amountIn,
            tokenAIn,
            exactOut,
            tickLimit
        );
    }

    function swap(
        uint256 amount,
        uint256 transferAmount,
        bool tokenAIn,
        bool exactOutput
    ) internal returns (uint256 returnedAmountIn, uint256 returnedAmountOut) {
        // Set the tick limit bounds based on the current active tick
        int32 tickLimit = tokenAIn
            ? pool.getState().activeTick + 10
            : pool.getState().activeTick - 10;
        vm.startPrank(recipient);

        IERC20 inputToken = tokenAIn ? pool.tokenA() : pool.tokenB();
        IERC20 outputToken = tokenAIn ? pool.tokenB() : pool.tokenA();

        uint256 outputTokenBalanceBefore = outputToken.balanceOf(recipient);

        // The pool uses push accounting so transfer the tokens to the pool before calling swap
        inputToken.transfer(address(pool), transferAmount);

        (returnedAmountIn, returnedAmountOut) = pool.swap(
            recipient,
            IMaverickV2Pool.SwapParams({
                amount: amount,
                tokenAIn: tokenAIn,
                exactOutput: exactOutput,
                tickLimit: tickLimit
            }),
            ""
        );

        uint256 outputTokenBalanceAfter = outputToken.balanceOf(recipient);
        assertEq(
            outputTokenBalanceAfter - outputTokenBalanceBefore,
            returnedAmountOut
        );
        vm.stopPrank();
    }

    function swapExactInWithRouter(
        uint256 amount,
        uint256 transferAmount,
        bool tokenAIn,
        uint256 minReceiveAmount
    ) internal returns (uint256 returnedAmountOut) {
        vm.startPrank(recipient);

        IERC20 inputToken = tokenAIn ? pool.tokenA() : pool.tokenB();
        IERC20 outputToken = tokenAIn ? pool.tokenB() : pool.tokenA();

        uint256 outputTokenBalanceBefore = outputToken.balanceOf(recipient);

        // The pool uses push accounting so transfer the tokens to the pool before calling swap
        inputToken.approve(address(router), transferAmount);

        (returnedAmountOut) = router.exactInputSingle(
            recipient,
            pool,
            tokenAIn,
            amount,
            minReceiveAmount
        );

        uint256 outputTokenBalanceAfter = outputToken.balanceOf(recipient);
        assertEq(
            outputTokenBalanceAfter - outputTokenBalanceBefore,
            returnedAmountOut
        );
        vm.stopPrank();
    }

    function swapExactOutWithRouter(
        uint256 amount,
        uint256 transferAmount,
        bool tokenAIn,
        uint256 amountInMaximum
    ) internal returns (uint256 returnedAmountIn) {
        vm.startPrank(recipient);

        IERC20 inputToken = tokenAIn ? pool.tokenA() : pool.tokenB();

        uint256 inputTokenBalanceBefore = inputToken.balanceOf(recipient);

        // The pool uses push accounting so transfer the tokens to the pool before calling swap
        inputToken.approve(address(router), transferAmount);
        (returnedAmountIn, ) = router.exactOutputSingle(
            recipient,
            pool,
            tokenAIn,
            amount,
            amountInMaximum
        );

        uint256 inputTokenBalanceAfter = inputToken.balanceOf(recipient);
        assertEq(
            inputTokenBalanceBefore - inputTokenBalanceAfter,
            returnedAmountIn
        );
        vm.stopPrank();
    }

    function test_SwapTokenAInExactIn() public {
        (, uint256 estimatedAmountOut) = estimateSwap(1e6, true, false);
        (, uint256 amountOut) = swap(1e6, 1e6, true, false);
        assertEq(estimatedAmountOut, amountOut);
    }

    function test_SwapTokenAInExactInWithRouter() public {
        (, uint256 estimatedAmountOut) = estimateSwap(1e6, true, false);
        uint256 amountOut = swapExactInWithRouter(
            1e6,
            1e6,
            true,
            estimatedAmountOut
        );
        assertEq(estimatedAmountOut, amountOut);
    }

    function test_SwapTokenAInExactOut() public {
        (uint256 estimatedAmountIn, ) = estimateSwap(1e6, true, true);
        (uint256 amountIn, ) = swap(1e6, estimatedAmountIn, true, true);
        assertEq(estimatedAmountIn, amountIn);
    }

    function test_SwapTokenAInExactOutWithRouter() public {
        (uint256 estimatedAmountIn, ) = estimateSwap(1e6, true, true);
        uint256 amountIn = swapExactOutWithRouter(
            1e6,
            estimatedAmountIn,
            true,
            estimatedAmountIn
        );
        assertEq(estimatedAmountIn, amountIn);
    }

    function test_SwapTokenBInExactIn() public {
        (, uint256 estimatedAmountOut) = estimateSwap(1e6, false, false);
        (, uint256 amountOut) = swap(1e6, 1e6, false, false);
        assertEq(estimatedAmountOut, amountOut);
    }

    function test_SwapTokenBInExactInWithRouter() public {
        (, uint256 estimatedAmountOut) = estimateSwap(1e6, false, false);
        uint256 amountOut = swapExactInWithRouter(
            1e6,
            1e6,
            false,
            estimatedAmountOut
        );
        assertEq(estimatedAmountOut, amountOut);
    }

    function test_SwapTokenBInExactOut() public {
        (uint256 estimatedAmountIn, ) = estimateSwap(1e6, false, true);
        (uint256 amountIn, ) = swap(1e6, estimatedAmountIn, false, true);
        assertEq(estimatedAmountIn, amountIn);
    }

    function test_SwapTokenBInExactOutWithRouter() public {
        (uint256 estimatedAmountIn, ) = estimateSwap(1e6, false, true);
        uint256 amountIn = swapExactOutWithRouter(
            1e6,
            estimatedAmountIn,
            false,
            estimatedAmountIn
        );
        assertEq(estimatedAmountIn, amountIn);
    }
}
