pragma solidity 0.4.24;


import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Timestamped.sol";

/**
* @title SaleStrategy
* @dev The SaleStrategy is a contract that defines price and bonuses strategy for Bxbet token crowdsale.
* The contract has an owner defined (should be Bxbet crowdsale smart contract)
*/
contract SaleStrategy is Ownable, Timestamped {
    using SafeMath for uint256;    
 
    /**
    * Describes stage structure fields
    * @param id stage id to differ stages
    * @param start stage start date
    * @param end stage end date
    * @param minInvestment minimal investment accepted by SC during the stage
    * @param supply total tokens available for the stage
    */
    struct Stage {
        uint256 id;
        uint256 minInvestment;
        uint256 supply;
        uint256 start;
        uint256 end;        
    }

    // Array of stages supported by SC
    Stage[] public stages;

    /**
    * Describes bonus parameters
    * @param stageId stage that bonuses should work for
    * @param limit threshold value for changing bonus value
    * @param bonus bonus size
    */ 
    struct VolumeBonus {
        uint256 stageId;
        uint256 limit;
        uint256 bonus;
    }

    // Array of bonuses supported by SC
    VolumeBonus[] public bonuses;
    // Pre-sale stage start datetime
    uint256 public presaleStart;
    // Pre-sale stage length
    uint256 public presaleInterval;
    // Sale stage start datetime
    uint256 public saleStart;
    // Sale stage start datetime
    uint256 public saleInterval;

    /**
    * @param _start Crowdsale presale stage start date
    * @param _presaleInterval Crowdsale presale stage length
    * @param _saleInterval Crowdsale sale stage length
    */
    constructor(uint256 _start, uint256 _presaleInterval, uint256 _saleInterval) public {
        _setStages(_start, _presaleInterval, _saleInterval);
        _setBonuses();
    }

    /**
    * @dev Checks if crowdsale is in active state
    * @return Flag identifying crowdsale state
    */
    function isOpen() external view returns(bool) {
        return getTimestamp() <= saleStart + saleInterval;
    }
    
    /**
    * @dev Configures next stage parameters based on provided start date and length
    * @param _start Stage start datetime
    * @param _interval Stage length
    * @return End date for crowdsale
    */
    function configureNextStage(uint256 _start, uint256 _interval) external onlyOwner returns(uint256) {
        require(_start > getTimestamp() && getTimestamp() < saleStart && _interval > 0, "Active stage can not be configurred");
        if (getTimestamp() < presaleStart) {
            presaleStart = _start;
            presaleInterval = _interval;
            saleStart = _start + _interval;

            Stage memory privateStage = stages[0];
            Stage memory presaleStage = stages[1];
           
            privateStage.end = presaleStart;
            stages[0] = privateStage;
            
            presaleStage.start = presaleStart;
            presaleStage.end = presaleStart + presaleInterval;
            stages[1] = presaleStage;
        } else {
            saleStart = _start;
            saleInterval = _interval;            
        }

        Stage memory saleStage = stages[2];
        saleStage.start = saleStart;
        saleStage.end = saleStart + saleInterval;
        stages[2] = saleStage;

        return saleStart + saleInterval;
    }    

    /**
    * @dev Calculates tokens amount and bonus tokens amount based on investment value, current stage and bonus rules
    * @param _usd Investment value in USD
    * @param _rate Token rate
    * @param _sold Number of tokens sold by the moment
    * @return Amount of tokens for main and bonus parts
    */
    function getTokenAmounts(uint256 _usd, uint256 _rate, uint256 _sold) public view returns (uint256 tokens, uint256 bonus) { 
        bonus = 0;

        require(_rate > 0, "Rate value can not be equal to 0.");

        Stage memory currentStage = _getCurrentStage();
        require(currentStage.id > 0 && currentStage.minInvestment > 0 && currentStage.supply > 0, "Stage configuration was not found.");        
        
        require(_usd >= currentStage.minInvestment, "Invested value can not be less than minimum investment level.");
        tokens = _usd.div(_rate).mul(10 ** 18);
        
        uint256 bonusSize = _getCurrentBonus(currentStage.id, _usd);
        bonus = tokens.mul(bonusSize).div(10 ** 4);        
        
        require(currentStage.supply >= _sold.add(tokens).add(bonus), "Amount of sold tokens can not exceed defined stage volume.");        
    }

    /**
    * @dev Configures crowdsale bonuses
    */
    function _setBonuses() private {
        bonuses.push(VolumeBonus(1, uint256(5000).mul(10 ** 18), 4000));
        bonuses.push(VolumeBonus(2, uint256(300).mul(10 ** 18), 1250));
        bonuses.push(VolumeBonus(2, uint256(2000).mul(10 ** 18), 2000));
        bonuses.push(VolumeBonus(2, uint256(15000).mul(10 ** 18), 3000));
        bonuses.push(VolumeBonus(3, uint256(250).mul(10 ** 18), 500));
        bonuses.push(VolumeBonus(3, uint256(500).mul(10 ** 18), 1000));
        bonuses.push(VolumeBonus(3, uint256(2500).mul(10 ** 18), 1250));
    }

    /**
    * @dev Configures crowdsale stages based on provided start date and stage intervals
    * @param _start Stage start datetime
    * @param _presaleInterval Pre-sale stage length
    * @param _saleInterval Sale stage length
    */
    function _setStages(uint256 _start, uint256 _presaleInterval, uint256 _saleInterval) private {
        require(_start > getTimestamp() && _presaleInterval > 0 && _saleInterval > 0, "Incorrect stage configuration.");

        presaleStart = _start;
        presaleInterval = _presaleInterval;
        saleStart = _start + _presaleInterval;
        saleInterval = _saleInterval;

        stages.push(Stage(
            1, 
            uint256(5000).mul(10 ** 18), 
            uint256(15000000).mul(10 ** 18), 
            getTimestamp(), presaleStart)
        );
        stages.push(Stage(
            2, 
            uint256(300).mul(10 ** 18), 
            uint256(55500000).mul(10 ** 18), 
            presaleStart, 
            presaleStart + presaleInterval)
        );
        stages.push(Stage(
            3, 
            uint256(100).mul(10 ** 18), 
            uint256(120000000).mul(10 ** 18), 
            saleStart, 
            saleStart + saleInterval)
        );
    }    

    /**
    * @dev Finds current stage parameters according to the rules and current date and time
    * @return Current stage parameters (available volume of tokens and price in USD)
    */
    function _getCurrentStage() private view returns (Stage) {
        uint256 index = 0;
        uint256 time = getTimestamp();        

        Stage memory result;

        while (index < stages.length) {
            Stage memory activeStage = stages[index];

            if ((time >= activeStage.start && time < activeStage.end)) {
                result = activeStage;
            }

            index++;             
        }

        return result;
    }

    /**
    * @dev Finds current bonus value according to bonus rules and invested value
    * @return Current bonus size
    */
    function _getCurrentBonus(uint256 _stageId, uint256 _amount) private view returns (uint256) {
        uint256 bonus = 0;
        uint256 index = 0;

        while (index < bonuses.length && (bonuses[index].stageId != _stageId || _amount >= bonuses[index].limit)) {
            if (bonuses[index].stageId == _stageId) {
                bonus = bonuses[index].bonus;
            }
            index++;
        }
        return bonus;
    }
}