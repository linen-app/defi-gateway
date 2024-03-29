pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../lib/ds-math/src/math.sol";
import "./interfaces/ISaiTub.sol";
import "./interfaces/IWrappedEther.sol";
import "./interfaces/IDex.sol";
import "./ArrayUtils.sol";


contract MakerDaoGateway is Pausable, DSMath {
    using ArrayUtils for bytes32[];

    ISaiTub public saiTub;
    IDex public dex;
    IWrappedEther public weth;
    IERC20 public peth;
    IERC20 public dai;
    IERC20 public mkr;

    mapping(bytes32 => address) public cdpOwner;
    mapping(address => bytes32[]) public cdpsByOwner;

    event CdpOpened(address indexed owner, bytes32 cdpId);
    event CdpClosed(address indexed owner, bytes32 cdpId);
    event CollateralSupplied(address indexed owner, bytes32 cdpId, uint wethAmount, uint pethAmount);
    event DaiBorrowed(address indexed owner, bytes32 cdpId, uint amount);
    event DaiRepaid(address indexed owner, bytes32 cdpId, uint amount);
    event CollateralReturned(address indexed owner, bytes32 cdpId, uint wethAmount, uint pethAmount);
    event CdpTransferred(address indexed oldOwner, address indexed newOwner, bytes32 cdpId);
    event CdpEjected(address indexed newOwner, bytes32 cdpId);
    event CdpRegistered(address indexed newOwner, bytes32 cdpId);

    modifier isCdpOwner(bytes32 cdpId) {
        require(cdpOwner[cdpId] == msg.sender || cdpId == 0, "CDP belongs to a different address");
        _;
    }

    constructor(ISaiTub _saiTub, IDex _dex) public {
        saiTub = _saiTub;
        dex = _dex;
        weth = saiTub.gem();
        peth = saiTub.skr();
        dai = saiTub.sai();
        mkr = saiTub.gov();
    }

    function cdpsByOwnerLength(address _owner) external view returns (uint) {
        return cdpsByOwner[_owner].length;
    }

    function systemParameters() external view returns (uint liquidationRatio, uint annualStabilityFee, uint daiAvailable) {
        liquidationRatio = saiTub.mat();
        annualStabilityFee = rpow(saiTub.fee(), 365 days);
        daiAvailable = sub(saiTub.cap(), dai.totalSupply());
    }
    
    function cdpInfo(bytes32 cdpId) external returns (uint borrowedDai, uint outstandingDai, uint suppliedPeth) {
        (, uint ink, uint art, ) = saiTub.cups(cdpId);
        borrowedDai = art;
        suppliedPeth = ink;
        outstandingDai = add(saiTub.rap(cdpId), saiTub.tab(cdpId));
    }
    
    function pethForWeth(uint wethAmount) public view returns (uint) {
        return rdiv(wethAmount, saiTub.per());
    }

    function wethForPeth(uint pethAmount) public view returns (uint) {
        return rmul(pethAmount, saiTub.per());
    }

    function() external payable {
        // For unwrapping WETH
    }

    // SUPPLY AND BORROW
    
    // specify cdpId if you want to use existing CDP, or pass 0 if you need to create a new one
    // for new and active CDPs collateral amount should be > 0.005 PETH
    function supplyEthAndBorrowDai(bytes32 cdpId, uint daiAmount) whenNotPaused isCdpOwner(cdpId) external payable {
        bytes32 id = supplyEth(cdpId);
        borrowDai(id, daiAmount);
    }

    // specify cdpId if you want to use existing CDP, or pass 0 if you need to create a new one 
    function supplyWethAndBorrowDai(bytes32 cdpId, uint wethAmount, uint daiAmount) whenNotPaused isCdpOwner(cdpId) external {
        bytes32 id = supplyWeth(cdpId, wethAmount);
        borrowDai(id, daiAmount);
    }

    // returns id of actual CDP (existing or a new one)
    // for new and active CDPs collateral amount should be > 0.005 PETH
    function supplyEth(bytes32 cdpId) whenNotPaused isCdpOwner(cdpId) public payable returns (bytes32 _cdpId) {
        if (msg.value > 0) {
            weth.deposit.value(msg.value)();
            return _supply(cdpId, msg.value);
        }

        return cdpId;
    }

    // for new and active CDPs collateral amount should be > 0.005 PETH
    // don't forget to approve WETH before supplying
    // returns id of actual CDP (existing or a new one)
    function supplyWeth(bytes32 cdpId, uint wethAmount) whenNotPaused isCdpOwner(cdpId) public returns (bytes32 _cdpId) {
        if (wethAmount > 0) {
            require(weth.transferFrom(msg.sender, address(this), wethAmount));
            return _supply(cdpId, wethAmount);
        }

        return cdpId;
    }

    function borrowDai(bytes32 cdpId, uint daiAmount) whenNotPaused isCdpOwner(cdpId) public {
        if (daiAmount > 0) {
            saiTub.draw(cdpId, daiAmount);

            require(dai.transfer(msg.sender, daiAmount));

            emit DaiBorrowed(msg.sender, cdpId, daiAmount);
        }
    }

    // REPAY AND RETURN

    // don't forget to approve DAI before repaying
    function repayDaiAndReturnEth(bytes32 cdpId, uint daiAmount, uint ethAmount, bool payFeeInDai) whenNotPaused isCdpOwner(cdpId) external {
        repayDai(cdpId, daiAmount, payFeeInDai);
        returnEth(cdpId, ethAmount);
    }

    // don't forget to approve DAI before repaying
    // pass -1 to daiAmount to repay all outstanding debt
    // pass -1 to wethAmount to return all collateral
    function repayDaiAndReturnWeth(bytes32 cdpId, uint daiAmount, uint wethAmount, bool payFeeInDai) whenNotPaused isCdpOwner(cdpId) public {
        repayDai(cdpId, daiAmount, payFeeInDai);
        returnWeth(cdpId, wethAmount);
    }

    // don't forget to approve DAI before repaying
    // pass -1 to daiAmount to repay all outstanding debt
    function repayDai(bytes32 cdpId, uint daiAmount, bool payFeeInDai) whenNotPaused isCdpOwner(cdpId) public {
        if (daiAmount > 0) {
            uint _daiAmount = daiAmount;
            if (_daiAmount == uint(- 1)) {
                // repay all outstanding debt
                _daiAmount = saiTub.tab(cdpId);
            }

            _ensureApproval(dai, address(saiTub));
            _ensureApproval(mkr, address(saiTub));

            uint govFeeAmount = _calcGovernanceFee(cdpId, _daiAmount);
            _handleGovFee(govFeeAmount, payFeeInDai);

            require(dai.transferFrom(msg.sender, address(this), _daiAmount));

            saiTub.wipe(cdpId, _daiAmount);

            emit DaiRepaid(msg.sender, cdpId, _daiAmount);
        }
    }

    function returnEth(bytes32 cdpId, uint ethAmount) whenNotPaused isCdpOwner(cdpId) public {
        if (ethAmount > 0) {
            uint effectiveWethAmount = _return(cdpId, ethAmount);
            weth.withdraw(effectiveWethAmount);
            msg.sender.transfer(effectiveWethAmount);
        }
    }

    function returnWeth(bytes32 cdpId, uint wethAmount) whenNotPaused isCdpOwner(cdpId) public {
        if (wethAmount > 0) {
            uint effectiveWethAmount = _return(cdpId, wethAmount);
            require(weth.transfer(msg.sender, effectiveWethAmount));
        }
    }

    function closeCdp(bytes32 cdpId, bool payFeeInDai) whenNotPaused isCdpOwner(cdpId) external {
        repayDaiAndReturnWeth(cdpId, uint(-1), uint(-1), payFeeInDai);
        _removeCdp(cdpId, msg.sender);
        saiTub.shut(cdpId);
        
        emit CdpClosed(msg.sender, cdpId);
    }

    // TRANSFER AND ADOPT

    // You can migrate your CDP from MakerDaoGateway contract to another owner
    function transferCdp(bytes32 cdpId, address nextOwner) isCdpOwner(cdpId) external {
        address _owner = nextOwner;
        if (_owner == address(0x0)) {
            _owner = msg.sender;
        }
        
        saiTub.give(cdpId, _owner);

        _removeCdp(cdpId, msg.sender);

        emit CdpTransferred(msg.sender, _owner, cdpId);
    }
    
    function ejectCdp(bytes32 cdpId) onlyPauser external {
        address owner = cdpOwner[cdpId];
        saiTub.give(cdpId, owner);

        _removeCdp(cdpId, owner);

        emit CdpEjected(owner, cdpId);
    }

    // If you want to migrate existing CDP to MakerDaoGateway contract,
    // you need to register your cdp first with this function, and then execute `give` operation,
    // transferring CDP to the MakerDaoGateway contract
    function registerCdp(bytes32 cdpId, address owner) whenNotPaused external {
        require(saiTub.lad(cdpId) == msg.sender, "Can't register other's CDP");
        require(cdpOwner[cdpId] == address(0x0), "Can't register CDP twice");

        address _owner = owner;
        if (_owner == address(0x0)) {
            _owner = msg.sender;
        }

        cdpOwner[cdpId] = _owner;
        cdpsByOwner[_owner].push(cdpId);

        emit CdpRegistered(_owner, cdpId);
    }

    // INTERNAL FUNCTIONS

    function _supply(bytes32 cdpId, uint wethAmount) internal returns (bytes32 _cdpId) {
        _cdpId = cdpId;
        if (_cdpId == 0) {
            _cdpId = _createCdp();
        }

        _ensureApproval(weth, address(saiTub));

        uint pethAmount = pethForWeth(wethAmount);

        saiTub.join(pethAmount);

        _ensureApproval(peth, address(saiTub));

        saiTub.lock(_cdpId, pethAmount);
        emit CollateralSupplied(msg.sender, _cdpId, wethAmount, pethAmount);
    }

    function _return(bytes32 cdpId, uint wethAmount) internal returns (uint _wethAmount) {
        uint pethAmount;

        if (wethAmount == uint(- 1)) {
            // return all collateral
            pethAmount = saiTub.ink(cdpId);
        } else {
            pethAmount = pethForWeth(wethAmount);
        }

        saiTub.free(cdpId, pethAmount);

        _ensureApproval(peth, address(saiTub));

        saiTub.exit(pethAmount);

        _wethAmount = wethForPeth(pethAmount);

        emit CollateralReturned(msg.sender, cdpId, _wethAmount, pethAmount);
    }

    function _calcGovernanceFee(bytes32 cdpId, uint daiAmount) internal returns (uint mkrFeeAmount) {
        uint daiFeeAmount = rmul(daiAmount, rdiv(saiTub.rap(cdpId), saiTub.tab(cdpId)));
        (bytes32 val, bool ok) = saiTub.pep().peek();
        require(ok && val != 0, 'Unable to get mkr rate');

        return wdiv(daiFeeAmount, uint(val));
    }

    function _handleGovFee(uint mkrGovAmount, bool payWithDai) internal {
        if (mkrGovAmount > 0) {
            if (payWithDai) {
                uint daiAmount = dex.getPayAmount(dai, mkr, mkrGovAmount);

                _ensureApproval(dai, address(dex));

                require(dai.transferFrom(msg.sender, address(this), daiAmount));
                dex.buyAllAmount(mkr, mkrGovAmount, dai, daiAmount);
            } else {
                require(mkr.transferFrom(msg.sender, address(this), mkrGovAmount));
            }
        }
    }

    function _ensureApproval(IERC20 token, address spender) internal {
        if (token.allowance(address(this), spender) != uint(- 1)) {
            require(token.approve(spender, uint(- 1)));
        }
    }

    function _createCdp() internal returns (bytes32 cdpId) {
        cdpId = saiTub.open();

        cdpOwner[cdpId] = msg.sender;
        cdpsByOwner[msg.sender].push(cdpId);

        emit CdpOpened(msg.sender, cdpId);
    }
    
    function _removeCdp(bytes32 cdpId, address owner) internal {
        (uint i, bool ok) = cdpsByOwner[owner].findElement(cdpId);
        require(ok, "Can't find cdp in owner's list");
        
        cdpsByOwner[owner].removeElement(i);
        delete cdpOwner[cdpId];
    }
}