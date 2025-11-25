# MACD Laguerre Histogram Professional

## 1. Summary (Introduction)

The `MACD_Laguerre_Histogram_Pro` is the dedicated histogram component for our Laguerre MACD system. Its sole purpose is to calculate and display the difference between the `MACD_Laguerre_Line_Pro` and its corresponding signal line.

This indicator visually represents the convergence and divergence of momentum. The height and depth of the histogram bars provide an immediate sense of momentum acceleration and deceleration.

It is designed as a **companion indicator** to be overlaid in the same window as the `MACD_Laguerre_Line_Pro`. When their parameters are synchronized, they form a complete, modern, and highly responsive MACD system. The signal line's smoothing method is user-selectable, offering a choice between a **Laguerre filter** or one of the four standard moving average types (SMA, EMA, SMMA, LWMA).

## 2. Mathematical Foundations and Calculation Logic

To ensure perfect synchronization and accuracy without external dependencies, this indicator performs the full MACD calculation internally before outputting only the histogram.

### Calculation Steps (Algorithm)

1. **Calculate the MACD Line:** First, a fast and a slow Laguerre filter are calculated on the source price. The MACD Line is their difference.
    * $\text{MACD Line}_t = \text{LaguerreFilter}(P, \gamma_{fast})_t - \text{LaguerreFilter}(P, \gamma_{slow})_t$

2. **Calculate the Signal Line:** A smoothing of the user-selected type (`MA Type`) is applied to the `MACD Line` calculated in the previous step.
    * $\text{Signal Line}_t = \text{Smoothing}(\text{MACD Line}, \text{Parameters})_t$

3. **Calculate the Histogram:** The final output is the difference between the MACD Line and the Signal Line.
    * $\text{Histogram}_t = \text{MACD Line}_t - \text{Signal Line}_t$

## 3. MQL5 Implementation Details

* **Self-Contained Calculation:** The indicator is fully self-contained. Its engine (`MACD_Laguerre_Histogram_Calculator.mqh`) internally recalculates the entire Laguerre MACD line using the `Laguerre_Engine`. This "shared engine" architecture avoids the instability of `iCustom` calls.

* **Flexible Signal Line Calculation:** The calculator uses a `switch` block to apply the user's chosen smoothing method for the signal line. This includes a dedicated, state-managed calculation for the `Laguerre` option and reuses our universal `CalculateMA` helper function for standard MA types.

* **Object-Oriented Design (Inheritance):** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

## 4. Parameters

* **Laguerre MACD Settings:**
  * **`InpGamma1` / `InpGamma2`:** The gamma coefficients for the two base Laguerre filters. The smaller value will be the fast filter, the larger will be the slow one.
* **Signal Line Settings:**
  * **`InpSignalMAType`:** A dropdown menu to select the smoothing type for the signal line. Options include `Laguerre`, `SMA`, `EMA`, `SMMA`, `LWMA`.
  * **`InpSignalPeriod`:** The lookback period for **standard MA** signal lines.
  * **`InpSignalGamma`:** The gamma coefficient used **only** if the signal line type is set to `Laguerre`.
* **Price Source:**
  * **`InpSourcePrice`:** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

This indicator is designed to be used in conjunction with `MACD_Laguerre_Line_Pro`.

**How to set up the full system:**

1. Add the `MACD_Laguerre_Line_Pro` indicator to a chart window.
2. Drag the `MACD_Laguerre_Histogram_Pro` indicator **onto the same indicator window**.
3. **Crucially, ensure that the `InpGamma1`, `InpGamma2`, and `InpSourcePrice` parameters in both indicators are identical.**
4. You can now adjust the `Signal Period` and `Signal MA Type` in the Histogram indicator to see how different signal lines affect the momentum profile.

### Interpreting the Histogram

* **Zero Line Crossover:** This is the most direct signal.
  * When the histogram crosses from **negative to positive**, it confirms that the MACD Line has crossed above its Signal Line, generating a bullish signal.
  * When the histogram crosses from **positive to negative**, it confirms a bearish crossover.
* **Momentum Acceleration/Deceleration:**
  * **Growing Bars:** If the histogram bars are getting larger (further from zero), it means the distance between the MACD Line and Signal Line is increasing, and momentum is accelerating.
  * **Shrinking Bars:** If the histogram bars are getting smaller (closer to zero), it signals that momentum is decelerating, which can be an early warning of a potential trend change or consolidation.
* **Divergence:** Divergence between the histogram's peaks/troughs and price action can signal powerful reversal opportunities.
