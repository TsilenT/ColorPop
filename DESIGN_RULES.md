	# Match-3 Godot Prototype: Stage 1 Design Rules

This document outlines all constraints for the 8x8 game prototype. The Antigravity agent must reference these rules for all GDScript generation.

## I. Game Parameters
- **Board Size:** 8 columns, 8 rows (COLS=8, ROWS=8).
- **Goal:** 10,000 Points.
- **Limit:** 20 Turns.
- **Core Move:** One Tile Insertion Move per turn (dragging a tile into a row/column shifts all other tiles).

## II. Tile Definitions (Tile.gd)
- **Tile Types (Enum):** RED, YELLOW, GREEN, BLUE, BLACK
- **Tile Base Point Values (B):**
	- RED (Primary Point): +150
	- YELLOW (Secondary Point): +75
	- BLACK (Penalty): -500 (Deduction)
	- GREEN (Multiplier) / BLUE (Mana): 0 points.

## III. Scoring & Combo Formula
- **Efficiency Multiplier (Combo):** A +25% bonus is applied for every tile matched over 3 (N-3).
- **Final Points Formula (P_total):**
  $$P_{\text{total}} = N \times B \times M \times (1 + (N-3) \times 0.25)$$
  (Where N ≥ 3, B is Base Value, M is Global Multiplier).
- **Penalty Scaling:** The BLACK tile deduction (-500) must also be scaled by the Global Multiplier (M).

## IV. Resource Mechanics (Green & Blue)
- **Global Multiplier (M):** Starts at 1.0x.
	- Match-3 Green: +1.0x.
	- Match-N Green: The base +1.0x is scaled by the Combo Multiplier (e.g., Match-4 is +1.25x).
	- **DECAY:** If a Green tile match is NOT made, the Global Multiplier must decay by **-0.5x** at the start of the next turn.
- **Mana (BLUE):** Base is 4 Mana/Tile.
	- Formula: Mana Gain = $N \times 4 \times (1 + (N-3) \times 0.25)$
	- Mana Gauge: 60 Mana Capacity.
	- Spell 1 Cost: 60 Mana.
- **Spell 1: "The Catalyst":** Transforms 1 selected BLACK Tile into 1 RED Tile.
