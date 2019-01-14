var MakerDaoGateway = artifacts.require('MakerDaoGateway');

var saiTubeAddress = null;

module.exports = (deployer, network) => {
  if (network === 'live') {
    throw new Error('No live address')
  } else if (network === 'kovan') {
    saiTubeAddress = '0xa71937147b55deb8a530c7229c442fd3f31b7db2';
  } else if (network === 'testchain') {
    saiTubeAddress = '0xe82ce3d6bf40f2f9414c8d01a35e3d9eb16a1761';
  } else {
    throw new Error('Unknown network: ' + network);
  }

  deployer.deploy(MakerDaoGateway, saiTubeAddress);
};
