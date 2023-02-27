//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/**
    @author Praxxas DeFi
    @title KS Gas Escrow Interface
    @notice See KSGasEscrow.sol for more details.
*/
interface IKSGasEscrow {
    function totalDepositors() external view returns (uint256);
    function owner() external view returns (address _owner);
    function escrowStatus() external view returns (bool _status);
    function gasPercent() external view returns (uint256 gasPercent_);
    function authorized() external view returns (address _authorized);
    function gasWallet() external view returns (address _ksGasWallet);
    function depositorInfo(address address_) external view returns (uint256 transactionCount_, uint256 depositBalance_);
    function depositorIndividualTXInfo(address address_, uint256 txID_) external view returns (uint256 typeOfTx_, uint256 amount_, uint256 blockStamp_, uint256 timeStamp_, string memory reference_);
    function setTriggerFactory(address tf_) external;
    function adjustContractStatus() external;
    function changeOwner() external;
    function changeGasPercent(uint256 newGas_) external;
    function recoverCoin(address to_) external;
    function recoverToken(address token_, address to_) external;
    function depositGas() external payable;
    function withdrawGas(uint256 amount_) external;
    function transferToGasWallet(uint256 amount_, address addressFrom_, uint256 txType_, string memory reference_) external returns (uint256 gasQuantity_);
}