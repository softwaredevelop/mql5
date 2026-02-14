# Entropy Pro (Indicator)

## 1. Summary

**Entropy Pro** is a cutting-edge quantitative indicator based on Information Theory. It measures the **Regularity** and **Predictability** of price action.

While volatility indicators (like ATR) measure *how much* the price moves, Entropy measures *how chaotically* it moves. It answers the question: *"Is the market structure organized (Trend/Cycle) or random (Noise)?"*

## 2. Methodology & Logic

The indicator uses the **Sample Entropy (SampEn)** algorithm, which is robust even for shorter time series typical in trading.

* **Logic:** It counts how often specific price patterns (of length $m$) repeat themselves within a tolerance ($r$).
* **High Entropy:** Low repetition. The market is full of surprises. Pure Noise.
* **Low Entropy:** High repetition. The market structure is rigid and predictable. This usually happens during strong Trends or tightly controlled Ranges (Accumulation).

## 3. Visualization & Interpretation

The indicator uses a **Colored Histogram** to signal market states.

* **Green Bars (Low Entropy < 1.0):** **Organized State.** The market is "locked in".
  * If associated with a directional move, it confirms a **Reliable Trend**.
  * If associated with a flat market, it signals **Consolidation** (pre-breakout tension).
* **Gray Bars (High Entropy > 1.5):** **Chaotic State.** The market is disorderly. Price action is efficient (random walk) and hard to predict. Technical signals are unreliable here.

## 4. Parameters

* `InpPeriod`: The rolling window size for analysis (Default: `50`).
  * *Shorter (`30`):* More reactive for scalping.
  * *Longer (`100`):* Better for regime detection on H1/H4 timeframes.
* `InpDim`: Pattern length to match (Default: `2`). Standard for SampEn.
* `InpTol`: Tolerance coefficient (Default: `0.2`). Determines how strict the pattern matching is relative to standard deviation.

## 5. Strategic Usage

1. **Trend Confirmation:** A strong trend should ideally have **Decreasing Entropy**. If the price is rising but Entropy is skyrocketing (Gray bars spiking), the trend is unstable and "nervous" (prone to crash).
2. **Breakout Validation:** Breakouts often occur from zones of Low Entropy. A breakout accompanied by Low Entropy (Green bars) is statistically more likely to sustain.
3. **Hurst Combination:** Entropy and Hurst are natural partners.
    * **Low Entropy + High Hurst:** The "Golden Zone" for trend following.
    * **High Entropy + Hurst ~ 0.5:** Random Walk (Stay Out).
