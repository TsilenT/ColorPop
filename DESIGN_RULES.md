# Match-3 Game Mechanics & Design Rules

This document outlines the current logic and constraints of the game as implemented.

## I. Game Parameters
- **Board Size:** 8 columns x 8 rows (columns expandable to 10 via Grid Expansion upgrade).
- **Limit:** 20 Turns per level.
- **Level Targets:** $Level \times 5000 \times 1.05^{(Level - 1)}$.
- **Rewards:**
	- **Gold:** 2% of Final Score $\times$ Difficulty Multiplier (Easy 4x, Normal 2x, Hard 1x).
	- **Diamonds:** $\lfloor 0.5 \times TurnsRemaining \times Level \rfloor$.

## II. Tile Definitions
### Standard Scoring Tiles
The 4 main colors (RED, YELLOW, PURPLE, ORANGE) are assigned values from a randomized pool at the start of each level.
- **Pool:** [50, 100, 100, 150] (Low, Med, Med, High).
- **Discovery:** Values are hidden ("???") until the player matches the specific color, revealing its tier.

### Special Tiles
- **GREEN (Catalyst):** Grants Score Multiplier. Base Score: 0.
- **BLUE (Mana):** Grants Mana. Base Score: 0.
- **BLACK (Hazard):** Penalty score.
  - Value: $-50 - (Level \times 50)$.

## III. Formulas

### 1. Match Efficiency
Matches larger than 3 grant exponential bonuses.
$$Efficiency = \max(1.0, 1.25^{(Count - 3)})$$
*(Floor of 1.0 prevents penalties for small matches, e.g. via Harvest Spell)*

### 2. Base Scoring
$$MatchScore = Count \times BaseValue \times GlobalMult \times Efficiency$$
- **Upgrades:** Specific Color Upgrades add $+10\%$ to the final $MatchScore$ per level.

### 3. Global Multiplier (Green)
$$Gain = 0.1 \times Count \times Efficiency$$
- **Effect:** Adds to the Global Multiplier (starts at 1.0x).
- **Upgrade:** Green Mult Upgrade increases this **Gain** by $+10\%$ per level.
- **Decay:** None.

### 4. Mana (Blue)
$$Gain = Count \times 5 \times Efficiency$$
- **Upgrade:** Blue Mult Upgrade increases this **Gain** by $+10\%$ per level.
- **Max Mana:** $50 + (UpgradeLevel \times 10)$.

## IV. Spells & Abilities
### 1. "The Catalyst" (Classic)
- **Cost:** $50 - (UpgradeLevel \times 5)$ (Minimum 10).
- **Effect:** Transforms a selected **BLACK** tile into the **Highest Value** tile type.
- **Cap:** Minimum cost reached at Level 8.

### 2. "Harvest" (Premium)
- **Unlock:** 100 Diamonds.
- **Cost:** 50 Mana (rebalanced from 100).
- **Effect:** Select a row to clear it. Tiles are collected, grouped by color, and matched. Diamonds in the row join **every** color group (intentional wildcard bonus).

## V. Progression & Shop
- **Currencies:**
  - **Gold**: Main upgrade currency.
  - **Diamonds**: Premium currency for unlocking Spells & Special Strats.
- **Upgrades:**
  - **Gold Shop**: Mana Well (+10 Max Mana), Efficiency (-5 Catalyst Cost, max 8), Color Masteries (+10% per level to each color's effect).
  - **Diamond Shop**:
	- **Gem Fortune**: +1% Super Diamond spawn chance per tile in a 4+ match (max 20).
	- **Harvest**: Unlocks Harvest spell.
	- **Cinderella**: +25% Green Tile Spawn Rate (max 4).
	- **Grid Expansion**: +1 board column (max 2).
	- **Relax**: Unlocks auto-matching; turns no longer decrement while active (hidden until 10k diamonds).
	- **Gold Sack** (exchange): appears once all diamond upgrades are maxed; converts diamonds to gold at 1:5.

## VI. Systems
- **Audio**: Procedural 8-bit sound engine (Code-generated).
- **Visuals**:
  - Valid spell casts tint buttons green.
  - Harvest mode highlights target row in red.
