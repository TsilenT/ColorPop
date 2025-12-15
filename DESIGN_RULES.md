# Match-3 Game Mechanics & Design Rules

This document outlines the current logic and constraints of the game as implemented.

## I. Game Parameters
- **Board Size:** 8 columns x 8 rows.
- **Limit:** 20 Turns per level.
- **Level Targets:** $1000 + (Level \times 5000)$.
- **Level Reward:** $100 \times Level$ Gold.

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
$$Efficiency = 1.25^{(Count - 3)}$$

### 2. Base Scoring
$$MatchScore = Count \times BaseValue \times GlobalMult \times Efficiency$$
- **Upgrades:** Specific Color Upgrades (e.g., Red Mult) add $+10\%$ to the final $MatchScore$ per level.

### 3. Global Multiplier (Green)
$$Gain = 0.1 \times Count \times Efficiency$$
- **Effect:** Adds to the Global Multiplier (starts at 1.0x).
- **Upgrade:** Green Mult Upgrade increases this **Gain** by $+10\%$ per level.
- **Decay:** None (Multiplier persists through the level).

### 4. Mana (Blue)
$$Gain = Count \times 5 \times Efficiency$$
- **Upgrade:** Blue Mult Upgrade increases this **Gain** by $+10\%$ per level.
- **Max Mana:** $50 + (UpgradeLevel \times 10)$.

### 5. Spell: "The Catalyst"
- **Cost:** $50 - (UpgradeLevel \times 5)$ (Minimum 10).
- **Effect:** Transforms a selected **BLACK** tile into the **Highest Value** tile type currently on the board.

## IV. Progression & Shop
- **Gold:** Earned by completing levels.
- **Upgrades:**
  - **Mana Cap:** +10 Max Mana.
  - **Spell Cost:** -5 Ability Cost.
  - **Color Mults (Red, Yel, Pur, Org):** +10% Score for that color.
  - **Green Mult:** +10% Multiplier Gain rate.
  - **Blue Mult:** +10% Mana Gain rate.
- **Save System:** Tracks Gold, Upgrade Levels, and Settings persistently.
