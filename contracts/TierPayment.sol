// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TierPayment is Ownable { 

 // Structs Modifers and Events
    struct Tier {
        uint8 percentage;
        address[] walletsArray;
        mapping(address => Balance) balances;
        mapping(address => uint) indexOf;
        mapping(address => bool) exist;
    }

    struct Balance { 
        uint256 withdrawalCount;
        uint256[] withdrawalHistory;
        uint256 balance;
    }

    struct ReturnTiers {

        address[]   MembersT1; 
        uint256     MembersCountT1; 
        address[]   MembersT2; 
        uint256     MembersCountT2; 
        address[]   MembersT3; 
        uint256     MembersCountT3;

    }

    mapping (uint8 => Tier) TierList;
    uint256 private contractBalance; 
    uint256 private contractEarningPercentage; 


    modifier ValidTier(uint8 tierNumber){
        require(tierNumber > 0 && tierNumber <= 3, "Tier must be 1, 2 or 3" );
        _;
    }

    modifier WalletExist(address wallet){
        require(_walletExist(wallet), "This wallet exist in 1 of our tiers" );
        _;
    }

    modifier WalletNotExist(address wallet){
        require(!_walletExist(wallet), "This wallet exist in 1 of our tiers" );
        _;
    }
    

    event WithdrawContractBalance(uint256 amount,address owner);
    event WithdrawWalletBalance(uint256 amount,address owner);
    event SaveBalanceToContract(uint256 amount);
    event ItemSold(uint256 amount);
    event AddWalletToAnSpecificTier(address wallet, uint8 tierNumber);
    event RemoveWalletFromAnSpecificTier(address wallet, uint8 tierNumber);

// END Structs Modifers and Events

    constructor(){
        // estas variables podrian ser seadas desde el constructor, por motivos del TEST se hacen hardcoded.
        contractBalance = 0;
        contractEarningPercentage= 3;
        TierList[1].percentage = 20;
        TierList[2].percentage = 20;
        TierList[3].percentage = 40;
    }

    function checkTierMembers(uint8 tierNumber) ValidTier(tierNumber) public view returns(address[] memory, uint256) {
        return (TierList[tierNumber].walletsArray, TierList[tierNumber].walletsArray.length );
    }

    function checkAllTiers() public view returns(ReturnTiers memory){
        return ReturnTiers({
            MembersT1: TierList[1].walletsArray,
            MembersCountT1: TierList[1].walletsArray.length,
            MembersT2: TierList[2].walletsArray,
            MembersCountT2: TierList[2].walletsArray.length,
            MembersT3: TierList[3].walletsArray,
            MembersCountT3: TierList[3].walletsArray.length 
        });
    }

    function TierPercentage(uint8 tierNumber) ValidTier(tierNumber) public view returns(uint8) {
        return TierList[tierNumber].percentage;
    }

    function addWalletToAnSpecificTier(uint8 tierNumber, address wallet) ValidTier(tierNumber) WalletNotExist(wallet) onlyOwner public {
        Tier storage currentTier = TierList[tierNumber];
        currentTier.exist[wallet] = true;
        currentTier.balances[wallet] = Balance({
            withdrawalCount: 0,
            withdrawalHistory: new uint256[](0) ,
            balance: 0
        });
        currentTier.indexOf[wallet] = currentTier.walletsArray.length;
        currentTier.walletsArray.push(wallet);
        emit AddWalletToAnSpecificTier(wallet, tierNumber);
    }
    
    function removeWalletFromAnSpecificTier(uint8 tierNumber, address wallet) ValidTier(tierNumber) WalletExist(wallet) onlyOwner public {
        Tier storage currentTier = TierList[tierNumber];

        require(currentTier.balances[wallet].balance == 0, "You must withdraw all the balance of this wallet");

        delete currentTier.balances[wallet];
        delete currentTier.exist[wallet];

        uint index = currentTier.indexOf[wallet];
        uint lastIndex = currentTier.walletsArray.length - 1;
        address lastKey = currentTier.walletsArray[lastIndex];

        currentTier.indexOf[lastKey] = index;
        delete currentTier.indexOf[wallet];

        currentTier.walletsArray[index] = lastKey;
        currentTier.walletsArray.pop();
        emit RemoveWalletFromAnSpecificTier(wallet, tierNumber);
    }

    function getContractBalance() public view onlyOwner returns (uint256) {
        return contractBalance;
    }

    function getWalletBalance(address reciever) public view  WalletExist(reciever) onlyOwner returns (uint256){
        uint256 balance;
        for(uint8 tier = 1; tier <= 3; tier++){
            if(TierList[tier].walletsArray.length > 0){
                if(TierList[tier].exist[reciever]){
                    balance = TierList[tier].balances[reciever].balance;
                }
            }
        }
        return balance;
    }

    function withdraw(address reciever) WalletExist(reciever) public onlyOwner{
        address payable to = payable(reciever);
        uint256 balance;
        for(uint8 tier = 1; tier <= 3; tier++){
            if(TierList[tier].walletsArray.length > 0){
            if(TierList[tier].exist[reciever]){
                balance = TierList[tier].balances[reciever].balance;
                TierList[tier].balances[reciever].withdrawalHistory.push(balance);
                TierList[tier].balances[reciever].withdrawalCount++;
                TierList[tier].balances[reciever].balance = 0;
                }
            }
        to.transfer(balance);
        emit WithdrawWalletBalance(balance, reciever);
        }
    }

    function withdrawContractBalance(address reciever) public onlyOwner {
        address payable to = payable(reciever);
        uint256 balance = getContractBalance(); 
        to.transfer(balance);
        contractBalance = 0;
        emit WithdrawContractBalance(balance, reciever);
    }

    function sellAsset() public payable returns(string memory){
        require(msg.value > 0, "The amount cannot be 0");
        
        _profitSplit(msg.value);
        
        emit ItemSold(msg.value);

        return "Asset sold";
    }


    // internal functions 

    function _walletExist(address wallet) internal view returns(bool){
        bool exist = false;
        for(uint8 tier = 1; tier <= 3; tier++){
            if(TierList[tier].exist[wallet]){
                return true;
            }
        }
        return exist;
    }

    function _profitSplit(uint256 amount) internal {
        uint256 tempAmount = amount;
        for(uint8 tier = 1; tier <= 3; tier++){
            uint8 percentage = TierList[tier].percentage;
            if(TierList[tier].walletsArray.length > 0){
                uint splitAmount = (amount / 100) * percentage;
                tempAmount -= splitAmount;
                for(uint walletIndex = 0; walletIndex < TierList[tier].walletsArray.length; walletIndex++){
                    address wallet = TierList[tier].walletsArray[walletIndex];
                    TierList[tier].balances[wallet].balance += (splitAmount / TierList[tier].walletsArray.length);
                }
            }
        }
        uint256 contractEarnings = (amount / 100) * contractEarningPercentage;
        contractBalance += contractEarnings;
        tempAmount -= contractEarnings;
        if(tempAmount > 0){
            contractBalance += tempAmount;
            emit SaveBalanceToContract(contractEarnings + tempAmount);
        }else{
            emit SaveBalanceToContract(contractEarnings);
        }
        
    }

}