# Ehlers Channel Pro

## 1. Summary (Introduction)

The **Ehlers Channel Pro** is a sophisticated variation of the Keltner Channel that leverages John Ehlers' advanced digital signal processing filters for the centerline.

Instead of a standard Moving Average, it uses either the **SuperSmoother** or the **UltimateSmoother**. These filters are designed to eliminate aliasing noise and provide a cleaner representation of the underlying trend with minimal lag. This results in a channel that is more stable during ranging markets and more responsive during trends compared to traditional EMA-based channels.

The bands are calculated using the **Average True Range (ATR)**, providing a volatility-adjusted envelope.

## 2. Mathematical Foundations

The indicator combines two robust algorithms:

1. **Centerline (Ehlers Filter):**
    * **SuperSmoother:** A 2-pole Butterworth filter optimized for removing noise while retaining trend.
    * **UltimateSmoother:** A variation designed to have even less lag in certain conditions.
    * Both filters use complex coefficients derived from the cutoff `Period`.

2. **Bands (ATR):**
    * $\text{Upper Band}_t = \text{Smoother}_t + (\text{Multiplier} \times \text{ATR}_t)$
    * $\text{Lower Band}_t = \text{Smoother}_t - (\text{Multiplier} \times \text{ATR}_t)$

## 3. MQL5 Implementation Details

* **Modular Design:** The calculator (`Ehlers_Channel_Calculator.mqh`) composes two independent engines: `CEhlersSmootherCalculator` for the centerline and `CATRCalculator` for the bands.
* **O(1) Incremental Calculation:** Optimized for high performance.
* **Heikin Ashi Integration:** Full support for Heikin Ashi price data for both the centerline and the ATR calculation.

## 4. Parameters

### Smoother Settings (Centerline)

* **Smoother Type:** Select between `SUPERSMOOTHER` and `ULTIMATESMOOTHER`.
* **Period:** The cutoff period for the filter (e.g., 20). Lower values make it faster but noisier.
* **Price Source:** Selects the input data (Standard or Heikin Ashi).

### Channel Settings (Bands)

* **ATR Period:** The lookback period for volatility. Default is `14`.
* **Multiplier:** The width of the channel in ATR units. Default is `2.0`.
* **ATR Source:** Selects whether to use Standard or Heikin Ashi candles for the ATR calculation.

## 5. Usage and Interpretation

### Trend Following

* **Breakout:** A candle close outside the channel often signals the start of a trend. The smoothness of the Ehlers filter helps filter out false breakouts caused by short-term noise spikes.
* **Trend Riding:** In a strong trend, price tends to stay between the centerline and the outer band.

### Mean Reversion

* **Rejection:** When the centerline is flat (indicating a range), price rejections at the outer bands are high-probability reversal signals targeting the centerline.
