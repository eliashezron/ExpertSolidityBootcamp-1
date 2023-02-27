// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./Ownable.sol";

contract Constants {
    uint256 constant tradeFlag = 1;
    // uint256 private basicFlag;
    uint256 constant dividendFlag = 1;
}

contract GasContract is Ownable, Constants {
    uint256 public totalSupply; // cannot be updated
    uint256 private paymentCounter;
    uint256 private wasLastOdd = 1;

    address private contractOwner;
    // bool private isReady;
    // address[5] public administrators;
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }
    PaymentType constant defaultPayment = PaymentType.Unknown;

    struct Payment {
        uint256 paymentID;
        uint256 amount;
        bool adminUpdated;
        PaymentType paymentType;
        address recipient;
        address admin; // administrators address
        string recipientName; // max 8 characters
    }

    // struct History {
    //     address updatedBy;
    //     uint256 lastUpdate;
    //     uint256 blockNumber;
    // }
    // History[] public paymentHistory; // when a payment was updated

    // mapping(address)

    struct ImportantStruct {
        uint256 valueA; // max 3 digits
        uint256 valueB; // max 3 digits
        uint256 bigValue;
    }
    mapping(address => bool) private isAdmin;
    mapping(uint256 => address) public administrators;
    mapping(address => uint256) private isOddWhitelistUser;
    mapping(address => uint256) private balances;
    mapping(address => uint256) public whitelist;
    mapping(address => Payment[]) private payments;
    mapping(address => ImportantStruct) private whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);
    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );

    error InvalidAddress(address addr, string message);
    error InvalidEntry(uint256 amt, string message);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        for (uint256 ii; ii < 5; ) {
            if (_admins[ii] == address(0)) {
                revert InvalidAddress(_admins[ii], "Invalid address");
            }
            administrators[ii] = _admins[ii];
            isAdmin[_admins[ii]] = true;
            emit supplyChanged(_admins[ii], 0);
            unchecked {
                ++ii;
            }
        }

        balances[msg.sender] = totalSupply;
        emit supplyChanged(msg.sender, totalSupply);
    }

    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        if (!isAdmin[senderOfTx] || senderOfTx != contractOwner) {
            revert InvalidAddress(senderOfTx, "Caller not admin");
        }
        _;
    }

    modifier checkIfWhiteListed(address sender) {
        address senderOfTx = msg.sender;
        uint256 usersTier = whitelist[senderOfTx];
        if (senderOfTx != sender || usersTier < 0 || usersTier > 4) {
            revert InvalidAddress(senderOfTx, "Invalid address");
        }
        _;
    }

    // function getPaymentHistory()
    //     external
    //     payable
    //     returns (History[] memory paymentHistory_)
    // {
    //     return paymentHistory;
    // }

    // function checkForAdmin(address _user) public view returns (bool) {
    //     return isAdmin[_user];
    // }

    function balanceOf(address _user) external view returns (uint256 balance_) {
        // uint256 balance = balances[_user];
        return balances[_user];
    }

    function getTradingMode() external pure returns (bool) {
        // bool mode;
        // (tradeFlag == 1 || dividendFlag == 1) ? mode = true : mode = false;
        return true;
    }

    // function addHistory(address _updateAddress) public returns (bool) {
    //     History memory history;
    //     history.blockNumber = block.number;
    //     history.lastUpdate = block.timestamp;
    //     history.updatedBy = _updateAddress;
    //     paymentHistory.push(history);

    //     return (true);
    // }

    function getPayments(address _user)
        external
        view
        returns (Payment[] memory payments_)
    {
        if (_user == address(0)) {
            revert InvalidAddress(_user, "Invalid address");
        }
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) external returns (bool status_) {
        address senderOfTx = msg.sender;
        if (balances[senderOfTx] < _amount) {
            revert InvalidEntry(_amount, "insufficient Balance");
        }
        if (bytes(_name).length > 9) {
            revert InvalidEntry(bytes(_name).length, "long name");
        }
        balances[senderOfTx] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);

        Payment memory payment;
        payment.admin = address(0);
        payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = _name;
        payment.paymentID = ++paymentCounter;
        payments[senderOfTx].push(payment);

        return true;
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) external onlyAdminOrOwner {
        if (_ID < 0) {
            revert InvalidEntry(_ID, "invalid entry");
        }
        if (_amount < 0) {
            revert InvalidEntry(_amount, "invalid entry");
        }
        if (_user == address(0)) {
            revert InvalidAddress(_user, "invalid entry");
        }

        // address senderOfTx = msg.sender;
        uint256 len = payments[_user].length;

        for (uint256 ii; ii < len; ) {
            if (payments[_user][ii].paymentID == _ID) {
                payments[_user][ii].adminUpdated = true;
                payments[_user][ii].admin = _user;
                payments[_user][ii].paymentType = _type;
                payments[_user][ii].amount = _amount;
                // bool tradingMode = getTradingMode();
                // addHistory(_user);
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    payments[_user][ii].recipientName
                );
            }
            unchecked {
                ++ii;
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier)
        external
        onlyAdminOrOwner
    {
        if (_tier > 255) {
            revert InvalidEntry(_tier, "tier lessthan 255");
        }
        whitelist[_userAddrs] = _tier;
        if (_tier > 3) {
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1) {
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3) {
            whitelist[_userAddrs] = 2;
        }
        uint256 wasLastAddedOdd = wasLastOdd;
        isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        (wasLastAddedOdd == 1) ? wasLastOdd = 0 : wasLastOdd = 1;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct memory _struct
    ) external checkIfWhiteListed(msg.sender) {
        address senderOfTx = msg.sender;
        if (balances[senderOfTx] < _amount || _amount < 3) {
            revert InvalidEntry(_amount, "insuffienct amount");
        }
        balances[senderOfTx] -= _amount;
        balances[_recipient] += _amount;
        balances[senderOfTx] += whitelist[senderOfTx];
        balances[_recipient] -= whitelist[senderOfTx];

        // whiteListStruct[senderOfTx] = ImportantStruct(0, 0, 0);
        ImportantStruct storage newImportantStruct = whiteListStruct[
            senderOfTx
        ];
        newImportantStruct.valueA = _struct.valueA;
        newImportantStruct.bigValue = _struct.bigValue;
        newImportantStruct.valueB = _struct.valueB;
        emit WhiteListTransfer(_recipient);
    }
}
