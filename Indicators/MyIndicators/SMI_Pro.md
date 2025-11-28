# Stochastic Momentum Index (SMI) Pro

## 1. Summary (Introduction)

The Stochastic Momentum Index (SMI), developed by William Blau, is a smoother version of the standard Stochastic Oscillator. It measures the relationship between the closing price and the *midpoint* of its high-low range, rather than the closing price's position within the range.

The result is an oscillator that fluctuates around a zero line, providing clearer signals and minimizing erratic behavior.

Our `SMI_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The SMI involves multiple layers of smoothing, using Exponential Moving Averages (EMAs).

### Required Components

* **%K Period:** The lookback period for finding the highest high and lowest low.
* **%D Period:** The period for the double EMA smoothing.
* **Signal Period:** The period for the final EMA smoothing that creates the signal line.

### Calculation Steps (Algorithm)

1. **Find the Price Range:** For each bar, determine the highest high and lowest low over the `%K Period`.
2. **Calculate the Relative Distance:** Determine the distance of the current close from the midpoint of the high-low range.
    $\text{Relative Distance}_i = \text{Close}_i - \frac{\text{Highest High}_i + \text{Lowest Low}_i}{2}$
3. **First EMA Smoothing:** Apply an EMA with the `%D Period` to both the `Relative Distance` and the `Range`.
4. **Second EMA Smoothing:** Apply another EMA with the `%D Period` to the results of the first smoothing.
5. **Calculate the SMI Value:** The final SMI is calculated as a percentage.
    $\text{SMI}_i = 100 \times \frac{\text{EMA2(Relative)}_i}{\text{EMA2(Range)}_i / 2}$
6. **Calculate the Signal Line:** The signal line is an EMA of the SMI line itself, using the `Signal Period`.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`SMI_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CSMICalculator`**: The base class that performs the full, multi-stage SMI calculation on a given set of High, Low, and Close prices.
  * **`CSMICalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * The internal buffers (`m_ema_rel`, `m_ema_range`, etc.) persist their state between ticks, allowing the recursive EMA algorithms to continue seamlessly from the last known value.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Robust EMA Initialization:** Each recursive EMA calculation step is carefully initialized with a simple average to provide a stable starting point for the calculation chain and prevent floating-point overflows.

## 4. Parameters

* **%K Length (`InpLengthK`):** The lookback period for finding the highest high and lowest low. Default is `10`.
* **%D Length (`InpLengthD`):** The period used for the double EMA smoothing. Default is `3`.
* **EMA Length (`InpLengthEMA`):** The smoothing period for the final signal line. Default is `3`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The SMI typically uses +40 as the overbought level and -40 as the oversold level.
* **Crossovers:**
  * **SMI / Signal Line Crossover:** When the SMI line crosses above its signal line, it can be considered a bullish signal. When it crosses below, it's a bearish signal.
  * **Zero Line Crossover:** A crossover of the SMI line above the zero line indicates that bullish momentum is taking control. A crossover below zero indicates bearish momentum.
* **Divergence:** Look for divergences between the SMI and the price. A bearish divergence (higher price highs, lower SMI highs) can signal a potential top, while a bullish divergence (lower price lows, higher SMI lows) can signal a potential bottom.
* **Caution:** While smoother than a standard Stochastic, the SMI is still a momentum oscillator and can give false signals in choppy markets.
