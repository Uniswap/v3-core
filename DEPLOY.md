To deploy uniswap system run

```
yarn deploy -pk [private-key] -j [json-rpc] -w9 [network token] -ncl [network token symbol] -o [owner address of uniswap contracts]
```

create a `.env` file from the `.env.sample`

To verify look at the `state.json`
run this command for every contract in there
```
npx hardhat verify --newtwork [network name] [contract address]
```