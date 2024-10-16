// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MorphoToken
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice The MORPHO Token contract.
contract Wrapper {
    /* CONSTANTS */

    /// @dev The address of the legacy MORPHO token.
    address public constant LEGACY_MORPHO = address(0x9994E35Db50125E0DF82e4c2dde62496CE330999);

    /* IMMUTABLES */

    /// @dev The address of the new MORPHO token.
    address public immutable NEW_MORPHO;

    /* ERRORS */

    /// @notice Reverts if the address is the zero address.
    error ZeroAddress();

    /// @notice Reverts if the address is the contract address.
    error SelfAddress();

    /* CONSTRUCTOR */

    /// @dev morphoToken address can be precomputed using create2.
    constructor(address morphoToken) {
        require(morphoToken != address(0), ZeroAddress());

        NEW_MORPHO = morphoToken;
    }

    /* PUBLIC */

    /// @dev Compliant to `ERC20Wrapper` contract from OZ for convenience.
    function depositFor(address account, uint256 amount) public returns (bool) {
        require(account != address(0), ZeroAddress());
        require(account != address(this), SelfAddress());

        IERC20(LEGACY_MORPHO).transferFrom(msg.sender, address(this), amount);
        IERC20(NEW_MORPHO).transfer(account, amount);
        return true;
    }

    /// @dev To ease wrapping via the bundler contract: https://github.com/morpho-org/morpho-blue-bundlers/blob/main/src/ERC20WrapperBundler.sol
    function underlying() public pure returns (address) {
        return LEGACY_MORPHO;
    }
}
