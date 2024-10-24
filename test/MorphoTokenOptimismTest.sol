// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {MorphoTokenOptimism} from "../src/MorphoTokenOptimism.sol";
import {DelegationToken} from "../src/DelegationToken.sol";
import {ERC1967Proxy} from
    "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ERC1967Utils} from
    "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract MorphoTokenOptimismTest is Test {
    address internal constant MORPHO_DAO = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;
    address internal REMOTE_TOKEN;
    address internal BRIDGE;

    MorphoTokenOptimism public tokenImplem;
    MorphoTokenOptimism public morphoOptimism;
    ERC1967Proxy public tokenProxy;

    uint256 internal constant MIN_TEST_AMOUNT = 100;
    uint256 internal constant MAX_TEST_AMOUNT = 1e28;

    function setUp() public virtual {
        REMOTE_TOKEN = makeAddr("RemoteToken");
        BRIDGE = makeAddr("Bridge");

        // DEPLOYMENTS
        tokenImplem = new MorphoTokenOptimism(REMOTE_TOKEN, BRIDGE);
        tokenProxy = new ERC1967Proxy(address(tokenImplem), hex"");

        morphoOptimism = MorphoTokenOptimism(payable(address(tokenProxy)));
        morphoOptimism.initialize(MORPHO_DAO);
    }

    function testInitializeZeroAddress(address randomAddress) public {
        vm.assume(randomAddress != address(0));

        address proxy = address(new ERC1967Proxy(address(tokenImplem), hex""));

        vm.expectRevert(MorphoTokenOptimism.ZeroAddress.selector);
        MorphoTokenOptimism(proxy).initialize(address(0));
    }

    function testUpgradeNotOwner(address updater) public {
        vm.assume(updater != address(0));
        vm.assume(updater != MORPHO_DAO);

        address newImplem = address(new MorphoTokenOptimism(REMOTE_TOKEN, BRIDGE));

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, updater));
        vm.prank(updater);
        morphoOptimism.upgradeToAndCall(newImplem, hex"");
    }

    function testUpgrade() public {
        address newImplem = address(new MorphoTokenOptimism(REMOTE_TOKEN, BRIDGE));

        vm.expectEmit(address(morphoOptimism));
        emit ERC1967Utils.Upgraded(newImplem);
        vm.prank(MORPHO_DAO);
        morphoOptimism.upgradeToAndCall(newImplem, hex"");
    }

    function testGetters() public view {
        assertEq(morphoOptimism.remoteToken(), REMOTE_TOKEN, "remoteToken");
        assertEq(morphoOptimism.bridge(), BRIDGE, "bridge");
        assertEq(morphoOptimism.owner(), MORPHO_DAO, "owner");
    }

    function testMintNoBridge(address account, address to, uint256 amount) public {
        vm.assume(account != address(0));
        vm.assume(to != address(0));
        vm.assume(account != BRIDGE);
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.expectRevert(MorphoTokenOptimism.NotBridge.selector);
        vm.prank(account);
        morphoOptimism.mint(to, amount);
    }

    function testMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        assertEq(morphoOptimism.totalSupply(), 0, "totalSupply");
        assertEq(morphoOptimism.balanceOf(to), 0, "balanceOf(account)");

        vm.expectEmit(address(morphoOptimism));
        emit DelegationToken.Mint(to, amount);
        vm.prank(BRIDGE);
        morphoOptimism.mint(to, amount);

        assertEq(morphoOptimism.totalSupply(), amount, "totalSupply");
        assertEq(morphoOptimism.balanceOf(to), amount, "balanceOf(account)");
    }

    function testBurnNoBridge(address account, address from, uint256 amount) public {
        vm.assume(account != address(0));
        vm.assume(from != address(0));
        vm.assume(account != BRIDGE);
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.expectRevert(MorphoTokenOptimism.NotBridge.selector);
        vm.prank(account);
        morphoOptimism.burn(from, amount);
    }

    function testBurn(address from, uint256 amountMinted, uint256 amountBurned) public {
        vm.assume(from != address(0));
        amountMinted = bound(amountMinted, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);
        amountBurned = bound(amountBurned, MIN_TEST_AMOUNT, amountMinted);

        vm.startPrank(BRIDGE);
        morphoOptimism.mint(from, amountMinted);

        vm.expectEmit(address(morphoOptimism));
        emit DelegationToken.Burn(from, amountBurned);
        morphoOptimism.burn(from, amountBurned);
        vm.stopPrank();

        assertEq(morphoOptimism.totalSupply(), amountMinted - amountBurned, "totalSupply");
        assertEq(morphoOptimism.balanceOf(from), amountMinted - amountBurned, "balanceOf(account)");
    }
}
