# Ultimate Oscillator (UO) Professional

## 1. Summary (Introduction)

The Ultimate Oscillator (UO), developed by Larry Williams, is a momentum oscillator designed to address the problem of false divergence signals by incorporating three different timeframes (short, medium, and long) into a single, weighted oscillator value.

This multi-timeframe approach provides a smoother and more reliable measure of momentum.

Our `UltimateOscillator_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The UO's calculation combines buying pressure over three distinct periods.

### Required Components

* **Three Periods (N1, N2, N3):** The three lookback periods, typically short (7), medium (14), and long (28).
* **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Buying Pressure (BP):** For each bar, determine the amount of "buying pressure."
    * $\text{True Low (TL)}_i = \text{Min}(\text{Low}_i, \text{Close}_{i-1})$
    * $\text{BP}_i = \text{Close}_i - \text{TL}_i$
2. **Calculate True Range (TR):** For each bar, calculate the True Range.
    * $\text{TR}_i = \text{Max}(\text{High}_i, \text{Close}_{i-1}) - \text{TL}_i$
3. **Sum BP and TR over Three Periods:** Calculate the sum of Buying Pressure and True Range over each of the three lookback periods.
4. **Calculate Three Averages:** For each period, divide the sum of BP by the sum of TR.
5. **Calculate the Final UO:** Combine the three averages using a weighted formula (4, 2, 1) and scale the result to 100.
    $\text{UO}_i = 100 \times \frac{(4 \times \text{Avg}_7) + (2 \times \text{Avg}_{14}) + (1 \times \text{Avg}_{28})}{4 + 2 + 1}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`UltimateOscillator_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CUltimateOscillatorCalculator`**: The base class that performs the full UO calculation on a given set of High, Low, and Close prices.
  * **`CUltimateOscillatorCalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

* **Efficient Calculation:** The summation of Buying Pressure and True Range over the three lookback periods is handled by an efficient **sliding window sum** technique.

## 4. Parameters

* **Period 1 (`InpPeriod1`):** The short-term lookback period. Default is `7`.
* **Period 2 (`InpPeriod2`):** The medium-term lookback period. Default is `14`.
* **Period 3 (`InpPeriod3`):** The long-term lookback period. Default is `28`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).

## 5. Usage and Interpretation

The Ultimate Oscillator is primarily used to identify divergences, which are its most reliable signals.

* **Bullish Divergence (Primary Buy Signal):**
    1. The price makes a **lower low**, but the UO makes a **higher low**.
    2. The low of the UO during the divergence should be **below 30**.
    3. A buy signal is triggered when the UO subsequently breaks **above the high** it made during the divergence.
* **Bearish Divergence (Primary Sell Signal):**
    1. The price makes a **higher high**, but the UO makes a **lower high**.
    2. The high of the UO during the divergence should be **above 70**.
    3. A sell signal is triggered when the UO subsequently breaks **below the low** it made during the divergence.
* **Caution:** Larry Williams specifically designed the indicator so that its divergence signals would be the most reliable. Simple overbought/oversold readings are generally not recommended as primary signals.
