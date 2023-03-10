//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../../interfaces/IERC20.sol";
import "../../interfaces/ITriggerFactoryToken.sol";
import "../../interfaces/IKSGasEscrow.sol";

/**
    @author Praxxas DeFi
    @title KS Token Individual Trigger Smart Contract
*/
contract TriggerIndividualToken {
    // Variables ------

        /// @notice Block deployment happened on.
        int public _deploymentBlock;
        /// @notice Timestamp deployment happened on.
        int public _deploymentTimestamp;

        /// @notice Total quantity of triggers.
        int public _triggerResultsCount = 0;
        /// @notice Total quantity of mock triggers.
        int public _triggerResultsMock = 0;
        struct TriggerResults {
            int id;
            int savedQuantity;
            int totalAttempted;
            int256 blockStarted;
            int256 timestampStarted;
            bool ownerExecuted;
            bool mock;
            int gasUsed;
        }
        /// @notice Returns the trigger results for a specific trigger ID.
        mapping(int => TriggerResults) public _triggerResults;

        /// @notice The TriggerFactory.
        ITriggerFactoryToken private _tf;

        /// @notice The owner of this individual trigger contract (the user of KillSwitch, not KillSwitch itself).
        address public _owner;

        address public _authorizedAddress;
        ///@notice The amount of grace triggers this individual contract has to execute before gas is required.
        int public _graceTriggers = 0;

        struct Settings {
            address backupAddress;
            bool isAuthorized;
            bool isPassPhraseSet;
            string passPhrase;
            bool reEntrancyGuard;
        }
        /// @notice Settings.
        Settings private _settings;

        /// Total assets assigned to watch.
        int public _totalWatched = 0;
        struct WatchedTokens {
            int watchId;
            address tokenAddress;
            string tokenName;
            string tokenSymbol;
            int tokenDecimals;
            int blockTimestamp;
            int blockNumber;
            bool isWatching;
            bool isEntry;
        }
        /// Asset ID returns the WatchedTokens struct.
        mapping(int => WatchedTokens) public _watchedTokens;

    // Modifiers ------
        modifier isOwner() { require(msg.sender == _owner, "ERR: Not the owner."); _;}
        modifier isAuthorized() { require(msg.sender == _authorizedAddress, "ERR: Not authorized."); _; }
        modifier passPhraseCheck(string memory passPhrase_) { require(_settings.isPassPhraseSet && keccak256(abi.encode(_settings.passPhrase)) == keccak256(abi.encode(passPhrase_)), "ERR: Required but wrong"); _; }
        modifier noReentrant() {
            require(!_settings.reEntrancyGuard, "ERR: No re-entrancy.");
            _settings.reEntrancyGuard = true;

            _;

            _settings.reEntrancyGuard = false;
        }

    // Constructor ------
        constructor(address backupAddress_, string memory passPhrase_, address ownerAddress_, address triggerFactory_) {
            require(backupAddress_ != msg.sender, "ERR: Backup cannot be primary");

            if(bytes(passPhrase_).length > 0) {
                _settings.isPassPhraseSet = true;
                _settings.passPhrase = passPhrase_;
            } else {
                _settings.isPassPhraseSet = false;
                _settings.passPhrase = string("");
            }
            _settings.backupAddress = backupAddress_;
            _owner = ownerAddress_;
            _deploymentBlock = int256(block.number);
            _deploymentTimestamp = int256(block.timestamp);

            _tf = ITriggerFactoryToken(triggerFactory_);
            _graceTriggers = _tf._masterGraceCount();
            _authorizedAddress = _tf._authorized();
        }

    // Getter functions ------

        /**
            @notice Utilized to get the entire trigger history from this specific contract.
            @return ids_ An integer array of the individual trigger IDs
            @return savedQuantities_ An integer array that is the quantity of tokens saved by that specific trigger
            @return totalAttempts_ An integer array that is the quantity of tokens attempted to be saved
            @return blocksStarted_ An integer array that is the block the trigger was executed on
            @return timestampsStarted_ An integer array that is the timestamp of when the trigger was executed
            @return didOwnerExecute_ A bool array of whether or not it was KS or the owner who performed the execution
            @return isAMock_ A bool array of whether it was an actual trigger or just a mock trigger
            @return gasUsed_ An integer array that is the amount of gas that transaction used
        */
        function triggerHistory() external view returns (int[] memory ids_, int[] memory savedQuantities_, int[] memory totalAttempts_, int256[] memory blocksStarted_, int256[] memory timestampsStarted_, bool[] memory didOwnerExecute_, bool[] memory isAMock_, int[] memory gasUsed_) {
            int[] memory ids = new int[](uint256(_triggerResultsCount));
            int[] memory savedQuantities = new int[](uint256(_triggerResultsCount));
            int[] memory totalAttempted = new int[](uint256(_triggerResultsCount));
            int256[] memory blockStarted = new int256[](uint256(_triggerResultsCount));
            int256[] memory timestampStarted = new int256[](uint256(_triggerResultsCount));
            bool[] memory ownerExecuted = new bool[](uint256(_triggerResultsCount));
            bool[] memory mocks = new bool[](uint256(_triggerResultsCount));
            int[] memory gasUsed = new int[](uint256(_triggerResultsCount));

            for(int i=0; i<_triggerResultsCount; i++) {
                ids[uint256(i)] = _triggerResults[i].id;
                savedQuantities[uint256(i)] = _triggerResults[i].savedQuantity;
                totalAttempted[uint256(i)] = _triggerResults[i].totalAttempted;
                blockStarted[uint256(i)] = _triggerResults[i].blockStarted;
                timestampStarted[uint256(i)] = _triggerResults[i].timestampStarted;
                ownerExecuted[uint256(i)] = _triggerResults[i].ownerExecuted;
                mocks[uint256(i)] = _triggerResults[i].mock;
                gasUsed[uint256(i)] = _triggerResults[i].gasUsed;
            }

            ids_ = ids;
            savedQuantities_ = savedQuantities;
            totalAttempts_ = totalAttempted;
            blocksStarted_ = blockStarted;
            timestampsStarted_ = timestampStarted;
            didOwnerExecute_ = ownerExecuted;
            isAMock_ = mocks;
            gasUsed_ = gasUsed;

            delete ids;
            delete savedQuantities;
            delete totalAttempted;
            delete blockStarted;
            delete timestampStarted;
            delete ownerExecuted;
            delete mocks;
            delete gasUsed;

            return (ids_, savedQuantities_, totalAttempts_, blocksStarted_, timestampsStarted_, didOwnerExecute_, isAMock_, gasUsed_);
        }

        /// @notice The assigned backup address by the owner.
        function backupAddress() external view returns (address backupAddress_) { return _settings.backupAddress; }

        /// @notice Is KillSwitch authorized to act on this contracts behalf.
        function isKSAuthorized() external view returns (bool result_) { return _settings.isAuthorized; }

        /// @notice Is the pass phrase set.
        function isPassPhraseSet() external view returns (bool result_) { return _settings.isPassPhraseSet; }

    // Authorized functions ------

        /**
            @notice Authorized override in case a passphrase is forgot.
            @notice This will utilize outside verification methods such as 2FA codes or the emergency recovery code on KillSwitch.
            @dev Requires the owner of this contract provides KillSwitch authorization.  Without it, it will revert.
        */
        function authorizedPassPhraseOverride() external isAuthorized {
            require(_settings.isAuthorized == true, "ERR: Auth disabled");

            _settings.isPassPhraseSet = false;
            _settings.passPhrase = string("");
        }

        /**
            @notice Modification of the grace triggers allowed.
            @notice Restricted to Authorized.
        */
        function modifyGraceTriggers(int newCount_) external isAuthorized { _graceTriggers = newCount_; }

        /**
            @notice Modifying the authorized address.
            @notice Restricted to Authorized.
            @param newAuthorizedAddress_ The new authorized address
        */
        function setNewAuthorizedAddress(address newAuthorizedAddress_) external isAuthorized { _authorizedAddress = newAuthorizedAddress_; }

        /**
            @notice Restricted to Authorized.
            @param to_ Address to receive coins
        */
        function recoverCoin(address to_) public virtual isAuthorized { payable(to_).transfer(address(this).balance); }

        /**
            @notice Restricted to Authorized.
            @param token_ Token address to retrieve
            @param to_ Address to receive coins
        */
        function recoverToken(address token_, address to_) public virtual isAuthorized { IERC20(token_).transfer(to_, IERC20(token_).balanceOf(address(this))); }

    // Owner functions ------

        /**
            @notice Modifying whether KillSwitch has authorization.
            @notice Restricted to owner.
        */
        function adjustAuthorization(string memory passPhrase_) external isOwner passPhraseCheck(passPhrase_) { _settings.isAuthorized = !_settings.isAuthorized; }

        /**
            @notice Setting a new backup address.
            @notice Restricted to owner.
            @param newBackupAddress_ Address of the new backup
        */
        function setNewBackup(address newBackupAddress_, string memory passPhrase_) external isOwner passPhraseCheck(passPhrase_) {
            require(newBackupAddress_ != _owner, "ERR: Backup cannot be primary.");

            _settings.backupAddress = newBackupAddress_;
        }

        /**
            @notice Adds a token to the watched list.
            @notice Restricted to owner.
            @param tokenAddresses_ An address array of token addresses to add to the watched list
            @return added_ An address array of returned addresses successfully added
            @return failed_ An address array of returned addresses that failed to be added
        */
        function addWatchTokens(address[] memory tokenAddresses_, string memory passPhrase_) external isOwner passPhraseCheck(passPhrase_) returns (address[] memory added_, address[] memory failed_) {
            int currentCount = _totalWatched;
            uint256 addedCount = 0;
            uint256 failedCount = 0;
            address[] memory addedTokens = new address[](tokenAddresses_.length);
            address[] memory failedTokens = new address[](tokenAddresses_.length);

            for(uint i=0; i<tokenAddresses_.length; i++) {
                if(getEntryByAddress(tokenAddresses_[i]) == false) {
                    IERC20 tokenToCall = IERC20(tokenAddresses_[i]);

                    _watchedTokens[currentCount].watchId = currentCount;
                    _watchedTokens[currentCount].tokenAddress = tokenAddresses_[i];
                    _watchedTokens[currentCount].tokenName = tokenToCall.name();
                    _watchedTokens[currentCount].tokenSymbol = tokenToCall.symbol();
                    _watchedTokens[currentCount].tokenDecimals = tokenToCall.decimals();
                    _watchedTokens[currentCount].blockTimestamp = int(block.timestamp);
                    _watchedTokens[currentCount].blockNumber = int(block.number);
                    _watchedTokens[currentCount].isWatching = true;
                    _watchedTokens[currentCount].isEntry = true;

                    _totalWatched++;

                    addedTokens[addedCount] = tokenAddresses_[i];
                    addedCount++;
                } else {
                    failedTokens[failedCount] == tokenAddresses_[i];
                    failedCount++;
                }
            }

            return (addedTokens, failedTokens);
        }

        /**
            @notice Toggling if an asset is watched or not.
            @notice Restricted to owner.
            @param watchId_ The ID of the watched address
        */
        function toggleWatch(int watchId_, string memory passPhrase_) external isOwner passPhraseCheck(passPhrase_) {
            require(_watchedTokens[watchId_].isEntry == true, "ERR: Watch ID doesn't exist.");

            _watchedTokens[watchId_].isWatching = !_watchedTokens[watchId_].isWatching;
        }

        /**
            @notice Changing the passphrase.
            @notice Restricted to owner.
            @param newPassPhrase_ The new passphrase
            @param currentPassPhrase_ The current passphrase
        */
        function changePassPhrase(string memory newPassPhrase_, string memory currentPassPhrase_) external isOwner passPhraseCheck(currentPassPhrase_) {
            if(bytes(newPassPhrase_).length >= 0) {
                _settings.isPassPhraseSet = true;
                _settings.passPhrase = newPassPhrase_;
            } else {
                _settings.isPassPhraseSet = false;
                _settings.passPhrase = string("");
            }
        }

    // Owner & authorized functions ------

        /**
            @notice The trigger function.
            @notice Restricted to the owner or the authorized address.
            @dev If gasStarted_ is 0, then gasOverride_ must be 0.
            @param mock_ Whether this trigger is a mock trigger (to test efficacy)
            @param gasStarted_ The starting gas amount
            @param gasOverride_ Overriding percentage to append to the gas amount
            @return triggerID_ The ID of this specific trigger within this contract
            @return totalSaved_ The total quantity of saved assets
            @return totalAttempted_ The total quantity of attempted assets
            @return blockNumber_ The block number of this trigger
            @return blockTimeStamp_ The time stamp of this trigger
        */
        function trigger(bool mock_, uint256 gasStarted_, uint256 gasOverride_) external noReentrant returns (int triggerID_, int totalSaved_, int totalAttempted_, int blockNumber_, int blockTimeStamp_) {
            require(msg.sender == _authorizedAddress || msg.sender == _owner, "ERR: Not owner or authorized.");
            bool ownerExecuted = true;
            if(msg.sender == _authorizedAddress) {
                require(_settings.isAuthorized == true, "ERR: Auth disabled");
                ownerExecuted = false;
            }

            int totalSaved = 0;
            int totalAttempted = 0;

            IERC20 tokenToCall;
            for(int i=0; i<_totalWatched; i++) {
                if(_watchedTokens[i].isWatching == true) {
                    tokenToCall = IERC20(_watchedTokens[i].tokenAddress);

                    uint256 allowance = tokenToCall.allowance(_owner, address(this));
                    uint256 owned = tokenToCall.balanceOf(_owner);

                    if(allowance >= 1 && owned >= 1) {
                        if(mock_ == true) {
                            totalSaved++;
                        } else {
                            (bool success) = tokenToCall.transferFrom(_owner, _settings.backupAddress, allowance >= owned ? owned : allowance);

                            if(success) {
                                totalSaved++;
                            }
                        }
                    }

                    totalAttempted++;
                }
            }
            
            _triggerResults[_triggerResultsCount].id = _triggerResultsCount;
            _triggerResults[_triggerResultsCount].savedQuantity = totalSaved;
            _triggerResults[_triggerResultsCount].blockStarted = int256(block.number);
            _triggerResults[_triggerResultsCount].timestampStarted = int256(block.timestamp);
            _triggerResults[_triggerResultsCount].mock = mock_;
            _triggerResults[_triggerResultsCount].totalAttempted = totalAttempted;
            _triggerResults[_triggerResultsCount].ownerExecuted = ownerExecuted;
            _triggerResults[_triggerResultsCount].gasUsed = 0;

            if(mock_ == true) { _triggerResultsMock++; }

            if(msg.sender == _authorizedAddress && mock_ == false) {
                if(_graceTriggers >= 1) {
                    _graceTriggers--;
                } else {
                    IKSGasEscrow ge = IKSGasEscrow(_tf._gasEscrow());
                    uint256 gasUsed = (gasStarted_ - gasleft());
                    (uint256 gasQuantity_) = ge.transferToGasWallet(gasOverride_ > 0 ? gasOverride_ : gasUsed, _owner, 2, "");
                    _triggerResults[_triggerResultsCount].gasUsed = int(gasQuantity_);
                }
            }
            
            _triggerResultsCount++;

            return (_triggerResultsCount--, totalSaved, totalAttempted, int256(block.number), int256(block.timestamp));
        }

    // Internal functions ------

        function getEntryByAddress(address tokenAddress_) internal view returns (bool result) {
            require(tokenAddress_ == address(tokenAddress_), "ERR: Address must be an address.");

            bool isFound = false;
            for(int i=0; i<_totalWatched; i++) {
                if(_watchedTokens[i].tokenAddress == tokenAddress_) {
                    isFound = true;
                }
            }

            return isFound;
        }
}