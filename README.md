# FiveM Camera Bounty

#### `bara-camera-bounty`

**Camera Bounty** is a resource for FiveM that adds photography bounties to the game, encouraging players to explore the map and take photos of wildlife and nature.

Bounty zones appear on the map periodically. Players are paid based on their efforts — including whether they managed to photograph any animals and how far into the bounty zone they explored.

Built for **QBox** and uses **Renewed-Banking**.

---

## Configuration

Configuration is located in `/config/config.lua`.

| Config Item            | Example                                                     | Description                                                                 |
|------------------------|-------------------------------------------------------------|-----------------------------------------------------------------------------|
| `debug`                | `true`                                                      | Enables debug messages in the client and server consoles, and shows a visual cone when a photo is taken. |
| `COMPANY_NAME`         | `"Photo Company"`                                           | The name of the company that pays the player (used in bank transactions).   |
| `BANK_DEPOSIT_MESSAGE` | `"Photo Bounty Reward"`                                     | The reference text shown in the player's bank transaction.                  |
| `BANK_DEPOSIT_COMPANY` | `"Photo Company"`                                           | The name of the bank account sending the payment.                           |
| `MIN_PAYOUT`           | `50`                                                        | Minimum payout for an eligible photo.                                       |
| `MAX_PAYOUT`           | `300`                                                       | Maximum payout for an eligible photo.                                       |
| `PHOTOGRAPHY_ZONES`    | `{ { x = 1172.4, y = 2696.8, z = 37.1, radius = 250.0 }, }` | Locations eligible to become active bounty zones.                           |