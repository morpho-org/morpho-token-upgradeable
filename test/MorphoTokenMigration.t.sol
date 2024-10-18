// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "lib/forge-std/src/Test.sol";
import {BaseTest} from "./helpers/BaseTest.sol";
import {Wrapper} from "../src/Wrapper.sol";
import {IMulticall} from "./helpers/interfaces/IMulticall.sol";
import {EncodeLib} from "./helpers/libraries/EncodeLib.sol";
import {IERC20} from
    "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MorphoTokenMigrationTest is BaseTest {
    address internal constant BUNDLER_ADDRESS = 0x4095F064B8d3c3548A3bebfd0Bbfd04750E30077;
    address internal constant LEGACY_MORPHO = 0x9994E35Db50125E0DF82e4c2dde62496CE330999;

    IMulticall internal bundler;
    IERC20 internal legacyMorpho;

    uint256 internal forkId;

    bytes[] internal bundle;

    function setUp() public virtual override {
        _fork();

        vm.startPrank(MORPHO_DAO);
        RolesAuthority(LEGACY_MORPHO).setPublicCapability(0x23b872dd, true);
        RolesAuthority(LEGACY_MORPHO).setPublicCapability(0xa9059cbb, true);
        vm.stopPrank();

        bundler = IMulticall(BUNDLER_ADDRESS);
        legacyMorpho = IERC20(LEGACY_MORPHO);

        super.setUp();
    }

    function _fork() internal virtual {
        string memory rpcUrl = vm.rpcUrl("ethereum");
        uint256 forkBlockNumber = 20969715;

        forkId = vm.createSelectFork(rpcUrl, forkBlockNumber);
        vm.chainId(1);
    }

    function testDeployWrapperZeroAddress() public {
        vm.expectRevert();
        new Wrapper(address(0));
    }

    function testTotalSupply() public view {
        assertEq(newMorpho.totalSupply(), 1_000_000_000e18);
    }

    function testInitialWrapperBalances() public view {
        assertEq(legacyMorpho.balanceOf(address(wrapper)), 0);
        assertEq(newMorpho.balanceOf(address(wrapper)), 1_000_000_000e18);
    }

    function testDepositForZeroAddress(uint256 amount) public {
        vm.assume(amount != 0);

        vm.expectRevert();
        wrapper.depositFor(address(0), amount);
    }

    function testDepositForSelfAddress(uint256 amount) public {
        vm.assume(amount != 0);

        vm.expectRevert();
        wrapper.depositFor(address(wrapper), amount);
    }

    function testWithdrawToZeroAddress(uint256 amount) public {
        vm.assume(amount != 0);

        vm.expectRevert();
        wrapper.withdrawTo(address(0), amount);
    }

    function testWithdrawToSelfAddress(uint256 amount) public {
        vm.assume(amount != 0);

        vm.expectRevert();
        wrapper.withdrawTo(address(wrapper), amount);
    }

    function testDAOMigration() public {
        uint256 daoTokenAmount = legacyMorpho.balanceOf(MORPHO_DAO);

        bundle.push(EncodeLib._erc20TransferFrom(LEGACY_MORPHO, daoTokenAmount));
        bundle.push(EncodeLib._erc20WrapperDepositFor(address(wrapper), daoTokenAmount));

        vm.startPrank(MORPHO_DAO);
        legacyMorpho.approve(address(bundler), daoTokenAmount);
        bundler.multicall(bundle);
        vm.stopPrank();

        assertEq(legacyMorpho.balanceOf(MORPHO_DAO), 0, "legacyMorpho.balanceOf(MORPHO_DAO)");
        assertEq(legacyMorpho.balanceOf(address(wrapper)), daoTokenAmount, "legacyMorpho.balanceOf(wrapper)");
        assertEq(newMorpho.balanceOf(MORPHO_DAO), daoTokenAmount, "newMorpho.balanceOf(MORPHO_DAO)");
    }

    function testMigration(address migrater, uint256 amount) public {
        vm.assume(migrater != address(0));
        vm.assume(migrater != MORPHO_DAO);
        amount = bound(amount, MIN_TEST_AMOUNT, 1_000_000_000e18);

        deal(LEGACY_MORPHO, migrater, amount);

        bundle.push(EncodeLib._erc20TransferFrom(LEGACY_MORPHO, amount));
        bundle.push(EncodeLib._erc20WrapperDepositFor(address(wrapper), amount));

        vm.startPrank(migrater);
        legacyMorpho.approve(address(bundler), amount);
        bundler.multicall(bundle);
        vm.stopPrank();

        assertEq(legacyMorpho.balanceOf(migrater), 0, "legacyMorpho.balanceOf(migrater)");
        assertEq(legacyMorpho.balanceOf(address(wrapper)), amount, "legacyMorpho.balanceOf(wrapper)");
        assertEq(newMorpho.balanceOf(address(wrapper)), 1_000_000_000e18 - amount, "newMorpho.balanceOf(wrapper)");
        assertEq(newMorpho.balanceOf(migrater), amount, "newMorpho.balanceOf(migrater)");
    }

    function testRevertMigration(address migrater, uint256 migratedAmount, uint256 revertedAmount) public {
        vm.assume(migrater != address(0));
        vm.assume(migrater != MORPHO_DAO);
        migratedAmount = bound(migratedAmount, MIN_TEST_AMOUNT, 1_000_000_000e18);
        revertedAmount = bound(revertedAmount, MIN_TEST_AMOUNT, migratedAmount);

        deal(LEGACY_MORPHO, migrater, migratedAmount);

        bundle.push(EncodeLib._erc20TransferFrom(LEGACY_MORPHO, migratedAmount));
        bundle.push(EncodeLib._erc20WrapperDepositFor(address(wrapper), migratedAmount));

        vm.startPrank(migrater);
        legacyMorpho.approve(address(bundler), migratedAmount);
        bundler.multicall(bundle);
        vm.stopPrank();

        vm.startPrank(migrater);
        newMorpho.approve(address(wrapper), revertedAmount);
        wrapper.withdrawTo(migrater, revertedAmount);
        vm.stopPrank();

        assertEq(legacyMorpho.balanceOf(migrater), revertedAmount, "legacyMorpho.balanceOf(migrater)");
        assertEq(
            legacyMorpho.balanceOf(address(wrapper)), migratedAmount - revertedAmount, "legacyMorpho.balanceOf(wrapper)"
        );
        assertEq(
            newMorpho.balanceOf(address(wrapper)),
            1_000_000_000e18 - migratedAmount + revertedAmount,
            "newMorpho.balanceOf(wrapper)"
        );
        assertEq(newMorpho.balanceOf(migrater), migratedAmount - revertedAmount, "newMorpho.balanceOf(migrater)");
    }
}

interface RolesAuthority {
    function setPublicCapability(bytes4 functionSig, bool enabled) external;
}
