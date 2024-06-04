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
import {FeeModifierAccessorOwned} from "../src/router-compatible/FeeModifierAccessorOwned.sol";

contract OwnedProgrammablePoolBaseSepolia is Test {
    IMaverickV2Factory public factory;
    IMaverickV2Pool public pool;
    IMaverickV2Pool public newPool;
    IMaverickV2Router public router;
    IMaverickV2RewardRouter public rewardRouter;
    IERC20 public tokenA;
    IERC20 public tokenB;

    FeeModifierAccessorOwned public accessor;
    address public accessorAddress;

    address public constant recipient = address(10);
    bytes constant EMPTY_PRICE_BREAKS = hex"010000000000000000000000";
    address public constant owner = address(11);

    function setUp() public virtual {
        uint256 forkId = vm.createFork("https://sepolia.base.org/", 10855383);
        vm.selectFork(forkId);

        accessor = new FeeModifierAccessorOwned(owner);
        accessorAddress = address(accessor);

        rewardRouter = IMaverickV2RewardRouter(payable(0xE889c94e233Ca0788E9bc3899cC5BBc5eA1b1053));
        router = IMaverickV2Router(payable(0x5eDEd0d7E76C563FF081Ca01D9d12D6B404Df527));

        factory = rewardRouter.factory();

        pool = factory.lookup(0, 1)[0];
        tokenA = pool.tokenA();
        tokenB = pool.tokenB();

        deal(address(tokenA), address(this), 10e18);
        deal(address(tokenB), address(this), 10e18);
        tokenA.approve(address(rewardRouter), type(uint256).max);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(rewardRouter), type(uint256).max);
        newPool = factory.createPermissioned(0, 0, 10, 3600, tokenA, tokenB, 0, 0xF, accessorAddress, false, false);
    }

    function test_PoolFeeSetting() public {
        // unable to set fee directly on permissionless pool
        vm.expectRevert();
        pool.setFee(1, 1);

        // unable to set fee directly on permissioned pool
        vm.expectRevert();
        newPool.setFee(1, 1);

        // non owner can not make this call on the accessor
        vm.expectRevert();
        accessor.updateFee(newPool, 1, 1);
    }

    function test_PoolFeeSettingPrankOwner() public {
        vm.startPrank(owner);

        // owner can update fee on the pool
        assertEq(newPool.fee(true), 0);
        assertEq(newPool.fee(false), 0);
        accessor.updateFee(newPool, 1, 1);
        assertEq(newPool.fee(true), 1);
        assertEq(newPool.fee(false), 1);

        // owner of accessor is also unable to set fee directly on permissioned
        // pool
        vm.expectRevert();
        newPool.setFee(1, 1);

        // owner of accessor is unable to set fee directly on permissionless
        // pool through the acccessor
        vm.expectRevert();
        accessor.updateFee(pool, 1, 1);
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

        // swap through protocol router works
        uint256 amountOut = router.exactInputSingle(recipient, newPool, true, 100, 1);
        assertGt(amountOut, 0);
    }
}
