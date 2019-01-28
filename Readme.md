# DeFi Gateway

## MakerDAO gateway

More info about MakerDAO: https://makerdao.com/en/whitepaper

### Functionality
- Supply ETH or WETH as collateral
- Pay stability fee in MKR or DAI (using Oasis DEX)
- Support of multiple CDPs on one address

No assets are stored on a smart contract, besides CDP ownership.

## References:
- [MakerDAO SAI](https://github.com/makerdao/sai)
- [InstaDApp](https://github.com/InstaDApp/InstaContract)

## Run test:
- `npm run test:chain` (in a separate terminal)
- `npm test`