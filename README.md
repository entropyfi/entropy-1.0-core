<a href="https://www.entropyfi.com" target="_blank">
    <img alt="entropyfi" src="https://raw.githubusercontent.com/entropyfi/entropy-resource/master/Entropyfi.svg" width="120px" height=:"120px" align="left">
</a>

<div align="left">

# 「 Entropyfi - 1.0 Core 」

**_<a href="https://www.entropyfi.com/">WWW.ENTROPYFI.COM</a>_** / 📦 The Entropyfi V2 Core Protocol

</div>

# Lossless Protocol [![Awesome](https://cdn.rawgit.com/sindresorhus/awesome/d7305f38d29fed78fa85652e3a63e154dd8e8829/media/badge.svg)](https://github.com/sindresorhus/awesome#readme)

## Document Structure

> an overall of current code strucutre

    └── LosslessProtocol
        ├── contracts           # smart contract files
        │   ├── core                # core contracts
        │   └── interfaces          # interfaces
        ├── scripts             # ts scripts for deployment
        └── test                # all test related
             ├── mainnet            # hardhat mainnet tests
             └── unit-test          # hardhat unit tests

## Setup Your Environment

1. install all packages

   ```shell
   ❯ yarn install
   ```

2. create your own .env file, check out the sample [.env_sample](.env_sample)

   ```shell
   ❯ touch .env
   ```

3. to deploy a contract with many dependent files
   - flattern the .sol file by using
   ```shell
   ❯ truffle-flattener <solidity-files>
   ```
   - modify [deploy contract](./migrations/2_deploy_contracts.js)
   - Note: use [abi.hashEX](https://abi.hashex.org/#) to generate ABI-encoded output
   - deploy command
   ```shell
   ❯ npx hardhat run --network kovan ./scripts/deploy.ts
   ```
   - verify contract command
   ```shell
   ❯ npx hardhat verify --network kovan  CONTRACT_ADDRESS  "INPUT1" "INPUT2" ...
   ```

## Unit Tests & Mainnet Data Test

> [hardhat](https://hardhat.org/) (with [ethers.js](https://github.com/ethers-io/ethers.js/)) is used for testing.

1. make sure you have compiled our contracts. The build files should locate under folder `artifacts`
   ```shell
   ❯ yarn compile
   ```
2. run **unit test**
   ```shell
   ❯ yarn test
   ```
3. checkout our **harhat mainnet forking test** [readme-mainnet-forking.md](./readme-mainnet-forking.md)

   ```
   yarn hardhat --network hardhat test
   ```

## Static Analyse using Slither

> install [slither](https://github.com/crytic/slither) first

1. run slither

   ```
   ❯ slither . --truffle-build-directory + 'contract address'
   ```

> save output to a file
>
> 1. `script [filename]` (for example: `script output.txt`)
> 2. run slither

## run with Docker

1. Install `docker` and `docker-compose`
2. set up '.env'
3. create running environment and start a new bash

   ```
   # first way
   ❯ docker-compose run contracts-env bash

   # second way
   ❯ yarn start-docker
   ```
