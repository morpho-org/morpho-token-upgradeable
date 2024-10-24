// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {MorphoTokenEthereum} from "../../src/MorphoTokenEthereum.sol";
import {Delegation, Signature} from "../../src/DelegationToken.sol";
import {Wrapper} from "../../src/Wrapper.sol";
import {ERC1967Proxy} from
    "../../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

// TODO: Test the following:
// - Test every paths
// - Test migration flow
// - Test bundler wrapping
// - Test access control
// - Test voting
// - Test delegation
contract BaseTest is Test {
    address public constant MORPHO_DAO = 0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa;

    MorphoTokenEthereum public tokenImplem;
    MorphoTokenEthereum public newMorpho;
    ERC1967Proxy public tokenProxy;
    Wrapper public wrapper;

    uint256 internal constant MIN_TEST_AMOUNT = 100;
    uint256 internal constant MAX_TEST_AMOUNT = 1e28;

    function setUp() public virtual {
        // DEPLOYMENTS
        tokenImplem = new MorphoTokenEthereum();
        tokenProxy = new ERC1967Proxy(address(tokenImplem), hex"");
        wrapper = new Wrapper(address(tokenProxy));

        newMorpho = MorphoTokenEthereum(payable(address(tokenProxy)));
        newMorpho.initialize(MORPHO_DAO, address(wrapper));
    }

    function _validateAddresses(address[] memory addresses) internal view {
        for (uint256 i = 0; i < addresses.length; i++) {
            vm.assume(addresses[i] != address(0));
            vm.assume(addresses[i] != MORPHO_DAO);
            vm.assume(addresses[i] != address(wrapper));
            for (uint256 j = i + 1; j < addresses.length; j++) {
                vm.assume(addresses[i] != addresses[j]);
            }
        }
    }
}
