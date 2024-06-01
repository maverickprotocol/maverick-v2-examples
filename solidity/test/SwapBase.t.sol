// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IMaverickV2Factory} from "../src/interfaces/IMaverickV2Factory.sol";
import {IMaverickV2Quoter} from "../src/interfaces/IMaverickV2Quoter.sol";
import {IMaverickV2Router} from "../src/interfaces/IMaverickV2Router.sol";

import {SwapBaseSepolia} from "./SwapBaseSepolia.sol";

contract SwapBaseTest is SwapBaseSepolia {
    function setUp() public override {
        uint256 forkId = vm.createFork("https://mainnet.base.org/", 14762450);
        vm.selectFork(forkId);

        router = IMaverickV2Router(payable(0x77f71FaaE76c4B661B52dD6471aaBE8Dcb632B97));
        quoter = IMaverickV2Quoter(0xfc201f0f4123bd11429A4d12Fdb6BE7145d55DD5);

        factory = router.factory();
        pool = factory.lookup(0, 1)[0];

        deal(address(pool.tokenA()), recipient, 10e18);
        deal(address(pool.tokenB()), recipient, 10e18);
    }
}
