pragma solidity 0.4.24;


import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract ReferralStrategy is Ownable {
    using SafeMath for uint256;

    // Referral banner bonus for new users details
    mapping(string => uint256) private bannerNewBonuses;
    // Referral banner invited users
    mapping(address => string) private bannerInvites;    

    // Referral link bonus for link owner details
    mapping(address => uint256) private linkOwnerBonuses;
    // Referral link bonus for new users details
    mapping(address => uint256) private linkNewBonuses;
    // Referral link invited users
    mapping(address => address) private linkInvites;    

    /**
    * Event for logging new refferal link owner
    * @param linkOwner referral link owner address
    * @param baseBonus bonus size that invited uses will receive
    * @param selfBonus bonus size that each invited user will bring
    */
    event LinkSetLog(address indexed linkOwner, uint256 baseBonus, uint256 selfBonus);

    /**
    * Event for logging new referral banner id
    * @param bannerId referral banner id
    * @param baseBonus bonus size that invited uses will receive
    */
    event BannerSetLog(string bannerId, uint256 baseBonus);

    /**
    * Event for logging new accounts registerred usin referral link
    * @param linkOwner referral link owner address
    * @param linkNew account that user referral link for registration
    */
    event InviteByLinkLog(address indexed linkOwner, address indexed linkNew);

    /**
    * Event for logging new accounts registerred usin referral link
    * @param bannerId referral banner id
    * @param bannerNew account that user referral banner for registration
    */
    event InviteByBannerLog(string bannerId, address indexed bannerNew); 

    /**
    * @dev Registers new referral link in the referral system
    * @param _linkOwner account that is defined as referral owner and referral source id
    * @param _baseBonus bonus size that all new accounts will receive during registration
    * @param _selfBonus bonus size that referral owner will receive for each new registered user
    */
    function setLink(address _linkOwner, uint256 _baseBonus, uint256 _selfBonus) external onlyOwner {
        require(_linkOwner != address(0), "Referral link should have an owner.");

        linkNewBonuses[_linkOwner] = _baseBonus;
        linkOwnerBonuses[_linkOwner] = _selfBonus;
        emit LinkSetLog(_linkOwner, _baseBonus, _selfBonus);
    }

    /**
    * @dev Adds new account that is registered using referral link
    * @param _linkOwner referral link owner account
    * @param _linkNew new registered account
    */
    function addLinkInvite(address _linkOwner, address _linkNew) external onlyOwner {
        require(_linkOwner != address(0), "Link invite can not be connected to an empty address.");
        require(_linkNew != address(0), "Link invite can not be applied to an empty address.");

        linkInvites[_linkNew] = _linkOwner;
        emit InviteByLinkLog(_linkOwner, _linkNew);
    }

    /**
    * @dev Registers new referral banner in the referral system
    * @param _bannerId identifier that is used as referral source id
    * @param _baseBonus bonus size that all new accounts will receive during registration
    */
    function setBanner(string _bannerId, uint256 _baseBonus) external onlyOwner {
        require(bytes(_bannerId).length > 0, "Referral banner should have an id.");

        bannerNewBonuses[_bannerId] = _baseBonus;
        emit BannerSetLog(_bannerId, _baseBonus);
    }

    /**
    * @dev Adds new account that is registered using referral banner
    * @param _bannerId referral banner source id
    * @param _bannerNew new registered account
    */
    function addBannerInvite(string _bannerId, address _bannerNew) external onlyOwner {
        require(bytes(_bannerId).length > 0, "Banner invite can not be connected to an empty id.");
        require(_bannerNew != address(0), "Banner invite can not be applied to an empty address.");

        bannerInvites[_bannerNew] = _bannerId;
        emit InviteByBannerLog(_bannerId, _bannerNew);
    } 

    /**
    * @dev Receives information on referral bonuses 
    * @param _buyer accoun that makes an investment
    * @param _tokens amount of tokens that the account bought
    */
    function getReferralBonuses(address _buyer, uint256 _tokens) 
        public view returns(address refOwner, uint256 ownerBonus, address refNew, uint256 newBonus) {
        require(_buyer != address(0), "Bonus tokens can not be received by empty address.");

        if (linkInvites[_buyer] != address(0)) {
            address linkOwner = linkInvites[_buyer];

            uint256 ownerBonusValue = linkOwnerBonuses[linkOwner];
            ownerBonus = _tokens.mul(ownerBonusValue).div(10 ** 4);
            refOwner = linkOwner;

            uint256 newBonusValue = linkNewBonuses[linkOwner];
            newBonus = _tokens.mul(newBonusValue).div(10 ** 4);
            refNew = _buyer;
        } else if (bytes(bannerInvites[_buyer]).length != 0) {
            string memory bannerId = bannerInvites[_buyer];

            uint256 bannerNewBonusValue = bannerNewBonuses[bannerId];
            newBonus = _tokens.mul(bannerNewBonusValue).div(10 ** 4);
            refNew = _buyer;
        }
    }    
}