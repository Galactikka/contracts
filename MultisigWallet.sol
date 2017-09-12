pragma solidity ^0.4.2;

/* Custom multisignature wallet allows to spent collected funds with agreement of required count of Coordinators
 * Comes in unlocked state after creation, when owner can configure list of Corrdinators or change the ownership
 * In locked state account can withdraw funds. Once locked, contract cannot be unlocked and reconfigured
 *
 * At same time each coordinator can tell the contract about his or her agreement only for single transfer
 * 
 * Each coordinator can configure, which amount he or she is agree to spent and to which Ethereum address
 * Any of coordinator can trigger transfer attempt
 * On transfer attempt wallet counts, how many coordinators agree with the trasnfer, and if required count is reached, transfer is performed
 */

contract MultisigWallet {
	
	// Stores current ballance
	uint public balance;
	
	// Stores lock state
	bool public isLocked;
	
	// Stores ownership
	address public owner;
	
	// Holds agreements for ougoing transfer for Coordinators
	mapping (address => uint) public coordinatorAgreeForTransferFor;
	mapping (address => address) public coordinatorAgreeForTransferTo;
	mapping (uint => address) public coordinatorAccountIndex;
	uint public coordinatorAccountCount;
	
	// Keeps required count of coordinators to perform transfer
	uint public minCoordinatorCount;
	
	// Fires when ownership is changed
	event OwnerChanged(address newOwner);
	
	// Fires on entering lock state
	event Lock();
		
	// Primary constructor
	function MultisigWallet(	
		uint  _minCoordinatorCount
	) {
		owner=msg.sender;		
		minCoordinatorCount=_minCoordinatorCount;		
		balance=0;		
		isLocked = false;		
	}
	
	// Changes ownership
	function changeOwner(address newOwner) {
		if (isLocked) revert();
		if (msg.sender!=owner) revert();
		owner=newOwner;
		OwnerChanged(owner);
	}
	
	// Locks. Before Lock you can change Coordinaltor list, but can't perform transfers
	function lock() {
		if (isLocked) revert();
		if (msg.sender!=owner) revert();
		isLocked=true;
		Lock();
	}
	
	// Adds new coordinator
	function addCoordinator(address newCoordinator) {
		if (isLocked) revert();
		if (msg.sender!=owner) revert();
		coordinatorAccountIndex[coordinatorAccountCount]=newCoordinator;
		coordinatorAgreeForTransferTo[newCoordinator]=0x0;
		coordinatorAgreeForTransferFor[newCoordinator]=0;
		coordinatorAccountCount++;
	}
	
	// Removes exist coordinator from list of coordinators
	function removeCoordinator(address coordinator) {
		if (isLocked) revert();
		if (msg.sender!=owner) revert();
		delete coordinatorAgreeForTransferTo[coordinator];
		delete coordinatorAgreeForTransferFor[coordinator];
		for (uint i=0;i<coordinatorAccountCount;i++)
			if (coordinatorAccountIndex[i]==coordinator){
				for (uint j=i;j<coordinatorAccountCount-1;j++)
					coordinatorAccountIndex[j]=coordinatorAccountIndex[j+1];
				coordinatorAccountCount--;
				delete coordinatorAccountIndex[coordinatorAccountCount];
				i=coordinatorAccountCount;
			}
	}
	
	// Accepts the vote of coordinator for upcoming transfer: which amount he or she is agree and to which address
	function coordinatorSetAgreeForTransfer(address receiver, uint value_) {
		uint value = value_;
		bool found=false;
		for (uint i=0;i<coordinatorAccountCount;i++)
			if (coordinatorAccountIndex[i]==msg.sender){
				found=true;
				i=coordinatorAccountCount;
			}
		if (!found) revert();
		coordinatorAgreeForTransferTo[msg.sender]=receiver;
		coordinatorAgreeForTransferFor[msg.sender]=value;
	}
	
	// Attempts to make outgoing transfer of specified value to specified receiver
	// Transfer will be processed if required count of coordinators are agree
	function transfer(uint value_, address receiver) payable {
		uint value = value_;
		if (!isLocked) revert();
		if (value > balance) revert();
		
		bool found=false;
		if (msg.sender==owner) found=true;
		for (uint i=0;(!found)&&(i<coordinatorAccountCount);i++)
			if (coordinatorAccountIndex[i]==msg.sender){
				found=true;
			}
		if (!found) revert();
		
		uint agree=0;
		for (i=0;i<coordinatorAccountCount;i++)
			if ((coordinatorAgreeForTransferFor[coordinatorAccountIndex[i]]>=value) &&
			(coordinatorAgreeForTransferTo[coordinatorAccountIndex[i]]==receiver))
				agree++;
		if (agree<minCoordinatorCount) revert();
		for (i=0;i<coordinatorAccountCount;i++)
			if ((coordinatorAgreeForTransferFor[coordinatorAccountIndex[i]]>=value) &&
			(coordinatorAgreeForTransferTo[coordinatorAccountIndex[i]]==receiver))
				coordinatorAgreeForTransferFor[coordinatorAccountIndex[i]]-=value;
		balance-=value;
		receiver.transfer(value);
	}
	
	// Common interface for incoming transfers
	function () payable {
		if (!isLocked) revert();
		balance+=msg.value;
	}
	
	// Virtual interface for incoming transfers that emulates our Distributor contract
	function passToServise() payable {
		if (!isLocked) revert();
		if (msg.value<=0) revert();
		balance+=msg.value;
	}
	
	// Virtual interface for incoming transfers that emulates our Distributor contract
	function passToShare() payable {
		if (!isLocked) revert();
		if (msg.value<=0) revert();
		balance+=msg.value;
	}
}