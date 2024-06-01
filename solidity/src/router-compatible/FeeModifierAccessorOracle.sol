// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {IMaverickV2Pool} from "../interfaces/IMaverickV2Pool.sol";
import {FeeModifierAccessorBase} from "../FeeModifierAccessorBase.sol";

interface IChainLinkAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/**
 * @notice Permissionless updateFee function that compares oracle price to
 * threshold to determine if a fee update will occur or not.
 */
contract FeeModifierAccessorOracle is FeeModifierAccessorBase {
    // chainlink price feed oracle
    IChainLinkAggregatorV3 public immutable oracle;

    constructor(
        IChainLinkAggregatorV3 _oracle,
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
    {
        oracle = _oracle;
    }

    function updateFee(IMaverickV2Pool pool) external returns (uint256 newFeeAIn, uint256 newFeeBIn) {
        (newFeeAIn, newFeeBIn) = _updateFee(pool, true);
    }

    function _getPrice(IMaverickV2Pool) internal view override returns (int256 price) {
        (, price, , , ) = oracle.latestRoundData();
    }
}
