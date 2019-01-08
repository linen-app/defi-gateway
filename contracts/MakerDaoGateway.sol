pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./interfaces/ISaiTub.sol";
import "./interfaces/IWrappedEther.sol";


contract MakerDaoGateway is Pausable {
    ISaiTub public saiTube;
    IWrappedEther public wrappedEther;

    function approveERC20() public {
        wrappedEther.approve(saiTube, 2**256 - 1);
        // IERC20 pethTkn = IERC20(getAddress("peth"));
        // pethTkn.approve(cdpAddr, 2**256 - 1);
        // IERC20 mkrTkn = IERC20(getAddress("mkr"));
        // mkrTkn.approve(cdpAddr, 2**256 - 1);
        // IERC20 daiTkn = IERC20(getAddress("dai"));
        // daiTkn.approve(cdpAddr, 2**256 - 1);
    }


    constructor(ISaiTub _saiTube, IWrappedEther _wrappedEther) public {
        require(address(_saiTube) != 0x0);
        require(address(_wrappedEther) != 0x0);

        saiTube = _saiTube;
        wrappedEther = _wrappedEther;

        approveERC20();
    }

    function supplyAndBorrow(uint cdpId, uint daiAmount, address beneficiary) external payable {
        if (msg.value > 0) {
            supplyEth(cdpId);
        }
        if (daiAmount > 0) {
            //borrowDai(cdpId, daiAmount, beneficiary);
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
    
    function supplyEth(uint cdpId) public payable {
        wrappedEther.deposit.value(msg.value)();
        //supplyWeth(cdpId, msg.value);
    }

    function supplyWeth(uint cdpId, uint wethAmount) public payable {
        wrappedEther.transferFrom(msg.sender, this, wethAmount);
        //saiTube.join(wethAmount);
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
