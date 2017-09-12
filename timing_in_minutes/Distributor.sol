pragma solidity ^0.4.2;

 /*
  * Distributor is used to show participants the exact way how the money will be spent
  * It allows to pass all the incoming transfer only to Marketing or share it between all accounts 
  * by specific scheme
  *
  * With owner account you specify the list of accounts to share with share amounts
  * then you lock distributor to make it ready
  *
  * For example if you add Account1 with share 10, Account2 with share 15, Account3 with share 25
  * passToShare will give 20% to Account1, 30% to Account2 and 70% to Account3
  * and passToMarketing will give 100% to Marketing
  *
  * Money is not transferred immediately, instead it's loaded to internal ballance
  * And then the share accounts can make withdraw calls to withdraw money from balance
  */

contract Distributor {
	address public owner;
	uint public marketing = 0;
	mapping (address => uint) public accountBalances;
	mapping (address => uint) public accountShares;
	mapping (uint => address) public accountIndex;
	uint public accountCount;
	bool public isLocked;
	
	event Lock();
	event OwnerChanged(address newOwner);
	event MarketingChanged(address newMarketing);
	event ShareAccountAdded(address newShareAccount, uint newShare);
	event ShareAccountRemoved(address shareAccountToRemove);
	event PaidToMarketing(uint value);
	event PaidToShare(uint value);
	event Withdraw(address receiver, uint value);
	
	function Distributor() {
		owner=msg.sender;
	}
	
	modifier Unlocked() { if (!isLocked) _; }
	modifier Locked() { if (isLocked) _; }
	
	function changeOwner(address newOwner) {
		if (isLocked) throw;
		if (msg.sender!=owner) throw;
		owner=newOwner;
		OwnerChanged(owner);
	}
	
	function lock() Unlocked {
		if (msg.sender!=owner) throw;
		isLocked=true;
		Lock();
	}
	
	function setMarketing(address newMarketingAccount, uint newShare) Unlocked {
		if (msg.sender!=owner) throw;
		if (marketing == 0){
			marketing=accountCount;
			accountIndex[marketing]=newMarketingAccount;
			accountShares[newMarketingAccount]=newShare;
			accountBalances[newMarketingAccount]=0;
			accountCount++;
		} else {
			ShareAccountRemoved(accountIndex[marketing]);
			accountBalances[newMarketingAccount]=accountBalances[accountIndex[marketing]];
			delete accountBalances[accountIndex[marketing]];
			delete accountShares[accountIndex[marketing]];
			accountIndex[marketing]=newMarketingAccount;
			accountShares[newMarketingAccount]=newShare;
		}
		ShareAccountAdded(newMarketingAccount,newShare);
		MarketingChanged(newMarketingAccount);
	}
	
	function addShareAccount(address newShareAccount, uint newShare) Unlocked {
		if (msg.sender!=owner) throw;
		accountIndex[accountCount]=newShareAccount;
		accountShares[newShareAccount]=newShare;
		accountBalances[newShareAccount]=0;
		accountCount++;
		ShareAccountAdded(newShareAccount,newShare);
	}
	
	function removeShareAccount(address shareAccountToRemove) Unlocked {
		if (msg.sender!=owner) throw;
		delete accountShares[shareAccountToRemove];
		delete accountBalances[shareAccountToRemove];
		for (uint i=0;i<accountCount;i++)
			if (accountIndex[i]==shareAccountToRemove){
				for (uint j=i;j<accountCount-1;j++)
					accountIndex[j]=accountIndex[j+1];
				accountCount--;
				delete accountIndex[accountCount];
				i=accountCount;
			}
		ShareAccountRemoved(shareAccountToRemove);
	}
	
	function passToServise() Locked payable {
		if (msg.value<=0) throw;
		accountBalances[accountIndex[marketing]]+=msg.value;
		PaidToMarketing(msg.value);
	}
	
	function passToShare() Locked payable {
		if (msg.value<=0) throw;
		uint totalShares=0;
		for (uint i=0;i<accountCount;i++)
			totalShares+=accountShares[accountIndex[i]];
		for (i=0;i<accountCount;i++)
			accountBalances[accountIndex[i]]+=msg.value*accountShares[accountIndex[i]]/totalShares;
		PaidToShare(msg.value);
	}
	
	function withdraw(uint _amount) Locked payable {
		uint amount=_amount;
		if (accountBalances[msg.sender]<=0) throw;
		if (amount<=0) throw;
		if (accountBalances[msg.sender]-amount<0) throw;
		msg.sender.transfer(amount);
		accountBalances[msg.sender]-=amount;
		Withdraw(msg.sender,amount);
	}
}