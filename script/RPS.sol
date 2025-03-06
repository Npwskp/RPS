// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS is CommitReveal, TimeUnit {
    uint public numPlayer = 0;
    uint public reward = 0;
    // 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Lizard, 4 - Spock, 5 - Undefined
    mapping (address => uint) public player_choice;
    mapping(address => bool) public player_not_played;
    mapping(address => bool) public player_not_revealed;
    address[] public players;
    uint public numInput = 0;
    uint public numPlayerReveal = 0;
    
    // New state variables
    mapping(address => bool) public whitelistedAddresses;
    
    // Events
    event GameReset();
    event RefundRequested(address player);
    event RefundProcessed(address player, uint amount);
    event GameResult(address winner, uint choice1, uint choice2);
    
    constructor() {
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
            startTime = block.timestamp;
        }
    }

    function getChoiceHash(uint256 choice, string memory salt) public pure returns (bytes32) {
        require(choice >= 0 && choice <= 4, "Invalid choice"); // 0-4 for RPSLS

        bytes32 _salt = keccak256(abi.encodePacked(salt)); 
        bytes32 _choice = bytes32(choice); 

        return getHash(keccak256(abi.encodePacked(_choice, _salt))); 
    }

    function commitChoice(bytes32 commitHash) public {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);
        commit(commitHash);
    }

    function revealChoice(uint choice, string memory salt) public {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);
        require(choice >= 0 && choice <= 4, "Invalid choice"); // 0-4 for RPSLS
        
        bytes32 _salt = keccak256(abi.encodePacked(salt)); 
        bytes32 _choice = bytes32(choice); 
        bytes32 revealHash = keccak256(abi.encodePacked(_choice, _salt));
        reveal(revealHash);
        
        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        player_not_revealed[msg.sender] = false;
        numInput++;
        numPlayerReveal++;
        
        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function refundNotRevealCase() public {
        require(numInput == 2);
        require(numPlayerReveal < 2);
        require(elapsedMinutes() >= 20 minutes);
        
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if (player_not_revealed[players[0]]) {
            account1.transfer(reward);
        } else {
            account0.transfer(reward);
        }
        
        _resetGame();
    }

    function refundNotEnoughPlayerCase() public {
        require(numInput < 2);
        require(elapsedMinutes() >= 10 minutes);

        for (uint i = 0; i < numPlayer; i++) {
            address payable player = payable(players[i]);
            if (player_not_played[player]) {
                player.transfer(reward / numPlayer);
            }
        }

        _resetGame();
    }


    function _resetGame() public {
        for(uint i = 0; i < players.length; i++) {
            player_not_played[players[i]] = false;
            player_choice[players[i]] = 5; // Reset to undefined
            player_not_revealed[players[i]] = true;
        }
        players = new address[](0);
        numPlayer = 0;
        numInput = 0;
        numPlayerReveal = 0;
        reward = 0;
        startTime = 0;
        
        emit GameReset();
    }

    function _checkWinner(uint p0Choice, uint p1Choice) private pure returns (uint8) {
        if (p0Choice == p1Choice) {
            return 0; // equal
        }

        // Check if p0 wins (p1Choice is 1 or 2 steps behind in the cycle)
        if ((p0Choice + 3) % 5 == p1Choice || (p0Choice + 4) % 5 == p1Choice) {
            return 1; // p0 wins
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
        _resetGame();
    }
}
