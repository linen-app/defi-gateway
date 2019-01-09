pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISaiTub.sol";
import "./interfaces/IWrappedEther.sol";


contract MakerDaoGateway is Pausable {
    using SafeMath for uint;

    ISaiTub public saiTube;
    IWrappedEther public wrappedEther;
    IERC20 public pooledEther;
    IERC20 public dai;

    mapping (bytes32 => address) public cdpOwner;

    // TODO: check indexed fields
    event CdpOpened(address indexed owner, bytes32 cdpId);
    event CollateralSupplied(address indexed owner, bytes32 cdpId, uint wethAmount, uint pethAmount);
    event DaiBorrowed(address indexed owner, bytes32 cdpId, uint amount);


    constructor(ISaiTub _saiTube) public {
        saiTube = _saiTube;
        wrappedEther = saiTube.gem();
        pooledEther = saiTube.skr();
        dai = saiTube.sai();

        approveERC20();
    }
    
    // SUPPLY AND BORROW

    function supplyAndBorrow(bytes32 cdpId, uint daiAmount, address beneficiary) external payable {
        bytes32 id = cdpId; //TO FIX
        if (msg.value > 0) {
            id = supplyEth(cdpId);
        }
        if (daiAmount > 0) {
            borrowDai(id, daiAmount, beneficiary);
        }
    }
    
    // ETH amount should be > 0.005
    function supplyEth(bytes32 cdpId) public payable returns (bytes32) {
        wrappedEther.deposit.value(msg.value)();
        return supply(cdpId, msg.value);
    }

    // WETH amount should be > 0.005
    // don't forget to approve before supplying
    function supplyWeth(bytes32 cdpId, uint wethAmount) public returns (bytes32) {
        wrappedEther.transferFrom(msg.sender, this, wethAmount);
        return supply(cdpId, wethAmount);
    }

    function pethPEReth(uint ethNum) public view returns (uint rPETH) {
        rPETH = (ethNum.mul(10 ** 27)).div(saiTube.per());
    }

    function supply(bytes32 cdpId, uint wethAmount) internal returns (bytes32) {
        uint pethAmount = pethPEReth(wethAmount); //TODO adjust acording to the rate;
        saiTube.join(pethAmount);

        assert(pooledEther.balanceOf(this) >= pethAmount);

        bytes32 id = cdpId;
        if(id == 0) {
            id = saiTube.open();
            cdpOwner[id] = msg.sender;
            emit CdpOpened(msg.sender, id);
        } else {
            require(cdpOwner[id] == msg.sender, "CDP belongs to a different address");
        }

        saiTube.lock(id, pethAmount);
        emit CollateralSupplied(msg.sender, id, wethAmount, pethAmount);

        return id;
    }

    // TODO: handle beneficiary address
    function borrowDai(bytes32 cdpId, uint daiAmount, address beneficiary) public {
        require(cdpOwner[cdpId] == msg.sender, "CDP belongs to a different address");
        
        saiTube.draw(cdpId, daiAmount);
        dai.transfer(msg.sender, daiAmount);
        emit DaiBorrowed(msg.sender, cdpId, daiAmount);
    }

    // REPAY AND RETURN
    
    function repayAndReturn(bytes32 cdpId, uint daiAmount, uint ethAmount) external {
        if (daiAmount > 0) {
            repayDai(cdpId, daiAmount);
        }
        if (ethAmount > 0) {
            returnEth(cdpId, ethAmount);
        }
    }

    function repayDai(bytes32 cdpId, uint daiAmount) public {
        
    }

    function returnEth(bytes32 cdpId, uint ethAmount) public {
        
    }

    function returnWeth(bytes32 cdpId, uint wethAmount) public {
        
    }

    function transferCdp(bytes32 cdpId, address nextOwner) external {

    }

    function migrateCdp(bytes32 cdpId) external {
        
    }

    function approveERC20() public {
        wrappedEther.approve(saiTube, 2**256 - 1);
        pooledEther.approve(saiTube, 2**256 - 1);
        // IERC20 mkrTkn = IERC20(getAddress("mkr"));
        // mkrTkn.approve(cdpAddr, 2**256 - 1);
        // IERC20 daiTkn = IERC20(getAddress("dai"));
        // daiTkn.approve(cdpAddr, 2**256 - 1);
    }

}
