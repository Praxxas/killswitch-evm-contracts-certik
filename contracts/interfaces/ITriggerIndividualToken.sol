//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/**
    @author Praxxas DeFi
    @title KS Trigger Individual Token Interface
    @notice See TriggerIndividualToken.sol for more details.
*/
interface ITriggerIndividualToken {
    function _deploymentBlock() external view returns (int deploymentBlock_);
    function _deploymentTimestamp() external view returns (int deploymentTimestamp_);
    function _triggerResultsCount() external view returns (int triggerResultsCount_);
    function _triggerResultsMock() external view returns (int triggerResultsMock_);
    function _triggerResults(int count_) external view returns (int id_, int savedQuantity_, int totalAttempted_, int256 blockStarted_, int256 timestampStarted_, bool ownerExecuted_, bool mock_, int gasUsed_);
    function _owner() external view returns (address owner_);
    function _authorizedAddress() external view returns (address authorized_);
    function _graceTriggers() external view returns (int graceTriggers_);
    function _totalWatched() external view returns (int totalWatched_);
    function _watchedTokens(int) external view returns (int watchId, address tokenAddress, string memory tokenName, string memory tokenSymbol, int tokenDecimals, int blockTimestamp, int blockNumber, bool isWatching, bool isEntry);
    function triggerHistory() external view returns (int[] memory ids_, int[] memory savedQuantities_, int[] memory totalAttempts_, int256[] memory blocksStarted_, int256[] memory timestampsStarted_, bool[] memory didOwnerExecute_, bool[] memory isAMock_, int[] memory gasUsed_);
    function backupAddress() external view returns (address backupAddress_);
    function isKSAuthorized() external view returns (bool result_);
    function isPassPhraseSet() external view returns (bool result_);
    function authorizedPassPhraseOverride() external;
    function modifyGraceTriggers(int newCount_) external;
    function setNewAuthorizedAddress(address newAuthorizedAddress_) external;
    function recoverCoin(address to_) external;
    function recoverToken(address token_, address to_) external;
    function adjustAuthorization(string memory passPhrase_) external;
    function setNewBackup(address newBackupAddress_, string memory passPhrase_) external;
    function addWatchTokens(address[] memory tokenAddresses_, string memory passPhrase_) external returns (address[] memory added, address[] memory failed);
    function toggleWatch(int watchId_, string memory passPhrase_) external;
    function changePassPhrase(string memory newPassPhrase_, string memory currentPassPhrase_) external;
    function trigger(bool mock_, uint256 gasStarted_, uint256 gasOverride_) external returns (int triggerID_, int totalSaved_, int totalAttempted_, int blockNumber_, int blockTimeStamp_);
}