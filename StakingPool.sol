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
 */
contract StakingPool {
    
    address public owner;
    bool public active;
    address public tokenAddress;
    uint public totalStaked;
    mapping(address depositor => bool active) public depositors;

    address[] private _stakers;
    mapping(address staker => uint tokens) private _stake;

    constructor(address _tokenAddress) {
        require(IERC20(_tokenAddress).totalSupply() > 0, "Token must have a supply to stake.");
        tokenAddress = _tokenAddress;
        owner = msg.sender;
        depositors[owner] = true;
    }

    function deposit(uint amount) public payable {
        require(active == true, "Staking pool is inactive. Contact owner to (re)activate.");
        require(depositors[msg.sender] == true, "Deposit failed. Contact owner to be added as a depositor.");
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount), "Deposit failed. Review sender balance and approvals.");
        for (uint i = 0; i < _stakers.length; i++) {
            uint stake_ = _stake[_stakers[i]];
            if (stake_ == 0) continue;
            uint dividend = amount * stake_ / totalStaked;
            _stake[_stakers[i]] += dividend;
        }
        totalStaked += amount;
    }

    function stake(uint amount) external payable {
        require(active == true, "Staking pool is inactive. Contact owner to (re)activate.");
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount), "Staking failed. Review sender balance and approvals.");
        if (_stake[msg.sender] == 0) _stakers.push(msg.sender);
        _stake[msg.sender] += amount;
        totalStaked += amount;
    }
    
    function unstake(uint amount) external payable {
        require(amount <= _stake[msg.sender], "Unstaking failed. Amount exceeds stake size.");
        require(IERC20(tokenAddress).transfer(msg.sender, amount), "Unstaking failed. Review staking pool balance.");
        _stake[msg.sender] -= amount;
        totalStaked -= amount;
    }

    function destake() external {
        require(active == false, "Cannot destake active pool.");
        require(msg.sender == owner, "Owner only.");
        for (uint i = 0; i < _stakers.length; i++) {
            address staker = _stakers[i];
            uint stake_ = _stake[staker];
            if (stake_ == 0) continue;
            if (IERC20(tokenAddress).transfer(staker, stake_)) _stake[staker] = 0;
        }
    }

    function stakeSize() external view returns (uint) {
        return _stake[msg.sender];
    }

    function stakeSizeFor(address staker) external view returns (uint) {
        require(msg.sender == owner, "Owner only.");
        return _stake[staker];
    }

    function activate() external {
        require(active == false, "Staking pool is already active.");
        require(msg.sender == owner, "Owner only.");
        active = true;
    }

    function deactivate() external {
        require(active == true, "Staking pool is already inactive.");
        require(msg.sender == owner, "Owner only.");
        active = false;
    }

    function transferOwner(address newOwner) external {
        require(active == true, "Staking pool is inactive. (Re)activate first.");
        require(msg.sender == owner, "Owner only.");
        owner = newOwner;
    }

    function addDepositor(address depositor) external {
        require(active == true, "Staking pool is inactive. (Re)activate first.");
        require(msg.sender == owner, "Owner only.");
        depositors[depositor] = true;
    }

    function removeDepositor(address depositor) external {
        require(active == true, "Staking pool is inactive. (Re)activate first.");
        require(msg.sender == owner, "Owner only.");
        depositors[depositor] = false;
    }

}