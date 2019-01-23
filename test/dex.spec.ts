import * as chai from 'chai';
import {utils, Contract, constants, ContractTransaction} from 'ethers';
import {Web3Provider} from 'ethers/providers';
import {BigNumber} from 'ethers/utils';
import {IDex} from "../types/ethers-contracts/IDex";
import {DummyToken} from "../types/ethers-contracts/DummyToken";
import {Artifacts, transaction} from "./utils";
import * as TestchainAddress from '../lib/testchain/out/addresses.json'

chai.use(require('bn-chai')(BigNumber));
chai.use(require('chai-string'));

const DexArtifacts: Artifacts  = artifacts.require('IDex') as any;
const DummyTokenArtifacts: Artifacts = artifacts.require('DummyToken') as any;

contract('DEX', ([deployer, user]) => {
    let dex: IDex;
    let mkr: DummyToken;

    const dexAddress = TestchainAddress.MAKER_OTC;
    const daiAddress = TestchainAddress.SAI;
    const mkrAddress = TestchainAddress.GOV;

    before(async () => {
        const provider = new Web3Provider(web3.currentProvider);
        const signer = provider.getSigner(deployer);

        dex = new Contract(
            dexAddress,
            DexArtifacts.abi,
            signer
        ) as IDex;
        
        mkr = new Contract(
            mkrAddress,
            DummyTokenArtifacts.abi,
            signer
        ) as DummyToken;
    });
    
    it('should offer order successfully', async () => {
        const balance = await mkr.functions.balanceOf(deployer);
        const amount = utils.parseEther('0.0005');        
        expect(balance.gte(amount), 'MKR balance check').to.be.true;
        
        await transaction(mkr.functions.approve(dexAddress, constants.MaxUint256));
        
        await transaction(dex.functions.offer(amount, mkrAddress, amount, daiAddress, 0));
    });

    it('should get pay amount correctly', async () => {
        const amount = await dex.functions.getPayAmount(daiAddress, mkrAddress, 10);
        
        expect(amount.isZero()).to.be.false;
    });
});
