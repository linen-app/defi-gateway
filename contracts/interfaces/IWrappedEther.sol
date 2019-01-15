pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";


contract IWrappedEther is IERC20 {
    function deposit() external payable;
    function withdraw(uint amount) external;
}
