// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC20Upgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {Ownable2StepUpgradeable} from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {ERC20DelegatesUpgradeable} from "./ERC20DelegatesUpgradeable.sol";
import {
    ERC20PermitUpgradeable,
    NoncesUpgradeable
} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title MorphoToken
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The MORPHO Token contract.
contract MorphoToken is ERC20DelegatesUpgradeable, ERC20PermitUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    /* CONSTANTS */

    /// @dev The name of the token.
    string internal constant NAME = "Morpho Token";

    /// @dev The symbol of the token.
    string internal constant SYMBOL = "MORPHO";

    /* ERRORS */

    /// @notice Reverts if the address is the zero address.
    error ZeroAddress();

    /* PUBLIC */

    /// @notice Initializes the contract.
    /// @param dao The DAO address.
    /// @param wrapper The wrapper contract address to migrate legacy MORPHO tokens to the new one.
    function initialize(address dao, address wrapper) public initializer {
        require(dao != address(0), ZeroAddress());
        require(wrapper != address(0), ZeroAddress());

        ERC20Upgradeable.__ERC20_init(NAME, SYMBOL);
        Ownable2StepUpgradeable.__Ownable2Step_init();
        ERC20PermitUpgradeable.__ERC20Permit_init(NAME);

        _transferOwnership(dao); // Transfer ownership to the DAO.
        _mint(wrapper, 1_000_000_000e18); // Mint 1B to the wrapper contract.
    }

    /// @inheritdoc ERC20PermitUpgradeable
    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return ERC20PermitUpgradeable.nonces(owner);
    }

    /* INTERNAL */

    /// @inheritdoc ERC20DelegatesUpgradeable
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20DelegatesUpgradeable)
    {
        ERC20DelegatesUpgradeable._update(from, to, value);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
