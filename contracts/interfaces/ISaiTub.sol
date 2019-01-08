pragma solidity 0.4.24;

interface ISaiTub {
    function open() public returns (bytes32 cup);
    function join(uint wad) public;
    function exit(uint wad) public;
    function give(bytes32 cup, address guy) public;
    function lock(bytes32 cup, uint wad) public;
    function free(bytes32 cup, uint wad) public;
    function draw(bytes32 cup, uint wad) public;
    function wipe(bytes32 cup, uint wad) public;
    function per() public view returns (uint ray);
    function lad(bytes32 cup) public view returns (address);
}