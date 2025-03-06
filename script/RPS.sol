// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    // 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Lizard, 4 - Spock, 5 - Undefined
    mapping (address => uint) public player_choice;
    mapping(address => bool) public player_not_played;
    address[] public players;
    uint public numInput = 0;
    
    // New state variables
    uint public startTime;
    uint public constant TIMEOUT_DURATION = 1 hours;
    mapping(address => bool) public whitelistedAddresses;
    CommitReveal public commitRevealContract;
    TimeUnit public timeUnitContract;
    
    // Events
    event GameReset();
    event RefundRequested(address player);
    event RefundProcessed(address player, uint amount);
    event GameResult(address winner, uint choice1, uint choice2);
    
    constructor(address _commitRevealAddress, address _timeUnitAddress) {
        commitRevealContract = CommitReveal(_commitRevealAddress);
        timeUnitContract = TimeUnit(_timeUnitAddress);
        // Initialize whitelisted addresses
        whitelistedAddresses[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        whitelistedAddresses[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        whitelistedAddresses[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        whitelistedAddresses[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
    }

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(whitelistedAddresses[msg.sender], "Address not whitelisted");
        if (numPlayer > 0) {
            require(msg.sender != players[0]);
        }
        require(msg.value == 1 ether);
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
        
        if (numPlayer == 1) {
            startTime = timeUnitContract.startTime();
        }
    }

    function commitChoice(bytes32 commitHash) public {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);
        commitRevealContract.commit(commitHash);
    }

    function revealChoice(uint choice, bytes32 revealHash) public {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);
        require(choice >= 0 && choice <= 4, "Invalid choice"); // 0-4 for RPSLS
        
        commitRevealContract.reveal(revealHash);
        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        numInput++;
        
        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function requestRefund() public {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);
        require(timeUnitContract.elapsedSeconds() >= TIMEOUT_DURATION, "Timeout not reached");
        
        uint refundAmount = 1 ether;
        player_not_played[msg.sender] = false;
        reward -= refundAmount;
        
        emit RefundRequested(msg.sender);
        payable(msg.sender).transfer(refundAmount);
        emit RefundProcessed(msg.sender, refundAmount);
    }

    function resetGame() public {
        require(numInput == 2 || (timeUnitContract.elapsedSeconds() >= TIMEOUT_DURATION && numPlayer == 2));
        
        // Reset all state variables
        for(uint i = 0; i < players.length; i++) {
            player_not_played[players[i]] = false;
            player_choice[players[i]] = 5; // Reset to undefined
        }
        players = new address[](0);
        numPlayer = 0;
        numInput = 0;
        reward = 0;
        startTime = 0;
        
        emit GameReset();
    }

    function _checkWinner(uint p0Choice, uint p1Choice) private pure returns (uint8) {
        if (p0Choice == 5 || p1Choice == 5) {
            return 0; // Undefined results in tie
        }

        if (p0Choice == p1Choice) {
            return 0; // equal
        }

        if((p0Choice + 1) % 5 == p1Choice || (p0Choice - 2) % 5 == p1Choice) {
            return 1; // p0win
        }

        return 2; // p1win
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);
        
        uint8 result = _checkWinner(p0Choice, p1Choice);
        
        if (result == 1) {
            account0.transfer(reward);
            emit GameResult(account0, p0Choice, p1Choice);
        }
        else if (result == 2) {
            account1.transfer(reward);
            emit GameResult(account1, p0Choice, p1Choice);
        }
        else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
            emit GameResult(address(0), p0Choice, p1Choice); // Tie game
        }
    }
}
