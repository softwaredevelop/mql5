# KAMA Channel Pro

## 1. Summary (Introduction)

The **KAMA Channel Pro** is an adaptive variation of the classic Keltner Channel. Instead of using a standard Moving Average (like SMA or EMA) for the centerline, it employs Perry Kaufman's **Adaptive Moving Average (KAMA)**.

This substitution transforms the channel into a highly responsive tool:

* **Trending Markets:** The KAMA centerline tracks price closely, and the channel expands to encompass the trend.
* **Ranging Markets:** The KAMA flattens out significantly, and the channel becomes horizontal, clearly defining the support and resistance boundaries of the range.

The bands are calculated using the **Average True Range (ATR)**, providing a volatility-adjusted envelope around the adaptive centerline.

## 2. Mathematical Foundations

The indicator combines two robust algorithms:

1. **Centerline (KAMA):**
    * Calculated based on the Efficiency Ratio (ER) of the price.
    * When ER is high (efficient, trending move), KAMA speeds up.
    * When ER is low (inefficient, choppy move), KAMA slows down.

2. **Bands (ATR):**
    * $\text{Upper Band}_t = \text{KAMA}_t + (\text{Multiplier} \times \text{ATR}_t)$
    * $\text{Lower Band}_t = \text{KAMA}_t - (\text{Multiplier} \times \text{ATR}_t)$

## 3. MQL5 Implementation Details

* **Modular Design:** The calculator (`KAMA_Channel_Calculator.mqh`) composes two independent engines: `CKamaCalculator` for the centerline and `CATRCalculator` for the bands.
* **O(1) Incremental Calculation:** Optimized for high performance.
* **Heikin Ashi Integration:** Full support for Heikin Ashi price data for both the centerline and the ATR calculation.

## 4. Parameters

### KAMA Settings (Centerline)

* **ER Period:** The lookback period for the Efficiency Ratio. Default is `10`.
* **Fast EMA Period:** The speed of KAMA during the strongest trend. Default is `2`.
* **Slow EMA Period:** The speed of KAMA during the noisiest range. Default is `30`.
* **Price Source:** Selects the input data (Standard or Heikin Ashi).

### Channel Settings (Bands)

* **ATR Period:** The lookback period for volatility. Default is `14`.
* **Multiplier:** The width of the channel in ATR units. Default is `2.0`.
* **ATR Source:** Selects whether to use Standard or Heikin Ashi candles for the ATR calculation.

## 5. Usage and Interpretation

### Trend Following (Breakouts)

* **Signal:** A candle close outside the channel (above Upper or below Lower) often signals the start of a strong impulsive move, especially if the KAMA line is also sloping in that direction.
* **Trailing Stop:** The KAMA line itself (or the opposite band) can serve as an excellent trailing stop level.

### Mean Reversion (Range Trading)

* **Context:** When the KAMA line is flat (horizontal), the market is in a range.
* **Signal:** Price touching the Upper Band is a potential sell signal (target: KAMA line). Price touching the Lower Band is a potential buy signal.

### The "Flatline" Setup

* Watch for periods where the KAMA line becomes extremely flat. This indicates a consolidation phase. A subsequent breakout from the channel is often explosive.
