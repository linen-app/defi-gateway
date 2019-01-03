var MakerDaoGateway = artifacts.require("MakerDaoGateway");
var KyberGateway = artifacts.require("KyberGateway");

const saiTubeAddress = '0xa71937147b55deb8a530c7229c442fd3f31b7db2';

module.exports = (deployer) => {
    deployer.deploy(KyberGateway);
    deployer.deploy(MakerDaoGateway, saiTubeAddress);
};
