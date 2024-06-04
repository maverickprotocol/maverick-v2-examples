// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IMaverickV2Factory} from "../src/interfaces/IMaverickV2Factory.sol";
import {IMaverickV2Quoter} from "../src/interfaces/IMaverickV2Quoter.sol";
import {IMaverickV2Router} from "../src/interfaces/IMaverickV2Router.sol";

import {SwapBaseSepolia} from "./SwapBaseSepolia.sol";

contract SwapBaseTest is SwapBaseSepolia {
    function setUp() public override {
        uint256 forkId = vm.createFork("https://mainnet.base.org/", 15344285);
        vm.selectFork(forkId);

        router = IMaverickV2Router(payable(0x5eDEd0d7E76C563FF081Ca01D9d12D6B404Df527));
        quoter = IMaverickV2Quoter(0xb40AfdB85a07f37aE217E7D6462e609900dD8D7A);

        factory = router.factory();
        pool = factory.lookup(0, 1)[0];

        deal(address(pool.tokenA()), recipient, 10e18);
        deal(address(pool.tokenB()), recipient, 10e18);
    }
}
