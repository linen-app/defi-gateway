pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";


interface KyberNetworkProxyInterface {
    function maxGasPrice() external view returns(uint);
    function getUserCapInWei(address user) external view returns(uint);
    function getUserCapInTokenWei(address user, IERC20 token) external view returns(uint);
    function enabled() external view returns(bool);
    function info(bytes32 id) external view returns(uint);

    function getExpectedRate(IERC20 src, IERC20 dest, uint srcQty) external view
        returns (uint expectedRate, uint slippageRate);

    function trade(
        IERC20 src,
        uint srcAmount,
        IERC20 dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
    ) external payable returns(uint);
}