var MakerDaoGateway = artifacts.require("MakerDaoGateway");
var KyberGateway = artifacts.require("KyberGateway");

const saiTubeAddress = '0xe82ce3d6bf40f2f9414c8d01a35e3d9eb16a1761';
const wethAddress = '0x7ba25f791fa76c3ef40ac98ed42634a8bc24c238';

module.exports = (deployer) => {
    deployer.deploy(KyberGateway);
    deployer.deploy(MakerDaoGateway, saiTubeAddress, wethAddress);
};
