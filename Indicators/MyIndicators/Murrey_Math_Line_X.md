# Murrey Math Line X Indicator

## 1. Summary (Introduction)

The Murrey Math Line X is a comprehensive support and resistance indicator based on the geometric trading principles of W.D. Gann. Developed and simplified by T. Henning Murrey, the system posits that market movements are not random but follow a natural, harmonic order that can be divided into octaves of 1/8th.

This MQL5 indicator automatically identifies the relevant price range (or "octave") for a given period and plots a grid of 13 key price levels. These lines are not simple pivot points; each has a distinct "personality" and serves as a probabilistic guide for potential price reversals, continuations, and trading range boundaries. The indicator is fully Multi-Timeframe (MTF) capable, allowing it to display levels from a higher timeframe on any lower timeframe chart.

## 2. Mathematical Foundations and Calculation Logic

The calculation of Murrey Math Lines is a multi-step process designed to normalize price action into a standardized geometric framework.

1. **Define the Period and Range:** The algorithm first identifies the highest high (`H`) and lowest low (`L`) over a specified lookback period (default is 64 bars). This defines the initial price range.

2. **Determine the Octave:** This is the core of the Murrey Math system. The algorithm does not use the raw price range directly. Instead, it finds the "perfect octave" that the current range fits into. This is achieved by:
   a. Identifying a "fractal" value based on the magnitude of the highest high (e.g., if the price is between 1.5625 and 3.125, the fractal is 3.125).
   b. Using this fractal and the initial range, it calculates the size of the main octave (`octave`).
   c. It then finds the bottom (`mn`) and top (`mx`) of the square that perfectly contains the initial price range.

3. **Normalize the Range:** A complex set of rules (represented by the `x1..x6` and `y1..y6` calculations in the code) further refines the `mn` and `mx` values to find the true operational range for the current market structure, resulting in a `finalL` (bottom) and `finalH` (top).

4. **Calculate the Levels:** Once the final, normalized range is established, the calculation is straightforward:
   a. The distance between each main level (`dmml`) is the height of the octave divided by 8:
   `dmml = (finalH - finalL) / 8`
   b. The lines are then calculated by adding or subtracting this `dmml` value from the base levels. The central [4/8]P line corresponds to the midpoint of a key internal range, and all other lines are derived from it. The full set of lines spans from [-2/8]P to [+2/8]P.

## 3. MQL5 Implementation Details

This indicator was refactored from its original procedural form into a robust, object-oriented, and self-contained structure, adhering to our core development principles.

- **Self-Contained Object-Oriented Design:** The entire logic is encapsulated within a single `.mq5` file but is internally structured into distinct classes for clarity and maintainability:

  - `CMurreyMathCalculator`: A dedicated class that handles the complex, multi-timeframe (MTF) data retrieval and the core mathematical algorithm. It is completely decoupled from any drawing logic.
  - `CMurreyMathDrawer`: This class is solely responsible for all chart interactions, including the creation, movement, and styling of the `OBJ_HLINE` and `OBJ_TEXT` objects. Its destructor (`~CMurreyMathDrawer`) ensures all objects are automatically removed from the chart (RAII principle).
  - `CMurreyMathController`: A high-level controller class that manages the lifecycle of the calculator and drawer objects, orchestrating the flow of data between them.

- **Stable MTF Implementation:** The indicator correctly implements Multi-Timeframe functionality. The `CMurreyMathCalculator` uses `CopyHigh()` and `CopyLow()` to fetch data from the user-specified `InpUpperTimeframe`. The recalculation of levels is triggered only when a **new bar forms on that higher timeframe**, ensuring the levels remain stable and accurate, as intended.

- **Efficient Update and Drawing Logic:**

  - The main `OnCalculate()` function is streamlined. It detects new bars on the higher timeframe to trigger a full recalculation.
  - For other events, such as the user scrolling or zooming the chart, it triggers a lightweight redraw to reposition the text labels without performing the heavy mathematical calculations. This is achieved by tracking the `CHART_FIRST_VISIBLE_BAR` property and only redrawing when it changes.

- **Robust Label Positioning:** The logic for placing the text labels was carefully implemented to exactly replicate the behavior of the original, proven indicator. It uses a timeseries-based `time` array and adjusts the time coordinate of the text objects based on the user's `InpLabelSide` choice, ensuring the labels are always correctly positioned on the left or right side of the chart.

## 4. Parameters

- **`InpPeriod`**: The lookback period used to find the highest high and lowest low on the selected timeframe. Default: `64`.
- **`InpUpperTimeframe`**: The timeframe on which the Murrey Math calculation is performed. Setting this to a higher timeframe (e.g., `PERIOD_H4`) will display the H4 levels on any lower timeframe chart (e.g., M15). `PERIOD_CURRENT` uses the chart's own timeframe. Default: `PERIOD_H4`.
- **`InpStepBack`**: The number of bars to shift the calculation start point into the past. `0` means the calculation is based on the most recent bars. Default: `0`.
- **`InpLabelSide`**: Determines where the descriptive text labels are displayed.
  - `Left`: Labels are aligned to the left edge of the chart window.
  - `Right`: Labels are aligned to the most recent price action on the right.
  - Default: `Left`.
- **Line Colors & Widths**: A full set of inputs to customize the color and width of each of the 13 Murrey Math lines individually.
- **Labels**: Inputs to control the font, font size, and object prefix for all created chart objects.

## 5. Usage and Interpretation

Each Murrey Math line has a specific meaning and suggests a high probability price behavior.

- **[8/8]P & [0/8]P (Ultimate Resistance & Support)**: These are the strongest levels. Price will have the most difficulty breaking through them. Excellent points for taking profits or expecting a major reversal.
- **[7/8]P & [1/8]P (Weak, Stop & Reverse)**: If price moves quickly to these levels and stalls, a reversal is highly likely. If price moves through them without pausing, it will likely continue to the 8/8 or 0/8 level.
- **[6/8]P & [2/8]P (Pivot, Reverse)**: Strong reversal points, second only in importance to the 4/8 line.
- **[5/8]P & [3/8]P (Top & Bottom of Trading Range)**: The market spends approximately 40% of its time moving between these two lines. A sustained break outside this range signals a potential new trend.
- **[4/8]P (Major S/R Pivot)**: The most significant single line. It provides major support when price is above it and major resistance when price is below it. It is often the best level to initiate new trades.
- **[+1/8]P, [+2/8]P, [-1/8]P, [-2/8]P**: These are "overshoot" levels, indicating extreme overbought or oversold conditions where price has moved beyond its expected harmonic range.
