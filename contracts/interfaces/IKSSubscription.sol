//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/**
    @author Praxxas DeFi
    @title KS Subscription Interface
    @notice See KSSubscription.sol for more details.
*/
interface IKSSubscription {
    function _owner() external view returns (address);
    function _recipient() external view returns (address);
    function _subscriptionOptions(uint) external view returns (uint id, string memory title, uint amount, uint duration, address tokenPaymentAddress, bool isValid);
    function _totalSubscriptions() external view returns (uint);
    function _totalUniqueSubscriptions() external view returns (uint);
    function _subscriptions(address) external view returns (uint id, uint renewedTime, uint expirationTime, bool isValid);
    function recoverCoin(address to_) external;
    function recoverToken(address token_, address to_) external;
    function changeOwner(address newOwner_) external;
    function changeRecipient(address newRecipient_) external;
    function addSubscriptionOption(uint amount_, uint duration_, string memory title_, address tokenPaymentAddress) external;
    function toggleSubscriptionOption(uint optionId_) external;
    function removeTime(address[] memory subscriberAddress_, uint[] memory timeToRemove_) external;
    function addTime(address[] memory subscriberAddress_, uint[] memory timeToAdd_, uint[] memory optionIfAny_) external;
    function performSubscriptionAction(uint optionId_) external returns (bool status_);
}