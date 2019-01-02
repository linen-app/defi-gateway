var MakerDaoGateway = artifacts.require("MakerDaoGateway");

module.exports = (deployer) => {
    deployer.deploy(MakerDaoGateway);
};
