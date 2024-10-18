// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseTest} from "./helpers/BaseTest.sol";
import {SigUtils} from "./helpers/SigUtils.sol";
import {MorphoToken} from "../src/MorphoToken.sol";
import {ERC1967Proxy} from
    "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MorphoTokenTest is BaseTest {
    function testInitilizeZeroAddress(address randomAddress) public {
        vm.assume(randomAddress != address(0));

        address proxy = address(new ERC1967Proxy(address(tokenImplem), hex""));

        vm.expectRevert();
        MorphoToken(proxy).initialize(address(0), randomAddress);

        vm.expectRevert();
        MorphoToken(proxy).initialize(randomAddress, address(0));
    }

    function testUpgradeNotOwner(address updater) public {
        vm.assume(updater != address(0));
        vm.assume(updater != MORPHO_DAO);

        address newImplem = address(new MorphoToken());

        vm.expectRevert();
        newMorpho.upgradeToAndCall(newImplem, hex"");
    }

    function testUpgrade() public {
        address newImplem = address(new MorphoToken());

        vm.prank(MORPHO_DAO);
        newMorpho.upgradeToAndCall(newImplem, hex"");
    }

    function testOwnDelegation(address delegator, uint256 amount) public {
        vm.assume(delegator != address(0));
        vm.assume(delegator != MORPHO_DAO);
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        deal(address(newMorpho), delegator, amount);

        vm.prank(delegator);
        newMorpho.delegate(delegator);

        assertEq(newMorpho.delegates(delegator), delegator);
        assertEq(newMorpho.getVotes(delegator), amount);
    }

    function testDelegate(address delegator, address delegatee, uint256 amount) public {
        address[] memory addresses = new address[](2);
        addresses[0] = delegator;
        addresses[1] = delegatee;
        _validateAddresses(addresses);
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        deal(address(newMorpho), delegator, amount);

        vm.prank(delegator);
        newMorpho.delegate(delegatee);

        assertEq(newMorpho.delegates(delegator), delegatee);
        assertEq(newMorpho.getVotes(delegator), 0);
        assertEq(newMorpho.getVotes(delegatee), amount);
    }

    function testDelegateBySigExpired(SigUtils.Delegation memory delegation, uint256 privateKey, uint256 expiry)
        public
    {
        expiry = bound(expiry, MAX_TEST_AMOUNT, MAX_TEST_AMOUNT);
        privateKey = bound(privateKey, 1, type(uint32).max);
        address delegator = vm.addr(privateKey);

        address[] memory addresses = new address[](2);
        addresses[0] = delegator;
        addresses[1] = delegation.delegatee;
        _validateAddresses(addresses);

        delegation.expiry = expiry;
        delegation.nonce = 0;

        Signature memory sig;
        bytes32 digest = SigUtils.getTypedDataHash(delegation, address(newMorpho));
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        vm.warp(expiry + 1);

        vm.expectRevert();
        newMorpho.delegateBySig(delegation.delegatee, delegation.nonce, delegation.expiry, sig.v, sig.r, sig.s);
    }

    function testDelegateBySigWrongNonce(SigUtils.Delegation memory delegation, uint256 privateKey, uint256 nounce)
        public
    {
        vm.assume(nounce != 0);
        privateKey = bound(privateKey, 1, type(uint32).max);
        address delegator = vm.addr(privateKey);

        address[] memory addresses = new address[](2);
        addresses[0] = delegator;
        addresses[1] = delegation.delegatee;
        _validateAddresses(addresses);

        delegation.expiry = bound(delegation.expiry, block.timestamp, type(uint256).max);
        delegation.nonce = nounce;

        Signature memory sig;
        bytes32 digest = SigUtils.getTypedDataHash(delegation, address(newMorpho));
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        vm.expectRevert();
        newMorpho.delegateBySig(delegation.delegatee, delegation.nonce, delegation.expiry, sig.v, sig.r, sig.s);
    }

    function testDelegateBySig(SigUtils.Delegation memory delegation, uint256 privateKey, uint256 amount) public {
        privateKey = bound(privateKey, 1, type(uint32).max);
        address delegator = vm.addr(privateKey);

        address[] memory addresses = new address[](2);
        addresses[0] = delegator;
        addresses[1] = delegation.delegatee;
        _validateAddresses(addresses);
        vm.assume(newMorpho.nonces(delegator) == 0);

        delegation.expiry = bound(delegation.expiry, block.timestamp, type(uint256).max);
        delegation.nonce = 0;

        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);
        deal(address(newMorpho), delegator, amount);

        Signature memory sig;
        bytes32 digest = SigUtils.getTypedDataHash(delegation, address(newMorpho));
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        newMorpho.delegateBySig(delegation.delegatee, delegation.nonce, delegation.expiry, sig.v, sig.r, sig.s);

        assertEq(newMorpho.delegates(delegator), delegation.delegatee);
        assertEq(newMorpho.getVotes(delegator), 0);
        assertEq(newMorpho.getVotes(delegation.delegatee), amount);
        assertEq(newMorpho.nonces(delegator), 1);
    }

    function testMultipleDelegations(
        address delegator1,
        address delegator2,
        address delegatee,
        uint256 amount1,
        uint256 amount2
    ) public {
        address[] memory addresses = new address[](3);
        addresses[0] = delegator1;
        addresses[1] = delegator2;
        addresses[2] = delegatee;
        _validateAddresses(addresses);
        amount1 = bound(amount1, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);
        amount2 = bound(amount2, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        deal(address(newMorpho), delegator1, amount1);
        deal(address(newMorpho), delegator2, amount2);

        vm.prank(delegator1);
        newMorpho.delegate(delegatee);

        vm.prank(delegator2);
        newMorpho.delegate(delegatee);

        assertEq(newMorpho.getVotes(delegatee), amount1 + amount2);
    }

    function testTransferVotingPower(
        address delegator1,
        address delegator2,
        address delegatee1,
        address delegatee2,
        uint256 initialAmount,
        uint256 transferredAmount
    ) public {
        address[] memory addresses = new address[](4);
        addresses[0] = delegator1;
        addresses[1] = delegator2;
        addresses[2] = delegatee1;
        addresses[3] = delegatee2;
        _validateAddresses(addresses);
        initialAmount = bound(initialAmount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);
        transferredAmount = bound(transferredAmount, MIN_TEST_AMOUNT, initialAmount);

        deal(address(newMorpho), delegator1, initialAmount);

        vm.prank(delegator2);
        newMorpho.delegate(delegatee2);

        vm.startPrank(delegator1);
        newMorpho.delegate(delegatee1);
        newMorpho.transfer(delegator2, transferredAmount);
        vm.stopPrank();

        assertEq(newMorpho.getVotes(delegatee1), initialAmount - transferredAmount);
        assertEq(newMorpho.getVotes(delegatee2), transferredAmount);
    }

    function testERC20DelegatesStorageLocation() public pure {
        bytes32 expected =
            keccak256(abi.encode(uint256(keccak256("morpho.storage.ERC20Delegates")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(expected, 0x1dc92b2c6e971ab6e08dfd7dcec0e9496d223ced663ba2a06543451548549500);
    }
}
