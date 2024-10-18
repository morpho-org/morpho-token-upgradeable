// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IDelegates
/// @author Morpho Association
/// @custom:contact security@morpho.org
/// @notice The Delegates interface.
interface IDelegates {
    // @dev The signature used has expired.
    error DelegatesExpiredSignature(uint256 expiry);

    // @dev Emitted when an account changes their delegate.
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    // @dev Emitted when a token transfer or delegate change results in changes to a delegate's number of voting units.
    event DelegateVotesChanged(address indexed delegate, uint256 previousVotes, uint256 newVotes);

    // @dev Returns the current amount of votes that `account` has.
    function getVotes(address account) external view returns (uint256);

    // @dev Returns the delegate that `account` has chosen.
    function delegates(address account) external view returns (address);

    // @dev Delegates votes from the sender to `delegatee`.
    function delegate(address delegatee) external;

    // @dev Delegates votes from signer to `delegatee`.
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
}
