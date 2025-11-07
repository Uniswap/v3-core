# Base Integration Notes for Uniswap v3-core

Uniswap v3 on Base benefits from low fees and fast finality, which makes concentrated liquidity strategies more practical for smaller LPs.

## Network & IDs
- Base Mainnet `chainId: 8453`
- Base Sepolia `chainId: 84532`

## Fee Tiers & Use
- 0.01%: Stable pairs / highly correlated assets (e.g., bridged stables)
- 0.05%: Blue chips / high-liquidity pairs
- 0.3%: General purpose
- 1%: Long-tail / volatile tokens

## LP Strategy Notes on Base
- Tight ranges can be viable due to lower gas; monitor volatility and rebalance on events.
- Use TWAP oracles (v3 observations) for safer onchain quotes; extend observation cardinality for active pools.
- For new listings on Base, seed a wider initial range, then narrow after price discovery.

## Testing Checklist (Base)
- ✅ Deploy factory/router on Base testnet or use existing addresses
- ✅ Create pool → initialize sqrtPriceX96
- ✅ Mint position → collect fees → burn/withdraw
- ✅ Validate observations length & slot0 updates
- ✅ Verify events on BaseScan for indexing

## Risk & Ops
- Watch for MEV around tight ranges; use off-chain alerts for price deviations.
- Keep gas sponsor/relayer in mind if integrating with Smart Wallet flows on Base.

> Low fees + concentrated liquidity = faster iteration for LPs on Base.
