import { MakerDaoGatewayContract } from '../types/truffle-contracts';

const MakerDaoGateway = artifacts.require<MakerDaoGatewayContract>("MakerDaoGateway");
const Erc20 = artifacts.require("KyberGateway");

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const saiTubeAddress = '0xe82ce3d6bf40f2f9414c8d01a35e3d9eb16a1761';
const daiAddress = '0xc226f3cd13d508bc319f4f4290172748199d6612'

contract('MakerDaoGateway', ([deployer]) => {
    it("should assert true", async () => {
        const dai = await Erc20.at(daiAddress);
        const makerDaoGateway = await MakerDaoGateway.new(saiTubeAddress, { from: deployer })
        const daiAmount = web3.utils.toWei('5');
        const ethAmount = web3.utils.toWei('0.05');
        await makerDaoGateway.supplyAndBorrow(0, daiAmount, ethAmount, ZERO_ADDRESS, {from: deployer});
    });
});
