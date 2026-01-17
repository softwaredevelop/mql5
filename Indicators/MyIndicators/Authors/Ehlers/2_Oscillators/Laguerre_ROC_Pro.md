# Laguerre ROC Pro (Rate of Change)

## 1. Summary (Introduction)

The **Laguerre ROC Pro** is a momentum oscillator that measures the rate of change (slope) of the Laguerre Filter. By calculating the velocity of this smooth, low-lag filter instead of raw price, it provides a significantly cleaner and more reliable momentum signal than the traditional ROC indicator.

It serves as an excellent tool for identifying trend direction, strength, and potential reversals with minimal noise.

## 2. Mathematical Foundations

The indicator operates in two steps:

1. **Calculate Laguerre Filter:** First, the price is smoothed using the Laguerre Filter algorithm (controlled by `Gamma`).
2. **Calculate Rate of Change:** The change in the filter's value is calculated between the current bar and the previous bar.

### Calculation Modes

The indicator offers two modes for calculating this change:

* **Points (Slope):** Calculates the absolute difference.
  * $\text{ROC} = \text{Laguerre}_t - \text{Laguerre}_{t-1}$
  * *Best for:* Analyzing absolute volatility in pips/points on a specific instrument.

* **Percent:** Calculates the percentage change.
  * $\text{ROC} = \frac{\text{Laguerre}_t - \text{Laguerre}_{t-1}}{\text{Laguerre}_{t-1}} \times 100$
  * *Best for:* Comparing momentum across different instruments or timeframes.

## 3. Parameters

* **Gamma (`InpGamma`):** Controls the smoothness of the underlying Laguerre filter. Default is `0.7`.
* **Source Price (`InpSourcePrice`):** Selects the input data (Standard or Heikin Ashi).
* **ROC Mode (`InpROCMode`):** Selects between `ROC_POINTS` and `ROC_PERCENT`.
* **Signal Period (`InpSignalPeriod`):** The smoothing period for the Signal line (Red line). Default is `3`.
* **Signal Method (`InpSignalMethod`):** The averaging method for the Signal line.

## 4. Usage and Interpretation

### Zero Line Crossovers (Trend Reversal)

* **Bullish:** When the ROC crosses **above zero**, it means the Laguerre Filter has turned upwards. This is a primary buy signal.
* **Bearish:** When the ROC crosses **below zero**, it means the Laguerre Filter has turned downwards. This is a primary sell signal.

### Signal Line Crossovers

* For earlier entries, traders can use the crossover of the ROC line (Blue) and its Signal line (Red). This often precedes the zero crossover.

### Divergence (Trend Exhaustion)

* **Bearish Divergence:** Price makes a higher high, but the ROC makes a lower high. This indicates that the upward momentum is fading, even if price is still rising.
* **Bullish Divergence:** Price makes a lower low, but the ROC makes a higher low. This indicates waning bearish pressure.

### Momentum Strength

* The distance of the ROC line from zero indicates the strength of the trend. A steep, high ROC value suggests a strong, impulsive move. A flattening ROC near zero suggests consolidation.
