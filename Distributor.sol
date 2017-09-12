pragma solidity ^0.4.2;

 /*
  * Distributor is used to show participants the exact way how the money will be spent
  * It allows to pass all the incoming transfer only to Marketing or share it between all Share accounts 
  * by specific scheme
  *
  * With owner account you specify the list of Share accounts with share values
  * then you lock Distributor. Once locked, contract cannot be unlocked and reconfigured
  *
  * For example if you add Account1 with share 10, Account2 with share 15, Account3 with share 25
  * passToShare will share 20% to Account1, 30% to Account2 and 70% to Account3
  * and passToMarketing will pass 100% of incoming transfer to Marketing
  *
  * Money is not transferred immediately, instead it's loaded to internal ballance
  * And then the Share accounts can make withdraw calls to withdraw money from balance at any time they want
  */

contract Distributor {
	// Public contract variables
	address public owner;
	uint public marketing = 0;
	mapping (address => uint) public accountBalances;
	mapping (address => uint) public accountShares;
	mapping (uint => address) public accountIndex;
	uint public accountCount;
	bool public isLocked;
	
	// Events that contract can fire
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
	
	// Changes the ownership when unlocked
	function changeOwner(address newOwner) {
		if (isLocked) throw;
		if (msg.sender!=owner) throw;
		owner=newOwner;
		OwnerChanged(owner);
	}
	
	// Locks contract to prevent further reconfiguration. Lock can be done by owner only
	function lock() Unlocked {
		if (msg.sender!=owner) throw;
		isLocked=true;
		Lock();
	}
	
	// Allows to set Marketing address. While marketing takes part in overal share process,
	// it can receive Marketing-related payments in 100% amount
	function setMarketing(address newMarketingAccount, uint newShare) Unlocked {
		if (msg.sender!=owner) throw;
		if (marketing == 0){
			// If marketing hasn't been defined previously, it's added to Share account list
			marketing=accountCount;
			accountIndex[marketing]=newMarketingAccount;
			accountShares[newMarketingAccount]=newShare;
			accountBalances[newMarketingAccount]=0;
			accountCount++;
		} else {
			// If marketing has been defined previously, it will be replaced with new address provided in this call
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
	
	// Adds new account to Share list
	function addShareAccount(address newShareAccount, uint newShare) Unlocked {
		if (msg.sender!=owner) throw;
		accountIndex[accountCount]=newShareAccount;
		accountShares[newShareAccount]=newShare;
		accountBalances[newShareAccount]=0;
		accountCount++;
		ShareAccountAdded(newShareAccount,newShare);
	}
	
	// Removes account from share list. Unsets Marketing account if it has been passed to remove
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
				if (i==marketing)
					marketing=0;
				i=accountCount;				
			}
		ShareAccountRemoved(shareAccountToRemove);
	}
	
	// Payable method to pass funds to Marketing account directly
	function passToServise() Locked payable {
		if (msg.value<=0) throw;
		accountBalances[accountIndex[marketing]]+=msg.value;
		PaidToMarketing(msg.value);
	}
	
	// Payale method to pass funds to be shared by configures scheme between Share accounts according to their share amounts
	function passToShare() Locked payable {
		if (msg.value<=0) throw;
		uint totalShares=0;
		for (uint i=0;i<accountCount;i++)
			totalShares+=accountShares[accountIndex[i]];
		for (i=0;i<accountCount;i++)
			accountBalances[accountIndex[i]]+=msg.value*accountShares[accountIndex[i]]/totalShares;
		PaidToShare(msg.value);
	}
	
	// Withdraw funds from Share account balance to Share account
	// Identifies Share account by sender
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