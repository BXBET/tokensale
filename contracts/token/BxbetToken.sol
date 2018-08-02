pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/BurnableToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/DetailedERC20.sol";
import "openzeppelin-solidity/contracts/ownership/HasNoEther.sol";
import "../access/Operable.sol";

/**
* @title ERC20Token
* @dev The ERC20Token is a ERC20 token implementation
*/
contract BxbetToken is BurnableToken, StandardToken, DetailedERC20, HasNoEther, Operable {
    using SafeMath for uint256;

    //initially tokens locked for any transfers
    bool public isLocked;

    address public saleWallet;
    address public bountyWallet;
    address public reserveWallet;
    address public teamWallet;
    address public advisorWallet;

    constructor (address _saleWallet,
                 address _bountyWallet,
                 address _reserveWallet,
                 address _teamWallet,
                 address _advisorWallet,
                 address _owner)
        DetailedERC20("BX BET", "BX", 18) public {

        isLocked = true;        

        configureWallet(_saleWallet, uint256(120000000).mul(10 ** 18));
        saleWallet = _saleWallet;
        configureWallet(_bountyWallet, uint256(10000000).mul(10 ** 18));
        bountyWallet = _bountyWallet;
        configureWallet(_reserveWallet, uint256(30000000).mul(10 ** 18));
        reserveWallet = _reserveWallet;
        configureWallet(_teamWallet, uint256(20000000).mul(10 ** 18));
        teamWallet = _teamWallet;
        configureWallet(_advisorWallet, uint256(20000000).mul(10 ** 18));
        advisorWallet = _advisorWallet;

        require(_owner != address(0));
        owner = _owner;
    }   

    /**
    * @dev Applies only during lock interval. Reverts in case account is not Operator role
    */
    modifier hasOperatePermission() {
        if (isLocked) {
            require(hasRole(msg.sender, ROLE_OPERATOR));
        }
        _;
    }

    /**
    * @dev Allows token manipulations (transfer, burn, etc.)
    */
    function activate() onlyOwner public {
        isLocked = false;
    }

    function transfer(address _to, uint256 _value) public hasOperatePermission returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public hasOperatePermission returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public hasOperatePermission returns (bool) {
        return super.approve(_spender, _value);
    }

    function increaseApproval(address _spender, uint _addedValue) public hasOperatePermission returns (bool success) {
        return super.increaseApproval(_spender, _addedValue);
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public hasOperatePermission returns (bool success) {
        return super.decreaseApproval(_spender, _subtractedValue);
    }

    function burn(uint256 _value) public hasOperatePermission {
        super.burn(_value);
    }

    /**
    * @dev Peforms basic configuration and tokens distribution for a pre-defined wallet
    * @param _wallet address to configure
    * @param _amount tokens to distribute
    */
    function configureWallet(address _wallet, uint256 _amount) private {
        require(_wallet != address(0));

        addOperator(_wallet); 
        totalSupply_ = totalSupply_.add(_amount);       
        balances[_wallet] = _amount;
        emit Transfer(address(0), _wallet, _amount);
    }
}