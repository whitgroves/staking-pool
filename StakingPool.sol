// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";

/**
 * Contract designed to stake any ERC20 token and distribute deposits of said token according to stake size.
 * 
 * Transfers into the contract must be pre-approved via IERC20.approve() on the original token.
 *
 * The contract owner cannot make withdrawals outside of their own staked tokens, but can deactivate and then
 * destake the pool to auto-transfer funds back to stakeholders.
 *
 * The staking pool is inactive by default.
 */
contract StakingPool {
    
    address public owner;
    bool public active;
    bool public retired;
    address public tokenAddress;
    uint public totalStaked;
    mapping(address delegate => bool active) public delegates;

    address[] private _stakers;
    mapping(address staker => uint tokens) private _stake;
    uint8 private _warnings;

    constructor(address _tokenAddress) {
        require(IERC20(_tokenAddress).totalSupply() > 0, "Token must have a supply to stake.");
        tokenAddress = _tokenAddress;
        owner = msg.sender;
        delegates[owner] = true;
    }

    function stake(uint amount) external returns (bool) {
        require(active == true, "Staking pool is inactive. Pre-staked funds may still be withdrawn.");
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount), 
                "Staking failed. Review sender balance and approvals.");
        if (_stake[msg.sender] == 0) _stakers.push(msg.sender);
        _stake[msg.sender] += amount;
        totalStaked += amount;
        return true;
    }
    
    function unstake(uint amount) external returns (bool) {
        require(amount <= _stake[msg.sender], "Unstaking failed. Amount exceeds stake size.");
        require(IERC20(tokenAddress).transfer(msg.sender, amount), 
                "Unstaking failed. Review staking pool balance and contact contract owner.");
        _stake[msg.sender] -= amount;
        totalStaked -= amount;
        return true;
    }

    function distribute() public returns (bool) {
        require(delegates[msg.sender] == true, "Delegates only. Contact owner to be added as a delegate.");
        uint totalDistribution = IERC20(tokenAddress).balanceOf(address(this)) - totalStaked;
        uint totalDistributed = 0;
        for (uint i = 0; i < _stakers.length; i++) {
            uint stake_ = _stake[_stakers[i]];
            if (stake_ == 0) continue;
            uint scale = (stake_ * 1e18) / totalStaked;
            uint distribution = (totalDistribution * scale) / 1e18;
            _stake[_stakers[i]] += distribution;
            totalDistributed += distribution;
        }
        totalStaked += totalDistributed;
        return true;
    }

    function destake() public returns (bool) {
        require(msg.sender == owner, "Owner only.");
        require(active == false, "Staking pool is still active. Deactivate first.");
        for (uint i = 0; i < _stakers.length; i++) {
            address staker = _stakers[i];
            uint stake_ = _stake[staker];
            if (stake_ == 0) continue;
            if (IERC20(tokenAddress).transfer(staker, stake_)) {
                _stake[staker] = 0;
                totalStaked -= stake_;
            }
        }
        return true;
    }

    function stakeSize() external view returns (uint) {
        return _stake[msg.sender];
    }

    function stakeSizeFor(address staker) external view returns (uint) {
        require(delegates[msg.sender] == true, "Delegates only.");
        return _stake[staker];
    }

    function activate() external returns (bool) {
        require(msg.sender == owner, "Owner only.");
        require(active == false, "Staking pool is already active.");
        require(retired == false, "Staking pool has been permanently retired.");
        active = true;
        return true;
    }

    function deactivate() external returns (bool) {
        require(msg.sender == owner, "Owner only.");
        require(active == true, "Staking pool is already inactive.");
        active = false;
        return true;
    }

    function retire() external returns (bool) {
        require(msg.sender == owner, "Owner only.");
        require(active == false, "Cannot retire an active pool.");
        require(distribute(), "Final distribution failed.");
        require(destake(), "Final destaking failed.");
        retired = true;
        IERC20 token = IERC20(tokenAddress);
        uint remainder = token.balanceOf(address(this)) - totalStaked;
        token.approve(msg.sender, remainder);
        return true;
    }

    function transferOwner(address newOwner) external returns (bool) {
        require(msg.sender == owner, "Owner only.");
        require(active == true, "Staking pool is inactive. (Re)activate first.");
        owner = newOwner;
        return true;
    }

    function addDelegate(address delegate) external returns (bool) {
        require(msg.sender == owner, "Owner only.");
        require(active == true, "Staking pool is inactive. (Re)activate first.");
        delegates[delegate] = true;
        return true;
    }

    function removeDelegate(address delegate) external returns (bool) {
        require(msg.sender == owner, "Owner only.");
        require(active == true, "Staking pool is inactive. (Re)activate first.");
        delegates[delegate] = false;
        return true;
    }

}