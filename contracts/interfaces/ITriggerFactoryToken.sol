//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/**
    @author Praxxas DeFi
    @title KS Trigger Factory Token Interface
    @notice See TriggerFactoryToken.sol for more details.
*/
interface ITriggerFactoryToken {
    function _owner() external view returns (address owner);
    function _authorized() external view returns (address authorized);
    function _gasEscrow() external view returns (address gasEscrow);
    function _gasWallet() external view returns (address gasWallet);
    function _individualCount() external view returns (int individualCount);
    function _individualTriggers(int) external view returns (int triggerId, address triggerAddress, address triggerOwner, bool exists);
    function _individualTriggersByAddress(address) external view returns (int id_);
    function _triggerAddressByOwner(address) external view returns (address triggerAddress_);
    function _masterGraceCount() external view returns (int graceCount);
    function triggerExists(int id_) external view returns (bool result);
    function changeOwner(address newOwner_) external returns (bool result);
    function changeMasterGraceCount(int newCount_) external;
    function changeIndividualGraceCount(int[] memory newCount_, address[] memory individualAddress_) external returns (address[] memory successAddresses_);
    function changeGasWallet(address newWallet_) external returns (bool result);
    function changeGasEscrow(address newEscrowAddress_) external;
    function changeAuthorized(address newAuthorized_) external returns (bool result);
    function recoverCoin(address to_) external;
    function recoverToken(address token_, address to_) external;
    function changeIndividualAuthorized(address individualAddress_, address newAuthorized_) external returns (bool result);
    function executeTrigger(address individualAddress_, uint256 gasOverride_) external returns (int triggerID_, int totalSaved_, int totalAttempted_, int blockNumber_, int blockTimeStamp_);
    function deployIndividualContract(address backupAddress_) external returns (address newTriggerAddress);
}