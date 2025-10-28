# Butterworth Momentum Professional

## 1. Summary (Introduction)

The Butterworth Momentum Pro is an oscillator that applies John Ehlers' high-fidelity **Butterworth Filter** to a **momentum source (Close - Open)** instead of the price.

While the standard `Butterworth_Filter_Pro` provides an exceptionally smooth representation of the trend, this indicator isolates and smooths the bar-by-bar momentum. The Butterworth filter is a "maximally flat" filter, meaning it is designed for maximum rejection of noise outside its passband.

The result is an extremely smooth, zero-mean oscillator that clearly displays the major, underlying waves of momentum, filtering out almost all minor, insignificant fluctuations.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a Butterworth-smoothed average of the `Close - Open` value of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Momentum Source:** For each bar, the source data is calculated as `Momentum = Close - Open`.
2. **Apply Butterworth Filter:** A 2-pole or 3-pole Butterworth filter is calculated on this `Momentum` data series. The recursive formula depends on the two (or three) previous filter values and a weighted sum of recent momentum values.

## 3. MQL5 Implementation Details

* **Unified Calculator (`Butterworth_Calculator.mqh`):** This indicator uses the exact same, powerful calculator engine as the `Butterworth_Filter_Pro`. The only difference is that it is initialized in `SOURCE_MOMENTUM` mode.
* **Heikin Ashi Integration:** The indicator fully supports calculation on smoothed Heikin Ashi data (`HA Close - HA Open`).
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure the stateful, recursive calculation is always stable.

## 4. Parameters

* **Period (`InpPeriod`):** The critical period of the Butterworth filter, which controls its smoothing and responsiveness.
* **Poles (`InpPoles`):** The number of poles for the filter (2 or 3). A 3-pole filter provides maximum smoothing at the cost of increased lag.
* **Candle Source (`InpCandleSource`):** Selects between `Standard` and `Heikin Ashi` candles for the `Close - Open` calculation.

## 5. Usage and Interpretation

The Butterworth Momentum is a **slow, smooth, confirming momentum oscillator**. Its primary strength is its ability to ignore noise and show only the most significant momentum shifts.

* **Zero-Line Crossover (Trend Momentum Confirmation):**
  * A cross **above the zero line** provides a strong, albeit lagging, confirmation that bullish momentum is in control.
  * A cross **below the zero line** confirms that bearish momentum is dominant.
* **Divergence:** Due to its extreme smoothness, divergences on the Butterworth Momentum are rare but typically very significant. A clear divergence signals a high probability of a major trend reversal.
* **Caution:** This is **not a timing indicator**. Its signals are intentionally delayed due to the heavy smoothing. It should be used to confirm the primary momentum direction, not to pinpoint entries. For timing, it should be combined with a faster tool.
