// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC20Upgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {Ownable2StepUpgradeable} from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {OptimismMintableERC20Upgradeable} from "./OptimismMintableERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from
    "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title MorphoToken
/// @author Morpho Association
/// @custom:contact security@morpho.org
/// @notice The MORPHO Token contract for Optimism networks.
contract MorphoTokenOptimism is
    OptimismMintableERC20Upgradeable,
    ERC20PermitUpgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    /* CONSTANTS */

    /// @dev The name of the token.
    string internal constant NAME = "Morpho Token";

    /// @dev The symbol of the token.
    string internal constant SYMBOL = "MORPHO";

    /* PUBLIC */

    /// @notice Initializes the contract.
    /// @param dao The DAO address.
    /// @param remoteToken The address of the Morpho Token on Ethereum.
    /// @param bridge The address of the StandardBridge contract.
    function initialize(address dao, address remoteToken, address bridge) public initializer {
        require(dao != address(0), ZeroAddress());
        require(remoteToken != address(0), ZeroAddress());
        require(bridge != address(0), ZeroAddress());

        ERC20Upgradeable.__ERC20_init(NAME, SYMBOL);
        Ownable2StepUpgradeable.__Ownable2Step_init();
        ERC20PermitUpgradeable.__ERC20Permit_init(NAME);
        OptimismMintableERC20Upgradeable.__OptimismMintableERC20_init(remoteToken, bridge);

        _transferOwnership(dao); // Transfer ownership to the DAO.
    }

    /* INTERNAL */

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
