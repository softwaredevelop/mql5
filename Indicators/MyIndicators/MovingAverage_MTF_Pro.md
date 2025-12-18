# Moving Average MTF Pro

## 1. Summary (Introduction)

The `MovingAverage_MTF_Pro` is a versatile multi-timeframe (MTF) version of our universal moving average indicator. It allows a trader to calculate one of the four fundamental moving average types (SMA, EMA, SMMA, LWMA) on a **higher, user-selected timeframe** and project it onto the current, lower-timeframe chart.

This provides a clear, smoothed-out view of the underlying trend from a broader perspective without needing to switch charts.

## 2. Mathematical Foundations and Calculation Logic

### Core MA Types

* **SMA:** Simple Moving Average.
* **EMA:** Exponential Moving Average.
* **SMMA:** Smoothed Moving Average (Wilder's).
* **LWMA:** Linear Weighted Moving Average.

### MTF Calculation Steps

1. **Fetch Data:** Retrieves OHLC data for the selected higher timeframe.
2. **Calculate:** Performs the recursive or standard calculation on the higher timeframe data.
3. **Map:** Projects the values to the current chart, creating a "step-like" visual representation.

## 3. MQL5 Implementation Details

* **Self-Contained:** No `iCustom` dependencies. Uses direct `Copy...` functions for stability.
* **Universal Engine (`MovingAverage_Engine.mqh`):** Reuses the core logic from the standard suite for consistency.

* **Optimized Incremental Calculation (O(1)):**
    This indicator is engineered for performance:
  * **HTF State Tracking:** Tracks `htf_prev_calculated` to avoid redundant math on the higher timeframe.
  * **Persistent State:** Preserves the recursive state of EMAs and SMMAs between ticks.
  * **Smart Mapping:** The projection loop handles index alignment precisely and only updates changed bars.

* **Dual-Mode Logic:** Automatically switches between MTF mode (projection) and Standard mode (direct calculation) based on the timeframe selection.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The calculation timeframe.
* **Period (`InpPeriod`):** The lookback period.
* **MA Type (`InpMAType`):** SMA, EMA, SMMA, or LWMA.
* **Applied Price (`InpSourcePrice`):** Standard or Heikin Ashi price sources.

## 5. Usage and Interpretation

* **Trend Direction:** A rising MTF MA indicates a bullish higher-timeframe trend; falling indicates bearish.
* **Pullbacks:** In an uptrend, a pullback to the MTF MA often represents a high-value buying opportunity (dynamic support).
* **Crossovers:** Price crossing the MTF MA can signal a potential reversal in the major trend.
