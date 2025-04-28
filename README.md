# HiSwing: Pattern Generator

**HiSwing: Pattern Generator** is a dynamic and customizable pattern and groove midi generator for Monome Norns. This script generates MIDI note patterns with adjustable groove templates, pattern lengths, step velocities, and reduction amounts. Ideal for creating evolving percussions, hi hats and basslines.

## Installation

1. Clone or download the repository to your Norns device.
2. Place the script folder into the Norns `scripts` directory.
3. Load the script on Norns to begin using it.

## Controls

- **K2:** Randomizes the step velocities in the pattern.
- **E2:** Changes the length of the pattern from 1 to 16 steps.
- **E3:** Switches between different groove templates. 
- **K3 + E2:** Adjusts the MIDI channel for output (1–16).
- **K3 + E3:** Reduces the number of active steps in the pattern (0–100%).

### Encoders:
- **E1:** Not used in this version.
- **E2:** Adjusts the pattern length (or MIDI channel if holding K3).
- **E3:** Adjusts groove template (or pattern reduction if holding K3).

## Grooves

The following groove templates are included, each with different step velocities:

1. **House 1:** 127,100,127,100,127,100,127,100,127,100,127,100,127,100,127,100
2. **Funky 1:** 127,64,100,64,127,64,100,64,127,64,100,64,127,64,100,64
3. **Deep House:** 127,127,89,89,127,127,89,89,127,127,89,89,127,127,89,89
4. **Garage:** 114,114,127,89,114,114,127,89,114,114,127,89,114,114,127,89
5. **Oldschool:** 127,89,114,89,127,89,114,89,127,89,114,89,127,89,114,89
6. **Electro Bounce:** 127,76,127,76,127,76,127,76,127,76,127,76,127,76,127,76

## MIDI Notes

The script is set to output MIDI note **C2** (note number 36). This can be adjusted if needed for different setups.

## Usage

After initializing, the script generates a constant C2 hi-hat pattern, which evolves as you tweak the parameters:

- Use **K2** to randomize the velocities of the steps, creating an unpredictable yet structured rhythm.
- Adjust the **E2** encoder to set the pattern length from 1 to 16 steps.
- **E3** changes the groove, which modifies the velocity of the steps, adding variation.
- Hold **K3** to make additional adjustments:
  - **E2** changes the MIDI channel.
  - **E3** adjusts the amount of pattern reduction, altering how many steps are active (from 0%–100%).

The pattern will run continuously until the script is stopped.

## Dependencies

- **musicutil:** Used for music-related utility functions.
- **core/midi:** For MIDI communication.

## License

This script is open-source and licensed under the MIT License.

---

Let me know if you'd like any adjustments!
