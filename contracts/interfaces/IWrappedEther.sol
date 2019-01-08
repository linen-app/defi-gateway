pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";


contract IWrappedEther is IERC20 {
    function deposit() public payable;
    function withdraw(uint amount) public;
}
