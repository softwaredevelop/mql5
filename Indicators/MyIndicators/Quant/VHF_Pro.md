# Vertical Horizontal Filter (VHF) Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Vertical Horizontal Filter (VHF) Pro Suite** is an institutional-grade trend-intensity analysis suite comprising two advanced indicators: `VHF_Pro` (Standard) and `VHF_MTF_Pro` (Multi-Timeframe).

Originally developed by Adam White in 1991, the Vertical Horizontal Filter measures the mathematical "efficiency" of price movement to answer a single, critical quantitative question: **"Is the market Trending or Ranging?"**

Unlike traditional moving average-based filters that suffer from lag, VHF compares the net distance the price has traveled (Range) against the total effort/noise it took to get there (Path Length/Volatility). This yields a dimensionless, normalized coefficient between $0.0$ and $1.0$ that cleanly isolates trending phases from choppy consolidations.

---

## 2. Methodology & Calculation Modes

The indicators determine the trend intensity coefficient using the formula:

$$\text{VHF}_t = \frac{\text{Numerator (Range)}_t}{\text{Denominator (Path Length)}_t}$$

We have upgraded the classic algorithm to support two selectable calculation modes:

### Mode A: Classic (Close-Only)

* **Numerator:** Measures the net range using closing prices only over lookback $N$ (`InpPeriod`):
  $$\text{Numerator}_t = \max(C_{t \dots t-N+1}) - \min(C_{t \dots t-N+1})$$
* **Best for:** Smoother filtering on highly volatile, noisy assets.

### Mode B: Professional (High-Low)

* **Numerator:** Measures the complete trading range over lookback $N$, accounting for wicks and failed breakouts:
  $$\text{Numerator}_t = \max(H_{t \dots t-N+1}) - \min(L_{t \dots t-N+1})$$
* **Best for:** Accurate detection of trading ranges and volatility breakout setups.

### Denominator (Noise Base)

The denominator represents the total "distance walked" by the price, calculated as the sum of absolute changes of the source price over the period:

$$\text{Denominator}_t = \sum_{k=0}^{N-1} |P_{t-k} - P_{t-k-1}|$$

---

## 3. Interpretation

The suite displays a colored step-histogram representing trend intensity:

* **VHF < 0.30 (Gray Zone):** **Congestion / Chop Phase.** The market is range-bound and highly inefficient. Trend-following strategies (such as Moving Average crossovers) will fail. Use Oscillator or Mean Reversion systems.
* **VHF > 0.30 (Blue Zone):** **Emerging Trend.** A directional move is establishing itself. Volatility is beginning to expand.
* **VHF > 0.40 (Gold Zone):** **Established Trend.** Price action is highly efficient. This is the optimal "Sweet Spot" for trend-following entries.
* **Rising VHF:** Trend strength is increasing.
* **Falling VHF:** The trend is decaying or the market is transitioning back into a consolidation.

---

## 4. Advanced MQL5 MTF Implementation (The Warping Solution)

### A. The Live-Bar Warping Problem

In standard MTF implementations, updating the indicator separate-window tick-by-tick results in a highly distorted "jagged" or "fűrészfog" shape on the current forming HTF bar. Because standard `OnCalculate` only updates the very last lower timeframe (LTF) index (`rates_total - 1`), the previous LTF bars belonging to the active forming HTF block retain stale historic tick states.

### B. The Forming LTF Block Flat-Force Solution

`VHF_MTF_Pro` resolves this issue by implementing the **Forming LTF Block Flat-Force** step-alignment algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

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

By forcing a full-block rewrite on every live tick, the active HTF step (both the VHF line and the background color) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### C. Asynchronous Timer Guard & Heikin Ashi Pipeline

* **Background Timer:** High-frequency MTF data requests often suffer from terminal loading gaps. A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as history is ready.

* **Heikin Ashi Support:** The suite integrates `CVHFCalculator_HA`, which extends the standard calculator. It processes Heikin Ashi-smoothed candles (`m_ha_calculator`) internally, delivering a noise-reduced VHF value ideal for clean, macro-level trend-quality filtering.

---

## 5. Parameters

### A. Common Parameters

* **VHF Period (`InpPeriod`):** The lookback window ($N$) for the trend intensity calculation (Default: `28`).

* **VHF Mode (`InpMode`):** Select between **Classic (Close-Only)** and **Professional (High-Low)**. (Default: `VHF_MODE_CLOSE_ONLY`).
* **Applied Price (`InpSourcePrice`):** The applied price source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate trend intensity on (Default: `PERIOD_M5`).

---

## 6. Strategic Quantitative Usage

### A. Trend-Following Filter

Before entering a trend trade (e.g., MA Crossover or breakout), verify the VHF value:

* If VHF is in the **Gray Zone ($< 0.30$)**, the trend lacks statistical efficiency. Filter out the breakout signal and wait.
* Only execute trend entries when the VHF histogram turns **Blue ($> 0.30$) or Gold ($> 0.40$)**.

### B. Dynamic Exit Timing

If you are currently holding a trend position and the VHF peaks in the Gold Zone ($> 0.50$) and starts falling sharply:

* The trend is losing its momentum and transitioning back into a consolidation phase.
* *Trading Action:* Tighten stop-losses, trail stops aggressively, or take profits.

### C. Top-Down Macro Trend Filter (MTF Strategy)

1. **Macro Trend Intensity (H1/H4):** Apply `VHF_MTF_Pro` set to H1 or H4 on an M5/M15 execution chart.
2. **The Filter:** Only seek trend-following trades (e.g., EMA pullback buy setups) on the lower timeframe if the macro **H1 VHF** is **Blue ($> 0.30$) or Gold ($> 0.40$)**.
3. **The Squeeze Overlay:** If H1 VHF is **Gray ($< 0.30$)** (consolidation), ignore all local trend signals. Run range-bound grid bots or mean-reversion strategies until the macro filter confirms the emergence of a new trend.
