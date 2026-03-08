# V-Score Pro (Indicator)

## 1. Summary

**V-Score Pro** (Volume-Weighted Score) is an institutional Mean Reversion indicator. While standard Z-Scores measure deviation from a simple time-based average (SMA), the V-Score measures deviation from the **Volume-Weighted Average Price (VWAP)**.

This distinction is critical: VWAP represents the "True Value" or the average price paid by all participants. Therefore, V-Score tells you if the current price is "Expensive" or "Cheap" relative to where the real money has been transacted.

## 2. Methodology & Logic

The indicator calculates how many Standard Deviations ($\sigma$) the price is away from the VWAP.

### The Formula

$$V\text{-}Score = \frac{\text{Price} - \text{VWAP}}{\sigma_{(Price - VWAP)}}$$

* **Numerator:** The distance between the current price and the VWAP.
* **Denominator:** The standard deviation of this distance over a rolling window ($N$).

### Interpretation

The indicator oscillates around **0.0** (which is the VWAP line).

* **+2.0 Sigma (Orange/Red):** Price is statistically expensive given the volume profile. The elastic band is stretched. Reversion to VWAP is likely.
* **-2.0 Sigma (Blue):** Price is statistically cheap. Good area for value buying.
* **0.0 (Gray):** Price is at fair value (on the VWAP).

## 3. MQL5 Implementation Details

* **Engine (`VScore_Calculator.mqh`):**
  * Integrates the `CVWAPCalculator` engine to ensure the VWAP baseline matches the standard institutional calculation (anchored to Session, Week, or Month).
  * Calculates standard deviation dynamically on the deviation array, not just raw price variance.
* **Visuals:**
  * Colored Histogram for instant state recognition.

## 4. Parameters

* `InpPeriod`: The rolling window for standard deviation calculation (Default: `20`). A shorter period makes the bands tighter and the score more volatile.
* `InpVWAPReset`: The anchor for the VWAP calculation.
  * `PERIOD_SESSION` (Default): Resets daily. Use for Intraday trading.
  * `PERIOD_WEEK`: Resets weekly. Use for Swing trading.
  * `PERIOD_MONTH`: Resets monthly. Use for Position trading.

## 5. Strategic Usage

1. **Mean Reversion:**
    When the V-Score hits **+2.0** or **+3.0** and starts to curl back down, it is a high-probability short signal targeting the VWAP (0.0).
2. **Trend Continuation (The "Value" Play):**
    In a strong uptrend, wait for the V-Score to drop below **-1.0** or **-2.0** (Oversold relative to VWAP) to enter Long. Do not buy when V-Score is already > 2.0.
3. **Squeeze Confluence:**
    If `Squeeze_Pro` shows a Squeeze (Low Volatility) and V-Score is near 0.0, a significant move is imminent, launching from Fair Value.
