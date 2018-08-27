pragma solidity 0.4.24;


import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../access/Operable.sol";
import "./Timestamped.sol";


/**
* @title Escrow Smart Contract.
*/
contract Escrow is Operable, Timestamped {
    using SafeMath for uint256;

    /**
    * @dev Participant struct holds information about an escrow participant.
    */
    struct Participant {
        uint256 id;
        // Total amount of tokens to be released.
        uint256 totalTokens;
        // Amount of delivered tokens.
        uint256 deliveredTokens;
    }

    /**
    * @dev Event for add escrow participant operation logging
    * @param _wallet Participant address
    * @param _amount Amount allocated for the participant
    */
    event AddParticipantLog(address indexed _wallet, uint256 _amount);
    /**
    * @dev Event for delete escrow participant operation logging
    * @param _wallet Participant address
    */
    event DeleteParticipantLog(address indexed _wallet);
    /**
    * @dev Event for set activation date operation logging
    * @param _activationTimestamp Activation datetime
    */
    event ActivateLog(uint256 _activationTimestamp);

    // Time when tokens release process started.
    uint256 public activationTimestamp;

    // Default wallet address
    address public defaultWallet;
    // List of participants
    address[] public participantsList;
    // Participant details map.
    mapping (address => Participant) public participants;

    // Max number of participants supported by the contract
    uint256 public maxParticipantsCount = 50;    
    // Total amount of tokens alloted for all participants.
    uint256 public participantsTotal = 0;
    // Total amount of delivered tokens.
    uint256 public deliveredTotal = 0;

    // Total amount of tokens to release.
    ERC20 public token;
    // Number of intervals till total supply is released.
    uint256 public intervals;
    // Duration of one onterval.
    uint256 public intervalDuration;
    // Whether first interval should be included in intervals count.
    bool public includeFirst;

    constructor(
        address _owner,
        ERC20 _token,
        address _defaultWallet,
        uint256 _start,
        uint256 _intervals,
        uint256 _intervalDuration,
        bool _includeFirst
    ) public {
        require(_intervals > 0, "Invalid intervals count");
        require(_intervalDuration > 0, "Invalid interval duration");
        require(_token != address(0), "Invalid token address.");

        token = _token;

        setActivationDatetime(_start);

        intervals = _intervals;
        intervalDuration = _intervalDuration;
        includeFirst = _includeFirst;                

        require(_defaultWallet != address(0), "Invalid default wallet address.");
        defaultWallet = _defaultWallet;
        participants[defaultWallet] = Participant(0, 0, 0);
        participantsList.push(defaultWallet);

        require(_owner != address(0), "Invalid owner address.");
        addOperator(_owner);
        owner = _owner;
    }

    /**
     * @dev Require editable flag to be set.
     */
    modifier editableOnly {
        require(activationTimestamp == 0 || getTimestamp() < activationTimestamp, "Contract is not editable.");
        _;
    }

    /**
     * @dev Require editable flag to be set.
     */
    modifier activated {
        require(getTimestamp() >= activationTimestamp, "Contract is not activated.");
        _;
    }

    /**
     * @dev Require wallet address to differ from default wallet.
     */
    modifier validAddress(address _wallet) {
        require(_wallet != address(0), "Use deleteParticipant() to remove record.");
        require(_wallet != defaultWallet, "Address should differ from default wallet.");
        _;
    }    

    /**
     * @dev Require amount to be less or equal than total tokens supply.
     */
    modifier validAmount(uint256 _amount) {
        uint256 toolTokenBalance = token.balanceOf(address(this)) - participantsTotal;

        require (_amount <= toolTokenBalance, "Amount should be less or equal than total tokens supply.");
        _;
    }

    /**
    * @dev Get array of participants wallets.
    * @return Array of wallets.
    */
    function getParticipants() public view returns (address[]) {
        return participantsList;
    }


    /**
    * @dev Add participant to the list.
    * @param _wallet Participant address.
    * @param _amount Amount of token to release for that address.
    */
    function addParticipant(address _wallet, uint256 _amount)
        public
        hasOperatePermission
        editableOnly
        validAddress(_wallet)
        validAmount(_amount) {        
        require(participantsList.length + 1 <= maxParticipantsCount, "Max list length reached.");

        uint256 id = participants[_wallet].id;
        if (id == 0) {
            id = participantsList.length;
            participantsList.push(_wallet);
        }
        else {
            participantsTotal = participantsTotal.sub(participants[_wallet].totalTokens);
        }

        participants[_wallet] = Participant(id, _amount, 0);
        participantsTotal = participantsTotal.add(_amount);

        emit AddParticipantLog(_wallet, _amount);
    }

    /**
    * @dev Delete participant from the list.
    * @param _wallet ID of the participant.
    */
    function deleteParticipant(address _wallet)
    public
    hasOperatePermission
    editableOnly
    validAddress(_wallet)
    {
        uint256 id = participants[_wallet].id;
        if (id == 0) return;        

        participantsList[id] = participantsList[participantsList.length-1];            
        delete(participantsList[participantsList.length-1]);
        participantsList.length--;

        participantsTotal = participantsTotal.sub(participants[_wallet].totalTokens);
        participants[_wallet] = Participant(0, 0, 0);

        emit DeleteParticipantLog(_wallet);
    }

    /**
    * @dev Updates start date for release process
    * @param _start Release process start datetime
    */
    function setActivationDatetime(uint256 _start) public onlyOwner editableOnly {
        require(_start > getTimestamp(), "Invalid date.");

        activationTimestamp = _start;

        emit ActivateLog(activationTimestamp);             
    }

    /**
     * @dev Get released ttokens for given participant.
     * @param _wallet ID of the participant.
     * @return Amount of released for current time tokens.
     */
    function getReleasedTokens(address _wallet)
        public
        view
        activated
        returns (uint256 releasedTokens){
        uint256 intervalsPassed = SafeMath.sub(getTimestamp(), activationTimestamp).div(intervalDuration);

        if (intervalsPassed == 0 && !includeFirst) {
            return 0;
        }

        uint256 restTokens = 0;
        if (_wallet == defaultWallet) {
            restTokens = token.balanceOf(address(this))
            .add(deliveredTotal)
            .sub(participantsTotal);
        } else {
            restTokens = participants[_wallet].totalTokens;
        }

        intervalsPassed = includeFirst ? intervalsPassed.add(1) : intervalsPassed;
        if (intervalsPassed >= intervals) {
            return restTokens;
        }

        uint256 tokensPerInterval = restTokens.div(intervals);
        releasedTokens = tokensPerInterval.mul(intervalsPassed);

        return releasedTokens;
    }

    /**
     * @dev Get available tokens for given participant.
     * @param _wallet ID of the participant.
     * @return Amount of available to delivery tokens.
     */
    function getAvailableTokens(address _wallet)
        public
        view
        activated
        returns (uint256 availableTokens) {
        uint256 releasedTokens = getReleasedTokens(_wallet);
        availableTokens = releasedTokens.sub(participants[_wallet].deliveredTokens);
        return availableTokens;
    }

    /**
     * @dev Deliver available tokens to the participants wallets.
     */
    function deliver() external activated {
        for (uint256 id = 0; id < participantsList.length; id++) {
            address wallet = participantsList[id];
            uint256 availableTokens = getAvailableTokens(wallet);

            if (availableTokens > 0) {
                token.transfer(wallet, availableTokens);
                participants[wallet].deliveredTokens = participants[wallet].deliveredTokens.add(availableTokens);
                deliveredTotal = deliveredTotal.add(availableTokens);
            }
        }
    }     
}
