import * as chai from 'chai';
import {BigNumber} from 'ethers/utils';
chai.use(require('bn-chai')(BigNumber));
chai.use(require('chai-string'));
chai.use(require('chai-as-promised'));
import {expect, assert} from 'chai';
import {utils, Contract, constants} from 'ethers';
import {Web3Provider} from 'ethers/providers';
import {MakerDaoGateway} from '../types/ethers-contracts/MakerDaoGateway';
import {DummyToken} from '../types/ethers-contracts/DummyToken';
import {IWrappedEther} from '../types/ethers-contracts/IWrappedEther';
import {Artifacts, transaction} from "./utils";
import * as TestchainAddress from '../lib/testchain/out/addresses.json'
import {SaiTub} from "../types/ethers-contracts/SaiTub";

const MakerDaoGatewayArtifacts: Artifacts  = artifacts.require('MakerDaoGateway') as any;
const SaiTubArtifacts: Artifacts  = artifacts.require('SaiTub') as any;
const DummyTokenArtifacts: Artifacts = artifacts.require('DummyToken') as any;
const IWrappedEtherArtifacts: Artifacts = artifacts.require('IWrappedEther') as any;

const tubAddress = TestchainAddress.TUB;
const wethAddress = TestchainAddress.GEM;
const daiAddress = TestchainAddress.SAI;

contract('MakerDaoGateway: auxiliary actions', ([deployer, user]) => {
    let makerDaoGateway: MakerDaoGateway;
    let makerDaoGatewayPauser: MakerDaoGateway;
    let saiTub: SaiTub;
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

        makerDaoGatewayPauser = new Contract(
            MakerDaoGatewayArtifacts.address,
            MakerDaoGatewayArtifacts.abi,
            provider.getSigner(deployer)
        ) as MakerDaoGateway;

        saiTub = new Contract(
            tubAddress,
            SaiTubArtifacts.abi,
            signer
        ) as SaiTub;

        dai = new Contract(daiAddress, DummyTokenArtifacts.abi, signer) as DummyToken;
        weth = new Contract(wethAddress, IWrappedEtherArtifacts.abi, signer) as IWrappedEther;
    });

    it('should supplyAndBorrow successfully', async () => {
        const daiAmount = utils.parseEther('0.5');
        const ethAmount = utils.parseEther('0.1');
        const preEthBalance = await provider.getBalance(user);
        const preDaiBalance = await dai.functions.balanceOf(user);

        const {tx, receipt} = await transaction(makerDaoGateway.functions.supplyEthAndBorrowDai(
            constants.HashZero,
            daiAmount,
            {value: ethAmount, gasLimit: 6000000}
        ));

        const length = await makerDaoGateway.functions.cdpsByOwnerLength(user);
        cdpId = await makerDaoGateway.functions.cdpsByOwner(user, length.sub(1));

        const postEthBalance = await provider.getBalance(user);
        const postDaiBalance = await dai.functions.balanceOf(user);
        const ethUsedForGas = (receipt.gasUsed || new BigNumber(0)).mul(tx.gasPrice);
        expect(preEthBalance.sub(postEthBalance), 'ETH balance check').to.eq.BN(ethAmount.add(ethUsedForGas));
        expect(postDaiBalance.sub(preDaiBalance), 'DAI balance check').to.eq.BN(daiAmount)
    });
    
    it('should pause successfully', async () => {
        await transaction(makerDaoGatewayPauser.functions.pause({gasLimit: 6000000}));

        const isPaused = await makerDaoGatewayPauser.functions.paused();
        expect(isPaused, 'state check').to.be.true;
    });

    it('should be able to transfer CDP', async () => {
        const oldOwnerFromSaiTub = await saiTub.functions.lad(cdpId);
        expect(oldOwnerFromSaiTub, 'saiTub old owner check').to.be.equalIgnoreCase(makerDaoGateway.address);
        
        const oldOwnerFromGateway = await makerDaoGateway.functions.cdpOwner(cdpId);
        expect(oldOwnerFromGateway, 'gateway old owner check').to.be.equalIgnoreCase(user);
        
        const preCdpsLength = await makerDaoGateway.functions.cdpsByOwnerLength(user);

        const cdpIdFromGateway = await makerDaoGateway.functions.cdpsByOwner(user, preCdpsLength.sub(1));
        expect(cdpIdFromGateway, 'gateway cdpId check').to.be.eq.BN(cdpId);
        
        await transaction(makerDaoGateway.functions.transferCdp(cdpId, user, {gasLimit: 6000000}));

        const postCdpsLength = await makerDaoGateway.functions.cdpsByOwnerLength(user);
        expect(postCdpsLength, 'cdps length check').to.eq.BN(preCdpsLength.sub(1));
        
        const newOwner = await saiTub.functions.lad(cdpId);
        expect(newOwner, 'new owner check').to.be.equalIgnoreCase(user);

        const newOwnerFromGateway = await makerDaoGateway.functions.cdpOwner(cdpId);
        expect(newOwnerFromGateway, 'gateway new owner check').to.be.equalIgnoreCase(constants.AddressZero);
    });

    it('should unpause successfully', async () => {
        await transaction(makerDaoGatewayPauser.functions.unpause({gasLimit: 6000000}));

        const isPaused = await makerDaoGatewayPauser.functions.paused();
        expect(isPaused, 'state check').to.be.false;
    });

    it('should be able to register CDP', async () => {
        const oldOwnerFromGateway = await makerDaoGateway.functions.cdpOwner(cdpId);
        expect(oldOwnerFromGateway, 'gateway old owner check').to.be.equalIgnoreCase(constants.AddressZero);

        const preCdpsLength = await makerDaoGateway.functions.cdpsByOwnerLength(user);

        await transaction(makerDaoGateway.functions.registerCdp(cdpId, user, {gasLimit: 6000000}));
        await transaction(saiTub.functions.give(cdpId, makerDaoGateway.address, {gasLimit: 6000000}));

        const postCdpsLength = await makerDaoGateway.functions.cdpsByOwnerLength(user);
        expect(postCdpsLength, 'cdps length check').to.eq.BN(preCdpsLength.add(1));

        const newOwner = await saiTub.functions.lad(cdpId);
        expect(newOwner, 'new owner check').to.be.equalIgnoreCase(makerDaoGateway.address);

        const newOwnerFromGateway = await makerDaoGateway.functions.cdpOwner(cdpId);
        expect(newOwnerFromGateway, 'gateway new owner check').to.be.equalIgnoreCase(user);

        const cdpIdFromGateway = await makerDaoGateway.functions.cdpsByOwner(user, postCdpsLength.sub(1));
        expect(cdpIdFromGateway, 'gateway cdpId check').to.be.eq.BN(cdpId);
    });

    it('should not be able to eject cdp by user', async () => {
        await assert.isRejected(transaction(
            makerDaoGateway.functions.ejectCdp(cdpId, {gasLimit: 6000000})
        ), 'transaction failed', 'permissions check');
    });
    
    it('should not be able to transfer others cdp', async () => {
        await assert.isRejected(transaction(
            makerDaoGatewayPauser.functions.transferCdp(cdpId, deployer, {gasLimit: 6000000})
        ), 'transaction failed', 'permissions check');
    });
    
    it('should be able to eject CDP by pauser', async () => {
        const oldOwnerFromSaiTub = await saiTub.functions.lad(cdpId);
        expect(oldOwnerFromSaiTub, 'saiTub old owner check').to.be.equalIgnoreCase(makerDaoGateway.address);

        const oldOwnerFromGateway = await makerDaoGateway.functions.cdpOwner(cdpId);
        expect(oldOwnerFromGateway, 'gateway old owner check').to.be.equalIgnoreCase(user);

        const preCdpsLength = await makerDaoGateway.functions.cdpsByOwnerLength(user);

        const cdpIdFromGateway = await makerDaoGateway.functions.cdpsByOwner(user, preCdpsLength.sub(1));
        expect(cdpIdFromGateway, 'gateway cdpId check').to.be.eq.BN(cdpId);

        await transaction(makerDaoGatewayPauser.functions.ejectCdp(cdpId, {gasLimit: 6000000}));

        const postCdpsLength = await makerDaoGateway.functions.cdpsByOwnerLength(user);
        expect(postCdpsLength, 'cdps length check').to.eq.BN(preCdpsLength.sub(1));

        const newOwner = await saiTub.functions.lad(cdpId);
        expect(newOwner, 'new owner check').to.be.equalIgnoreCase(user);

        const newOwnerFromGateway = await makerDaoGateway.functions.cdpOwner(cdpId);
        expect(newOwnerFromGateway, 'gateway new owner check').to.be.equalIgnoreCase(constants.AddressZero);
    });
});
