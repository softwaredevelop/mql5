# Autocorrelation Pro Suite (Standard & MTF)

## 1. Summary

The **Autocorrelation Pro Suite** is an institutional-grade, high-performance statistical suite comprising two advanced indicators:

* `Autocorrelation_Pro` (Single timeframe separate window oscillator)
* `Autocorrelation_MTF_Pro` (Multi-Timeframe separate window oscillator)

This proprietary suite measures the "Serial Dependence" of market returns in real-time. It directly answers the core quantitative question: *"Does the direction and magnitude of the current price move statistically predict the direction of the next price move?"*

Unlike trend indicators that lag behind price levels (e.g., Moving Averages), the Autocorrelation Suite analyzes the mathematical relationship between the *Current Log-Return* ($R_t$) and the *Previous Log-Return* ($R_{t-1}$). It serves as an ultimate regime filter, allowing quantitative systems to instantly distinguish between persistent Trend Regimes, mean-reverting Oscillation Regimes, and non-directional Random Walks.

---

## 2. Mathematical Methodology

To perform mathematically rigorous correlation sweeps, price series $P_t$ are first transformed into stationary logarithmic returns to prevent spurious statistics:

$$R_t = \ln\left(\frac{P_t}{P_{t-1}}\right)$$

The calculator computes the **Lag-1 Pearson Correlation Coefficient** ($\rho_1$) over a rolling window of size $N$ (`InpPeriod`):

$$\rho_1 = \frac{\text{Covariance}(R_t, R_{t-1})}{\sigma_{R_t} \times \sigma_{R_{t-1}}}$$

### Statistical Interpretations

* **Positive Correlation ($\rho_1 > \text{Threshold}$):** **Serial Persistence (Momentum).** A positive return is statistically likely to be followed by another positive return. "Winners keep winning." The market is in a sustained Trend Regime.
* **Negative Correlation ($\rho_1 < -\text{Threshold}$):** **Serial Mean-Reversion (Mean Reverting).** A positive return is statistically likely to be followed by a negative return (immediate pullback). The market is in an oscillating, range-bound, or "choppy" regime.
* **Zero Correlation ($\rho_1 \approx 0.0$):** **Random Walk (Noise).** Price returns are independent and possess no memory. There is no statistical edge for continuation or reversion.

---

## 3. Visualization & Interpretation

The indicators display a colored Histogram oscillating between the absolute boundaries of $-1.0$ and $+1.0$.

* **Green Bars ($> \text{InpThreshold}$):** **Persistent Trend Regime.** The market exhibits serial continuation.
  * *Optimal Trading Style:* Breakout strategies, Moving Average crossovers, and adding to winning positions (pyramiding).
* **Red Bars ($< -\text{InpThreshold}$):** **Mean-Reversion Regime.** The market exhibits immediate rejection of new highs and lows.
  * *Optimal Trading Style:* Buying support / selling resistance (Range Trading), fading breakouts, and employing Bollinger Bands or RSI oscillator overbought/oversold systems.
* **Gray Bars (Neutral Zone):** **Random Noise.** No statistical edge is present. Quantitative systems should stand aside or tighten execution filters.

---

## 4. Multi-Timeframe Step Alignment (Solving the Live-Bar Warping Bug)

Traditional MTF separate-window indicators often suffer from severe visual warping on their right edge. Since the MTF calculation updates tick-by-tick, updating only the latest lower timeframe (LTF) index (`rates_total - 1`) causes the older LTF bars belonging to the current forming HTF block to retain outdated tick values, creating a jagged, diagonal, or fűrészfog-like distortion.

### The Forming LTF Block Flat-Force Algorithm

`Autocorrelation_MTF_Pro` resolves this issue by implementing a robust step-blocking design pattern. On every live tick, the indicator dynamically traces back to the very first LTF bar matching the active forming HTF bar:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start index of the forming HTF step block
```

By forcing the calculation's `start` index back to the beginning of the active block on every tick, the indicator completely overwrites the entire active block uniformly. This guarantees a mathematically correct, perfectly flat horizontal block (Flat Step) on the right edge of the chart in real-time.

---

## 5. Input Parameters

### A. Common Parameters

* **Period (`InpPeriod`):** The lookback window size for the Pearson correlation calculation (Default: `20`).
  * *Short Window (5 - 15):* Highly reactive, ideal for scalp-level momentum transitions.
  * *Long Window (20 - 50):* Stabilized institutional regime filter.

* **Significance Threshold (`InpThreshold`):** The correlation level required to trigger color transitions (Default: `0.1`).
* **Applied Price (`InpPrice`):** The price series source used to compute log-returns (Default: `PRICE_CLOSE`).

### B. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The higher timeframe to calculate autocorrelation on, which is then mapped down to the current chart (Default: `PERIOD_M5`).

---

## 6. Strategic Quantitative Usage

### A. Top-Down Macro Regime Filter (MTF Strategy)

Before deploying capital on a lower timeframe trend strategy, execute a macro persistence check:

1. Apply `Autocorrelation_MTF_Pro` on an `M1` execution chart, set to monitor the **`PERIOD_H1`** target timeframe.
2. If the H1 MTF histogram is strongly **Green**, macro serial persistence is active. You are cleared to trade lower timeframe breakout and momentum trend-following strategies.
3. If the H1 MTF histogram turns **Red**, macro serial mean-reversion is dominant. Immediately halt trend-following bots and activate range-bound, support/resistance fading systems.

### B. Regime-Change Breakout Confirmation

Consolidation phases are characterized by low volatility and near-zero or negative autocorrelation (Red/Gray). The transition of the autocorrelation histogram from **Red/Gray directly into Green** is a leading statistical indicator that a consolidation is turning into a high-velocity, persistent breakout.
