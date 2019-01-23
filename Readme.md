# DeFi Gateway

## MakerDAO gateway

#TODO:
- FIX AND ADD TESTS

More info about MakerDAO: https://makerdao.com/en/whitepaper

### Functionality
- Supply ETH or WETH as collateral
- Pay stability fee in MKR or DAI (using Kyber)
- Support of multiple cdps on one address

No assets are stored on smart contract, besides CDP ownership.

## Smart contracts arcitecture
1. Role-based auth
2. Pausable by pauser role

## References:
- InstaDApp
- MakerDAO
- Augur
- 0x
- Dharma
- Aragon
- Melonport
- Gnosis