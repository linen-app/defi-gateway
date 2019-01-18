import * as chai from 'chai';
import {expect} from 'chai';
import {utils, Contract, constants} from 'ethers';
import {Web3Provider} from 'ethers/providers';
import {MakerDaoGateway} from '../types/ethers-contracts/MakerDaoGateway';
import {DummyToken} from '../types/ethers-contracts/DummyToken';
import {IWrappedEther} from '../types/ethers-contracts/IWrappedEther';
import {BigNumber} from 'ethers/utils';
import {Artifacts, increaseTime, transaction} from "./utils";
import * as TestchainAddress from '../lib/testchain/out/addresses.json'

chai.use(require('bn-chai')(BigNumber));
chai.use(require('chai-string'));

const MakerDaoGatewayArtifacts: Artifacts  = artifacts.require('MakerDaoGateway') as any;
const DummyTokenArtifacts: Artifacts = artifacts.require('DummyToken') as any;
const IWrappedEtherArtifacts: Artifacts = artifacts.require('IWrappedEther') as any;

const tubAddress = TestchainAddress.TUB;
const wethAddress = TestchainAddress.GEM;
const daiAddress = TestchainAddress.SAI;
const dexAddress = TestchainAddress.MAKER_OTC;

contract('MakerDaoGateway', ([deployer, user]) => {
    let makerDaoGateway: MakerDaoGateway;
    let dai: DummyToken;
    let weth: IWrappedEther;
    let provider: Web3Provider;
    let cdpId: string;

    before(async () => {
        provider = new Web3Provider(web3.currentProvider);
        const signer = provider.getSigner(user);

        makerDaoGateway = new Contract(
            MakerDaoGatewayArtifacts.address,
            MakerDaoGatewayArtifacts.abi,
            signer
        ) as MakerDaoGateway;

        dai = new Contract(daiAddress, DummyTokenArtifacts.abi, signer) as DummyToken;
        weth = new Contract(wethAddress, IWrappedEtherArtifacts.abi, signer) as IWrappedEther;
    });

    it('should be initialized correctly', async () => {
        expect(await makerDaoGateway.functions.saiTub()).to.be.equalIgnoreCase(tubAddress);
        expect(await makerDaoGateway.functions.dex()).to.be.equalIgnoreCase(dexAddress);
    });

    it('should have correct system parameters', async () => {
        const {annualStabilityFee, liquidationRatio} = await makerDaoGateway.functions.systemParameters();
        
        expect(annualStabilityFee, 'annualStabilityFee check').to.eq.BN('1004999999999999999962248547');
        expect(liquidationRatio, 'liquidationRatio check').to.eq.BN(new BigNumber(10).pow(26).mul(15));
    });

    it('should have correct WETH contract', async () => {
        const wethAmount = utils.parseEther('0.006');
        const preWethBalance = await weth.functions.balanceOf(user);

        await transaction(weth.functions.approve(makerDaoGateway.address, constants.MaxUint256));
        await transaction(weth.functions.deposit({value: wethAmount}));

        const postWethBalance = await weth.functions.balanceOf(user);

        expect(postWethBalance.sub(preWethBalance), 'WETH balance check').to.eq.BN(wethAmount);
    });

    it('should supplyWeth successfully', async () => {
        const wethAmount = utils.parseEther('0.006');
        const preWethBalance = await weth.functions.balanceOf(user);
        const preLength = await makerDaoGateway.functions.cdpsByOwnerLength(user);

        await transaction(makerDaoGateway.functions.supplyWeth(constants.HashZero, wethAmount, {gasLimit: 6000000}));

        const postWethBalance = await weth.functions.balanceOf(user);
        expect(preWethBalance.sub(postWethBalance), 'WETH balance check').to.eq.BN(wethAmount);

        const postLength = await makerDaoGateway.functions.cdpsByOwnerLength(user);
        expect(postLength.sub(preLength), 'CDPs count check').to.eq.BN(1);

        cdpId = await makerDaoGateway.functions.cdpsByOwner(user, preLength);
        const owner = await makerDaoGateway.functions.cdpOwner(cdpId);
        expect(cdpId, 'CDP id check').to.be.not.empty;
        expect(owner, 'CDP owner check').to.equalIgnoreCase(user);
    });

    it('should supplyAndBorrow successfully', async () => {
        const daiAmount = new BigNumber(10);
        const ethAmount = utils.parseEther('0.006');
        const preEthBalance = await provider.getBalance(user);
        const preDaiBalance = await dai.functions.balanceOf(user);

        const {tx, receipt} = await transaction(makerDaoGateway.functions.supplyEthAndBorrowDai(
            cdpId,
            daiAmount,
            {value: ethAmount, gasLimit: 6000000}
        ));

        const postEthBalance = await provider.getBalance(user);
        const postDaiBalance = await dai.functions.balanceOf(user);
        const ethUsedForGas = (receipt.gasUsed || new BigNumber(0)).mul(tx.gasPrice);
        expect(preEthBalance.sub(postEthBalance), 'ETH balance check').to.eq.BN(ethAmount.add(ethUsedForGas));
        expect(postDaiBalance.sub(preDaiBalance), 'DAI balance check').to.eq.BN(daiAmount)
    });
    
    it('should repay successfully', async () => {
        await increaseTime(60 * 60 * 24, provider);
        
        const daiAmount = new BigNumber(1);
        const preDaiBalance = await dai.functions.balanceOf(user);

        await transaction(dai.functions.approve(makerDaoGateway.address, constants.MaxUint256));
        await transaction(makerDaoGateway.functions.repayDai(cdpId, daiAmount, true, {gasLimit: 6000000}));

        const postDaiBalance = await dai.functions.balanceOf(user);
        expect(preDaiBalance.sub(postDaiBalance), 'DAI balance check').to.eq.BN(daiAmount);
    });

    it('should return WETH successfully', async () => {
        const wethAmount = utils.parseEther('0.001');
        const preWethBalance = await weth.functions.balanceOf(user);

        await transaction(makerDaoGateway.functions.returnWeth(cdpId, wethAmount, {gasLimit: 6000000}));

        const postWethBalance = await weth.functions.balanceOf(user);
        expect(postWethBalance.sub(preWethBalance), 'WETH balance check').to.eq.BN(wethAmount);
    });

    it('should return ETH successfully', async () => {
        const ethAmount = utils.parseEther('0.001');
        const preEthBalance = await provider.getBalance(user);

        const {tx, receipt} = await transaction(makerDaoGateway.functions.returnEth(cdpId, ethAmount, {gasLimit: 6000000}));

        const postEthBalance = await provider.getBalance(user);
        const ethUsedForGas = (receipt.gasUsed || new BigNumber(0)).mul(tx.gasPrice);
        expect(postEthBalance.sub(preEthBalance), 'ETH balance check').to.eq.BN(ethAmount.sub(ethUsedForGas));
    });

    it('should repayAndReturn successfully', async () => {
        const daiAmount = new BigNumber(1);
        const ethAmount = utils.parseEther('0.001');
        const preDaiBalance = await dai.functions.balanceOf(user);

        await transaction(dai.functions.approve(makerDaoGateway.address, constants.MaxUint256));
        await transaction(makerDaoGateway.functions.repayDaiAndReturnEth(cdpId, daiAmount, ethAmount, true, {gasLimit: 6000000}));

        const postDaiBalance = await dai.functions.balanceOf(user);
        expect(preDaiBalance.sub(postDaiBalance), 'DAI balance check').to.eq.BN(daiAmount);
    });

    it('should repayAndReturn all successfully', async () => {
        const daiAmount = new BigNumber(9);
        const ethAmount = utils.parseEther('0.004');
        const preDaiBalance = await dai.functions.balanceOf(user);
        const preEthBalance = await provider.getBalance(user);  

        const {tx, receipt} = await transaction(makerDaoGateway.functions.repayDaiAndReturnEth(cdpId, constants.MaxUint256, constants.MaxUint256, true, {gasLimit: 6000000}));

        const postDaiBalance = await dai.functions.balanceOf(user);
        const postEthBalance = await provider.getBalance(user);
        const ethUsedForGas = (receipt.gasUsed || new BigNumber(0)).mul(tx.gasPrice);
        expect(preDaiBalance.sub(postDaiBalance), 'DAI balance check').to.eq.BN(daiAmount);
        expect(postEthBalance.sub(preEthBalance), 'ETH balance check').to.eq.BN(ethAmount.sub(ethUsedForGas));
    });

    xit('should not allow token leaks', async () => {
    });

    xit('', async () => {
    });


});