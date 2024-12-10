// This is spec is taken from the Open Zeppelin repositories at https://github.com/OpenZeppelin/openzeppelin-contracts/blob/448efeea6640bbbc09373f03fbc9c88e280147ba/certora/specs/ERC20.spec, and patched to support the DelegationToken.

import "Delegation.spec";

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Rules: only the token holder or an approved third party can reduce an account's balance                             │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
rule onlyAuthorizedCanTransfer(env e, method f) {
    requireInvariant totalSupplyIsSumOfBalances();
    requireInvariant balancesLTEqTotalSupply();
    requireInvariant twoBalancesLTEqTotalSupply();

    calldataarg args;
    address account;

    uint256 allowanceBefore = allowance(account, e.msg.sender);
    uint256 balanceBefore   = balanceOf(account);
    f(e, args);
    uint256 balanceAfter    = balanceOf(account);

    assert (
        balanceAfter < balanceBefore
    ) => (
        f.selector == sig:burn(address, uint256).selector ||
        e.msg.sender == account ||
        f.selector == sig:transferFrom(address, address, uint256).selector && balanceBefore - balanceAfter <= to_mathint(allowanceBefore)
    );
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Rules: only mint and burn can change total supply                                                                   │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
rule noChangeTotalSupply(env e) {
    requireInvariant totalSupplyIsSumOfBalances();
    requireInvariant balancesLTEqTotalSupply();

    method f;
    calldataarg args;

    uint256 totalSupplyBefore = totalSupply();
    f(e, args);
    uint256 totalSupplyAfter = totalSupply();

    assert totalSupplyAfter > totalSupplyBefore => f.selector == sig:mint(address, uint256).selector;
    assert totalSupplyAfter < totalSupplyBefore => f.selector == sig:burn(address, uint256).selector;
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Rules: mint behavior and side effects                                                                               │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
rule mint(env e) {
    requireInvariant totalSupplyIsSumOfBalances();
    requireInvariant balancesLTEqTotalSupply();
    assert isTotalSupplyGTEqSumOfVotingPower();
    requireInvariant zeroAddressNoVotingPower();
    require nonpayable(e);

    address to;
    address other;
    uint256 amount;

    // cache state
    uint256 toBalanceBefore    = balanceOf(to);
    uint256 toVotingPowerBefore = delegatedVotingPower(delegatee(to));
    uint256 otherBalanceBefore = balanceOf(other);
    uint256 totalSupplyBefore  = totalSupply();

    // Safe require that follows from delegatedVotingPowerLTEqTotalVotingPower. 
    require toVotingPowerBefore <= sumOfVotingPower;

    // run transaction
    mint@withrevert(e, to, amount);

    // check outcome
    if (lastReverted) {
        assert e.msg.sender != owner() || to == 0 || totalSupplyBefore + amount > max_uint256 ||
            toVotingPowerBefore + amount > max_uint256 || e.msg.sender != currentContract.bridge;
    } else {
        // updates balance and totalSupply
        assert e.msg.sender == currentContract.bridge;
        assert to_mathint(balanceOf(to)) == toBalanceBefore   + amount;
        assert to_mathint(totalSupply()) == totalSupplyBefore + amount;

        // no other balance is modified
        assert balanceOf(other) != otherBalanceBefore => other == to;
    }
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Rules: burn behavior and side effects                                                                               │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
rule burn(env e) {
    requireInvariant balancesLTEqTotalSupply();
    assert isTotalSupplyGTEqSumOfVotingPower();
    requireInvariant zeroAddressNoVotingPower();
    require nonpayable(e);

    address from;
    address other;
    uint256 amount;
    require from == e.msg.sender;
    // cache state
    uint256 fromBalanceBefore  = balanceOf(from);
    uint256 fromVotingPowerBefore = delegatedVotingPower(delegatee(from));
    uint256 toVotingPowerBefore = delegatedVotingPower(delegatee(0x0));
    uint256 otherBalanceBefore = balanceOf(other);
    uint256 totalSupplyBefore  = totalSupply();

    // Safe require that follows from delegatedVotingPowerLTEqTotalVotingPower. 
    require fromVotingPowerBefore <= sumOfVotingPower;

    // run transaction
    burn@withrevert(e, from,  amount);

    // check outcome
    if (lastReverted) {
           assert e.msg.sender == 0x0 || fromBalanceBefore < amount || fromVotingPowerBefore < amount
               || e.msg.sender != currentContract.bridge;
    } else {
        // updates balance and totalSupply
        assert to_mathint(balanceOf(from)) == fromBalanceBefore - amount;
        assert to_mathint(totalSupply())   == totalSupplyBefore - amount;

        // no other balance is modified
        assert balanceOf(other) != otherBalanceBefore => other == from;
    }
}