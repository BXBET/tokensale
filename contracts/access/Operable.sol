pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/ownership/rbac/RBAC.sol";

/**
* @title Operable
* @dev Adds operator role to SC functionality
*/
contract Operable is Ownable, RBAC {
    // role key
    string public constant ROLE_OPERATOR = "operator";

    /**
    * @dev Reverts in case account is not Operator role
    */
    modifier hasOperatePermission() {
        require(hasRole(msg.sender, ROLE_OPERATOR));
        _;
    }

    /**
    * @dev Reverts in case account is not Owner or Operator role
    */
    modifier hasOwnerOrOperatePermission() {
        require(msg.sender == owner || hasRole(msg.sender, ROLE_OPERATOR));
        _;
    }

    /**
    * @dev Method to add accounts with Operator role
    * @param _operator address that will receive Operator role access
    */
    function addOperator(address _operator) onlyOwner public {
        addRole(_operator, ROLE_OPERATOR);
    }

    /**
    * @dev Method to remove accounts with Operator role
    * @param _operator address that will loose Operator role access
    */
    function removeOperator(address _operator) onlyOwner public {
        removeRole(_operator, ROLE_OPERATOR);
    }
}