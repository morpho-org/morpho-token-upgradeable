// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.27;

import {IDelegation, Signature, Delegation} from "./interfaces/IDelegation.sol";

import {ERC20PermitUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ECDSA} from
    "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable2StepUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title DelegationToken
/// @author Morpho Association
/// @custom:contact security@morpho.org
/// @dev Extension of ERC20 to support token delegation.
///
/// This extension keeps track of the current voting power delegated to each account. Voting power can be delegated
/// either by calling the `delegate` function directly, or by providing a signature to be used with `delegateBySig`.
///
/// This enables onchain votes on external voting smart contracts leveraging storage proofs.
///
/// By default, token balance does not account for voting power. This makes transfers cheaper. Whether an account
/// has to self-delegate to vote depends on the voting contract implementation.
abstract contract DelegationToken is IDelegation, ERC20PermitUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    /* CONSTANTS */

    bytes32 internal constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    // keccak256(abi.encode(uint256(keccak256("DelegationToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant DelegationTokenStorageLocation =
        0xd583ef41af40c9ecf9cd08176e1b50741710eaecf057b22e93a6b99fa47a6400;

    /* STORAGE LAYOUT */

    /// @custom:storage-location erc7201:DelegationToken
    struct DelegationTokenStorage {
        mapping(address => address) _delegatee;
        mapping(address => uint256) _delegatedVotingPower;
        mapping(address => uint256) _delegationNonce;
    }

    /* ERRORS */

    /// @notice The signature used has expired.
    error DelegatesExpiredSignature();

    /// @notice The delegation nonce used by the signer is not its current delegation nonce.
    error InvalidDelegationNonce();

    /* EVENTS */

    /// @notice Emitted when an delegator changes their delegatee.
    event DelegateeChanged(address indexed delegator, address indexed oldDelegatee, address indexed newDelegatee);

    /// @notice Emitted when a delegatee's delegated voting power changes.
    event DelegatedVotingPowerChanged(address indexed delegatee, uint256 oldVotes, uint256 newVotes);

    /// @notice Emitted whenever tokens are minted for an account.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted whenever tokens are burned from an account.
    event Burn(address indexed account, uint256 amount);

    /* CONSTRUCTOR */

    /// @dev Disables initializers for the implementation contract.
    constructor() {
        _disableInitializers();
    }

    /* GETTERS */

    /// @notice Returns the delegatee that `account` has chosen.
    function delegatee(address account) public view returns (address) {
        DelegationTokenStorage storage $ = _getDelegationTokenStorage();
        return $._delegatee[account];
    }

    /// @notice Returns the current voting power delegated to `account`.
    function delegatedVotingPower(address account) external view returns (uint256) {
        DelegationTokenStorage storage $ = _getDelegationTokenStorage();
        return $._delegatedVotingPower[account];
    }

    /// @notice Returns the current delegation nonce of `account`.
    function delegationNonce(address account) external view returns (uint256) {
        DelegationTokenStorage storage $ = _getDelegationTokenStorage();
        return $._delegationNonce[account];
    }

    /* DELEGATE */

    /// @notice Delegates the balance of the sender to `newDelegatee`.
    /// @dev Delegating to the zero address effectively removes the delegation, incidentally making transfers cheaper.
    /// @dev Delegating to the previous delegatee does not revert.
    function delegate(address newDelegatee) external {
        address delegator = _msgSender();
        _delegate(delegator, newDelegatee);
    }

    /// @notice Delegates the balance of the signer to `newDelegatee`.
    /// @dev Delegating to the zero address effectively removes the delegation, incidentally making transfers cheaper.
    /// @dev Delegating to the previous delegatee effectively revokes past signatures with the same nonce.
    function delegateWithSig(Delegation memory delegation, Signature calldata signature) external {
        require(block.timestamp <= delegation.expiry, DelegatesExpiredSignature());

        address delegator = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegation))),
            signature.v,
            signature.r,
            signature.s
        );

        DelegationTokenStorage storage $ = _getDelegationTokenStorage();
        require(delegation.nonce == $._delegationNonce[delegator]++, InvalidDelegationNonce());

        _delegate(delegator, delegation.delegatee);
    }

    /* INTERNAL */

    /// @dev Delegates the balance of the `delegator` to `newDelegatee`.
    function _delegate(address delegator, address newDelegatee) internal {
        DelegationTokenStorage storage $ = _getDelegationTokenStorage();
        address oldDelegatee = $._delegatee[delegator];
        $._delegatee[delegator] = newDelegatee;

        emit DelegateeChanged(delegator, oldDelegatee, newDelegatee);
        _moveDelegateVotes(oldDelegatee, newDelegatee, balanceOf(delegator));
    }

    /// @dev Moves voting power when tokens are transferred.
    /// @dev Emits a {IDelegates-DelegateVotesChanged} event.
    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);
        _moveDelegateVotes(delegatee(from), delegatee(to), value);
    }

    /// @dev Moves delegated votes from one delegate to another.
    function _moveDelegateVotes(address from, address to, uint256 amount) internal {
        DelegationTokenStorage storage $ = _getDelegationTokenStorage();
        if (from != to && amount > 0) {
            if (from != address(0)) {
                uint256 oldValue = $._delegatedVotingPower[from];
                uint256 newValue = oldValue - amount;
                $._delegatedVotingPower[from] = newValue;
                emit DelegatedVotingPowerChanged(from, oldValue, newValue);
            }
            if (to != address(0)) {
                uint256 oldValue = $._delegatedVotingPower[to];
                uint256 newValue = oldValue + amount;
                $._delegatedVotingPower[to] = newValue;
                emit DelegatedVotingPowerChanged(to, oldValue, newValue);
            }
        }
    }

    /// @dev Returns the DelegationTokenStorage struct.
    function _getDelegationTokenStorage() internal pure returns (DelegationTokenStorage storage $) {
        assembly {
            $.slot := DelegationTokenStorageLocation
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
