//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./TriggerIndividualToken.sol";
import "../../interfaces/IKSGasEscrow.sol";

/**
    @author Praxxas DeFi
    @title KS Token Trigger Factory Smart Contract
*/
contract TriggerFactoryToken {
    /// Variables ------

        /// @notice The owner of the KillSwitch Factory
        address public _owner;

        /// @notice The authorized wallet of the KillSwitch Factory
        address public _authorized;

        /// @notice The gas escrow contract address
        address public _gasEscrow;

        /// @notice The gas wallet that funds remote trigger calls
        address public _gasWallet;

        /// @notice Total individual triggers deployed
        int public _individualCount = 0;
        struct IndividualTriggers {
            int triggerId;
            address triggerAddress;
            address triggerOwner;
            bool exists;
        }
        /// @notice Individual triggers (int -> struct)
        mapping(int => IndividualTriggers) public _individualTriggers;
        /// @notice Individual trigger ID (address -> int)
        mapping(address => int) public _individualTriggersByAddress;
        /// @notice Individual trigger by owner address (address -> address)
        mapping(address => address) public _triggerAddressByOwner;
        /// @notice Grace count to give each newly deployed trigger
        int public _masterGraceCount = 0;

    // Modifiers ------

        modifier isOwner() { require(msg.sender == _owner, "ERR: Not owner"); _; }

    // Constructor ------
        constructor (address gasWallet_) {
            _owner = msg.sender;
            _authorized = msg.sender;
            _gasWallet = gasWallet_;
        }

    // Getter functions ------

        /**
            @notice Checks whether a trigger exists by it's ID.
            @param id_ The ID to check.
            @return result True or false
        */
        function triggerExists(int id_) external view returns (bool result) { return _individualTriggers[id_].exists; }

    // Owner & authorized functions ------

        /**
           @notice Changes the owner of the trigger factory.
           @notice Restricted to owner.
           @param newOwner_ Address of the new owner
        */
        function changeOwner(address newOwner_) external isOwner { _owner = newOwner_; }

        /**
            @notice Changes the master grace count.
            @notice Restricted to owner.
            @param newCount_ New grace count
        */
        function changeMasterGraceCount(int newCount_) external isOwner {
            _masterGraceCount = newCount_;
        }

        /**
            @notice Allows changing individual triggers' grace counts.
            @notice Restricted to owner.
            @param newCount_ New grace count
            @param individualAddress_ Trigger addresses to modify
            @return successAddresses_ Addresses that were successfully modified
        */
        function changeIndividualGraceCounts(int[] memory newCount_, address[] memory individualAddress_) external isOwner returns (address[] memory successAddresses_) {
            address[] memory successTriggers = new address[](individualAddress_.length);

            uint256 p = 0;
            for(int i=0; i<int(individualAddress_.length); i++) {
                if(_individualTriggers[_individualTriggersByAddress[individualAddress_[uint256(i)]]].exists == true) {
                    TriggerIndividualToken contracto = TriggerIndividualToken(individualAddress_[uint256(i)]);
                    contracto.modifyGraceTriggers(newCount_[uint256(i)]);

                    successTriggers[p] = individualAddress_[uint256(i)];
                    p++;
                }
            }

            return (successTriggers);
        }

        /**
            @notice Changing the gas wallet.
            @notice Restricted to owner.
            @param newWallet_ New gas wallet address
        */
        function changeGasWallet(address newWallet_) external isOwner { _gasWallet = newWallet_; }

        /**
            @notice Changing the gas escrow.
            @notice Restricted to owner.
            @param newEscrowAddress_ New gas escrow contract address
        */
        function changeGasEscrow(address newEscrowAddress_) external isOwner { _gasEscrow = newEscrowAddress_; }


        /**
            @notice Changing the authorized wallet.
            @notice Restricted to owner.
            @param newAuthorized_ New authorized wallet address
        */
        function changeAuthorized(address newAuthorized_) external isOwner { _authorized = newAuthorized_; }

        /**
            @notice Restricted to _owner.
            @param to_ Address to receive coins
        */
        function recoverCoin(address to_) public virtual isOwner { payable(to_).transfer(address(this).balance); }

        /**
            @notice Restricted to _owner.
            @param token_ Token address to retrieve
            @param to_ Address to receive coins
        */
        function recoverToken(address token_, address to_) public virtual isOwner { IERC20(token_).transfer(to_, IERC20(token_).balanceOf(address(this))); }

        /**
            @notice Changes the authorized address of an individual trigger.
            @notice Restricted to owner.
            @param individualAddress_ Individual trigger address to change
            @param newAuthorized_ New authorized address
        */
        function changeIndividualAuthorized(address individualAddress_, address newAuthorized_) external isOwner {
            require(_individualTriggers[_individualTriggersByAddress[individualAddress_]].exists == true, "ERR: Does not exist");
            require(newAuthorized_ != address(0), "ERR: New authorized invalid");

            TriggerIndividualToken(individualAddress_).setNewAuthorizedAddress(newAuthorized_);
        }

        /**
            @notice Execution of a trigger.
            @notice Restricted to owner or authorized.
            @param individualAddress_ Address of the individual trigger
            @param gasOverride_ If there's an override on the calculated gas, pass it through
            @return triggerID_ ID of the trigger
            @return totalSaved_ Quantity of saved assets
            @return totalAttempted_ Quantity of attempted to save assets
            @return blockNumber_ Block number that the execution took place on
            @return blockTimeStamp_ Block timestamp that the execution took place on
        */
        function executeTrigger(address individualAddress_, uint256 gasOverride_) external returns (int triggerID_, int totalSaved_, int totalAttempted_, int blockNumber_, int blockTimeStamp_) {
            uint256 gasStarted = gasleft();

            require(msg.sender == _owner || msg.sender == _authorized, "ERR: Not allowed");

            require(_individualTriggers[_individualTriggersByAddress[individualAddress_]].exists == true, "ERR: This does not exist");

            (int triggerIDInt_, int totalSavedInt_, int totalAttemptedInt_, int blockNumberInt_, int blockTimeStampInt_) = TriggerIndividualToken(individualAddress_).trigger(false, gasStarted, gasOverride_);

            return (triggerIDInt_, totalSavedInt_, totalAttemptedInt_, blockNumberInt_, blockTimeStampInt_);
        }

    // Public functions ------

        /**
            @notice Deploying an individual trigger contract.
            @param backupAddress_ The address that is used as the backup for the primary protected wallet
            @return newTriggerAddress The address of the new trigger
        */
        function deployIndividualContract(address backupAddress_, string memory passPhrase_) external returns (address newTriggerAddress) {
            require(_triggerAddressByOwner[msg.sender] == address(0), "ERR: Owner has already deployed");
            require(msg.sender != backupAddress_, "ERR: Backup cannot be primary");
            require(backupAddress_ != address(0) || backupAddress_ != address(this), "ERR: Incorrect backup address");

            TriggerIndividualToken toDeploy = new TriggerIndividualToken(backupAddress_, passPhrase_, msg.sender, address(this));

            int currentCount = _individualCount;

            _individualTriggers[currentCount].triggerId = currentCount;
            _individualTriggers[currentCount].triggerAddress = address(toDeploy);
            _individualTriggers[currentCount].triggerOwner = msg.sender;
            _individualTriggers[currentCount].exists = true;

            _individualTriggersByAddress[address(toDeploy)] = currentCount;
            _triggerAddressByOwner[msg.sender] = address(toDeploy);

            _individualCount++;

            return address(toDeploy);
        }
}