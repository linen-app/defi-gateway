pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./interfaces/ISaiTub.sol";


contract MakerDaoGateway is Pausable {
    address public saiTube;

    constructor(address _saiTube) public {
        saiTube = _saiTube;
    }

    function supplyAndBorrow(uint cdpId, uint daiAmount, uint ethAmount, address beneficiary) external payable {
        if (msg.value > 0) {
            supplyEth(cdpId, ethAmount);
        }
        if (daiAmount > 0) {
            borrowDai(cdpId, daiAmount, beneficiary);
        }
    }

    function repayAndReturn(uint cdpId, uint daiAmount, uint ethAmount) external {
        if (daiAmount > 0) {
            repayDai(cdpId, daiAmount);
        }
        if (ethAmount > 0) {
            returnEth(cdpId, ethAmount);
        }
    }

    function supplyEth(uint cdpId, uint ethAmount) public payable {
        
    }

    function supplyWeth(uint cdpId, uint wethAmount) public payable {
        
    }

    function borrowDai(uint cdpId, uint daiAmount, address beneficiary) public {
        
    }

    function repayDai(uint cdpId, uint daiAmount) public {
        
    }

    function returnEth(uint cdpId, uint ethAmount) public {
        
    }

    function returnWeth(uint cdpId, uint wethAmount) public {
        
    }

    function transferCdp(uint cdpId, address nextOwner) external {

    }

    function migrateCdp(uint cdpId) external {
        
    }

}
