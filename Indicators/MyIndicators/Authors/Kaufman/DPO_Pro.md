# Detrended Price Oscillator (DPO) Professional

## 1. Summary (Introduction)

The Detrended Price Oscillator (DPO) is a technical analysis tool designed to isolate and visualize short-term cycles by removing the longer-term trend from the price. By subtracting a moving average from the price, the DPO line oscillates around a zero level, clearly showing the cyclical peaks and troughs without the "skew" of the underlying trend.

Unlike many oscillators, the DPO is **not a momentum indicator**. Its primary purpose is to help identify the length of market cycles by measuring the distance between its peaks or troughs.

Our `DPO_Pro` implementation uses the classic, definition-true method, where the moving average is shifted backwards in time to properly align it with the price, thus removing the lag from the calculation and providing a more accurate representation of the cycle.

## 2. Mathematical Foundations and Calculation Logic

The DPO measures the difference between the current price and a past, centered moving average.

### Required Components

* **Period (N):** The lookback period for the moving average. This should be chosen to represent the trend you wish to remove.
* **MA Method:** The type of moving average to be used (SMA, EMA, etc.).
* **Source Price (P)**.

### Calculation Steps (Algorithm)

1. **Calculate the Moving Average:** Compute the selected Moving Average of the source price over period `N`.
    $\text{MA}_i = \text{MA}(P, N)_i$

2. **Determine the Shift (Displacement):** Calculate the time shift based on the period.
    $\text{Shift} = \text{Integer}(\frac{N}{2}) + 1$

3. **Calculate the DPO Value:** The DPO for the current bar `t` is the difference between the current price and the moving average value from `Shift` bars in the past.
    $\text{DPO}_t = P_t - \text{MA}_{t - \text{Shift}}$

This shifting process ensures that the comparison is made against the "centered" trend value, providing a more accurate cyclical oscillation around the zero line.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Modular Design (Composition):** The `CDPOCalculator` does not recalculate the moving average itself. Instead, it **contains an instance** of our universal `CMovingAverageCalculator`. This is a highly efficient use of our modular toolkit.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Shift Handling:** The algorithm correctly handles the lookback into the past (`i - Shift`) during incremental updates, ensuring that the DPO value is always based on the correct historical MA value.

* **Correct Heikin Ashi Logic:**
    In Heikin Ashi mode, the indicator ensures full consistency by calculating both the "Price" component and the "Moving Average" component from the Heikin Ashi data. This prevents "hybrid" errors where standard prices are compared to HA averages.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average that will be "detrended" from the price. (Default: `21`).
* **MA Method (`InpMAType`):** The type of moving average to use. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The DPO is an **analytical tool for cycle identification**, not a direct signal generator for entries and exits.

### 1. Identifying Cycle Periods (Primary Use)

* The DPO's primary function is to help you visually estimate the dominant cycle length in a market.
* **Method:** Measure the distance (in bars) between two consecutive, significant troughs (low points) on the DPO line. Do this for several cycles. The average of these distances will give you a good approximation of the market's current cycle period.
* **Application:** Once you know the approximate cycle period (e.g., 20 bars), you can anticipate that a new cycle low or high is likely to form roughly 20 bars after the previous one. This information can be used to time entries with other indicators.

### 2. Identifying Historical Highs and Lows

* The peaks and troughs of the DPO are directly aligned with the historical price peaks and troughs, but they are easier to see because the trend has been removed.
* You can draw horizontal lines on the DPO chart at levels where it has reversed multiple times in the past. When the DPO approaches these historical reversal levels again, it can signal that the current cycle is reaching an extreme.

### Important Considerations

* **Not a Momentum Oscillator:** Do not interpret the DPO's value as a measure of strength. A high DPO value simply means the price is far above its trend, not necessarily that the trend is strong.
* **Not for Overbought/Oversold:** The DPO is not bounded (like an RSI or Stochastic), so it does not have fixed overbought or oversold levels. Its extremes are relative to the specific market's volatility.
* **Lagging by Nature:** Although the MA lag is mathematically removed, the DPO is still based on past data and is best used for analyzing historical patterns to anticipate future rhythm.
