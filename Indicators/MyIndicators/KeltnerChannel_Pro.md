# Keltner Channel Pro

## 1. Summary (Introduction)

The Keltner Channel is a volatility-based channel indicator, with the modern version popularized by Linda Bradford Raschke. It consists of three lines: a central moving average line (Basis), an upper band, and a lower band, with the channel width determined by the Average True Range (ATR). It is primarily used to identify trend direction, measure volatility squeeze, and spot potential breakouts.

Our `KeltnerChannel_Pro` implementation is a unified, professional version that combines three distinct calculation methodologies into a single, flexible indicator:

1. **Standard:** Classic Keltner Channel using standard price data for both the MA and ATR.
2. **HA-Hybrid:** A smoothed MA based on Heikin Ashi prices, with channel width based on standard, real-market ATR.
3. **HA-Pure:** A fully smoothed channel where both the MA and the ATR are calculated from Heikin Ashi data.

The entire suite features a highly optimized $O(1)$ real-time mathematical engine, Heikin Ashi price source integration, and a dynamic volume-routing pipeline to support volume-weighted moving averages (VWMA).

---

## 2. Mathematical Foundations and Calculation Logic

The Keltner Channel is constructed by creating a channel around a central moving average, with the width determined by market volatility.

### Required Components

* **Middle Line (Basis):** A moving average of a selected price (e.g., EMA or VWMA).
* **ATR (Average True Range):** A measure of market volatility.
* **Factor (Multiplier):** A user-defined multiplier that adjusts the channel width.

### Calculation Steps (Algorithm)

1. **Calculate the Middle Line:** Compute the moving average of the selected source price. If VWMA is selected, the calculation is automatically weighted by volume:
    $$\text{Middle Line}_i = \text{MA}(\text{Source Price}, \text{MA Period})_i$$

2. **Calculate the Average True Range (ATR):** Compute the ATR for a given period (e.g., 10).

3. **Calculate the Upper and Lower Bands:** Add and subtract a multiple of the ATR from the middle line:
    $$\text{Upper Band}_i = \text{Middle Line}_i + (\text{Multiplier} \times \text{ATR}_i)$$
    $$\text{Lower Band}_i = \text{Middle Line}_i - (\text{Multiplier} \times \text{ATR}_i)$$

---

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and extreme execution speed.

* **Modular Calculation Engine (`KeltnerChannel_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **Composition Pattern:** The calculator orchestrates two powerful engines:
    1. **MA Engine:** It uses `MovingAverage_Engine.mqh` for the Middle Line, enabling advanced smoothing types (e.g., DEMA, TEMA, VWMA).
    2. **ATR Engine:** It uses `ATR_Calculator.mqh` for precise volatility measurement.
  * **ATR Source Logic:** The calculator internally checks the `InpAtrSource` parameter and decides whether to calculate the True Range from standard candles or Heikin Ashi candles.

* **Dynamic Volume Routing Pipeline:**
    To support the volume-weighted moving average (**VWMA**) as the channel basis, `KeltnerChannel_Pro` implements an automatic volume-routing pipeline in its `OnCalculate()` handler. It queries `SYMBOL_VOLUME_LIMIT` to determine if the broker provides Real Volume. It then dynamically copies either Real Volume (`volume[]`) or Tick Volume (`tick_volume[]`) and routes it down to the calculator engine, ensuring seamless and mathematically sound VWMA calculations.

* **Optimized Incremental Calculation (O(1)):**
    The indicator utilizes the `prev_calculated` state to determine the exact starting point for updates, performing calculations only on the active forming bar. The internal recursive filters (EMA, ATR, SMMA) persist their state between ticks, delivering a strict **O(1) complexity** per tick and eliminating CPU lag entirely.

---

## 4. Parameters

The indicator's parameters are logically grouped for clarity:

* **Middle Line (MA) Settings:**
  * `InpMaPeriod`: The lookback period for the middle line (Default: `20`).
  * `InpMaMethod`: The type of moving average for the middle line. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA**. (Default: `EMA`).
  * `InpSourcePrice`: The source price for the middle line (Standard or Heikin Ashi).
* **Channel (ATR) Settings:**
  * `InpAtrPeriod`: The lookback period for the ATR calculation (Default: `10`).
  * `InpMultiplier`: The factor to multiply the ATR by (Default: `2.0`).
  * `InpAtrSource`: Determines the source for the ATR calculation (`Standard` or `Heikin Ashi`), allowing you to create "Hybrid" or "Pure" HA channels.

---

## 5. Usage and Interpretation

* **Trend Identification:** The slope of the channel helps identify the trend. An upward-sloping channel suggests an uptrend, while a downward-sloping one suggests a downtrend.
* **Breakouts:** A strong close above the upper band can signal the start or continuation of an uptrend. A strong close below the lower band can signal the start or continuation of a downtrend.
* **Overbought/Oversold (in Ranges):** In a sideways, range-bound market, moves to the upper band can be seen as overbought, and moves to the lower band can be seen as oversold.
* **Volume-Weighted Basis (VWMA mode):** When the basis is set to `VWMA`, the middle line reacts faster during high-volume breakout bars and stays flatter during low-volume consolidations. This makes the channel highly adaptive to real institutional liquidity.
