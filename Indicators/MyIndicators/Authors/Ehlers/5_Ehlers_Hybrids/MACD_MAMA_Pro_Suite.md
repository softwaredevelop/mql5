# MACD MAMA Pro Suite

## 1. Summary (Introduction)

The **MACD MAMA Pro Suite** is a unique and highly adaptive variation of the MACD indicator. Instead of standard EMAs, it uses John Ehlers' **MESA Adaptive Moving Average (MAMA)** and **Following Adaptive Moving Average (FAMA)**.

The MAMA algorithm adapts its speed based on the rate of change of the market's phase. This allows the MACD line to be incredibly responsive during fast trends while virtually stopping (becoming flat) during consolidation periods, significantly reducing false signals compared to a standard MACD.

The suite consists of three indicators:

1. **`MACD_MAMA_Pro`:** The complete package (MACD Line, Signal Line, Histogram).
2. **`MACD_MAMA_Line_Pro`:** Displays only the MACD Line.
3. **`MACD_MAMA_Histogram_Pro`:** Displays only the Histogram.

## 2. Mathematical Foundations

The core of this system is the relationship between MAMA and FAMA:

1. **MAMA (Fast Line):** Adapts quickly to price changes.
2. **FAMA (Slow Line):** A synchronized, slower version of MAMA (steps in time with MAMA but with half the alpha).

**MACD Calculation:**

* $\text{MACD Line}_t = \text{MAMA}_t - \text{FAMA}_t$

Because FAMA is derived directly from MAMA, the two lines never cross randomly due to lag; they cross only when the market's phase actually shifts. This makes the MAMA MACD crossover a very pure signal.

## 3. MQL5 Implementation Details

* **Unified Calculator Engine:** Powered by `MACD_MAMA_Calculator.mqh`, which orchestrates the complex MAMA/FAMA logic.
* **O(1) Incremental Calculation:** Optimized for real-time performance.
* **Heikin Ashi Integration:** Full support for Heikin Ashi price data.

## 4. Parameters

### MAMA Settings

* **Fast Limit:** The maximum speed (alpha) the average can reach in a fast trend. Default is `0.5`.
* **Slow Limit:** The minimum speed (alpha) the average can drop to in a range. Default is `0.05`.
* **Price Source:** Selects the input data.

### Signal Line Settings (Oscillators Only)

* **Signal Period:** Lookback period for the Signal Line.
* **Signal Method:** Smoothing method (SMA, EMA, etc.).

## 5. Usage and Interpretation

### Zero Line Crossover

* **Bullish:** MACD Line crosses above zero (MAMA > FAMA).
* **Bearish:** MACD Line crosses below zero (MAMA < FAMA).
* *Note:* This is often the most reliable signal with MAMA, as it represents a fundamental shift in market phase.

### Signal Line Crossover

* Standard MACD rules apply: Buy when MACD crosses above Signal, Sell when below.
* These signals are faster but may be more frequent than zero line crossovers.

### Histogram

* Visualizes the momentum of the MAMA/FAMA separation. Useful for spotting divergence.
