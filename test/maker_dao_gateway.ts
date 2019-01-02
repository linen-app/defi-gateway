import { MakerDaoGatewayContract } from '../types/truffle-contracts';

const MakerDaoGateway = artifacts.require<MakerDaoGatewayContract>("MakerDaoGateway");

contract('MakerDaoGateway', ([deployer]) => {
    it("should assert true", async () => {
        const makerDaoGateway = await MakerDaoGateway.new({ from: deployer })
        assert.isDefined(makerDaoGateway);
    });
});
