import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ArrayUtils.sol";

pragma solidity 0.5.0;

contract TestArrayUtils {
    using ArrayUtils for bytes32[];

    bytes32[] array;
    
    constructor () public {
        array.push(0x0000000000000000000000000000000000000000000000000000000000000000);
        array.push(0x0000000000000000000000000000000000000000000000000000000000000001);
        array.push(0x0000000000000000000000000000000000000000000000000000000000000002);
        array.push(0x0000000000000000000000000000000000000000000000000000000000000003);
        array.push(0x0000000000000000000000000000000000000000000000000000000000000004);
        array.push(0x0000000000000000000000000000000000000000000000000000000000000005);
        
    }
    
    function testFindElement1() external {
        (uint index, bool ok) = array.findElement(0x0000000000000000000000000000000000000000000000000000000000000001);
        Assert.equal(ok, true, "ok check");
        Assert.equal(index, 1, "index check");
    }

    function testFindElement2() external {
        (, bool ok) = array.findElement(0x0000000000000000000000000000000000000000000000000000000000000006);
        Assert.equal(ok, false, "ok check");
    }
    
    function testRemoveFirstElement() external {
        uint preLength = array.length;
        array.removeElement(0);
        uint postLength = array.length;

        Assert.equal(preLength, postLength + 1, "length check");
        Assert.equal(array[0], 0x0000000000000000000000000000000000000000000000000000000000000001, "element check");
    }
    
    function testRemoveLastElement() external {
        uint preLength = array.length;
        array.removeElement(preLength - 1);
        uint postLength = array.length;

        Assert.equal(preLength, postLength + 1, "length check");
        Assert.equal(array[postLength - 1], 0x0000000000000000000000000000000000000000000000000000000000000004, "element check");
    }

}
