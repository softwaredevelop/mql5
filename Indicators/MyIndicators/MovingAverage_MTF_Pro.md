# Moving Average MTF Pro

## 1. Summary (Introduction)

The `MovingAverage_MTF_Pro` is a versatile multi-timeframe (MTF) version of our universal moving average indicator. It allows a trader to calculate any of the supported moving average types on a **higher, user-selected timeframe** and project it onto the current, lower-timeframe chart.

This provides a clear, smoothed-out view of the underlying trend from a broader perspective without needing to switch charts.

## 2. Mathematical Foundations and Calculation Logic

### Supported MA Types

The indicator leverages the unified `MovingAverage_Engine`, supporting a wide range of algorithms:

* **SMA:** Simple Moving Average.
* **EMA:** Exponential Moving Average.
* **SMMA:** Smoothed Moving Average (Wilder's).
* **LWMA:** Linear Weighted Moving Average.
* **DEMA:** Double Exponential Moving Average (Faster, less lag).
* **TEMA:** Triple Exponential Moving Average (Even faster).
* **TMA:** Triangular Moving Average (Double-smoothed SMA).

### MTF Calculation Steps

1. **Fetch Data:** Retrieves OHLC data for the selected higher timeframe.
2. **Calculate:** Performs the recursive or standard calculation on the higher timeframe data using the unified engine.
3. **Map:** Projects the values to the current chart using precise time-based alignment (`iBarShift`), creating a "step-like" visual representation that accurately reflects when the higher timeframe bar closed.

## 3. MQL5 Implementation Details

* **Self-Contained:** No `iCustom` dependencies. Uses direct `Copy...` functions for maximum stability and speed.
* **Universal Engine (`MovingAverage_Engine.mqh`):** Reuses the core logic from the standard suite, ensuring mathematical consistency across all indicators.
* **Optimized Incremental Calculation (O(1)):**
    This indicator is engineered for performance:
  * **HTF State Tracking:** Tracks `htf_prev_calculated` to avoid redundant math on the higher timeframe.
  * **Persistent State:** Preserves the recursive state of EMAs, DEMAs, etc., between ticks.
  * **Smart Mapping:** The projection loop handles index alignment precisely and only updates changed bars.
* **Dual-Mode Logic:** Automatically switches between MTF mode (projection) and Standard mode (direct calculation) based on the timeframe selection.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The calculation timeframe (e.g., H1, H4, D1). Must be greater than or equal to the current chart timeframe.
* **Period (`InpPeriod`):** The lookback period for the moving average.
* **MA Type (`InpMAType`):** Selects the calculation algorithm (SMA, EMA, DEMA, etc.).
* **Applied Price (`InpSourcePrice`):** Standard (Close, Open, etc.) or Heikin Ashi price sources.

## 5. Usage and Interpretation

* **Trend Direction:** A rising MTF MA indicates a bullish higher-timeframe trend; falling indicates bearish.
* **Dynamic Support/Resistance:** In an uptrend, a pullback to the MTF MA often represents a high-value buying opportunity (dynamic support).
* **Trend Filter:** Use the slope or position of the MTF MA to filter signals from faster indicators on the current chart (e.g., only buy if price is above the H4 EMA).
