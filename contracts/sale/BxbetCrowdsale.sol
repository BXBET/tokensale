pragma solidity 0.4.24;


import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../access/Whitelist.sol";
import "../token/BxbetToken.sol";
import "./SaleStrategy.sol";
import "./ReferralStrategy.sol";
import "./Escrow.sol";


/**
* @title BxbetCrowdsale
* @dev The BxbetCrowdsale is a crowdsale contract for BxbetToken token.
*/
contract BxbetCrowdsale is Pausable, Whitelist {
    using SafeMath for uint256;

    // The token being sold
    BxbetToken public token;
    // Refferal rules contract
    ReferralStrategy public referralStrategy;
    // Price rules contract
    SaleStrategy public saleStrategy;
    // Escrow contract for team tokens
    Escrow public teamEscrow;
    // Escrow contract for advisor tokens
    Escrow public advisorEscrow;
    // Address where collected funds should be transferred
    address public etherHolder;    

    // Token price in USD (18 decimals supported)
    uint256 public priceInUSD = uint256(19).mul(10 ** 16);
    // Hard cap in USD (18 decimals supported)
    uint256 public hardCapUSD = uint256(20000000).mul(10 ** 18);
    // Accumulates amount of raised funds in USD (18 decimals supported)
    uint256 public fundsRaised;

    // ETH rate in USD (18 decimals supported)
    uint256 public rateETHtoUSD;
    // BTC rate in USD (18 decimals supported)
    uint256 public rateBTCtoUSD;

    // Accumulates amount of sold tokens
    uint256 public tokensSold;    
    // Accumulates amount of investors
    uint256 public totalInvestors;
    // List of investors
    address[] public investors;
    // Token sales details
    mapping (address => uint256) public tokenSales;

    /**
    * Event for ETH to USD rate changes logging
    * @param newRate new rate value
    */
    event RateChangedLog(uint256 newRate);

    /**
    * @dev Event for token purchase logging
    * @param investmentType BTC or ETH investment
    * @param beneficiary Who got the tokens
    * @param value Weis paid
    * @param tokens Amount of tokens received
    * @param bonuses Amount of bonus tokens received
    */
    event TokensPurchaseLog(string investmentType, address indexed beneficiary, uint256 value, uint256 tokens, uint256 bonuses);

    /**
    * @dev Event for referral bonuses operation logging
    * @param ownerAddress Referral source owner (0 in case of banner)
    * @param ownerBonus Amount of bonus tokens for referral source owner (0 in case of banner)
    * @param newAddress Referral source based new account
    * @param newBonus Amount of bonus tokens for an account created from referral source
    */
    event RefferalBonusLog(address indexed ownerAddress, uint256 ownerBonus, address newAddress, uint256 newBonus);

    /**
    * @param _rateETHtoUSD Cost of ETH in USD
    * @param _etherHolder Address where collected funds will be forwarded to
    * @param _token Address of the token being sold
    */
    constructor(
        uint256 _rateETHtoUSD, 
        address _etherHolder, 
        BxbetToken _token, 
        ReferralStrategy _referralStrategy,
        SaleStrategy _saleStrategy,
        Escrow _teamEscrow,
        Escrow _advisorEscrow) public {
        setETHtoUSDrate(_rateETHtoUSD); 

        require(_referralStrategy != address(0), "Invalid referral strategy address.");
        require(_saleStrategy != address(0), "Invalid sale strategy address.");
        require(_teamEscrow != address(0), "Team escrow address can not be empty.");
        require(_advisorEscrow != address(0), "Advisor escrow address can not be empty.");        
        require(_token != address(0), "Token address can not be empty.");
        require(_etherHolder != address(0), "Wallet for raised funds can not be empty.");
               
        referralStrategy = _referralStrategy;        
        saleStrategy = _saleStrategy;        
        teamEscrow = _teamEscrow;       
        advisorEscrow = _advisorEscrow;        
        token = _token;
        etherHolder = _etherHolder;       
    }    

    /**
    * @dev Accepts investments to the contract, calculates and distributes tokens.
    */
    function() external payable {
        require(msg.data.length == 0, "Should not accept data.");
        _buyTokens(msg.sender, msg.value, "ETH");
    }

    /**
    * @dev low level token purchase ***DO NOT OVERRIDE***
    * @param _beneficiary Address performing the token purchase
    */
    function buyTokens(address _beneficiary) external payable {
        _buyTokens(_beneficiary, msg.value, "ETH");
    }

    /**
    * @dev Performs tokens distribution to ETH investor. Available to the owner only
    * @param _beneficiary wallet address that tokens should be distributed to
    * @param _ethAmount value that was invested in ETH (should support 18 decimals, so 1 BTC = 1 * 10 ^ 18)
    * @param _type Type of investment channel
    */
    function distributeTokensForInvestment(address _beneficiary, uint256 _ethAmount, string _type) external hasOwnerOrOperatePermission {
        _buyTokens(_beneficiary, _ethAmount, _type);        
    }

    /**
    * @dev Performs manual tokens distribution investor. Available to the owner only
    * @param _beneficiary wallet address that tokens should be distributed to
    * @param _tokensAmount number of tokens that should be delivered to a recipient (should support 18 decimals, so 1 BX = 1 * 10 ^ 18)
    */
    function distributeTokensManual(address _beneficiary, uint256 _tokensAmount) external onlyOwner {
        _preValidatePurchase(_beneficiary, _tokensAmount);

        _deliverTokens(_beneficiary, _tokensAmount);
        emit TokensPurchaseLog("MANUAL", _beneficiary, 0, _tokensAmount, 0);
    }

    /**
    * @dev Registers new referral link in the referral system
    * @param _linkOwner account that is defined as referral link owner and referral source id
    * @param _baseBonus bonus size that all new accounts will receive during registration
    * @param _selfBonus bonus size that referral owner will receive for each new registered user
    */
    function setReferralLink(address _linkOwner, uint256 _baseBonus, uint256 _selfBonus) external hasOwnerOrOperatePermission {
        referralStrategy.setLink(_linkOwner, _baseBonus, _selfBonus);
    }

    /**
    * @dev Adds new account that is registered using referral link
    * @param _linkOwner referral link owner account
    * @param _linkNew new registered account
    */
    function addReferralLinkInvite(address _linkOwner, address _linkNew) external hasOwnerOrOperatePermission {
        referralStrategy.addLinkInvite(_linkOwner, _linkNew);
    }

    /**
    * @dev Registers new referral banner in the referral system
    * @param _bannerId identifier that is used as referral source id
    * @param _baseBonus bonus size that all new accounts will receive during registration
    */
    function setReferralBanner(string _bannerId, uint256 _baseBonus) external hasOwnerOrOperatePermission {
        referralStrategy.setBanner(_bannerId, _baseBonus);
    }

    /**
    * @dev Adds new account that is registered using referral banner
    * @param _bannerId referral banner source id
    * @param _bannerNew new registered account
    */
    function addReferralBannerInvite(string _bannerId, address _bannerNew) external hasOwnerOrOperatePermission {
        referralStrategy.addBannerInvite(_bannerId, _bannerNew);
    }
   
    /**
    * @dev Burns all unsold tokens
    */
    function burnTokens() external {
        require(!saleStrategy.isOpen(), "Can not burn while crowdsale is active.");
        uint256 amount = token.balanceOf(this);
        token.burn(amount);
    }

    /**
    * @dev Updates start date for the sale and related contracts
    * @param _start Sale start datetime
    */
    function setNextStage(uint256 _start, uint256 _length) public onlyOwner {
        uint256 endDatetime = saleStrategy.configureNextStage(_start, _length);
        teamEscrow.setActivationDatetime(endDatetime);
        advisorEscrow.setActivationDatetime(endDatetime);      
    }

    /**
    * @dev Updates ETH to USD rate. Allowed only for contract owner.
    * @param _rateETHtoUSD Cost of ETH in USD
    */
    function setETHtoUSDrate(uint256 _rateETHtoUSD) public hasOwnerOrOperatePermission {
        require(_rateETHtoUSD > 0, "Rate can not be set to 0.");
        rateETHtoUSD = _rateETHtoUSD;
        emit RateChangedLog(rateETHtoUSD);
    }       

    /**
    * @dev Performs buy operation which includes:
    *   - investor validations
    *   - sale state validation
    *   - token amounts calculations and tokens distribution
    * @param _beneficiary wallet address that tokens should be distributed to
    * @param _value value that was invested wei
    * @param _investmentType type of investment (ETH, BTC, FIAT)
    */
    function _buyTokens(address _beneficiary, uint256 _value, string _investmentType) private {
        _preValidatePurchase(_beneficiary, _value);

        uint256 investmentInUSD = _value.mul(rateETHtoUSD).div(10 ** 18);

        require(hardCapUSD >= fundsRaised.add(investmentInUSD), "Crowdsale hard cap reached.");

        fundsRaised = fundsRaised.add(investmentInUSD);

        (uint256 tokenAmount, uint256 mainBonus) = saleStrategy.getTokenAmounts(investmentInUSD, priceInUSD, tokensSold);
        _processPurchase(_investmentType, _beneficiary, _value, tokenAmount, mainBonus);

        (address refOwner, uint256 ownerBonus, address refNew, uint256 newBonus) = referralStrategy.getReferralBonuses(_beneficiary, tokenAmount);
        _processRefferals(refOwner, ownerBonus, refNew, newBonus);
    }

    /**
    * @dev Executed when a purchase has been validated and is ready to be executed.
    * @param _investmentType type of investment (ETH, BTC, USD)
    * @param _beneficiary Address receiving the tokens
    * @param _value value that was invested wei
    * @param _tokens Number of tokens to be purchased
    * @param _bonuses Number of tokens for a bonus
    */
    function _processPurchase(string _investmentType, address _beneficiary, uint256 _value, uint256 _tokens, uint256 _bonuses) private {
        uint256 totalAmount = _tokens.add(_bonuses);       
        _deliverTokens(_beneficiary, totalAmount);
        _forwardFunds();
        emit TokensPurchaseLog(_investmentType, _beneficiary, _value, _tokens, _bonuses);
    }

    /**
    * @dev Executed when referral system is involved into purchase.
    * @param _owner Refferal source owner address
    * @param _ownerBonus Number of tokens to be delivered to the referral source owner
    * @param _new Account created from referral source
    * @param _newBonus Number of tokens to be delivered to the account created from referral source
    */
    function _processRefferals(address _owner, uint256 _ownerBonus, address _new, uint256 _newBonus) private {
        bool emitEvent = false;

        if (_ownerBonus > 0) {        
            _deliverTokens(_owner, _ownerBonus);
            emitEvent = true;
        }
        if (_newBonus > 0) {
            _deliverTokens(_new, _newBonus);
            emitEvent = true;
        }

        if (emitEvent) {
            emit RefferalBonusLog(_owner, _ownerBonus, _new, _newBonus);
        }
    }

    /**
    * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
    * @param _beneficiary Address performing the token purchase
    * @param _totalAmount Number of tokens to be delivered
    */
    function _deliverTokens(address _beneficiary, uint256 _totalAmount) private {
        if (tokenSales[_beneficiary] == 0) {
            investors.push(_beneficiary);
            totalInvestors = totalInvestors.add(1);
        }
        
        tokensSold = tokensSold.add(_totalAmount);

        tokenSales[_beneficiary] = tokenSales[_beneficiary].add(_totalAmount);       
    }

    /**
    * @dev Determines how ETH is stored/forwarded on purchases.
    */
    function _forwardFunds() private {
        etherHolder.transfer(msg.value);
    }

    /**
    * @dev Validation of an incoming purchase.
    * @param _beneficiary Address performing the token purchase
    * @param _value Value in wei involved in the purchase
    */
    function _preValidatePurchase(address _beneficiary, uint256 _value) private whenNotPaused onlyIfWhitelisted(_beneficiary) view {
        require(_beneficiary != address(0), "Can not accept an investment from 0 adress.");
        require(_value > 0, "Can not process 0 value investment.");
        require(saleStrategy.isOpen(), "Can not accep an investment as crowdsale is not active.");
    }  
}