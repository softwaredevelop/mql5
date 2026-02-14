# Variance Ratio Pro (Indicator)

## 1. Summary

**Variance Ratio Pro** is a statistical tool designed to test the **Random Walk Hypothesis** on financial time series. It acts as a high-level regime filter by analyzing the speed of volatility expansion.

Unlike trend indicators (Moving Averages) that lag, or oscillators (RSI) that saturate, the Variance Ratio measures the **structural properties** of price movement. It answers: *"Is the market trending (persistent), reverting (anti-persistent), or random?"*

## 2. Methodology & Logic

The indicator is based on the **Lo-MacKinlay Variance Ratio Test**. Ideally, if a market is a Random Walk, the variance of returns should scale linearly with time (Variance of 2-day returns should be exactly 2x the variance of 1-day returns). Deviation from this linearity reveals the market state.

### The Formula

$$VR(q) = \frac{\text{Var}(r_q)}{q \times \text{Var}(r_1)}$$

* $Var(r_1)$: Variance of 1-period log returns over window $N$.
* $Var(r_q)$: Variance of $q$-period log returns over window $N$.

### Interpretation

The indicator oscillates around **1.0**.

* **VR > 1.0 (Green):** **Trend Phase (Persistence).** The market is moving in a specific direction faster than randomness would dictate. This is often called "Mean Aversion" (running away from the average).
* **VR < 1.0 (Blue):** **Mean Reversion (Anti-Persistence).** The market is pulling back. A step forward is likely followed by a step back. Volatility is contracting relative to time.
* **VR ≈ 1.0 (Gray):** **Random Walk.** The market is efficient and unpredictable. Price action is noise.

## 3. MQL5 Implementation Details

* **Engine (`VarianceRatio_Calculator.mqh`):**
  * **Optimization:** Uses a **Sliding Window** algorithm for variance calculation. Instead of recalculating the entire summation loop for every bar (which would be slow), it incrementally updates sums as the window slides, ensuring $O(1)$ performance even with large lookback periods.
  * **Price Engine:** Contains integrated logic to handle both Standard and Heikin Ashi price sources efficiently.
* **Visuals:**
  * Uses `DRAW_COLOR_HISTOGRAM` centered at 1.0 for intuitive reading.

## 4. Parameters

* `InpWindow`: The sample size ($N$) for the variance calculation (Default: `64`). Larger windows give smoother, more reliable signals but are slower to react.
* `InpLag`: The aggregation period ($q$) (Default: `2`). A lag of 2 compares 2-bar returns to 1-bar returns, making it very sensitive to short-term autocorrelation.
* `InpPrice`: The price source (Close, High, Low, etc.). **Recommendation:** Use `PRICE_CLOSE` (Raw Price) for statistical validity.

## 5. Strategic Usage

1. **Trend Confirmation:** Only enter breakout trades when the histogram is **Green** ($VR > 1.0$) and rising. This confirms the breakout has "momentum memory".
2. **Fade/Reversal Filter:** If looking for a reversal trade, wait for the histogram to turn **Blue** ($VR < 1.0$). This confirms the trend structure has broken and the market is now mean-reverting.
3. **Noise Filter:** Avoid trading when the histogram is **Gray** (around 1.0). The market is random, and technical signals are likely false positives.
