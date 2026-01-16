# Bollinger Bands Indicator Family (Pro, %B, Width)

## 1. Summary (Introduction)

The Bollinger Bands®, developed by John Bollinger, are one of the most widely used and versatile technical analysis tools. They consist of a moving average (centerline) and two trading bands set at a certain number of standard deviations above and below the centerline. Because standard deviation is a measure of volatility, the bands automatically widen when volatility increases and narrow when volatility decreases.

This document covers our comprehensive, professionally coded MQL5 implementation of the Bollinger Bands family. Our suite goes beyond the standard indicator, offering a **`Bollinger_Bands_Pro`** version with full Heikin Ashi support and extended Moving Average types, along with two powerful derivative oscillators: **`Bollinger_Bands_PercentB`** and the **`Bollinger_Band_Width_Pro`**. Together, these tools provide a complete framework for analyzing price volatility and its relationship to the trend.

**Additionally, this document briefly covers two related, hybrid indicators in our collection: the `Bollinger_Bands_Fibonacci` and the `Bollinger_ATR_Oscillator`.**

## 2. Mathematical Foundations and Calculation Logic

All indicators in this family are derived from the same core statistical concepts: the moving average and the standard deviation.

### Required Components

- **Period (N):** The lookback period for the moving average and standard deviation calculation.
- **Deviation (D):** The number of standard deviations to set the bands away from the centerline.
- **MA Type:** The type of moving average to use for the centerline (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA).
- **Source Price:** The price series used for calculation (e.g., `PRICE_CLOSE`).

### Calculation Steps (Algorithm)

1. **Calculate the Centerline:** First, a moving average of the `Source Price` is calculated over the period `N` using the selected **MA Type**.
    - $\text{Centerline}_t = \text{MA}(\text{Price}, N, \text{Type})_t$

2. **Calculate the Standard Deviation:** The standard deviation of the `Source Price` over the same period `N` is calculated relative to the centerline.
    - $\text{StdDev}_t = \sqrt{\frac{\sum_{i=0}^{N-1} (\text{Price}_{t-i} - \text{Centerline}_t)^2}{N}}$

3. **Calculate the Main Bands:** The upper and lower bands are calculated by adding and subtracting the multiplied standard deviation from the centerline.
    - $\text{Upper Band}_t = \text{Centerline}_t + (D \times \text{StdDev}_t)$
    - $\text{Lower Band}_t = \text{Centerline}_t - (D \times \text{StdDev}_t)$

4. **Calculate Derivative Indicators:**
    - **Percent B (%B):** Normalizes the price's position relative to the bands.
        $\%B_t = \frac{\text{Price}_t - \text{Lower Band}_t}{\text{Upper Band}_t - \text{Lower Band}_t}$
    - **Band Width:** Measures the normalized width of the bands.
        $\text{BandWidth}_t = \frac{\text{Upper Band}_t - \text{Lower Band}_t}{\text{Centerline}_t}$

## 3. MQL5 Implementation Details

Our MQL5 suite is built on a shared, modular, and robust calculation engine to ensure consistency and maintainability across the entire indicator family.

- **Modular, Reusable Calculation Engine (`Bollinger_Bands_Calculator.mqh`):** The entire calculation logic is encapsulated within a single, powerful include file.
  - **Composition:** The calculator internally uses our `MovingAverage_Engine` to compute the centerline. This allows seamless support for advanced MA types like **TMA (Triangular MA)**, **DEMA**, and **TEMA**, which are rarely found in standard Bollinger implementations.
  - **Polymorphism:** The design allows all indicators in the family to dynamically choose the correct calculation engine (Standard or Heikin Ashi) at runtime based on user input.

- **Optimized Incremental Calculation:**
    All indicators employ an intelligent incremental algorithm.
  - They utilize the `prev_calculated` state to determine the exact starting point for updates.
  - **Persistent State:** The internal buffers persist their state between ticks. This allows recursive smoothing methods (like EMA, DEMA) to continue seamlessly from the last known value without re-processing the entire history.
  - This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

- **Unified "Pro" Indicators:** Instead of creating numerous separate files, we have consolidated functionality into powerful "Pro" versions.
  - **`Bollinger_Bands_Pro.mq5`**: The main indicator. A custom `enum` allows the user to select the source price, including a full range of **Heikin Ashi price types**.
  - **`Bollinger_Band_Width_Pro.mq5`**: This advanced oscillator not only displays the Band Width but also includes two additional, selectable analysis modes: **Bands on BandWidth** (for dynamic Squeeze detection) and **Extremes Channel** (for historical Squeeze/Bulge levels).

## 4. Parameters

- **Period (`InpPeriod`):** The lookback period for the MA and standard deviation. Default is `20`.
- **Deviation (`InpDeviation`):** The standard deviation multiplier. Default is `2.0`.
- **MA Type (`InpMAType`):** The type of moving average for the centerline. Options include:
  - `SMA` (Simple) - The classic Bollinger standard.
  - `EMA` (Exponential) - More responsive.
  - `SMMA` (Smoothed)
  - `LWMA` (Linear Weighted)
  - `TMA` (Triangular) - Very smooth.
  - `DEMA` (Double Exponential) - Low lag.
  - `TEMA` (Triple Exponential) - Extremely low lag.
- **Source Price (`InpSourcePrice`):** A comprehensive list of price sources, including all standard prices and a full range of Heikin Ashi prices. Default is `PRICE_CLOSE_STD`.
- **Analysis Mode (`InpDisplayMode`):** (Only for `Bollinger_Band_Width_Pro`) Allows the user to switch between the three display modes.

## 5. Usage and Interpretation

- **`Bollinger_Bands_Pro` (The Main Channel):**
  - **Volatility:** The width of the bands is the primary indicator of volatility. Narrow bands (**Squeeze**) often precede significant price moves. Wide bands indicate high volatility.
  - **Mean Reversion:** In ranging markets, prices tend to revert to the mean (the centerline).
  - **Trend Following:** In a strong trend, the price can "walk the bands," consistently running along the upper or lower band.

- **`Bollinger_Bands_PercentB` (The Oscillator):**
  - **Overbought/Oversold:** Values above 1.0 or below 0.0 indicate that the price has closed outside the bands.
  - **Divergence:** Divergence between price and %B can signal potential reversals.

- **`Bollinger_Band_Width_Pro` (The Volatility Meter):**
  - **Identifying the Squeeze:** This is the indicator's primary strength. When the Band Width line reaches a historical low (in "Extremes Channel" mode) or drops below its own lower Bollinger Band (in "Bands on BandWidth" mode), it signals a Squeeze is in effect, and traders should prepare for a potential breakout.
  - **Identifying Trend Exhaustion:** When the Band Width reaches a historical high (a "Bulge"), it often signals that the trend is mature and may be nearing exhaustion.

---

## **6. Related Hybrid Indicators**

**Our collection also includes two hybrid indicators that, while related, are based on distinct mathematical concepts.**

### **6.1 Bollinger Bands Fibonacci Ratios**

- **Concept:** This indicator uses the standard **Bollinger Bands calculation method** (MA + Standard Deviation) but replaces the single deviation multiplier with **three, separate Fibonacci ratios** (1.618, 2.618, 4.236).
- **Calculation:**
  - $\text{Upper Band 1}_t = \text{Centerline}_t + (1.618 \times \text{StdDev}_t)$
  - $\text{Upper Band 2}_t = \text{Centerline}_t + (2.618 \times \text{StdDev}_t)$
  - ...and so on for all 6 bands.
- **Interpretation:** It creates a multi-level volatility channel where each band represents a different statistical probability of price containment. It is a pure Bollinger-style indicator for advanced mean-reversion and volatility analysis.

### **6.2 Bollinger ATR Oscillator**

- **Concept:** This is a unique oscillator, described by Jon Anderson, that measures the **ratio between two different types of volatility**: the Average True Range (ATR) and the Bollinger Bandwidth.
- **Calculation:**
  - $\text{Oscillator Value}_t = \frac{\text{ATR}_t}{\text{Bollinger Bandwidth}_t} = \frac{\text{ATR}_t}{(\text{Upper Band}_t - \text{Lower Band}_t)}$
- **Advanced Configuration:** This indicator allows for independent source selection for the ATR component. You can choose to calculate the ATR from **Standard** candles (for a hybrid view) or from **Heikin Ashi** candles (for a fully smoothed view), regardless of the source used for the Bollinger Bands.
- **Interpretation:** It is a **volatility ratio oscillator**. A high value suggests that the short-term, absolute volatility (ATR) is large relative to the longer-term, mean-reverting volatility (Bandwidth), which can be characteristic of a strong, trending market. A low value may indicate a choppy, ranging market. It is a tool for analyzing the **character** of the market's volatility.
