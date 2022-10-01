// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./Ownable.sol";

error Unauthorized();
error SenderInsufficientBalance(uint256 balance, uint256 minRequired);
error RecipientNameTooLong();
error AmountToSendTooLow(uint256 sent, uint256 minRequired);
error InvalidAmount(uint256 sent, uint256 minRequired);
error InvalidId(uint256 sent, uint256 minRequired);
error InvalidUserAddress(address userAddress);
error UserNotWhitelisted();
error InvalidUserTier(uint256 tier, uint256 maxAllowedTier);

contract GasContract {
    uint256 constant tradePercent = 12;

    uint256 public immutable totalSupply; // cannot be updated
    address[5] public administrators;

    uint256 private paymentCounter;
    address private contractOwner;
    bool private wasLastOdd = true;

    mapping(address => uint256) public whitelist;
    mapping(address => Payment[]) private payments;
    mapping(address => uint256) private balances;
    mapping(address => uint256) private isOddWhitelistUser;
    
    History[] private paymentHistory; // when a payment was updated
    
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        uint256 amount;
        string recipientName; // max 8 characters   - cannot optimize because of the tests
        address recipient;
        address admin; // administrators address
        bool adminUpdated;
    }

    struct History {
        uint256 lastUpdate;
        uint256 blockNumber;
        address updatedBy;
    }
    struct ImportantStruct {
        // cannot optimize with tight packing because of the test
        uint256 valueA; // max 3 digits
        uint256 bigValue;
        uint256 valueB; // max 3 digits
    }

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        onlyAdminOrOwnerLogic();
        _;
    }

    modifier checkIfWhiteListed() {
        checkIfWhiteListedLogic();
        _;
    }

    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[5] memory _admins, uint256 _totalSupply) {        
        contractOwner = msg.sender;
        totalSupply = _totalSupply;
        administrators = _admins;
        balances[contractOwner] = _totalSupply;    
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) external {
        if (balances[msg.sender] < _amount) {
            revert SenderInsufficientBalance(balances[msg.sender], _amount);
        }
        if (bytes(_name).length >= 9) {
            revert RecipientNameTooLong();
        }

        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;

        payments[msg.sender].push(Payment({
            paymentType: PaymentType.BasicPayment,
            paymentID: ++paymentCounter,
            amount: _amount,
            recipientName: _name,
            recipient: _recipient,
            admin: address(0),
            adminUpdated: false
        }));
        
        emit Transfer(_recipient, _amount);
    }

    function balanceOf(address _user) external view returns (uint256 balance_) {
        return balances[_user];
    }

    function addToWhitelist(address _userAddrs, uint8 _tier)
        external
        onlyAdminOrOwner
    {
        whitelist[_userAddrs] = _tier > 3 ? 3 : _tier;
        wasLastOdd = !wasLastOdd;
        isOddWhitelistUser[_userAddrs] = wasLastOdd ? 1 : 0;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct calldata _struct
    ) external 
      checkIfWhiteListed 
    {
        if (balances[msg.sender] < _amount) {
            revert SenderInsufficientBalance(balances[msg.sender], _amount);
        }
        if (_amount <= 3) {
            revert AmountToSendTooLow(_amount, 4);
        }
        uint256 total = _amount - whitelist[msg.sender]; 
        balances[msg.sender] -= total;
        balances[_recipient] += total;

        emit WhiteListTransfer(_recipient);
    }
    
    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) external onlyAdminOrOwner {
        if (_ID == 0) {
            revert InvalidId(_ID, 1);
        }
        if (_amount == 0) {
            revert InvalidAmount(_amount, 1);
        }
        if (_user == address(0)) {
            revert InvalidUserAddress(_user);
        }

        Payment[] storage userPayments = payments[_user];
        for (uint256 i = 0; i < userPayments.length; i++) {
            if (userPayments[i].paymentID == _ID) {
                userPayments[i].adminUpdated = true;
                userPayments[i].admin = _user;
                userPayments[i].paymentType = _type;
                userPayments[i].amount = _amount;

                addHistory(_user, getTradingMode());
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    userPayments[i].recipientName
                );
                break;
            }
        }
    }

    function getPayments(address _user)
        external
        view
        returns (Payment[] memory payments_)
    {
        if (_user == address(0)) {
            revert InvalidUserAddress(_user);
        }
        return payments[_user];
    }
    
    function getTradingMode() public pure returns (bool mode_) {
        return true;
    }

    function onlyAdminOrOwnerLogic() private view {
        if (msg.sender != contractOwner || !checkForAdmin(msg.sender)) {
            revert Unauthorized();
        }
    }

    function checkIfWhiteListedLogic() private view {
        uint256 usersTier = whitelist[msg.sender];
        if (usersTier == 0) {
            revert UserNotWhitelisted();
        }
        if (usersTier > 3) {
            revert InvalidUserTier(usersTier, 3);
        }
    }
    
    function addHistory(address _updateAddress, bool _tradeMode)
        private
        returns (bool status_, bool tradeMode_)
    {
        paymentHistory.push(History(block.timestamp, block.number, _updateAddress));
        return (true, _tradeMode);
    }

    function checkForAdmin(address _user) private view returns (bool admin_) {
        address[5] memory administratorsTemp = administrators;
        for (uint256 i = 0; i < administratorsTemp.length; i++) {
            if (administratorsTemp[i] == _user) {
                return true;
            }
        }
        return false;
    }    
}
