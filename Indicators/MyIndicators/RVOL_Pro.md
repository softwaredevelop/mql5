# RVOL Pro (Relative Volume)

## 1. Summary (Introduction)

Relative Volume (RVOL) is a crucial tool for professional traders to validate price action and gauge institutional interest. Instead of displaying absolute volume, which can be misleading, RVOL measures the current bar's volume as a multiple of its recent average. This instantly highlights periods of unusually high or low activity.

The `RVOL_Pro` indicator provides a clean, multi-color histogram for immediate visual feedback, allowing traders to confirm breakouts, spot potential reversals (climactic volume), and identify low-participation moves that might be traps.

## 2. Mathematical Foundations and Calculation Logic

The core of the RVOL indicator is a simple yet powerful ratio that contextualizes volume.

### Required Components

* **Current Volume:** The volume of the current bar (`Volume_i`).
* **Average Volume:** A simple moving average (SMA) of the volume over the `N` preceding bars.

### Calculation Steps (Algorithm)

1. **Calculate the Average Volume:** Compute the SMA of the volume for the `N` bars *prior* to the current bar.
    $\text{Average Volume}_{i} = \frac{1}{N} \sum_{k=1}^{N} \text{Volume}_{i-k}$

2. **Calculate the RVOL Ratio:** Divide the current bar's volume by the calculated average.
    $\text{RVOL}_i = \frac{\text{Volume}_i}{\text{Average Volume}_i}$

An RVOL value of `2.5` means the current bar's volume is 2.5 times higher than the recent average, indicating significant market activity.

## 3. MQL5 Implementation Details

* **Modular Calculation Engine (`RVOL_Calculator.mqh`):**
    The entire calculation logic is encapsulated within the `CRVOLCalculator` class. This engine is lightweight, stateless within itself (relying on passed data), and can be reused in scripts or Expert Advisors.
* **Optimized Incremental Calculation (O(1) per Bar):**
    The indicator utilizes `prev_calculated` to ensure that calculations are only performed on new or changed bars. The core logic involves a loop over the last `N` bars to compute the average, which is a constant-time operation for each new bar, guaranteeing high performance and zero lag.
* **Visual Signaling (`DRAW_COLOR_HISTOGRAM`):**
    The wrapper `RVOL_Pro.mq5` uses a multi-color histogram for intuitive signaling. It employs two buffers: one for the RVOL value (`INDICATOR_DATA`) and one for the color index (`INDICATOR_COLOR_INDEX`). This allows the color of each bar in the histogram to change dynamically based on user-defined thresholds.

## 4. Parameters

* **Calculation Settings:**
  * `InpPeriod`: The lookback period for calculating the average volume. (Default: `20`).
  * `InpVolumeType`: The type of volume to use (`VOLUME_TICK` or `VOLUME_REAL`). `VOLUME_REAL` is recommended for exchange-traded instruments where available.
* **Visual Settings:**
  * `InpLevelHigh`: The threshold above which volume is considered "High". (Default: `1.5`).
  * `InpLevelExtreme`: The threshold above which volume is considered "Extreme". (Default: `2.5`).
  * `InpColorNormal`, `InpColorHigh`, `InpColorExtreme`: Customizable colors for the three volume states, allowing for easy visual identification of market activity.

## 5. Usage and Interpretation

* **Breakout Confirmation:** A price breakout from a range or pattern accompanied by RVOL > `1.5` has a higher probability of being valid and indicates strong participation in the move.
* **Exhaustion / Climactic Volume:** An extreme RVOL spike (> `2.5` or `3.0`) at the end of a prolonged trend can signal a reversal.
  * **Blow-off Top:** Extreme RVOL on a large bullish candle after a long uptrend.
  * **Capitulation Bottom:** Extreme RVOL on a large bearish candle after a long downtrend.
* **Lack of Interest:** A price move (especially a breakout attempt) on low RVOL (< `0.8`) suggests a lack of institutional conviction and increases the likelihood of a "fakeout" or trap.
* **Absorption (Advanced):** High RVOL on a small-bodied candle (Doji/spinning top) near a key support/resistance level can signal that large passive orders are "absorbing" the aggressive market orders, often preceding a reversal.
