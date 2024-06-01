// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "./interfaces/IMaverickV2Pool.sol";

/**
 * @notice Permissionless updateFee function that compares oracle price to
 * threshold to determine if a fee update will occur or not.
 */
abstract contract FeeModifierAccessorBase {
    error NoFeeUpdate(int256 oraclePrice, uint256 feeAIn, uint256 feeBIn);
    error GetPriceNotImplemented();

    // threshold value to flip fees
    int256 public immutable priceThreshold;

    uint256 public immutable aboveThresholdFeeAIn;
    uint256 public immutable aboveThresholdFeeBIn;

    uint256 public immutable belowThresholdFeeAIn;
    uint256 public immutable belowThresholdFeeBIn;

    constructor(
        int256 _priceThreshold,
        uint256 _aboveThresholdFeeAIn,
        uint256 _aboveThresholdFeeBIn,
        uint256 _belowThresholdFeeAIn,
        uint256 _belowThresholdFeeBIn
    ) {
        priceThreshold = _priceThreshold;
        aboveThresholdFeeAIn = _aboveThresholdFeeAIn;
        aboveThresholdFeeBIn = _aboveThresholdFeeBIn;
        belowThresholdFeeAIn = _belowThresholdFeeAIn;
        belowThresholdFeeBIn = _belowThresholdFeeBIn;
    }

    function _updateFee(
        IMaverickV2Pool pool,
        bool revertOnNoChange
    ) internal returns (uint256 newFeeAIn, uint256 newFeeBIn) {
        (uint256 existingFeeAIn, uint256 existingFeeBIn) = (pool.fee(true), pool.fee(false));

        int256 price = _getPrice(pool);

        if (price >= priceThreshold) {
            (newFeeAIn, newFeeBIn) = (aboveThresholdFeeAIn, aboveThresholdFeeBIn);
        } else {
            (newFeeAIn, newFeeBIn) = (belowThresholdFeeAIn, belowThresholdFeeBIn);
        }
        if (existingFeeAIn == newFeeAIn && existingFeeBIn == newFeeBIn) {
            if (revertOnNoChange) revert NoFeeUpdate(price, newFeeAIn, newFeeBIn);
        } else {
            pool.setFee(newFeeAIn, newFeeBIn);
        }
    }

    function _getPrice(IMaverickV2Pool) internal view virtual returns (int256);
}
