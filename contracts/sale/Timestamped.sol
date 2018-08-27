pragma solidity 0.4.24;

/**
* @title Timestamped
* @dev The Timestamped contract has a separate method for receiving current timestamp.
* This simplifies derived contracts testability.
*/
contract Timestamped {
    /**
    * @dev Returns current timestamp.
    */
    function getTimestamp() internal view returns(uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}