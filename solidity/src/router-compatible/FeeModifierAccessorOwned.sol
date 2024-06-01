// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMaverickV2Pool} from "../interfaces/IMaverickV2Pool.sol";

/**
 * @notice Permissioned updateFee function allows owner to update fee.
 */
contract FeeModifierAccessorOwned is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}

    function updateFee(IMaverickV2Pool pool, uint256 newFeeAIn, uint256 newFeeBIn) external onlyOwner {
        pool.setFee(newFeeAIn, newFeeBIn);
    }
}
