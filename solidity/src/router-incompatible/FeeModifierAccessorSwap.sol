// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMaverickV2Pool} from "../interfaces/IMaverickV2Pool.sol";
import {IMaverickV2Factory} from "../interfaces/IMaverickV2Factory.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";

import {FeeModifierAccessorBase} from "../FeeModifierAccessorBase.sol";

contract SimpleRouter {
    error RouterTooLittleReceived(uint256 amountOutMinimum, uint256 amountOut);

    function exactInputSingle(
        address recipient,
        IMaverickV2Pool pool,
        bool tokenAIn,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) public payable returns (uint256 amountOut) {
        IERC20 inputToken = tokenAIn ? pool.tokenA() : pool.tokenB();

        inputToken.transferFrom(msg.sender, address(pool), amountIn);

        IMaverickV2Pool.SwapParams memory swapParams = IMaverickV2Pool.SwapParams({
            amount: amountIn,
            tokenAIn: tokenAIn,
            exactOutput: false,
            tickLimit: tokenAIn ? type(int32).max : type(int32).min
        });
        (, amountOut) = _swap(pool, recipient, swapParams, bytes(""));

        if (amountOut < amountOutMinimum) revert RouterTooLittleReceived(amountOutMinimum, amountOut);
    }

    function _swap(
        IMaverickV2Pool pool,
        address recipient,
        IMaverickV2Pool.SwapParams memory params,
        bytes memory data
    ) internal virtual returns (uint256 amountIn, uint256 amountOut) {
        (amountIn, amountOut) = pool.swap(recipient, params, data);
    }
}

contract FeeModifierAccessorSwap is SimpleRouter, FeeModifierAccessorBase {
    constructor(
        int256 _priceThreshold,
        uint256 _aboveThresholdFeeAIn,
        uint256 _aboveThresholdFeeBIn,
        uint256 _belowThresholdFeeAIn,
        uint256 _belowThresholdFeeBIn
    )
        FeeModifierAccessorBase(
            _priceThreshold,
            _aboveThresholdFeeAIn,
            _aboveThresholdFeeBIn,
            _belowThresholdFeeAIn,
            _belowThresholdFeeBIn
        )
    {}

    /**
     * @notice Implement accessor base price function.
     */
    function _getPrice(IMaverickV2Pool pool) internal view override returns (int256 price) {
        price = pool.getCurrentTwa();
    }

    function _swap(
        IMaverickV2Pool pool,
        address recipient,
        IMaverickV2Pool.SwapParams memory params,
        bytes memory data
    ) internal override returns (uint256 amountIn, uint256 amountOut) {
        (amountIn, amountOut) = pool.swap(recipient, params, data);
        _updateFee(pool, false);
    }
}
