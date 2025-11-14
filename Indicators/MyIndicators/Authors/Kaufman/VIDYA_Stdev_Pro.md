# VIDYA Stdev Professional

## 1. Summary (Introduction)

The `VIDYA_Stdev_Pro` is a "definition-true" implementation of Tushar Chande's original **Variable Index Dynamic Average (VIDYA)**, first introduced in 1992. It is an adaptive moving average that automatically adjusts its speed based on market volatility.

This version uses Chande's original method for measuring volatility: the ratio of a **short-term Standard Deviation** to a **long-term Standard Deviation**.

* When short-term volatility increases relative to the long-term average (indicating a potential trend or breakout), the VIDYA **speeds up** and follows prices more closely.
* When short-term volatility decreases (indicating a consolidating or quiet market), the VIDYA **slows down**, smoothing out market noise.

This indicator is a powerful tool for trend analysis, providing a more responsive and intelligent alternative to traditional moving averages.

## 2. Mathematical Foundations and Calculation Logic

The VIDYA is a modified Exponential Moving Average where the smoothing factor is dynamically adjusted by a volatility factor, `k`.

### Required Components

* **VIDYA Period (N):** The base period for the EMA-like smoothing calculation.
* **Short Stdev Period (S):** The lookback period for the short-term standard deviation.
* **Long Stdev Period (L):** The lookback period for the long-term standard deviation.
* **Source Price (P)**.

### Calculation Steps (Algorithm)

1. **Calculate Standard Deviations:** Two separate standard deviations are calculated on the source price `P`.
    * $\text{Stdev}_{short} = \text{StandardDeviation}(P, S)_t$
    * $\text{Stdev}_{long} = \text{StandardDeviation}(P, L)_t$

2. **Calculate the Volatility Factor (k):** The `k` factor is the ratio of the two standard deviations.
    * $k_t = \frac{\text{Stdev}_{short_t}}{\text{Stdev}_{long_t}}$

3. **Calculate the VIDYA:** The VIDYA is calculated recursively. The standard EMA smoothing factor (`alpha`) is multiplied by the dynamic `k` factor.
    * $\alpha = \frac{2}{N + 1}$
    * $\text{VIDYA}_t = (P_t \times \alpha \times k_t) + (\text{VIDYA}_{t-1} \times (1 - \alpha \times k_t))$
    * *(Note: The effective smoothing factor, `alpha * k`, is often capped at 1 to prevent instability in extreme volatility).*

## 3. MQL5 Implementation Details

* **Modular Calculation Engine (`VIDYA_Stdev_Calculator.mqh`):** All mathematical logic is encapsulated in a dedicated include file.

* **Definition-True Calculation:** The calculator uses a **manual, built-in helper function** to calculate the standard deviation according to its precise mathematical definition. This ensures accuracy and avoids dependencies on external indicator handles.

* **Robust State Management:** VIDYA is a recursive filter. Our `CVIDYAStdevCalculator` class implements **correct state management** by storing the previous VIDYA value in a member variable (`m_prev_vidya`), which is critical for a stable and accurate calculation.

* **Object-Oriented Design (Inheritance):** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

## 4. Parameters

* **VIDYA Period (`InpVidyaPeriod`):** The base period for the VIDYA smoothing. Chande's original suggestion is `9`.
* **Stdev Short (`InpStdevShort`):** The lookback period for the short-term standard deviation. Default is `9`.
* **Stdev Long (`InpStdevLong`):** The lookback period for the long-term standard deviation. Default is `30`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The `VIDYA_Stdev_Pro` is a versatile trend-following and filtering tool.

* **Comparison to Other VIDYA Variants:**
  * **VIDYA Stdev (this indicator):** Uses a pure measure of price volatility (standard deviation). It reacts to increases in price fluctuation, regardless of direction.
  * **VIDYA RSI/CMO:** Use momentum oscillators to measure volatility. They react to the *strength* of directional movement.
    This makes the Stdev version a unique tool for analyzing volatility-driven breakouts.

* **Adaptive Trend Line:** Use it as an intelligent trend line. It will hug the price during volatile, trending moves and flatten out during quiet, consolidating periods.
* **Trend Filter:** A flat or sideways VIDYA line is a strong indication of a low-volatility, ranging market.
* **Dynamic Support and Resistance:** In a trending market, the VIDYA line can act as a dynamic level of support or resistance.
