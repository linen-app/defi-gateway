require('ts-node/register');
var HDWalletProvider = require('truffle-hdwallet-provider');
var fs = require('fs');
var pkey = fs.readFileSync('pkey.txt').toString();

module.exports = {
    networks: {
        kovan: {
            provider: function () {
                return new HDWalletProvider([pkey], "https://kovan.infura.io/v3/???", 0, 1);
            },
            network_id: '42'
        },
        testchain: {
            host: "127.0.0.1",
            port: 2000,
            network_id: "*"
        }
    }
};