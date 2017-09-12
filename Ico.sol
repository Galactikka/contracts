pragma solidity ^0.4.2;
contract Token { function transfer(address, uint){ } }
contract Distributor { 
	function passToShare() payable public { }
	function passToMarketing() payable public { }
}
contract NextIco { 
	function start(address) payable public { } 
}

/*
 * ICO Contract
 *
 * Collects ether from participants when started
 * Can be started and stopped by timer, also can be started by previous ico oversale (Same contract)
 * Can be stopped by oversale and trigger next ico
 * Can be paused by Coordinators
 * Can return money if min cap is not reached
 * Sends tokens instantly after receiving incoming payment
 *
 * Designed to transfer collected funds to Distributor account (custom Multisignature wallet also can be used)
 * 
 * Lifecycle: deploy, add participants, set params, lock, take participance until end by time or hardcap, check results
 */


contract Ico {
	Distributor public distributorContract;
	Token public tokenReward;
	NextIco public next;
	address public previousIco;
	bool public isLinkedToNext;
	bool public needTransferFundsToMarketing;
	bool public canWithdrawBeforeEnd;
		   
	uint public minCap;
	uint public hardCap;
	
	uint public amountRaised;
	uint public tokenPrice;
	
	uint public startTime; 
	uint public endTime;
	uint public discount; 
	uint public minPurchase; 
	uint public tokenCount; 
	uint public tokenSold;	 
	
	bool public isLocked;
	bool public isPaused;
	
	address public owner;
	
	// Holds balances of participants
	mapping (address => uint) public participantAccountTokens;
	mapping (address => uint) public participantAccountSpent;
	mapping (uint => address) public participantAccountIndex;
	uint public participantAccountCount;
	
	// Holds agreements for pause/resume of Coordinators
	mapping (address => bool) public coordinatorAccountAgreeForResume;
	mapping (address => bool) public coordinatorAccountAgreeForPause;
	mapping (uint => address) public coordinatorAccountIndex;
	uint public coordinatorAccountCount;
	uint public minCoordinatorCount;
		
	bool public hardCapReached;
	bool public minCapReached;
	bool public minCapNotReached;
	bool public finished;
	
	bool public startedByPreviousOversale;
	
	event HardCapReached();
	event MinCapReached();
	event MinCapNotReached();
	
	event OwnerChanged(address newOwner);
	
	event Paused();
	event Resumed();
	
	event Lock();	
	
	event Participance(address participant, uint value, uint tokens);	
	
	event SoldOut();
	event NextRoundStarted(NextIco nextIco);
	event StartedOnPreviousRoundCompletion(address previousIco);
	
	modifier Unlocked() { if (!isLocked) _; }
	modifier Locked() { if (isLocked) _; }
	modifier Unpaused() { if (!isPaused) _; }
	modifier Open() { if (((startedByPreviousOversale) || (now>=startTime)) && ((!finished) && (now<=endTime))) _; }
	modifier Closed() { if ( !(((startedByPreviousOversale) || (now>=startTime)) && ((!finished) && (now<=endTime)))) _; }
	
	function isOpen() private returns(bool){ return (((startedByPreviousOversale) || (now>=startTime)) && ((!finished) && (now<=endTime))); }
	function isClosed() private returns(bool) { return ( !(((startedByPreviousOversale) || (now>=startTime)) && ((!finished) && (now<=endTime)))); }
		
	// Primary constructor. Ico params mostly passed by setParams()
	function Ico(
		address _distributor,
		address _tokenReward,
		
		uint _tokenPrice,
	
		uint  _minCoordinatorCount
	) {
		owner=msg.sender;
		
		distributorContract=Distributor(_distributor);
		tokenPrice=_tokenPrice;
		
		tokenReward = Token(_tokenReward);
		
		minCoordinatorCount=_minCoordinatorCount;
		
		amountRaised=0;
		tokenSold=0;
		isLocked = false;
		isPaused = false;
		hardCapReached = false;
		minCapReached = false;
		minCapNotReached = false;
		finished = false;	
		startedByPreviousOversale = false;
	}
	
	// Specifies ICO params
	function setParams(
		uint _minCap,
		uint _hardCap,
		
		uint _tokenCount,
		uint _startTime,
		uint _endTime,
		uint _discount,
		uint _minPurchase,
		
		NextIco _nextIco,
		address _previousIco,
		bool _isLinkedToNext,
		bool _needTransferFundsToMarketing,
		bool _canWithdrawBeforeEnd
	) Unlocked {
		if (msg.sender!=owner) throw;
		minCap=_minCap;
		hardCap=_hardCap;
		
		tokenCount=_tokenCount;
		startTime=_startTime; 
		endTime=_endTime;
		discount=_discount; 
		minPurchase=_minPurchase; 
		
		next = NextIco(_nextIco);
		previousIco = _previousIco;
		isLinkedToNext = _isLinkedToNext;		
		needTransferFundsToMarketing=_needTransferFundsToMarketing;
		canWithdrawBeforeEnd=_canWithdrawBeforeEnd;
	}
	
	function changeOwner(address newOwner) {
		if (isLocked) throw;
		if (msg.sender!=owner) throw;
		owner=newOwner;
		OwnerChanged(owner);
	}
	
	// Locks. Before Lock you can change ICO params and Coordinaltor list, but can't take participance.
	// With lock ICO can go
	function lock() Unlocked {
		if (msg.sender!=owner) throw;
		isLocked=true;
		Lock();
	}
	
	function addCoordinator(address newCoordinator) Unlocked {
		if (msg.sender!=owner) throw;
		coordinatorAccountIndex[coordinatorAccountCount]=newCoordinator;
		coordinatorAccountAgreeForPause[newCoordinator]=false;
		coordinatorAccountAgreeForResume[newCoordinator]=false;
		coordinatorAccountCount++;
	}
	
	function removeCoordinator(address coordinator) Unlocked {
		if (msg.sender!=owner) throw;
		delete coordinatorAccountAgreeForResume[coordinator];
		delete coordinatorAccountAgreeForPause[coordinator];
		for (uint i=0;i<coordinatorAccountCount;i++)
			if (coordinatorAccountIndex[i]==coordinator){
				for (uint j=i;j<coordinatorAccountCount-1;j++)
					coordinatorAccountIndex[j]=coordinatorAccountIndex[j+1];
				coordinatorAccountCount--;
				delete coordinatorAccountIndex[coordinatorAccountCount];
				i=coordinatorAccountCount;
			}
	}
	
	function coordinatorSetAgreeForPause(bool value) {
		bool found=false;
		for (uint i=0;i<coordinatorAccountCount;i++)
			if (coordinatorAccountIndex[i]==msg.sender){
				found=true;
				i=coordinatorAccountCount;
			}
		if (!found) throw;
		coordinatorAccountAgreeForPause[msg.sender]=value;
	}
	
	function coordinatorSetAgreeForResume(bool value) {
		bool found=false;
		for (uint i=0;i<coordinatorAccountCount;i++)
			if (coordinatorAccountIndex[i]==msg.sender){
				found=true;
				i=coordinatorAccountCount;
			}
		if (!found) throw;
		coordinatorAccountAgreeForResume[msg.sender]=value;
	}
	
	// Coordinator can pause or resume opened ICO. First they need to agree with pause or resume
	// When minimal count of coordinators are agree, any of them can call pause or resume
	// In pause mode participance is locked
	function pause() {
		if (isClosed()) throw;
		if (isPaused) throw;
		uint agree=0;
		for (uint i=0;i<coordinatorAccountCount;i++)
			if (coordinatorAccountAgreeForPause[coordinatorAccountIndex[i]]==true)
				agree++;
		if (agree<minCoordinatorCount) throw;
		isPaused=true;
		for (i=0;i<coordinatorAccountCount;i++)
			coordinatorAccountAgreeForPause[coordinatorAccountIndex[i]]=false;
		Paused();
	}
	
	function resume() {
		if (isClosed()) throw;
		if (!isPaused) throw;
		uint agree=0;
		for (uint i=0;i<coordinatorAccountCount;i++)
			if (coordinatorAccountAgreeForResume[coordinatorAccountIndex[i]]==true)
				agree++;
		if (agree<minCoordinatorCount) throw;
		isPaused=false;
		for (i=0;i<coordinatorAccountCount;i++)
			coordinatorAccountAgreeForResume[coordinatorAccountIndex[i]]=false;
		Resumed();
	}
	
	function estimateTokens(uint amount, uint discount) private returns (uint) {
		return amount*100/tokenPrice/(100-discount);
	}
	
	// To take participance wallets just send money to this contract when ICO is opened
	function () payable {
		if (!isLocked) throw;
		if (isPaused) throw;
		if (isClosed()) throw;
		participance (msg.sender, msg.value);
	}
	
	// If we go into oversale and there is linked next ico, contract passes the rest of money to it,
	// forcing it to start before its start time and sell some tokens to current participant
	// which initiated oversale there
	function participance (address sender, uint value) payable {
		uint amount = value;
		uint amountToPassToNext = 0;
		if (amount<minPurchase) throw;
		if (amountRaised+amount>hardCap) {
			if (!isLinkedToNext) throw;
			else {
				amountToPassToNext=amountRaised+amount-hardCap;
				amount=amount-amountToPassToNext;				
			}
		}
		
		uint tokens=estimateTokens(amount, discount);
		amountRaised+=amount;
		bool found=false;
		for (uint i=0;((i<participantAccountCount)&&(!found));i++)
			if (participantAccountIndex[i]==sender){
				found=true;					
				i=participantAccountCount;
			}
		if (!found){
			participantAccountIndex[participantAccountCount]=sender;
			participantAccountTokens[sender]=0;
			participantAccountSpent[sender]=0;
			participantAccountCount++;
		}
		participantAccountSpent[sender]+=amount;
		participantAccountTokens[sender]+=tokens;
		Participance(sender,amount,tokens);
		tokenSold+=tokens;
		checkIfCapsReached();
		checkIfNeedToStartNextRound(amountToPassToNext,sender);
		transferTokens();
	}
	
	// Triggers next ICO contract to start and sell some tokens if needed and configured
	function checkIfNeedToStartNextRound(uint amountToPassToNext, address sender) private{
		if (amountToPassToNext>0){
			finished=true;
			SoldOut();
			if (isLinkedToNext){
				next.start.value(amountToPassToNext)(sender);
				NextRoundStarted(next);
			}
		} 
	}
	
	function checkIfCapsReached() private {
		if ( (amountRaised>=hardCap) && (!hardCapReached) ) {
			hardCapReached=true;
			finished=true;
			HardCapReached();
		}
		else if ( (amountRaised>=minCap) && (!minCapReached) ) {
			minCapReached=true;
			MinCapReached();
		}
	}
	
	// Returns money to participants
	function cancelIco () private {
		for (uint i=0;i<participantAccountCount;i++)
			if (participantAccountSpent[participantAccountIndex[i]]>0){
				participantAccountIndex[i].transfer(participantAccountSpent[participantAccountIndex[i]]);
				participantAccountSpent[participantAccountIndex[i]]=0;
			}
	}
	
	// Transfer money to Distributor by Marketing way (only to Marketing)
	function transferFundsToMarketing (uint value) private {
		distributorContract.passToMarketing.value(value)();
	}
	
	// Transfer money to Distributor by share way (to share between all wallets by selected scheme)
	function transferFunds (uint value) private {
		distributorContract.passToShare.value(value)();
	}
	
	function transferTokens () private {
		for (uint i=0;i<participantAccountCount;i++)
			if (participantAccountTokens[participantAccountIndex[i]]>0){
				tokenReward.transfer(participantAccountIndex[i], participantAccountTokens[participantAccountIndex[i]]);
				participantAccountTokens[participantAccountIndex[i]]=0;
			}
	}
	
	function setFinishedFlags() private {
		if ( (now>endTime) && (!finished) ) {
			finished=true;
		}
	}
	
	// Anyone can call contract to check results when ICO is closed
	// value param is a value to pass to distributor. There's nothing wrong if anoyone will pass money
	function checkResults(uint value) payable {	
		if (isOpen()) throw;
		setFinishedFlags();
		transferTokens();
		if (amountRaised<minCap){
			if (!minCapReached){
				minCapReached=true;
				MinCapNotReached();
			}
			cancelIco();
		} else {
			if (value>0){
				if (needTransferFundsToMarketing)
					transferFundsToMarketing(value);
				else
					transferFunds(value);
			}
		}
	}
	
	// Withdraw funds before completion (suitable for Pre-ICO)
	function withdraw(uint value) payable {	
		if ((amountRaised<minCap)||(!canWithdrawBeforeEnd)) throw;
		bool found=(msg.sender==owner);
		for (uint i=0;(i<coordinatorAccountCount)&&(!found);i++)
			if (coordinatorAccountIndex[i]==msg.sender){
				found=true;
			}
		if (!found) throw;
		if (value>0){
			if (needTransferFundsToMarketing)
				transferFundsToMarketing(value);
			else
				transferFunds(value);
		}
	}	
	
	// Enter point to start from previous ICO. Passed money are used to sell some tokens to sender param
	function start(address sender) public payable{ 
		if (msg.sender!=previousIco) throw;
		if (!isLocked) throw;
		if (isPaused) throw;
		if (isOpen()) throw;
		if (startedByPreviousOversale) throw;
		startedByPreviousOversale=true;		
		StartedOnPreviousRoundCompletion(previousIco);
		participance (sender, msg.value);
	}
}