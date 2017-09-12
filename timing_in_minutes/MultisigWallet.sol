pragma solidity ^0.4.2;

contract MultisigWallet {
	
	uint public amountReceived;
	
	bool public isLocked;
	
	address public owner;
	
	// Holds agreements for ougoing transfer for Coordinators
	mapping (address => uint) public coordinatorAgreeForTransferFor;
	mapping (address => address) public coordinatorAgreeForTransferTo;
	mapping (uint => address) public coordinatorAccountIndex;
	uint public coordinatorAccountCount;
	uint public minCoordinatorCount;
	
	event OwnerChanged(address newOwner);
	
	event Lock();
		
	// Primary constructor
	function MultisigWallet(	
		uint  _minCoordinatorCount
	) {
		owner=msg.sender;
		
		minCoordinatorCount=_minCoordinatorCount;
		
		amountReceived=0;		
		isLocked = false;		
	}
	
	function changeOwner(address newOwner) {
		if (isLocked) throw;
		if (msg.sender!=owner) throw;
		owner=newOwner;
		OwnerChanged(owner);
	}
	
	// Locks. Before Lock you can change Coordinaltor list, but can't perform transfers
	function lock() {
		if (isLocked) throw;
		if (msg.sender!=owner) throw;
		isLocked=true;
		Lock();
	}
	
	function addCoordinator(address newCoordinator) {
		if (isLocked) throw;
		if (msg.sender!=owner) throw;
		coordinatorAccountIndex[coordinatorAccountCount]=newCoordinator;
		coordinatorAgreeForTransferTo[newCoordinator]=0x0;
		coordinatorAgreeForTransferFor[newCoordinator]=0;
		coordinatorAccountCount++;
	}
	
	function removeCoordinator(address coordinator) {
		if (isLocked) throw;
		if (msg.sender!=owner) throw;
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
	
	function coordinatorSetAgreeForTransferTo(address receiver) {
		bool found=false;
		for (uint i=0;i<coordinatorAccountCount;i++)
			if (coordinatorAccountIndex[i]==msg.sender){
				found=true;
				i=coordinatorAccountCount;
			}
		if (!found) throw;
		coordinatorAgreeForTransferTo[msg.sender]=receiver;
	}
	
	function coordinatorSetAgreeForTransferFor(uint value_) {
		uint value = value_;
		bool found=false;
		for (uint i=0;i<coordinatorAccountCount;i++)
			if (coordinatorAccountIndex[i]==msg.sender){
				found=true;
				i=coordinatorAccountCount;
			}
		if (!found) throw;
		coordinatorAgreeForTransferFor[msg.sender]=value;
	}
	
	// Attempts to make outgoing transfer of specified value to specified receiver
	// Transfer will be processed if required count of coordinators are agree
	function transfer(uint value_, address receiver) payable {
		uint value = value_;
		if (!isLocked) throw;
		if (value > amountReceived) throw;
		
		bool found=false;
		if (msg.sender==owner) found=true;
		for (uint i=0;(!found)&&(i<coordinatorAccountCount);i++)
			if (coordinatorAccountIndex[i]==msg.sender){
				found=true;
			}
		if (!found) throw;
		
		uint agree=0;
		for (i=0;i<coordinatorAccountCount;i++)
			if ((coordinatorAgreeForTransferFor[coordinatorAccountIndex[i]]>=value) &&
			(coordinatorAgreeForTransferTo[coordinatorAccountIndex[i]]==receiver))
				agree++;
		if (agree<minCoordinatorCount) throw;
		for (i=0;i<coordinatorAccountCount;i++)
			if ((coordinatorAgreeForTransferFor[coordinatorAccountIndex[i]]>=value) &&
			(coordinatorAgreeForTransferTo[coordinatorAccountIndex[i]]==receiver))
				coordinatorAgreeForTransferFor[coordinatorAccountIndex[i]]-=value;
		amountReceived-=value;
		receiver.transfer(value);
	}
	
	function () payable {
		if (!isLocked) throw;
		amountReceived+=msg.value;
	}
	
	function passToServise() payable {
		if (!isLocked) throw;
		if (msg.value<=0) throw;
		amountReceived+=msg.value;
	}
	
	function passToShare() payable {
		if (!isLocked) throw;
		if (msg.value<=0) throw;
		amountReceived+=msg.value;
	}
}