// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {Test, console} from "forge-std/Test.sol";

import {YoSifuStargateVaultFactory, YoSifuStargateVault} from "../src/YoSifuStargateVaultFactory.sol";
import {YoSifuStargateVaultWrapper} from "../src/YoSifuStargateVaultWrapper.sol";

import {IYoSifuStargateVault} from "../src/interfaces/IYoSifuStargateVault.sol";
import {ILPStaking} from "../src/interfaces/ILPStaking.sol";
import {IStargatePool} from "../src/interfaces/IStargatePool.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockSwapper} from "../src/mocks/MockSwapper.sol";

import {CurveSwapper} from "../src/swapper/CurveSwapper.sol";

contract YoSifuStargateVaultTest is Test {
    using SafeTransferLib for ERC20;

    YoSifuStargateVaultFactory public vaultFactory;
    YoSifuStargateVault public vault;
    YoSifuStargateVault public ethVault;
    YoSifuStargateVault public usdtVault;
    YoSifuStargateVaultWrapper public wrapper;
    MockSwapper public mockSwapper;
    CurveSwapper public curveSwapper;

    ERC20 public USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 public SGETH = ERC20(0x72E2F4830b9E45d52F80aC08CB2bEC0FeF72eD9c);
    ERC20 public USDT = ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    ERC20 public stargateUSDCLP =
        ERC20(0xdf0770dF86a8034b3EFEf0A1Bb3c889B8332FF56);
    ERC20 public stargateETHLP =
        ERC20(0x101816545F6bd2b1076434B54383a1E633390A2E);
    ERC20 public stargateUSDTLP =
        ERC20(0x38EA452219524Bb87e18dE1C24D3bB59510BD783);

    address public stargateStaking =
        address(0xB0D502E938ed5f4df2E681fE6E419ff29631d62b);
    address public stargateRouter =
        address(0x8731d54E9D02c286767d56ac03e8037C07e01e98);

    ERC20 public rewardToken =
        ERC20(0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6); // STG

    address public curveSTGPOOL =
        address(0x3211C6cBeF1429da3D0d58494938299C92Ad5860);

    uint256 public USDC_PID = 0;
    uint256 public USDT_PID = 1;
    uint256 public ETH_PID = 2;
    uint256 public fee = 20e16; // 20%

    address internal constant alice = address(0xABCD);
    address internal constant bob = address(0xBEEF);
    address internal constant feeTo = address(0x6969);
    address internal constant owner = address(0xADCB);

    function setUp() public {
        vaultFactory = new YoSifuStargateVaultFactory(
            stargateStaking,
            stargateRouter,
            rewardToken,
            owner
        );

        wrapper = new YoSifuStargateVaultWrapper(
            address(SGETH),
            stargateRouter,
            owner
        );

        vm.prank(owner);
        vault = vaultFactory.createVault(
            stargateUSDCLP,
            USDC_PID,
            feeTo,
            owner
        );

        vm.prank(owner);
        ethVault = vaultFactory.createVault(
            stargateETHLP,
            ETH_PID,
            feeTo,
            owner
        );

        vm.prank(owner);
        usdtVault = vaultFactory.createVault(
            stargateUSDTLP,
            USDT_PID,
            feeTo,
            owner
        );

        address[] memory vaults = new address[](3);
        vaults[0] = address(vault);
        vaults[1] = address(ethVault);
        vaults[2] = address(usdtVault);
        vm.prank(owner);
        wrapper.approveToVault(vaults);

        deal(address(USDC), alice, 100000e6);
        deal(address(USDC), bob, 50000e6);

        deal(alice, 100 ether);
        deal(bob, 10 ether);

        deal(address(USDT), alice, 100000e6);
        deal(address(USDT), bob, 50000e6);

        mockSwapper = new MockSwapper(address(vault));
        curveSwapper = new CurveSwapper(
            address(vault),
            curveSTGPOOL,
            rewardToken,
            USDC
        );

        vm.label(address(0xABCD), "Alice");
        vm.label(address(0xBEEF), "Bob");
        vm.label(address(0xBEEF), "Bob");
        vm.label(address(0xADCB), "Onwer");
        vm.label(address(0x6969), "Fee To");

        vm.prank(alice);
        USDC.safeApprove(address(wrapper), type(uint256).max);
        vm.prank(alice);
        USDT.safeApprove(address(wrapper), type(uint256).max);

        vm.prank(alice);
        ERC20(address(vault)).safeApprove(address(wrapper), type(uint256).max);
        vm.prank(alice);
        ERC20(address(ethVault)).safeApprove(
            address(wrapper),
            type(uint256).max
        );
        vm.prank(alice);
        ERC20(address(usdtVault)).safeApprove(
            address(wrapper),
            type(uint256).max
        );

        vm.prank(bob);
        USDC.safeApprove(address(wrapper), type(uint256).max);
        vm.prank(bob);
        USDT.safeApprove(address(wrapper), type(uint256).max);

        vm.prank(bob);
        ERC20(address(vault)).safeApprove(address(wrapper), type(uint256).max);
        vm.prank(bob);
        ERC20(address(ethVault)).safeApprove(
            address(wrapper),
            type(uint256).max
        );
        vm.prank(bob);
        ERC20(address(usdtVault)).safeApprove(
            address(wrapper),
            type(uint256).max
        );

        vm.prank(owner);
        vault.setFees(fee);
    }

    function testInitialDepositETH(uint256 assets) public {
        vm.assume(assets > 1 && assets <= alice.balance);
        uint256 aliceBalanceBefore = alice.balance;

        vm.prank(alice);
        (uint256 sharesVault, ) = wrapper.depositUnderlyingToVault{
            value: assets
        }(IYoSifuStargateVault(address(ethVault)), 0, assets, alice);

        vm.prank(alice);

        wrapper.withdrawUnderlyingFromVault(
            IYoSifuStargateVault(address(ethVault)),
            0,
            sharesVault,
            alice
        );

        assertEq(aliceBalanceBefore, alice.balance + 1);
    }

    function testInitialDeposit(uint256 assets) public {
        vm.assume(assets > 1 && assets <= USDC.balanceOf(alice));
        uint256 aliceBalanceBefore = USDC.balanceOf(alice);

        (uint256 preSharesVault, uint256 preSharesPool) = wrapper
            .previewDepositUnderlyingToVault(
                IYoSifuStargateVault(address(vault)),
                assets
            );

        vm.prank(alice);
        (uint256 sharesVault, uint256 sharesPool) = wrapper
            .depositUnderlyingToVault(
                IYoSifuStargateVault(address(vault)),
                preSharesVault,
                assets,
                alice
            );

        assertEq(preSharesVault, sharesVault);
        assertEq(preSharesPool, sharesPool);

        (uint256 preAssetsVault, uint256 preAssetsPool) = wrapper
            .previewWithdrawUnderlyingFromVault(
                IYoSifuStargateVault(address(vault)),
                sharesVault
            );

        vm.prank(alice);
        (uint256 assetsVault, uint256 assetsPool) = wrapper
            .withdrawUnderlyingFromVault(
                IYoSifuStargateVault(address(vault)),
                0,
                sharesVault,
                alice
            );

        assertEq(preAssetsVault, assetsVault);
        assertEq(preAssetsPool, assetsPool);

        assertEq(aliceBalanceBefore, USDC.balanceOf(alice) + 1);
    }

    function testInitialDepositUSDT(uint256 assets) public {
        vm.assume(assets > 1 && assets <= USDT.balanceOf(alice));
        uint256 aliceBalanceBefore = USDT.balanceOf(alice);
        vm.prank(alice);
        (uint256 sharesVault, ) = wrapper.depositUnderlyingToVault(
            IYoSifuStargateVault(address(usdtVault)),
            0,
            assets,
            alice
        );

        vm.prank(alice);
        wrapper.withdrawUnderlyingFromVault(
            IYoSifuStargateVault(address(usdtVault)),
            0,
            sharesVault,
            alice
        );

        assertEq(aliceBalanceBefore, USDT.balanceOf(alice) + 1);
    }

    function testDepositAndHarvest() public {
        // vm.assume(assets > 0 && assets <= stargateUSDCLP.balanceOf(alice));
        vm.prank(alice);
        (uint256 aliceShares, ) = wrapper.depositUnderlyingToVault(
            IYoSifuStargateVault(address(vault)),
            0,
            100e6,
            alice
        );

        bytes memory harvestData = abi.encode(address(USDC));

        deal(address(USDC), address(mockSwapper), 50e6);
        vm.prank(owner);
        vault.harvest(address(mockSwapper), 0, harvestData);

        vm.roll(block.number + 1);

        vm.prank(bob);
        (uint256 bobShares, ) = wrapper.depositUnderlyingToVault(
            IYoSifuStargateVault(address(vault)),
            0,
            50e6,
            bob
        );

        deal(address(USDC), address(mockSwapper), 50e6);
        vm.prank(owner);
        vault.harvest(address(mockSwapper), 0, harvestData);

        vm.prank(alice);
        wrapper.withdrawUnderlyingFromVault(
            IYoSifuStargateVault(address(vault)),
            0,
            aliceShares,
            alice
        );

        vm.prank(bob);
        wrapper.withdrawUnderlyingFromVault(
            IYoSifuStargateVault(address(vault)),
            0,
            bobShares,
            bob
        );
    }

    function testWarpDepositAndHarvest() public {
        // vm.assume(assets > 0 && assets <= stargateUSDCLP.balanceOf(alice));
        vm.prank(alice);

        (uint256 aliceShares, ) = wrapper.depositUnderlyingToVault(
            IYoSifuStargateVault(address(vault)),
            0,
            100000e6,
            alice
        );

        bytes memory harvestData = abi.encode(address(USDC));

        skip(10368000);
        vm.roll(block.number + 1);

        vm.prank(owner);
        vault.harvest(address(curveSwapper), 0, harvestData);

        vm.roll(block.number + 1);

        vm.prank(bob);
        (uint256 bobShares, ) = wrapper.depositUnderlyingToVault(
            IYoSifuStargateVault(address(vault)),
            0,
            50000e6,
            bob
        );

        skip(10368000);
        vm.roll(block.number + 1);

        vm.prank(owner);
        vault.harvest(address(curveSwapper), 0, harvestData);

        vm.roll(block.number + 1);

        vm.prank(alice);
        wrapper.withdrawUnderlyingFromVault(
            IYoSifuStargateVault(address(vault)),
            0,
            aliceShares,
            alice
        );

        vm.prank(bob);
        wrapper.withdrawUnderlyingFromVault(
            IYoSifuStargateVault(address(vault)),
            0,
            bobShares,
            bob
        );
    }
}
