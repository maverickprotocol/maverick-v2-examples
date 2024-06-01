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
import {FeeModifierAccessorSwap} from "../src/router-incompatible/FeeModifierAccessorSwap.sol";

contract FeeModifierAccessorSwapBaseSepolia is Test {
    IMaverickV2Factory public factory;
    IMaverickV2Pool public pool;
    IMaverickV2Pool public newPool;
    IMaverickV2Router public router;
    IMaverickV2RewardRouter public rewardRouter;
    IERC20 public tokenA;
    IERC20 public tokenB;

    FeeModifierAccessorSwap public accessor;
    address public accessorAddress;

    address public constant recipient = address(10);
    bytes constant EMPTY_PRICE_BREAKS = hex"010000000000000000000000";

    function setUp() public virtual {
        uint256 forkId = vm.createFork("https://sepolia.base.org/", 10721808);
        vm.selectFork(forkId);

        accessor = new FeeModifierAccessorSwap(0, 0.002e18, 0.001e18, 0.001e18, 0.002e18);
        accessorAddress = address(accessor);

        router = IMaverickV2Router(payable(0x5D7784E7bdB859cb9E8779995ae95ddF68C20fDB));
        rewardRouter = IMaverickV2RewardRouter(payable(0x7377d47335AD579a7e0BbeB09350f554c4A1aAeF));

        factory = rewardRouter.factory();

        pool = factory.lookup(0, 1)[0];
        tokenA = pool.tokenA();
        tokenB = pool.tokenB();

        deal(address(tokenA), address(this), 10e18);
        deal(address(tokenB), address(this), 10e18);
        tokenA.approve(address(rewardRouter), type(uint256).max);
        tokenB.approve(address(rewardRouter), type(uint256).max);
        newPool = factory.createPermissioned(0, 0, 10, 3600, tokenA, tokenB, 0, 0xF, accessorAddress, false, true);
        vm.label(address(newPool), "newPool");
    }

    function test_PoolFeeSetting() public {
        // unable to set fee directly on permissioned pool
        vm.expectRevert();
        newPool.setFee(1, 1);
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

    function test_AddAndSwap() public {
        // add liquidity to swap against
        IMaverickV2Pool.AddLiquidityParams memory params = getAddParams(0.01e18, 0, -2, 2);
        IMaverickV2Pool.AddLiquidityParams[] memory paramsArray = new IMaverickV2Pool.AddLiquidityParams[](1);
        paramsArray[0] = params;

        rewardRouter.mintPositionNft(
            newPool,
            recipient,
            EMPTY_PRICE_BREAKS,
            rewardRouter.packAddLiquidityArgsArray(paramsArray)
        );

        console2.log("twap", newPool.getCurrentTwa());
        console2.log("pool", newPool.getState().reserveA, newPool.getState().reserveB);
        console2.log("fee", newPool.fee(true), newPool.fee(false));

        // protocol router is not permissioned to swap
        vm.expectRevert();
        router.exactInputSingle(recipient, newPool, true, 100, 1);

        skip(5000);
        // accessor is permissioned to swap; must be very careful to approve accessors.
        tokenA.approve(address(accessor), type(uint256).max);
        accessor.exactInputSingle(recipient, newPool, true, 2e11, 1);

        skip(5000);
        console2.log("twap", newPool.getCurrentTwa());
        console2.log("pool", newPool.getState().reserveA, newPool.getState().reserveB);
        console2.log("fee", newPool.fee(true), newPool.fee(false));

        tokenB.approve(address(accessor), type(uint256).max);
        for (uint256 k; k < 4; k++) {
            accessor.exactInputSingle(recipient, newPool, false, 7e16, 1);

            skip(5000);
            console2.log("twap", newPool.getCurrentTwa());
            console2.log("pool", newPool.getState().reserveA, newPool.getState().reserveB);
            console2.log("fee", newPool.fee(true), newPool.fee(false));
        }
    }
}
