pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./IWrappedEther.sol";

interface ISaiTub {
    function sai() external view returns (IERC20);  // Stablecoin
    function sin() external view returns (IERC20);  // Debt (negative sai)
    function skr() external view returns (IERC20);  // Abstracted collateral
    function gem() external view returns (IWrappedEther);  // Underlying collateral

    function open() external returns (bytes32 cup);
    function join(uint wad) external;
    function exit(uint wad) external;
    function give(bytes32 cup, address guy) external;
    function lock(bytes32 cup, uint wad) external;
    function free(bytes32 cup, uint wad) external;
    function draw(bytes32 cup, uint wad) external;
    function wipe(bytes32 cup, uint wad) external;
    function per() external view returns (uint ray);
    function lad(bytes32 cup) external view returns (address);
}