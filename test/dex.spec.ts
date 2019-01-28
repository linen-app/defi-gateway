import * as chai from 'chai';
import {utils, Contract, constants} from 'ethers';
import {Web3Provider} from 'ethers/providers';
import {BigNumber} from 'ethers/utils';
import {IDex} from "../types/ethers-contracts/IDex";
import {DummyToken} from "../types/ethers-contracts/DummyToken";
import {Artifacts, transaction} from "./utils";
import * as TestchainAddress from '../lib/testchain/out/addresses.json'
import {expect} from "chai";

chai.use(require('bn-chai')(BigNumber));
chai.use(require('chai-string'));

const DexArtifacts: Artifacts  = artifacts.require('IDex') as any;
const DummyTokenArtifacts: Artifacts = artifacts.require('DummyToken') as any;

contract('DEX', ([deployer, user]) => {
    let dex: IDex;
    let mkr: DummyToken;
    let dai: DummyToken;

    const dexAddress = TestchainAddress.MAKER_OTC;
    const daiAddress = TestchainAddress.SAI;
    const mkrAddress = TestchainAddress.GOV;
    
    const amount = new BigNumber(1000000);

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
        
        dai = new Contract(
            daiAddress,
            DummyTokenArtifacts.abi,
            signer
        ) as DummyToken;
    });
    
    it('should offer order successfully', async () => {
        const balance = await mkr.functions.balanceOf(deployer);
        expect(balance.gte(amount), 'MKR balance check').to.be.true;
        
        await transaction(mkr.functions.approve(dexAddress, constants.MaxUint256));
        await transaction(dex.functions.offer(amount, mkrAddress, amount, daiAddress, 0));
    });

    it('should get pay amount correctly', async () => {
        const payAmount = await dex.functions.getPayAmount(daiAddress, mkrAddress, amount.div(1000));
        const payAmount2 = await dex.functions.getPayAmount(daiAddress, mkrAddress, amount.div(1000));
        console.log('getPayAmount', payAmount.toString());
        expect(payAmount.isZero()).to.be.false;
        expect(payAmount2.isZero()).to.be.false;
    });
    
    xit('should be able to buy mkr', async () => {
        const preMkrBalance = await mkr.functions.balanceOf(user);
        
        await transaction(dai.functions.approve(dexAddress, constants.MaxUint256));
        // need to provide dai tokens first
        await transaction(dex.functions.buyAllAmount(mkrAddress, amount, daiAddress, amount.mul(2)));
        
        const postMkrBalance = await mkr.functions.balanceOf(user);

        expect(postMkrBalance.sub(preMkrBalance), 'MKR balance check').to.eq.BN(amount);
    });
});