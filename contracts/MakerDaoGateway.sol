pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISaiTub.sol";
import "./interfaces/IWrappedEther.sol";


contract MakerDaoGateway is Pausable {
    using SafeMath for uint;

    ISaiTub public saiTub;

    mapping(bytes32 => address) public cdpOwner;
    mapping(address => bytes32[]) public cdpsByOwner;

    // TODO: check indexed fields
    event CdpOpened(address indexed owner, bytes32 cdpId);
    event CollateralSupplied(address indexed owner, bytes32 cdpId, uint wethAmount, uint pethAmount);
    event DaiBorrowed(address indexed owner, bytes32 cdpId, uint amount);
    event DaiRepaid(address indexed owner, bytes32 cdpId, uint amount);
    event CollateralReturned(address indexed owner, bytes32 cdpId, uint wethAmount, uint pethAmount);


    constructor(ISaiTub _saiTub) public {
        saiTub = _saiTub;
    }

    function cdpsByOwnerLength(address owner) public view returns (uint) {
        return cdpsByOwner[owner].length;
    }

    function () public payable {
        // For unwrapping WETH only
    }
    
    // SUPPLY AND BORROW
    
    // specify cdpId if you want to use existing CDP, or pass 0 if you need to create a new one 
    function supplyEthAndBorrowDai(bytes32 cdpId, uint daiAmount) external payable {
        bytes32 id = supplyEth(cdpId);
        borrowDai(id, daiAmount);
    }

    // specify cdpId if you want to use existing CDP, or pass 0 if you need to create a new one 
    function supplyWethAndBorrowDai(bytes32 cdpId, uint wethAmount, uint daiAmount) external payable {
        bytes32 id = supplyWeth(cdpId, wethAmount);
        borrowDai(id, daiAmount);
    }

    // ETH amount should be > 0.005 for new CDPs
    // returns id of actual cdp (existing or a new one)
    function supplyEth(bytes32 cdpId) public payable returns (bytes32) {
        if (msg.value > 0) {
            saiTub.gem().deposit.value(msg.value)();
            return _supply(cdpId, msg.value);
        }

        return cdpId;
    }

    // WETH amount should be > 0.005 for new CDPs
    // don't forget to approve WETH before supplying
    // returns id of actual cdp (existing or a new one)
    function supplyWeth(bytes32 cdpId, uint wethAmount) public returns (bytes32) {
        if (wethAmount > 0) {
            saiTub.gem().transferFrom(msg.sender, this, wethAmount);
            return _supply(cdpId, wethAmount);
        }

        return cdpId;
    }


    function _supply(bytes32 cdpId, uint wethAmount) internal returns (bytes32 id) {
        id = cdpId;
        if (id == 0) {
            id = createCdp();
        } else {
            require(cdpOwner[id] == msg.sender, "CDP belongs to a different address");
        }

        if (saiTub.gem().allowance(this, saiTub) != uint(-1)) {
            saiTub.gem().approve(saiTub, uint(-1));
        }

        uint pethAmount = pethForWeth(wethAmount);
        
        saiTub.join(pethAmount);

        if (saiTub.skr().allowance(this, saiTub) != uint(-1)) {
            saiTub.skr().approve(saiTub, uint(-1));
        }

        saiTub.lock(id, pethAmount);
        emit CollateralSupplied(msg.sender, id, wethAmount, pethAmount);
    }
    
    function createCdp() internal returns (bytes32 cdpId) {
        cdpId = saiTub.open();
        
        cdpOwner[cdpId] = msg.sender;
        cdpsByOwner[msg.sender].push(cdpId);
        
        emit CdpOpened(msg.sender, cdpId);
    }

    function borrowDai(bytes32 cdpId, uint daiAmount) public {
        require(cdpOwner[cdpId] == msg.sender, "CDP belongs to a different address");
        if (daiAmount > 0) {
            saiTub.draw(cdpId, daiAmount);
            
            saiTub.sai().transfer(msg.sender, daiAmount);
            
            emit DaiBorrowed(msg.sender, cdpId, daiAmount);
        }
    }

    // REPAY AND RETURN

    // don't forget to approve DAI before repaying
    function repayDaiAndReturnEth(bytes32 cdpId, uint daiAmount, uint ethAmount) external {
        repayDai(cdpId, daiAmount);
        returnEth(cdpId, ethAmount);
    }

    // don't forget to approve DAI before repaying
    // pass -1 to daiAmount to repay all outstanding debt
    // pass -1 to wethAmount to return all collateral
    function repayDaiAndReturnWeth(bytes32 cdpId, uint daiAmount, uint wethAmount) external {
        repayDai(cdpId, daiAmount);
        returnWeth(cdpId, wethAmount);
    }

    // don't forget to approve DAI before repaying
    function repayDai(bytes32 cdpId, uint daiAmount) public {
        require(cdpOwner[cdpId] == msg.sender, "CDP belongs to a different address");
        if (daiAmount > 0) {
            
            uint amount = daiAmount;
            if (daiAmount == uint(-1)) {
                amount = saiTub.tab(cdpId);
            }

            if (saiTub.sai().allowance(this, saiTub) != uint(-1)) {
                saiTub.sai().approve(saiTub, uint(-1));
            }
            if (saiTub.gov().allowance(this, saiTub) != uint(-1)) {
                saiTub.gov().approve(saiTub, uint(-1));
            }

            //TODO: handle gov fee
            saiTub.sai().transferFrom(msg.sender, this, amount);
            
            saiTub.wipe(cdpId, amount);

            emit DaiRepaid(msg.sender, cdpId, amount);
        }
    }

    function returnEth(bytes32 cdpId, uint ethAmount) public {
        require(cdpOwner[cdpId] == msg.sender, "CDP belongs to a different address");
        if (ethAmount > 0) {
            uint effectiveWethAmount = _return(cdpId, ethAmount);
            saiTub.gem().withdraw(effectiveWethAmount);
            msg.sender.transfer(effectiveWethAmount);
        }
    }

    function returnWeth(bytes32 cdpId, uint wethAmount) public {
        require(cdpOwner[cdpId] == msg.sender, "CDP belongs to a different address");
        if (wethAmount > 0){
            uint effectiveWethAmount = _return(cdpId, wethAmount);
            saiTub.gem().transfer(msg.sender, effectiveWethAmount);
        }
    }
    
    function _return(bytes32 cdpId, uint wethAmount) internal returns (uint effectiveWethAmount) {
        require(cdpOwner[cdpId] == msg.sender, "CDP belongs to a different address");

        uint pethAmount;
        
        if (wethAmount == uint(-1)){
            pethAmount = saiTub.ink(cdpId);
        } else {
            pethAmount = pethForWeth(wethAmount);
        }

        saiTub.free(cdpId, pethAmount);

        if (saiTub.skr().allowance(this, saiTub) != uint(-1)) {
            saiTub.skr().approve(saiTub, uint(-1));
        }
        
        saiTub.exit(pethAmount);
        
        effectiveWethAmount = wethForPeth(pethAmount);

        emit CollateralReturned(msg.sender, cdpId, effectiveWethAmount, pethAmount);
    }

    function transferCdp(bytes32 cdpId, address nextOwner) external {
        //TODO
    }

    function migrateCdp(bytes32 cdpId) external {
        //TODO
    }
    
    // Just for testing purpuses
    function withdrawMkr(uint mkrAmount) external onlyPauser {
        saiTub.gov().transfer(msg.sender, mkrAmount);
    }

    function pethForWeth(uint wethAmount) public view returns (uint) {
        return rdiv(wethAmount, saiTub.per());
    }

    function wethForPeth(uint pethAmount) public view returns (uint) {
        return rmul(pethAmount, saiTub.per());
    }

    uint constant internal RAY = 10 ** 27;
    
    // more info about ray math: https://github.com/dapphub/ds-math
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = x.mul(RAY).add(y / 2) / y;
    }

    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = x.mul(y).add(RAY / 2) / RAY;
    }
}
