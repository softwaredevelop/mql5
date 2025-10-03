# Commodity Channel Index (CCI) Professional Suite

## 1. Summary (Introduction)

The Commodity Channel Index (CCI), developed by Donald Lambert, is a versatile momentum oscillator that measures the current price level relative to an average price level. It is widely used to identify overbought/oversold conditions and cyclical turns.

Our professional suite provides a complete, unified family of indicators based on the CCI, all built upon our robust, modular framework:

- **`CCI_Pro.mq5`**: The main indicator. It plots the CCI line, a configurable moving average signal line, and optional **Bollinger Bands** calculated on the CCI itself.
- **`CCI_Oscillator_Pro.mq5`**: Displays the difference between the CCI and its signal line as a histogram, providing a clear visual of momentum acceleration/deceleration.
- **`CCI_PercentB_Pro.mq5`**: A %B oscillator that shows the CCI's position relative to its Bollinger Bands, scaled from 0 to 100.

All indicators in the suite can be calculated using either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The suite is constructed in a layered process, starting with the base CCI.

### Calculation Steps (Algorithm)

1. **Calculate the CCI Value:** The standard CCI is calculated based on the Typical Price, its SMA, and the Mean Absolute Deviation (MAD).
    $\text{CCI}_i = \frac{\text{Typical Price}_i - \text{SMA}_i}{0.015 \times \text{MAD}_i}$
2. **Calculate the Signal Line:** A moving average of the CCI line is calculated.
3. **Calculate the Bollinger Bands:** Standard Bollinger Bands are calculated on the CCI line, centered around the Signal Line.
    - $\text{StdDev}_t = \text{StandardDeviation}(\text{CCI}, \text{Bands Period})_t$
    - $\text{Upper Band}_t = \text{Signal Line}_t + (\text{Bands Deviation} \times \text{StdDev}_t)$
    - $\text{Lower Band}_t = \text{Signal Line}_t - (\text{Bands Deviation} \times \text{StdDev}_t)$
4. **Calculate the Oscillators:**
    - **CCI Oscillator:** $\text{Oscillator}_i = \text{CCI}_i - \text{Signal Line}_i$
    - **Percent B (%B):** $\text{\%B}_i = 100 \times \frac{\text{CCI}_i - \text{Lower Band}_i}{\text{Upper Band}_i - \text{Lower Band}_i}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability and maintainability.

- **Self-Contained Calculators:** Each indicator in the suite (`CCI_Pro`, `CCI_Oscillator_Pro`, `CCI_PercentB_Pro`) uses its own dedicated, self-contained calculator. Each calculator contains the full, multi-stage logic required for its specific output. This approach prioritizes stability and clarity for each individual component.

- **Object-Oriented Inheritance:** Within each calculator, an elegant inheritance model (`...Calculator` and `...Calculator_HA`) is used. The Heikin Ashi child class inherits all the complex logic from its base class and only overrides the initial data preparation step.

- **Stability via Full Recalculation:** All indicators employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

- **Mathematically Precise Implementation:** The engine adheres strictly to the mathematical definition of CCI, using a nested loop structure to calculate the Mean Absolute Deviation (MAD) precisely for each bar.

## 4. Parameters

- **CCI Period (`InpCCIPeriod`):** The lookback period for the base CCI calculation.
- **Applied Price (`InpSourcePrice`):** The source price for the base CCI. This unified dropdown allows selection from all standard and Heikin Ashi price types.
- **Overlay Settings:**
  - **Display Mode (`InpDisplayMode`):** (Only for `CCI_Pro`) Toggles between `CCI_Only`, `CCI_and_MA`, and `CCI_and_Bands`.
  - **MA Period (`InpMAPeriod`):** The period for the signal line, which also serves as the center for the Bollinger Bands.
  - **MA Method (`InpMAMethod`):** The type of moving average for the signal line.
  - **Bands Period (`InpBandsPeriod`):** The lookback period for the standard deviation calculation of the Bollinger Bands.
  - **Bands Deviation (`InpBandsDev`):** The standard deviation multiplier for the Bollinger Bands.

## 5. Usage and Interpretation

- **`CCI_Pro`:**
  - **Overbought/Oversold:** Readings above +100 and below -100.
  - **Crossovers:** CCI line crossing its signal line.
  - **Bollinger Bands:** The bands show the volatility *of the CCI itself*. A "squeeze" on the CCI bands can foreshadow a significant breakout in price momentum.
- **`CCI_Oscillator_Pro`:**
  - Visualizes the momentum of the CCI relative to its signal line. A zero-line cross confirms a signal line crossover on the `CCI_Pro`. Growing bars indicate accelerating momentum, while shrinking bars indicate decelerating momentum.
- **`CCI_PercentB_Pro`:**
  - **Overbought/Oversold:** Provides a normalized (0-100) view of overbought/oversold conditions. Readings above 80-100 or below 0-20 are significant.
  - **"Headroom":** Shows how much "room" the CCI has to move before it becomes extreme relative to its own recent volatility.
