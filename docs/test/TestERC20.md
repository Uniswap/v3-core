## `TestERC20`






-

## `constructor(uint256 amountToMint)` (public)





## `mint(address to, uint256 amount)` (public)






-

## `constructor(uint256 amountToMint)` (public)





## `mint(address to, uint256 amount)` (public)





## `name() → string` (public)

Returns the name of the token.



## `symbol() → string` (public)

Returns the symbol of the token, usually a shorter version of the
name.



## `decimals() → uint8` (public)

Returns the number of decimals used to get its user representation.
For example, if `decimals` equals `2`, a balance of `505` tokens should
be displayed to a user as `5,05` (`505 / 10 ** 2`).
Tokens usually opt for a value of 18, imitating the relationship between
Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
called.
NOTE: This information is only used for _display_ purposes: it in
no way affects any of the arithmetic of the contract, including
{IERC20-balanceOf} and {IERC20-transfer}.



## `totalSupply() → uint256` (public)

See {IERC20-totalSupply}.



## `balanceOf(address account) → uint256` (public)

See {IERC20-balanceOf}.



## `transfer(address recipient, uint256 amount) → bool` (public)

See {IERC20-transfer}.
Requirements:
- `recipient` cannot be the zero address.
- the caller must have a balance of at least `amount`.



## `allowance(address owner, address spender) → uint256` (public)

See {IERC20-allowance}.



## `approve(address spender, uint256 amount) → bool` (public)

See {IERC20-approve}.
Requirements:
- `spender` cannot be the zero address.



## `transferFrom(address sender, address recipient, uint256 amount) → bool` (public)

See {IERC20-transferFrom}.
Emits an {Approval} event indicating the updated allowance. This is not
required by the EIP. See the note at the beginning of {ERC20};
Requirements:
- `sender` and `recipient` cannot be the zero address.
- `sender` must have a balance of at least `amount`.
- the caller must have allowance for ``sender``'s tokens of at least
`amount`.



## `increaseAllowance(address spender, uint256 addedValue) → bool` (public)

Atomically increases the allowance granted to `spender` by the caller.
This is an alternative to {approve} that can be used as a mitigation for
problems described in {IERC20-approve}.
Emits an {Approval} event indicating the updated allowance.
Requirements:
- `spender` cannot be the zero address.



## `decreaseAllowance(address spender, uint256 subtractedValue) → bool` (public)

Atomically decreases the allowance granted to `spender` by the caller.
This is an alternative to {approve} that can be used as a mitigation for
problems described in {IERC20-approve}.
Emits an {Approval} event indicating the updated allowance.
Requirements:
- `spender` cannot be the zero address.
- `spender` must have allowance for the caller of at least
`subtractedValue`.



## `_transfer(address sender, address recipient, uint256 amount)` (internal)

Moves tokens `amount` from `sender` to `recipient`.
This is internal function is equivalent to {transfer}, and can be used to
e.g. implement automatic token fees, slashing mechanisms, etc.
Emits a {Transfer} event.
Requirements:
- `sender` cannot be the zero address.
- `recipient` cannot be the zero address.
- `sender` must have a balance of at least `amount`.



## `_mint(address account, uint256 amount)` (internal)

Creates `amount` tokens and assigns them to `account`, increasing
the total supply.
Emits a {Transfer} event with `from` set to the zero address.
Requirements
- `to` cannot be the zero address.



## `_burn(address account, uint256 amount)` (internal)

Destroys `amount` tokens from `account`, reducing the
total supply.
Emits a {Transfer} event with `to` set to the zero address.
Requirements
- `account` cannot be the zero address.
- `account` must have at least `amount` tokens.



## `_approve(address owner, address spender, uint256 amount)` (internal)

Sets `amount` as the allowance of `spender` over the `owner`s tokens.
This is internal function is equivalent to `approve`, and can be used to
e.g. set automatic allowances for certain subsystems, etc.
Emits an {Approval} event.
Requirements:
- `owner` cannot be the zero address.
- `spender` cannot be the zero address.



## `_setupDecimals(uint8 decimals_)` (internal)

Sets {decimals} to a value other than the default one of 18.
WARNING: This function should only be called from the constructor. Most
applications that interact with token contracts will not expect
{decimals} to ever change, and may work incorrectly if it does.



## `_beforeTokenTransfer(address from, address to, uint256 amount)` (internal)

Hook that is called before any transfer of tokens. This includes
minting and burning.
Calling conditions:
- when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
will be to transferred to `to`.
- when `from` is zero, `amount` tokens will be minted for `to`.
- when `to` is zero, `amount` of ``from``'s tokens will be burned.
- `from` and `to` are never both zero.
To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].



## `_msgSender() → address payable` (internal)





## `_msgData() → bytes` (internal)






-


-


