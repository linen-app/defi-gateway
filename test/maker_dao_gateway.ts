import * as chai from 'chai';
import { expect } from 'chai';
import { utils, Contract, constants, ContractTransaction } from 'ethers';
import { Web3Provider } from 'ethers/providers';
import { MakerDaoGateway } from '../types/ethers-contracts/MakerDaoGateway';
import { DummyToken } from '../types/ethers-contracts/DummyToken';
import { IWrappedEther } from '../types/ethers-contracts/IWrappedEther';
import { BigNumber } from 'ethers/utils';
import { ContractReceipt } from 'ethers/contract';

chai.use(require('bn-chai')(BigNumber));
chai.use(require('chai-string'));

const MakerDaoGatewayArtifacts = artifacts.require('MakerDaoGateway');
const DummyTokenArtifacts = artifacts.require('DummyToken');
const IWrappedEtherArtifacts = artifacts.require('IWrappedEther');

const saiTubeAddress = '0xe82ce3d6bf40f2f9414c8d01a35e3d9eb16a1761';
const daiAddress = '0xc226f3cd13d508bc319f4f4290172748199d6612';
const wethAddress = '0x7ba25f791fa76c3ef40ac98ed42634a8bc24c238';

async function transaction(transaction: Promise<ContractTransaction>): Promise<{ tx: ContractTransaction, reciept: ContractReceipt }> {
    const tx = await transaction;
    return { tx, reciept: await tx.wait() };
}

contract('MakerDaoGateway', ([deployer, user]) => {
    var makerDaoGateway: MakerDaoGateway;
    var dai: DummyToken;
    var weth: IWrappedEther;
    var provider: Web3Provider;
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
    })

    it('should have correct WETH contract', async () => {
        const address = await makerDaoGateway.functions.wrappedEther();
        expect(address, 'WETH address check').to.equalIgnoreCase(weth.address);

        const wethAmount = utils.parseEther('0.006');
        const preWethBalance = await weth.functions.balanceOf(user);

        await transaction(weth.functions.approve(makerDaoGateway.address, constants.MaxUint256));
        await transaction(weth.functions.deposit({ value: wethAmount }));

        const postWethBalance = await weth.functions.balanceOf(user);

        expect(postWethBalance.sub(preWethBalance), 'WETH balance check').to.eq.BN(wethAmount);
    })

    it('should supplyWeth sucessfuly', async () => {
        const wethAmount = utils.parseEther('0.006');
        const preWethBalance = await weth.functions.balanceOf(user);

        const { reciept } = await transaction(makerDaoGateway.functions.supplyWeth(constants.HashZero, wethAmount, { gasLimit: 6000000 }));

        const postWethBalance = await weth.functions.balanceOf(user);
        expect(preWethBalance.sub(postWethBalance), 'WETH balance check').to.eq.BN(wethAmount);

        expect(reciept.logs, 'Logs length check').have.lengthOf(1);
    });

    it('should supplyAndBorrow sucessfuly', async () => {
        const daiAmount = new BigNumber(1);//utils.parseEther('5');
        const ethAmount = utils.parseEther('0.006');
        const preEthBalance = await provider.getBalance(user);
        const preDaiBalance = await dai.functions.balanceOf(user);

        const { tx, reciept } = await transaction(makerDaoGateway.functions.supplyAndBorrow(
            constants.HashZero,
            daiAmount,
            constants.AddressZero,
            { value: ethAmount, gasLimit: 6000000 }
        ));

        const postEthBalance = await provider.getBalance(user);
        const postDaiBalance = await dai.functions.balanceOf(user);
        const ethUsedForGas = (reciept.gasUsed || new BigNumber(0)).mul(tx.gasPrice);
        expect(preEthBalance.sub(postEthBalance), 'ETH balance check').to.eq.BN(ethAmount.add(ethUsedForGas));
        expect(preDaiBalance.sub(postDaiBalance), 'DAI balance check').to.eq.BN(daiAmount.mul(-1))
    });

    xit('should repayAndReturn sucessfuly', async () => {
        const daiAmount = utils.parseEther('5');
        const ethAmount = utils.parseEther('0.05');
        const preDaiBalance = await dai.functions.balanceOf(user);

        await transaction(makerDaoGateway.functions.repayAndReturn(constants.HashZero, daiAmount, ethAmount));

        const postDaiBalance = await dai.functions.balanceOf(user);
        expect(preDaiBalance.sub(postDaiBalance), 'DAI balance check').to.eq.BN(daiAmount);
    });
});
