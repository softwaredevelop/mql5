# Z-Score Distance Pro (Indicator)

## 1. Summary (Introduction)

The `ZScore_Distance_Pro` is a statistical oscillator designed to identify market anomalies and extremities. Unlike traditional oscillators (RSI, Stochastic) which are bounded between 0 and 100, the Z-Score is theoretically unbounded but statistically confined. It measures the "distance" between the current price and its mean (average), expressed in units of Standard Deviation (Sigma).

It is primarily used for **Mean Reversion** strategies: spotting moments where the price has deviated so far from the norm that a snap-back correction is statistically probable.

## 2. Methodology and Logic

The indicator is based on Gaussian statistics (Normal Distribution).

### The Formula

$$Z = \frac{\text{Price} - \text{Mean}}{\text{Standard Deviation}}$$

* **Mean:** Simple Moving Average (SMA) of the last $N$ periods.
* **Standard Deviation:** Volatility measurement of the last $N$ periods.

### Statistical Interpretation

Assuming normal market distribution:

* **Z = 0:** Price is exactly at the mean (Fair Value).
* **Z > +2.0:** Price is 2 Sigmas above mean. This happens only ~2.5% of the time. (Overbought).
* **Z > +3.0:** An extreme outlier event. Reversion is highly likely.

## 3. MQL5 Implementation Details

The indicator is constructed using the modular "Professional Suite" architecture.

* **Calculator Engine (`ZScore_Calculator.mqh`):**
  * **Composition:** It embeds an instance of `CMovingAverageCalculator` to compute the Mean efficiently.
  * **Standard Deviation:** The engine calculates the population standard deviation over the rolling window.
* **Performance:**
  * Utilizes `prev_calculated` for incremental processing.
  * Optimized loops ensure minimal CPU usage even on lower timeframes.
* **Visuals:**
  * Uses a `DRAW_COLOR_HISTOGRAM` to visualize the Z-Score.
  * **Dynamic Coloring:** Bars automatically turn **Red** when above +2.0 (Short warning) and **Lime** when below -2.0 (Long warning).

## 4. Parameters

* **Settings:**
  * `InpPeriod`: The lookback window for both the Mean and the Standard Deviation calculation (Default: `20`).
  * `InpPrice`: The price source to analyze (Default: `Close Price`).

## 5. Usage and Workflow

1. **Trend Continuation (Z between 0 and 2):**
    If the Z-Score is oscillating between 0 and +1.5, the trend is healthy.
2. **Mean Reversion Entry (Z > 2.0):**
    * Wait for the Z-Score to spike above +2.0 (Red Bar).
    * **Trigger:** Enter a counter-trend trade when the score starts falling back below +2.0 or when it crosses back below +1.5. This confirms that the extreme momentum is fading.
3. **The "Black Swan" (Z > 3.0):**
    Values above 3.0 indicate panic or euphoria. These levels are rare and often mark major local tops or bottoms.
4. **Confluence:**
    Combine with `Squeeze_Pro`. If a Squeeze "Fires" and hits Z-Score > 3.0, expect a violent snap-back (Fakeout).
