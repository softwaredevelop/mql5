# Autocorrelation Pro (Indicator)

## 1. Summary

**Autocorrelation Pro** measures the "Serial Dependence" of market returns. It answers the question: *"Does yesterday's price move predict today's price move?"*

Unlike trend indicators that follow price levels, this proprietary statistical tool analyzes the relationship between the *Current Return* ($R_t$) and the *Previous Return* ($R_{t-1}$). It is a powerful filter for distinguishing between Momentum Regimes and Mean Reversion Regimes.

## 2. Methodology

The indicator calculates the **Lag-1 Pearson Correlation Coefficient** over a rolling window.

### The Formula

$$\rho_1 = \frac{\text{Cov}(R_t, R_{t-1})}{\sigma_{R_t} \sigma_{R_{t-1}}}$$

* **Positive Correlation ($\rho > 0$):** **Momentum Effect.** A positive return is likely followed by another positive return. "Winners keep winning."
* **Negative Correlation ($\rho < 0$):** **Reversion Effect.** A positive return is likely followed by a negative return (pullback). The market is "choppy" or "elastic".
* **Zero Correlation ($\rho \approx 0$):** **Random Walk.** The market has no memory; price changes are independent.

*Note: The calculation uses Logarithmic Returns ($\ln(P_t/P_{t-1})$) for statistical accuracy.*

## 3. Visualization & Interpretation

The indicator displays a colored Histogram oscillating between -1.0 and +1.0.

* **Green Bars (> 0.1):** **Trend Mode.** The market is exhibiting serial persistence. This is the optimal environment for:
  * Breakout strategies.
  * Moving Average crossovers.
  * Adding to winning positions.
* **Red Bars (< -0.1):** **Mean Reversion Mode.** The market is oscillating. Prices are rejecting new highs/lows. This is the optimal environment for:
  * Buying Support / Selling Resistance (Range Trading).
  * Fading breakouts (False Breakouts are common).
  * Bollinger Band / RSI strategies.
* **Gray Bars (-0.1 to 0.1):** **Random Noise.** No clear statistical edge.

## 4. Parameters

* `InpPeriod`: The lookback window for the correlation calculation (Default: `20`).
  * *Shorter Period (e.g., 10):* Highly reactive, good for scalping.
  * *Longer Period (e.g., 50):* Institutional regime filter.
* `InpThreshold`: The significance level for coloring (Default: `0.1`).
* `InpPrice`: The price source to analyze (Default: `PRICE_CLOSE`).

## 5. Strategic Usage

1. **Trend Filter:** Before entering a trend trade, check the Autocorrelation. If it is **Red (Negative)**, the probability of a sustained trend run is statistically low, even if other indicators say "Buy". Wait for it to turn Green.
2. **Volatile Breakouts:** If volatility is high but Autocorrelation is **Red**, expect a "V-Top" or "V-Bottom" reversal rather than a clean trend.
3. **Regime Change:** The transition from Red to Green often marks the moment a consolidation turns into a breakout.
