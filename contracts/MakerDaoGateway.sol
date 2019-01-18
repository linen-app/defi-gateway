pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../lib/ds-math/src/math.sol";
import "./interfaces/ISaiTub.sol";
import "./interfaces/IWrappedEther.sol";
import "./interfaces/IDex.sol";


contract MakerDaoGateway is Pausable, DSMath {

    ISaiTub public saiTub;
    IDex public dex;

    mapping(bytes32 => address) public cdpOwner;
    mapping(address => bytes32[]) public cdpsByOwner;

    // TODO: check indexed fields
    event CdpOpened(address indexed owner, bytes32 cdpId);
    event CollateralSupplied(address indexed owner, bytes32 cdpId, uint wethAmount, uint pethAmount);
    event DaiBorrowed(address indexed owner, bytes32 cdpId, uint amount);
    event DaiRepaid(address indexed owner, bytes32 cdpId, uint amount);
    event CollateralReturned(address indexed owner, bytes32 cdpId, uint wethAmount, uint pethAmount);
    
    modifier isCdpOwner(bytes32 cdpId) {
        require(cdpOwner[cdpId] == msg.sender || cdpId == 0, "CDP belongs to a different address");
        _;
    }

    constructor(ISaiTub _saiTub, IDex _dex) public {
        saiTub = _saiTub;
        dex = _dex;
    }
    
    function cdpsByOwnerLength(address owner) public view returns (uint) {
        return cdpsByOwner[owner].length;
    }

    function systemParameters() public view returns (uint liquidationRatio, uint annualStabilityFee) {
        liquidationRatio = saiTub.mat();
        annualStabilityFee = rpow(saiTub.fee(), 365 days);
    }

    function() external payable {
        // For unwrapping WETH
    }

    // SUPPLY AND BORROW

    // specify cdpId if you want to use existing CDP, or pass 0 if you need to create a new one 
    function supplyEthAndBorrowDai(bytes32 cdpId, uint daiAmount) isCdpOwner(cdpId) external payable {
        bytes32 id = supplyEth(cdpId);
        borrowDai(id, daiAmount);
    }

    // specify cdpId if you want to use existing CDP, or pass 0 if you need to create a new one 
    function supplyWethAndBorrowDai(bytes32 cdpId, uint wethAmount, uint daiAmount) isCdpOwner(cdpId) external {
        bytes32 id = supplyWeth(cdpId, wethAmount);
        borrowDai(id, daiAmount);
    }

    // ETH amount should be > 0.005 for new CDPs
    // returns id of actual cdp (existing or a new one)
    function supplyEth(bytes32 cdpId) isCdpOwner(cdpId) public payable returns (bytes32) {
        if (msg.value > 0) {
            saiTub.gem().deposit.value(msg.value)();
            return _supply(cdpId, msg.value);
        }

        return cdpId;
    }

    // WETH amount should be > 0.005 for new CDPs
    // don't forget to approve WETH before supplying
    // returns id of actual cdp (existing or a new one)
    function supplyWeth(bytes32 cdpId, uint wethAmount) isCdpOwner(cdpId) public returns (bytes32) {
        if (wethAmount > 0) {
            saiTub.gem().transferFrom(msg.sender, address(this), wethAmount);
            return _supply(cdpId, wethAmount);
        }

        return cdpId;
    }


    function _supply(bytes32 cdpId, uint wethAmount) internal returns (bytes32 id) {
        id = cdpId;
        if (id == 0) {
            id = _createCdp();
        } else {
            require(cdpOwner[id] == msg.sender, "CDP belongs to a different address");
        }

        _ensureApproval(saiTub.gem(), address(saiTub));

        uint pethAmount = pethForWeth(wethAmount);

        saiTub.join(pethAmount);

        _ensureApproval(saiTub.skr(), address(saiTub));

        saiTub.lock(id, pethAmount);
        emit CollateralSupplied(msg.sender, id, wethAmount, pethAmount);
    }

    function _createCdp() internal returns (bytes32 cdpId) {
        cdpId = saiTub.open();

        cdpOwner[cdpId] = msg.sender;
        cdpsByOwner[msg.sender].push(cdpId);

        emit CdpOpened(msg.sender, cdpId);
    }

    function borrowDai(bytes32 cdpId, uint daiAmount) isCdpOwner(cdpId) public {
        if (daiAmount > 0) {
            saiTub.draw(cdpId, daiAmount);

            saiTub.sai().transfer(msg.sender, daiAmount);

            emit DaiBorrowed(msg.sender, cdpId, daiAmount);
        }
    }

    // REPAY AND RETURN

    // don't forget to approve DAI before repaying
    function repayDaiAndReturnEth(bytes32 cdpId, uint daiAmount, uint ethAmount, bool payFeeInDai) isCdpOwner(cdpId) external {
        repayDai(cdpId, daiAmount, payFeeInDai);
        returnEth(cdpId, ethAmount);
    }

    // don't forget to approve DAI before repaying
    // pass -1 to daiAmount to repay all outstanding debt
    // pass -1 to wethAmount to return all collateral
    function repayDaiAndReturnWeth(bytes32 cdpId, uint daiAmount, uint wethAmount, bool payFeeInDai) isCdpOwner(cdpId) external {
        repayDai(cdpId, daiAmount, payFeeInDai);
        returnWeth(cdpId, wethAmount);
    }

    // don't forget to approve DAI before repaying
    // pass -1 to daiAmount to repay all outstanding debt
    function repayDai(bytes32 cdpId, uint daiAmount, bool payFeeInDai) isCdpOwner(cdpId) public {
        if (daiAmount > 0) {

            uint amount = daiAmount;
            if (daiAmount == uint(- 1)) {
                // repay all outstanding debt
                amount = saiTub.tab(cdpId);
            }

            _ensureApproval(saiTub.sai(), address(saiTub));
            _ensureApproval(saiTub.gov(), address(saiTub));

            uint govFeeAmount = _calcGovernanceFee(cdpId, amount);
            _handleGovFee(govFeeAmount, payFeeInDai);

            saiTub.sai().transferFrom(msg.sender, address(this), amount);

            saiTub.wipe(cdpId, amount);

            emit DaiRepaid(msg.sender, cdpId, amount);
        }
    }

    function returnEth(bytes32 cdpId, uint ethAmount) isCdpOwner(cdpId) public {
        if (ethAmount > 0) {
            uint effectiveWethAmount = _return(cdpId, ethAmount);
            saiTub.gem().withdraw(effectiveWethAmount);
            msg.sender.transfer(effectiveWethAmount);
        }
    }

    function returnWeth(bytes32 cdpId, uint wethAmount) isCdpOwner(cdpId) public {
        if (wethAmount > 0) {
            uint effectiveWethAmount = _return(cdpId, wethAmount);
            saiTub.gem().transfer(msg.sender, effectiveWethAmount);
        }
    }

    function _return(bytes32 cdpId, uint wethAmount) internal returns (uint effectiveWethAmount) {
        uint pethAmount;

        if (wethAmount == uint(- 1)) {
            // return all collateral
            pethAmount = saiTub.ink(cdpId);
        } else {
            pethAmount = pethForWeth(wethAmount);
        }

        saiTub.free(cdpId, pethAmount);

        _ensureApproval(saiTub.skr(), address(saiTub));

        saiTub.exit(pethAmount);

        effectiveWethAmount = wethForPeth(pethAmount);

        emit CollateralReturned(msg.sender, cdpId, effectiveWethAmount, pethAmount);
    }

    function _calcGovernanceFee(bytes32 cdpId, uint daiAmount) internal returns (uint mkrFeeAmount) {
        uint daiFeeAmount = rmul(daiAmount, rdiv(saiTub.rap(cdpId), saiTub.tab(cdpId)));
        (bytes32 val, bool ok) = saiTub.pep().peek();
        require(ok && val != 0, 'Unable to get mkr rate');

        mkrFeeAmount = wdiv(daiFeeAmount, uint(val));
    }

    function _handleGovFee(uint govFeeAmount, bool payWithDai) internal {
        if (govFeeAmount > 0) {
            if (payWithDai) {
                uint saiGovAmt = dex.getPayAmount(saiTub.sai(), saiTub.gov(), govFeeAmount);

                _ensureApproval(saiTub.sai(), address(dex));

                saiTub.sai().transferFrom(msg.sender, address(this), saiGovAmt);
                dex.buyAllAmount(saiTub.gov(), govFeeAmount, saiTub.sai(), saiGovAmt);
            } else {
                saiTub.gov().transferFrom(msg.sender, address(this), govFeeAmount);
            }
        }
    }

    function _ensureApproval(IERC20 token, address spender) internal {
        if (token.allowance(address(this), spender) != uint(- 1)) {
            require(token.approve(spender, uint(- 1)));
        }
    }

    function transferCdp(bytes32 cdpId, address nextOwner) isCdpOwner(cdpId) external {
        //TODO
    }

    function migrateCdp(bytes32 cdpId) external {
        //TODO
    }

    function pethForWeth(uint wethAmount) public view returns (uint) {
        return rdiv(wethAmount, saiTub.per());
    }

    function wethForPeth(uint pethAmount) public view returns (uint) {
        return rmul(pethAmount, saiTub.per());
    }
}
