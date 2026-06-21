# Volatility Regime Pro Suite (Standard & MTF)

## 1. Summary

The **Volatility Regime Pro Suite** is an institutional-grade, high-performance volatility filtering suite comprising two advanced indicators: `VolatilityRegime_Pro` (Standard) and `VolatilityRegime_MTF_Pro` (Multi-Timeframe).

Based on market microstructure theory, this suite is designed to identify the "Breathing Cycle" of financial markets: **Volatility Expansion vs Volatility Contraction.**

While traditional volatility indicators (such as standard ATR) simply represent nominal price movement ranges, this suite mathematically evaluates whether the market is actively waking up or entering a dormant state. It provides quantitative traders with a decisive macro-filter to dynamically transition between **Trend-Following / Breakout** systems (Expansion Regime) and **Mean-Reverting / Range-Trading** systems (Contraction Regime).

---

## 2. Methodology & Logic

The core mathematical engine calculates a dynamic ratio between short-term (impulsive) volatility and long-term (baseline) volatility.

### The Formula

$$\text{Volatility Ratio}_t = \frac{\text{Fast ATR}_t(P_{\text{fast}})}{\text{Slow ATR}_t(P_{\text{slow}})}$$

* **$\text{Fast ATR}(P_{\text{fast}}$ - Default: 5):** Captures the immediate, short-term "pulse" and impulsive momentum shifts of the market.
* **$\text{Slow ATR}(P_{\text{slow}}$ - Default: 50):** Establishes the stable, long-term historical baseline "noise level" of the market.

### Regime Categorization

* **Expansion Regime ($\text{Ratio} \ge \text{Threshold}$):** Short-term volatility is larger than the long-term baseline. The market is accelerating and injecting capital.
* **Contraction Regime ($\text{Ratio} < \text{Threshold}$):** Short-term volatility is lower than the long-term baseline. The market is compressing, consolidating, and building energy (often setting up for a violent "Volatility Squeeze").

---

## 3. Visualization

The indicators display a colored **Step-Histogram** oscillating around the critical $1.0$ equilibrium level.

* **Lime Green Bars ($\text{Ratio} \ge \text{InpThreshold}$):** **Active Volatility Expansion.** Market energy is high. Breakout setups are statistically likely to succeed.
* **Gray Bars ($\text{Ratio} < \text{InpThreshold}$):** **Quiet Volatility Contraction.** The market is dormant or consolidating. Trend-following strategies must stand aside due to high probabilities of false breakouts and choppy whipsaws.
* **Level 1.0 (Equilibrium):** The baseline value where short-term volatility equals long-term volatility. Crossovers of this line represent fundamental structural regime shifts.

---

## 4. Advanced MQL5 MTF Architecture (The Warping Solution)

### A. The Live-Bar Warping Problem

In standard MTF implementations, updating the indicator separate-window tick-by-tick results in a highly distorted "jagged" or "fűrészfog" shape on the current forming HTF bar. Because standard `OnCalculate` only updates the very last lower timeframe (LTF) index (`rates_total - 1`), the previous LTF bars belonging to the active forming HTF block retain stale historic tick states.

### B. The Forming LTF Block Flat-Force Solution

`VolatilityRegime_MTF_Pro` resolves this issue by implementing the **Forming LTF Block Flat-Force** step-alignment algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start index of the forming HTF step block on lower TF chart

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

By forcing a full-block rewrite on every live tick, the active HTF step remains perfectly flat and responsive in real-time, matching institutional charting standards.

### C. Asynchronous Timer Guard & Incremental O(1) Calculator

* **Background Timer:** High-frequency MTF data requests often suffer from terminal loading gaps. A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as history is ready.

* **O(1) Live-Tick ATR:** Historical ATR states are kept static. On every live tick, the latest HTF price elements are updated, and the calculators are executed incrementally on only the live index (`g_htf_count - 1`), optimizing CPU cycles.

---

## 5. Parameters

### A. Common Parameters

* **Fast ATR Period (`InpPeriodFast`):** The short-term lookback period (Default: `5`).

* **Slow ATR Period (`InpPeriodSlow`):** The long-term baseline lookback period (Default: `50`).
* **Expansion Threshold (`InpThreshold`):** The volatility ratio at which the market transitions into an Expansion Regime (Default: `1.0`).

### B. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate the Volatility Ratio on (Default: `PERIOD_H1`).

---

## 6. Strategic Quantitative Usage

### A. Breakout Confirmation

Never trade a trend breakout unless the Volatility Ratio is **Lime Green** (or has just crossed the threshold). Breakout attempts occurring in a "Gray" Contraction Regime are statistically doomed to fail due to a lack of institutional follow-through.

### B. Squeeze Pre-Signal

If the histogram drops extremely low (e.g., $< 0.70$), the market is in a state of hyper-compression. This is the setup phase for a major volatility explosion (such as a `TTM Squeeze`). Position yourself ahead of the crowd and prepare for a breakout when the histogram turns up and crosses `1.0`.

### C. Volatility Exhaustion

If the ratio reaches extreme highs (e.g., $> 1.80$ to $2.20$), volatility expansion has reached unsustainable levels ("Overheated"). These spikes represent climatic panic or buying/selling climaxes. Tighten stop-losses, trail stops aggressively, or take profits.

### D. Top-Down Volatility Alignment (MTF Core Strategy)

1. **Macro Volatility Filter (H1/H4):** Apply `VolatilityRegime_MTF_Pro` set to H1 or H4 on an M5/M15 execution chart.
2. **Momentum Alignment:** Only trade breakout and momentum trend-following strategies on the lower timeframe if the macro HTF Volatility Ratio is **Lime Green (Expanding)**.
3. **Fading Consolidations:** If the macro HTF Volatility Ratio is **Gray (Contracting)**, immediately halt trend-following bots and run range-trading oscillators (RSI/Stochastic) to fade range boundaries, as the macro structure lacks the energy to sustain breakouts.
