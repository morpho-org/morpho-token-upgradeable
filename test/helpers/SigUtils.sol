// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC5267} from
    "../../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/interfaces/IERC5267.sol";
import {Delegation, Signature} from "../../src/DelegationToken.sol";

struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

library SigUtils {
    bytes32 internal constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    bytes32 internal constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @dev Computes the hash of the EIP-712 encoded data.
    function getDelegationTypedDataHash(Delegation memory delegation, address contractAddress)
        internal
        view
        returns (bytes32)
    {
        (, string memory name, string memory version,,,,) = IERC5267(contractAddress).eip712Domain();
        return keccak256(
            bytes.concat("\x19\x01", domainSeparator(contractAddress, name, version), delegationHashStruct(delegation))
        );
    }

    function getPermitTypedDataHash(Permit memory permit, address contractAddress) internal view returns (bytes32) {
        (, string memory name, string memory version,,,,) = IERC5267(contractAddress).eip712Domain();
        return keccak256(
            bytes.concat("\x19\x01", domainSeparator(contractAddress, name, version), permitHashStruct(permit))
        );
    }

    function delegationHashStruct(Delegation memory delegation) internal pure returns (bytes32) {
        return keccak256(abi.encode(DELEGATION_TYPEHASH, delegation.delegatee, delegation.nonce, delegation.expiry));
    }

    function permitHashStruct(Permit memory permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, permit.owner, permit.spender, permit.value, permit.nonce, permit.deadline)
        );
    }

    function domainSeparator(address contractAddress, string memory name, string memory version)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(TYPE_HASH, keccak256(bytes(name)), keccak256(bytes(version)), block.chainid, contractAddress)
        );
    }
}
