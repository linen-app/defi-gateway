pragma solidity 0.5.0;

library ArrayUtils {
    function removeElement(bytes32[] storage array, uint index) internal {
        if (index >= array.length) return;

        for (uint i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        delete array[array.length - 1];
        array.length--;
    }

    function findElement(bytes32[] storage array, bytes32 element) internal view returns (uint index, bool ok) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return (i, true);
            }
        }

        return (0, false);
    }
}