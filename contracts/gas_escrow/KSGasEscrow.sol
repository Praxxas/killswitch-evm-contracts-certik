//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "../utils/SafeERC20.sol";
import "../interfaces/ITriggerFactoryToken.sol";

/**
    @author Praxxas DeFi
    @title KS Gas Escrow Smart Contract
*/
contract KSGasEscrow {
    using SafeERC20 for IERC20;
    
    // Events ------

        /// Emit an event
        event EmitEvent(string result);

    // Variables ------

        /// @notice TriggerFactory address
        ITriggerFactoryToken private _tf;
        struct Settings {
            address owner;
            bool isOpen;
            bool reEntrancyProtect;
        }
        /// @notice KSGasEscrow settings
        Settings private _settings;
    
        /// @notice Total Depositors
        uint256 public _totalDepositors = 0;
        struct Deposit {
            uint256 typeOfTx;
            uint256 amount;
            bool isValid;
            uint256 blockStamp;
            uint256 timeStamp;
            string toReference;
        }
        struct UserTracking {
            address depositorAddress;
            uint256 transactionCount;
            uint256 depositBalance;
            mapping(uint256 => Deposit) transactions;
            bool reEntrancyGuard;
            bool isValid;
        }
        /// @notice Depositors information
        mapping(address => UserTracking) private _depositors;

    // Modifiers ------
        modifier isOwner() { require(msg.sender == _settings.owner, "ERR: not owner"); _; }
        modifier isOwnerOrAuthorized() { require(msg.sender == _settings.owner || msg.sender == _tf._authorized(), "ERR: Not owner or auth"); _; }
        modifier isAuthorized() { require(msg.sender == _tf._authorized(), "ERR: not auth"); _; }
        modifier reEntrancyProtect(address address_) {
            if(_depositors[address_].isValid == true && _depositors[address_].reEntrancyGuard == false) {
                _depositors[address_].reEntrancyGuard = true;

                _;

                _depositors[address_].reEntrancyGuard = false;
            } else {
                revert("ERR: Not valid");
            }
        }
        modifier noReEntrancyGlobal() {
            require(_settings.reEntrancyProtect == false, "ReentrancyGuard: not allowed");
            _settings.reEntrancyProtect = true;

            _;

            _settings.reEntrancyProtect = false;
        }

    // Constructor ------
        constructor () {
            _settings.owner = msg.sender;
            _settings.isOpen = true;
            _settings.reEntrancyProtect = false;
        }

    // Get functions ------
        /**
            @notice Setting saved in a struct, requires a get function.
            @return _owner The address of the owning wallet
        */
        function owner() public view returns (address _owner) { return _settings.owner; }

        /**
            @notice Setting saved in a struct, requires a get function.
            @return _status The status for deposits/withdrawals
        */
        function escrowStatus() public view returns (bool _status) { return _settings.isOpen; }
        
        /**
            @notice Address is pulled directly from the _tf contract.
            @return _authorized The authorized address from the _tf contract
        */
        function authorized() public view returns (address _authorized) { return _tf._authorized(); }
        
        /**
            @notice Address is pulled directly from the _tf contract.
            @return _ksGasWallet The wallet that holds the gas for remote executions
        */
        function gasWallet() public view returns (address _ksGasWallet) { return _tf._gasWallet(); }

        /**
            @notice To retrieve depositor information.
            @notice Restricted to information owners wallet or _tf._authorized.
            @param address_ The address to pull the information for
            @return transactionCount_ Total number of transactions performed with the ks gas escrow contract
            @return depositBalance_ Total amount of the gas token that is deposited
        */
        function depositorInfo(address address_) public view returns (uint256 transactionCount_, uint256 depositBalance_) {
            address addressToUse;
            if(address_ != address(0)) {
                require(msg.sender == address_ || msg.sender == _tf._authorized(), "ERR: Not allowed");
                addressToUse = address_;
            } else {
                addressToUse = msg.sender;
            }

            return (_depositors[addressToUse].transactionCount, _depositors[addressToUse].depositBalance);
        }

        /**
            @notice To retrieve information about a depositors specific transaction.
            @notice Restricted to information owners wallet or _tf._authorized.
            @param address_ The address to pull the information for
            @param txID_ The ID of the specific transaction to view
            @return typeOfTx_ The type of transaction: 1) Deposit 2) KS Trigger 3) Withdrawal
            @return amount_ The amount this transaction was for
            @return blockStamp_ The block that the transaction was executed on
            @return timeStamp_ The timestamp of when the transaction was executed
            @return reference_ Any memo that should accompany any owner override transactions, typically the transaction ID of an execution that gas didn't get refunded for
        */
        function depositorIndividualTXInfo(address address_, uint256 txID_) public view returns (uint256 typeOfTx_, uint256 amount_, uint256 blockStamp_, uint256 timeStamp_, string memory reference_) {
            address addressToUse;
            if(address_ != address(0)) {
                require(msg.sender == address_ || msg.sender == _tf._authorized(), "ERR: Not allowed");
                addressToUse = address_;
            } else {
                addressToUse = msg.sender;
            }

            return (_depositors[addressToUse].transactions[txID_].typeOfTx, _depositors[addressToUse].transactions[txID_].amount, _depositors[addressToUse].transactions[txID_].blockStamp, _depositors[addressToUse].transactions[txID_].timeStamp, _depositors[addressToUse].transactions[txID_].toReference);
        }

    // Owner & Authorized functions ------

        /**
            @notice To change the trigger factory address.
            @notice Restricted to _owner.
            @param tf_ The new address to set
        */
        function setTriggerFactory(address tf_) public isOwner {
            _tf = ITriggerFactoryToken(tf_);

            emit EmitEvent("Trigger Factory Modified");
        }

        /// @notice Call to open or close the ks gas escrow contract.
        /// @notice Restricted to _tf._authorized
        function adjustContractStatus() external isOwnerOrAuthorized {
            _settings.isOpen = !_settings.isOpen;

            emit EmitEvent("Contract Status Modified");
        }
        
        /**
            @notice To change the ks gas escrow owner address.
            @notice Restricted to _tf._authorized
            @param owner_ The new address to set
        */
        function changeOwner(address owner_) external isOwner {
            _settings.owner = owner_;

            emit EmitEvent("Owner Changed Successfully");
        }
    
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

    // Depositor/Withdrawer functions ------

        /**
            @notice Function to call to deposit gas into the escrow
            @notice Gas CAN NOT just be sent here, it must pass through this function
            @dev Utilizes msg.value
        */
        function depositGas() external payable {
            uint256 msgValue = msg.value;
            require(msgValue > 0, "ERR: Too little");

            _newDepositorCheck(msg.sender);

            _logTransaction(msg.sender, 1, msgValue, "");
        }

        /**
            @notice Called when a user wants to withdraw deposited gas from the escrow
            @dev Has reentrancy protection
            @param amount_ The amount in wei form to withdraw
        */
        function withdrawGas(uint256 amount_) external reEntrancyProtect(msg.sender) {
            require(_depositors[msg.sender].depositBalance >= amount_, "ERR: Not enough");
            require(address(this).balance >= amount_, "ERR: Contract empty");

            address payable sendTo = payable(msg.sender);

            _logTransaction(msg.sender, 3, amount_, "");

            (bool success, ) = sendTo.call{value: amount_}("");
            require(success, "Unable to withdraw");
        }

        /**
            @notice Called to transfer gas from the escrow to the KS gas wallet
            @dev Restricted to _owner or _tf._authorized().
            @dev Requires that a trigger exists & is deployed for the msg.sender, allowing an override to withdrawals.
            @param amount_ The amount to transfer in wei form
            @param addressFrom_ The wallet which is having their gas deducted
            @param txType_ The transaction type: 1) Deposit 2) KS Trigger 3) Withdrawal
            @param reference_ Any memo that should accompany any owner override transactions, typically the transaction ID of an execution that gas didn't get refunded for
            @return gasQuantity_ The total amount of gas refunded to KS from the deposited amount
        */
        function transferToGasWallet(uint256 amount_, address addressFrom_, uint256 txType_, string calldata reference_) external returns (uint256 gasQuantity_) {
            require(msg.sender == _settings.owner || msg.sender == _tf._authorized() || _tf.triggerExists(_tf._individualTriggersByAddress(msg.sender)) == true, "ERR: Not allowed");
            require(_depositors[addressFrom_].depositBalance >= amount_ && address(this).balance >= amount_, "ERR: Not enough");

            (uint256 amount) = _logTransaction(addressFrom_, txType_, amount_, reference_);

            (bool success, ) = payable(_tf._gasWallet()).call{value: amount}("");
            require(success, "ERR: Refund failed");

            return amount;
        }

    // Internal functions ------

        function _newDepositorCheck(address address_) internal {
            if(_depositors[address_].isValid != true) {
                _depositors[address_].depositorAddress = address_;
                _depositors[address_].transactionCount = 0;
                _depositors[address_].depositBalance = 0;
                _depositors[address_].isValid = true;
                _depositors[address_].reEntrancyGuard = false;

                _totalDepositors++;
            }
        }

        function _logTransaction(address address_, uint256 typeOfTx_, uint256 amount_, string memory reference_) internal returns (uint256 finalAmount_) {
            uint256 depositBalance = _depositors[address_].depositBalance;
            uint256 txCount = _depositors[address_].transactionCount;
            
            _depositors[address_].transactionCount = txCount + 1;
            _depositors[address_].transactions[txCount].typeOfTx = typeOfTx_;
            _depositors[address_].transactions[txCount].isValid = true;
            _depositors[address_].transactions[txCount].blockStamp = block.number;
            _depositors[address_].transactions[txCount].timeStamp = block.timestamp;
            _depositors[address_].transactions[txCount].toReference = reference_;

            uint256 amount = amount_;

            if(typeOfTx_ == 1) { // Deposit
                _depositors[address_].depositBalance = depositBalance + amount;
            } else if(typeOfTx_ == 2) { // Trigger Executed By KS
                amount = amount * tx.gasprice;
                
                _depositors[address_].depositBalance = depositBalance - amount;
            } else if(typeOfTx_ == 3) { // Withdrawal
                _depositors[address_].depositBalance = depositBalance - amount;
            } else {
                revert("ERR: Unapproved tx type");
            }

            _depositors[address_].transactions[txCount].amount = amount;

            return amount;
        }
}