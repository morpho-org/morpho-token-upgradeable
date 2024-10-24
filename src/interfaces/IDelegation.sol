// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

struct Delegation {
    address delegatee;
    uint256 nonce;
    uint256 expiry;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

/// @title IDelegation
/// @author Morpho Association
/// @custom:contact security@morpho.org
interface IDelegation {
    function delegatedVotingPower(address account) external view returns (uint256);

    function delegatee(address account) external view returns (address);

    function delegationNonce(address account) external view returns (uint256);

    function delegate(address delegatee) external;

    function delegateWithSig(Delegation memory delegation, Signature calldata signature) external;
}
