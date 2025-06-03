# Staking Pool

A smart contract designed to stake any ERC20 token and distribute deposits of said token according to stake size.

The idea is to pool a specific token where holders can stake their share and the contract owner (or their delegates) can deposit and distribute additional tokens while ensuring that stakes can only be withdrawn by the addresses that staked them.

Stakers deposit their tokens via `StakingPool.stake()`, withdraw them with `StakingPool.unstake()`, and can view their balance with `StakingPool.stakeSize()`. Note that `stake()` requires a spending allowance on the token contract via `ERC20.approve()`.

Tokens deposited via `ERC20.transfer()` and `ERC20.transferFrom()` are automatically distributed when the owner or one of their delegates calls `StakingPool.distribute()`, and can only be withdrawn by stakeholders in proportion to their stakes. This is true even if the owner deactivates the pool.

Deactivation only prevents adding new stakes to the pool. Users can still unstake, delegates can still distribute, and the owner can only move funds via `StakingPool.destake()`, which automatically transfers all stakes back to their holder's addresses.

Even if the pool is permanently retired, the contract will make final calls to `distribute()` and `destake()` before granting the owner a spending allowance for any funds remaining due to rounding errors.

In effect, this means that **if you transfer tokens directly into the pool, those tokens are *gone***, unless you are the only stakeholder (or on good terms with the rest of them). This is by design to prevent a single party from draining the pool.

For automated distribution of rewards/dividends, it is recommended to transfer the tokens and call `distribute()` from the application layer, although direct transfers from the token contract (for example, as part of a transaction tax) are possible if that contract allows updates to the address(es) it deposits funds into.

Finally, note that once the ERC20 token is designated, it cannot be changed. If the token gets updated and redeployed to a new address, the owner will need to deploy and activate a new pool pointing at the updated token contract, update the token (or any payment processing contracts or applets) to point at the new pool, notify users of the change, then deactivate and permanently close the current pool with `StakingPool.retire()`.