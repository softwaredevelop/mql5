# Ultimate Oscillator (UO) Professional

## 1. Summary (Introduction)

The Ultimate Oscillator (UO), developed by Larry Williams, is a momentum oscillator designed to address the problem of false divergence signals often found in single-timeframe oscillators. It achieves this by incorporating three different timeframes (short, medium, and long) into a single, weighted oscillator value, providing a smoother and more reliable measure of momentum.

Our `UltimateOscillator_Pro` implementation is a unified, professional version that includes an **optional, fully customizable signal line** and allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The UO's calculation combines "Buying Pressure" relative to "True Range" over three distinct periods, using Larry Williams' specific definitions for these terms.

### Required Components

* **Three Periods (N₁, N₂, N₃):** The three lookback periods, typically `7`, `14`, and `28`.
* **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Buying Pressure (BP):** For each bar, this measures the closing price's position relative to the "true low".
    * $\text{True Low}_i = \text{Min}(\text{Low}_i, \text{Close}_{i-1})$
    * $\text{BP}_i = \text{Close}_i - \text{True Low}_i$

2. **Calculate True Range (TR):** For each bar, this measures the total "true" price excursion.
    * $\text{True High}_i = \text{Max}(\text{High}_i, \text{Close}_{i-1})$
    * $\text{TR}_i = \text{True High}_i - \text{True Low}_i$

3. **Sum BP and TR over Three Periods:** Calculate the moving sums of BP and TR for each of the three periods (N₁, N₂, N₃).
    * $\text{SumBP}_1 = \sum_{i=0}^{N_1-1} \text{BP}_{t-i}$ , $\text{SumTR}_1 = \sum_{i=0}^{N_1-1} \text{TR}_{t-i}$
    * *(Repeat for N₂ and N₃)*

4. **Calculate Three Averages:** For each period, calculate the ratio of the sums.
    * $\text{Avg}_1 = \frac{\text{SumBP}_1}{\text{SumTR}_1}$ , $\text{Avg}_2 = \frac{\text{SumBP}_2}{\text{SumTR}_2}$ , $\text{Avg}_3 = \frac{\text{SumBP}_3}{\text{SumTR}_3}$

5. **Calculate the Final UO:** Combine the three averages using a weighted formula (weights of 4, 2, and 1) and scale the result to 100.
    * $\text{UO}_t = 100 \times \frac{(4 \times \text{Avg}_1) + (2 \times \text{Avg}_2) + (1 \times \text{Avg}_3)}{4 + 2 + 1}$

## 3. MQL5 Implementation Details

* **Modular Calculation Engine (`UltimateOscillator_Calculator.mqh`):** The entire calculation logic is encapsulated within a reusable include file, separating the mathematical complexity from the user interface.

* **Object-Oriented Design (Inheritance):** A `CUltimateOscillatorCalculator` base class and a `CUltimateOscillatorCalculator_HA` derived class are used to cleanly separate the logic for standard and Heikin Ashi price sources.

* **Optional Signal Line:** The indicator is enhanced with a user-configurable moving average signal line. A `Display Mode` input allows the user to toggle the visibility of this line.

* **Stability and Efficiency:** We employ a full recalculation within `OnCalculate` for maximum stability. The summation of Buying Pressure and True Range is handled by an efficient **sliding window sum** technique (`sum += new_value; sum -= old_value;`), which is significantly faster than recalculating the sum on every bar.

## 4. Parameters

* **Period 1, 2, 3 (`InpPeriod1`, `InpPeriod2`, `InpPeriod3`):** The three lookback periods for the oscillator. Defaults are `7`, `14`, `28`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).
* **Signal Line Settings:**
  * `InpDisplayMode`: Toggles the visibility of the signal line.
  * `InpSignalPeriod`: The lookback period for the signal line.
  * `InpSignalMAType`: The type of moving average for the signal line.

## 5. Usage and Interpretation

The Ultimate Oscillator is primarily used to identify **divergences**, which are its most reliable signals, according to Larry Williams.

### Bullish Divergence (Primary Buy Signal)

A three-step pattern is required for a buy signal:

1. A **bullish divergence** occurs: the price makes a **lower low**, but the UO makes a **higher low**.
2. The low of the UO during the divergence must be **below 30**.
3. A buy signal is triggered only when the UO subsequently breaks **above the high** it made between the two lows of the divergence.

### Bearish Divergence (Primary Sell Signal)

A three-step pattern is required for a sell signal:

1. A **bearish divergence** occurs: the price makes a **higher high**, but the UO makes a **lower high**.
2. The high of the UO during the divergence must be **above 70** (some sources suggest 50).
3. A sell signal is triggered only when the UO subsequently breaks **below the low** it made between the two highs of the divergence.

### Secondary Signals

* **Signal Line Crossovers:** If the signal line is enabled, its crossovers with the UO line can provide earlier, shorter-term momentum signals, similar to a MACD or Stochastic.
* **Overbought/Oversold:** While not its primary purpose, values above 70 can be considered overbought and values below 30 can be considered oversold, especially in ranging markets.
