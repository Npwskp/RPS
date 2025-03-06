# Changes from RPS to RPSLS Smart Contract

## 1. Added Game Reset Functionality
- Now, a reset function allows the game to be restarted after a round has been completed, of refund happened.

## 2. Implemented Whitelisted Players
- Only specific accounts (limited to four addresses) are allowed to participate in the game.
- This ensures only authorized users can play, preventing unwanted access.

## 3. Upgraded Game from RPS to RPSLS
- The classic Rock-Paper-Scissors (RPS) game has been expanded into Rock-Paper-Scissors-Lizard-Spock (RPSLS).
- Fix logic for check winner to suitable for RPSLS

## 4. Prevented Front-Running with Commit-Reveal Mechanism
- Players were hesitant to choose first due to the risk of front-running (where an opponent can see their choice before making their own).
- A commit-reveal scheme has been introduced:
  - Players first submit a hashed version of their choice.
  - Once both players have committed, they reveal their choices.
  - This ensures fairness and prevents cheating.

## 5. Added Refund for Unmatched Players
- Previously, Player 0's funds could be locked indefinitely if no Player 1 joined.
- Now, a refund mechanism allows players to reclaim money after 10 minute.

## 6. Added Refund for Unfinished Games
- If both players joim, submits their choice, and only one is reveal the game cannot proceed.
- So we give the reward for user that already reveal after pass 20 minute
