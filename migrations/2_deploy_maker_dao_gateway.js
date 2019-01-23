var MakerDaoGateway = artifacts.require('MakerDaoGateway');

var saiTubAddress = null;
var dexAddress = null;

module.exports = function(deployer, network) {
  if (network === 'live') {
      saiTubAddress = '0x448a5065aebb8e423f0896e6c5d525c040f59af3';
      dexAddress = '0xB7ac09C2c0217B07d7c103029B4918a2C401eeCB';
  } else if (network.indexOf('kovan') >= 0) {
      saiTubAddress = '0xa71937147b55deb8a530c7229c442fd3f31b7db2';
      dexAddress = '0xdB3b642eBc6Ff85A3AB335CFf9af2954F9215994';
  } else if (network === 'testchain') {
      saiTubAddress = '0xe82ce3d6bf40f2f9414c8d01a35e3d9eb16a1761';
      dexAddress = '0x06ef37a95603cb52e2dff4c2b177c84cdb3ce989';
  } else {
      throw new Error('Unknown network: ' + network);
  }

  deployer.deploy(MakerDaoGateway, saiTubAddress, dexAddress);
};
