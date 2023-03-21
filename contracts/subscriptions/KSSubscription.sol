//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../utils/SafeERC20.sol";

/**
    @author Praxxas DeFi
    @title KS Subscription Smart Contract
*/
contract KSSubscription {
    using SafeERC20 for IERC20;

    // Events ------

        /// New Subscriber
        event NewSubscriber(address subscriber_, uint256 duration_);

        /// Emit an event
        event EmitEvent(string result);

    // Variables ------

        /// @notice Owner of the contract
        address public _owner;

        /// @notice Recipient of paid subscriptions
        address public _recipient;

        /// Global reEntrancy check
        bool private _reEntrancyProtect = false;

        /// @notice Total subscription options added
        uint public _totalSubscriptionOptions = 0;
        struct SubscriptionOptions {
            uint id;
            string title;
            uint amount;
            uint duration;
            address tokenPaymentAddress;
            bool isValid;
        }
        /// @notice Different subscription tiers available
        mapping(uint => SubscriptionOptions) public _subscriptionOptions;

        /// @notice Total subscriptions
        uint public _totalSubscriptions = 0;
        /// @notice Total unique wallet subscriptions
        uint public _totalUniqueSubscriptions = 0;
        struct Subscriptions {
            uint id;
            uint renewedTime;
            uint subscriptionStartTime;
            uint expirationTime;
            bool isValid;
        }
        /// @notice Specific subscription mapping
        mapping(address => Subscriptions) public _subscriptions;
    
    // Modifiers ------

        modifier isOwner { require(_owner == msg.sender, "ERR: Not the owner"); _; }
        modifier noReEntrancyGlobal() {
            require(_reEntrancyProtect == false, "ReentrancyGuard: not allowed");
            _reEntrancyProtect = true;

            _;

            _reEntrancyProtect = false;
        }

    // Constructor ------
        constructor(address recipient_) {
            require(recipient_ != address(0), "ERR: cannot be zero address");

            _owner = msg.sender;
            _recipient = recipient_;
        }

    //  Get functions ------

        /**
            @notice Utilized to check the validity of a subscription.
            @param subscriber_ The wallet address of the subscriber to check
            @return status_ The status of the subscription
        */
        function isSubscriptionActive(address subscriber_) public view returns (bool status_) {
            if(_subscriptions[subscriber_].isValid) {
                if(block.timestamp <= (_subscriptions[subscriber_].subscriptionStartTime + _subscriptions[subscriber_].expirationTime)) {
                    return true;
                } else {
                    return false;
                }
            } else {
                return false;
            }
        }

    //  Owner functions ------

        /**
            @notice Restricted to _owner.
            @param to_ Address to receive coins
        */
        function recoverCoin(address to_) public isOwner noReEntrancyGlobal {
            require(to_ != address(0), "ERR: to cannot be zero address");

            (bool success, ) = payable(to_).call{value: address(this).balance}("");
            require(success, "Unable to recover");

            emit EmitEvent("COINS Recovered Successfully");
        }

        /**
            @notice Restricted to _owner.
            @param token_ Token address to retrieve
            @param to_ Address to receive coins
        */
        function recoverToken(address token_, address to_) public isOwner {
            require(to_ != address(0), "ERR: to cannot be zero address");
            
            IERC20(token_).safeTransfer(to_, IERC20(token_).balanceOf(address(this)));

            emit EmitEvent("TOKENS Recovered Successfully");
        }

        /**
            @notice Restricted to _owner.
            @param newOwner_ New Owners Address
        */
        function changeOwner(address newOwner_) external isOwner {
            require(newOwner_ != address(0), "ERR: cannot be zero address");

            _owner = newOwner_;

            emit EmitEvent("Owner Changed Successfully");
        }

        /**
            @notice Restricted to _owner.
            @param newRecipient_ New Recipient Address
        */
        function changeRecipient(address newRecipient_) external isOwner {
            require(newRecipient_ != address(0), "ERR: cannot be zero address");

            _recipient = newRecipient_;

            emit EmitEvent("Recipient Changed Successfully");
        }

        /**
            @notice Restricted to _owner.
            @param amount_ The amount to charge, in the current token being charged's decimals
            @param duration_ The duration to add to their subscription expiration time
            @param title_ Title of the subscription
            @param tokenPaymentAddress_ Token address required for payment of this subscription option
        */
        function addSubscriptionOption(uint amount_, uint duration_, string memory title_, address tokenPaymentAddress_) external isOwner {
            _subscriptionOptions[_totalSubscriptionOptions].id = _totalSubscriptionOptions;
            _subscriptionOptions[_totalSubscriptionOptions].amount = amount_;
            _subscriptionOptions[_totalSubscriptionOptions].duration = duration_;
            _subscriptionOptions[_totalSubscriptionOptions].title = title_;
            _subscriptionOptions[_totalSubscriptionOptions].tokenPaymentAddress = tokenPaymentAddress_;
            _subscriptionOptions[_totalSubscriptionOptions].isValid = true;

            _totalSubscriptionOptions++;

            emit EmitEvent("Subscription Option Added");
        }

        /**
            @notice Restricted to _owner.
            @dev Toggles are unlimited
            @dev Option ID must exist
            @param optionId_ The option ID for which to toggle
        */
        function toggleSubscriptionOption(uint optionId_) external isOwner {
            require(_subscriptionOptions[optionId_].id == optionId_, "ERR: Option doesn't exist");

            _subscriptionOptions[optionId_].isValid = !_subscriptionOptions[optionId_].isValid;
            
            emit EmitEvent("Subscription Option Toggled");
        }

        /**
            @notice Restricted to _owner.
            @param subscriberAddress_ Array of subscriber addresses to remove time from
            @param timeToRemove_ The amount of time to deduct, if 0 or greater than the existing time, then it deducts it entirely
        */
        function removeTime(address[] memory subscriberAddress_, uint[] memory timeToRemove_) external isOwner {
            require(subscriberAddress_.length == timeToRemove_.length, "ERR: Not equal lengths");

            for(uint i=0; i<subscriberAddress_.length; i++) {
                if(_subscriptions[subscriberAddress_[i]].isValid && _subscriptions[subscriberAddress_[i]].expirationTime > 0) {
                    if(timeToRemove_[i] == 0 || _subscriptions[subscriberAddress_[i]].expirationTime <= timeToRemove_[i]) {
                        _subscriptions[subscriberAddress_[i]].expirationTime = 0;
                    } else {
                        _subscriptions[subscriberAddress_[i]].expirationTime = _subscriptions[subscriberAddress_[i]].expirationTime - timeToRemove_[i];
                    }
                }
            }
            
            emit EmitEvent("Subscription Time Reduction Enforced");
        }

        /**
            @notice Restricted to _owner.
            @param subscriberAddress_ The address of the wallet subscribing
            @param timeToAdd_ The length of time to extend their subscription
            @param optionIfAny_ The option ID if timeToAdd_ is 0
        */
        function addTime(address[] memory subscriberAddress_, uint[] memory timeToAdd_, uint[] memory optionIfAny_) external isOwner {
            for(uint i=0; i<subscriberAddress_.length; i++) {
                require(subscriberAddress_.length == timeToAdd_.length && timeToAdd_.length == optionIfAny_.length, "ERR: Not equal lengths");

                if(timeToAdd_[i] == 0) {
                    _performSubscriptionAction(subscriberAddress_[i], optionIfAny_[i]);
                } else {
                    if(!_subscriptions[subscriberAddress_[i]].isValid) {
                        _subscriptions[subscriberAddress_[i]].id = _totalUniqueSubscriptions;
                        _subscriptions[subscriberAddress_[i]].isValid = true;
                        _subscriptions[subscriberAddress_[i]].renewedTime = block.timestamp;
                        _subscriptions[subscriberAddress_[i]].subscriptionStartTime = block.timestamp;
                        _subscriptions[subscriberAddress_[i]].expirationTime = timeToAdd_[i];

                        _totalUniqueSubscriptions++;

                        emit NewSubscriber(subscriberAddress_[i], timeToAdd_[i]);
                    } else {
                        if(isSubscriptionActive(subscriberAddress_[i])) { _subscriptions[subscriberAddress_[i]].subscriptionStartTime = block.timestamp; }
                        _subscriptions[subscriberAddress_[i]].renewedTime = block.timestamp;
                        _subscriptions[subscriberAddress_[i]].expirationTime = _subscriptions[subscriberAddress_[i]].expirationTime + timeToAdd_[i];
                    }

                    _totalSubscriptions++;
                }
            }
            
            emit EmitEvent("Subscription Time Addition Allocated");
        }

    // Subscriber functions ------

        /**
            @notice To be called when initiating any new or additional subscription.
            @param optionId_ The option ID for the desired subscription
            @return status_ True or false depending on whether the subscription as successfully completed
        */
        function performSubscriptionAction(uint optionId_) public returns (bool status_) {
            require(msg.sender != address(this), "ERR: Sender == address(this)");
            require(IERC20(_subscriptionOptions[optionId_].tokenPaymentAddress).allowance(msg.sender, address(this)) >= _subscriptionOptions[optionId_].amount, "ERR: Approval not enough");

            IERC20(_subscriptionOptions[optionId_].tokenPaymentAddress).safeTransferFrom(msg.sender, _recipient, _subscriptionOptions[optionId_].amount);

            (bool resultInput) = _performSubscriptionAction(msg.sender, optionId_);

            return resultInput;
        }

    // Internal functions ------

        /**
            @notice Internal call inputting the subscription information
            @param subscriptionFor_ Address of the wallet the subscription is for
            @param optionId_ The subscription option ID
            @return status_ Whether or not the subscription information was input successfully
        */
        function _performSubscriptionAction(address subscriptionFor_, uint optionId_) internal returns (bool status_) {
            if(!_subscriptions[subscriptionFor_].isValid) {
                _subscriptions[subscriptionFor_].id = _totalUniqueSubscriptions;
                _subscriptions[subscriptionFor_].isValid = true;
                _subscriptions[subscriptionFor_].renewedTime = block.timestamp;
                _subscriptions[subscriptionFor_].subscriptionStartTime = block.timestamp;
                _subscriptions[subscriptionFor_].expirationTime = _subscriptionOptions[optionId_].duration;

                _totalUniqueSubscriptions++;

                emit NewSubscriber(subscriptionFor_, _subscriptionOptions[optionId_].duration);
            } else {
                if(isSubscriptionActive(subscriptionFor_)) { _subscriptions[subscriptionFor_].subscriptionStartTime = block.timestamp; }
                _subscriptions[subscriptionFor_].renewedTime = block.timestamp;
                _subscriptions[subscriptionFor_].expirationTime = _subscriptions[subscriptionFor_].expirationTime + _subscriptionOptions[optionId_].duration;
            }

            _totalSubscriptions++;

            return _subscriptions[subscriptionFor_].renewedTime == block.timestamp && _subscriptions[subscriptionFor_].expirationTime > 0;
        }
}