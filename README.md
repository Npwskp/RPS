# Changes from RPS to RPSLS Smart Contract

## 1. Added Game Reset Functionality
- Now, a reset function allows the game to be restarted after a round has been completed, of refund happened.

```solidity
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
```

## 2. Implemented Whitelisted Players
- Only specific accounts (limited to four addresses) are allowed to participate in the game.
- This ensures only authorized users can play, preventing unwanted access.

```solidity
constructor() {
  // Initialize whitelisted addresses
  whitelistedAddresses[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
  whitelistedAddresses[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
  whitelistedAddresses[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
  whitelistedAddresses[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
}
```

## 3. Upgraded Game from RPS to RPSLS
- The classic Rock-Paper-Scissors (RPS) game has been expanded into Rock-Paper-Scissors-Lizard-Spock (RPSLS).
- Fix logic for check winner to suitable for RPSLS

```solidity
// 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Lizard, 4 - Spock, 5 - Undefined
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
```

## 4. Prevented Front-Running with Commit-Reveal Mechanism
- Players were hesitant to choose first due to the risk of front-running (where an opponent can see their choice before making their own).
- also add get hash with salt to ensure security
- A commit-reveal scheme has been introduced:
  - Players first submit a hashed version of their choice.
  - Once both players have committed, they reveal their choices.
 
```solidity
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
```

## 5. Added Refund for Unmatched Players
- Previously, Player 0's funds could be locked indefinitely if no Player 1 joined.
- Now, a refund mechanism allows players to reclaim money after 10 minute.

```solidity
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

```

## 6. Added Refund for Unfinished Games
- If both players joim, submits their choice, and only one is reveal the game cannot proceed.
- So we give the reward for user that already reveal after pass 20 minute

```solidity
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
```
