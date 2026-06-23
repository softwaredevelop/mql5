# Volatility Squeeze Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Volatility Squeeze Pro Suite** is an institutional-grade volatility analysis suite comprising two advanced indicators: `Squeeze_Pro` (Standard) and `Squeeze_MTF_Pro` (Multi-Timeframe).

Based on John Carter's legendary "TTM Squeeze" concept, the suite identifies periods of extreme price consolidation (where energy is stored) and the subsequent explosive breakouts (where energy is released).

Instead of lagging behind price action (like traditional trend filters), the Squeeze suite monitors the co-dependency of two volatility envelopes: **Bollinger Bands** (standard deviation volatility) and **Keltner Channels** (average true range volatility). By mapping this structural interaction against a smoothed momentum oscillator, the suite allows quantitative traders to successfully time breakouts and avoid choppy, non-trending consolidations.

---

## 2. Methodology and Logic

The Squeeze principle relies on the physical and statistical interaction between two distinct volatility boundaries:

1. **Bollinger Bands (BB):** Measure volatility based on standard deviation around a moving average baseline. They contract tightly during low-volatility periods.
2. **Keltner Channels (KC):** Measure the normal ATR (Average True Range) volatility range.

### The "Squeeze" Compression Logic

* **SQUEEZE ON (Red Dots):** Triggered when the Bollinger Bands contract completely *inside* the Keltner Channels:
  $$\text{BB}_{\text{upper}} < \text{KC}_{\text{upper}} \quad \text{AND} \quad \text{BB}_{\text{lower}} > \text{KC}_{\text{lower}}$$
  This state indicates compressed volatility—the market is accumulating energy and preparing for an explosive directional run.
* **SQUEEZE OFF (Green Dots):** Triggered when the Bollinger Bands expand *outside* the Keltner Channels:
  $$\text{BB}_{\text{upper}} \ge \text{KC}_{\text{upper}} \quad \text{OR} \quad \text{BB}_{\text{lower}} \le \text{KC}_{\text{lower}}$$
  The compression is released. Volatility expands, and a high-velocity momentum move begins.

### Momentum Histogram

To determine the directional bias of the potential breakout, the indicator calculates a smoothed momentum oscillator representing the price delta from the mean of the Donchian Channel and the baseline SMA:

$$\text{Mom}_t = \text{Price}_t - \left( \frac{\text{Donchian Mid}_t + \text{SMA}_t}{2} \right)$$

* **Blue Bars:** Rising bullish momentum (long biased).
* **Red/Crimson Bars:** Falling bearish momentum (short biased).

---

## 3. Advanced MQL5 MTF Implementation (The Warping Solution)

### A. The Live-Bar Warping Problem

In standard MTF implementations, updating the indicator separate-window tick-by-tick results in a highly distorted "jagged" or "fűrészfog" shape on the current forming HTF bar. Because standard `OnCalculate` only updates the very last lower timeframe (LTF) index (`rates_total - 1`), the previous LTF bars belonging to the active forming HTF block retain stale historic tick states.

### B. The Forming LTF Block Flat-Force Solution

`Squeeze_MTF_Pro` resolves this issue by implementing the **Forming LTF Block Flat-Force** step-alignment algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

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

By forcing a full-block rewrite on every live tick, the active HTF step (both the momentum histogram and the squeeze dots) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### C. Asynchronous Timer Guard & Incremental O(1) Calculator

* **Background Timer:** High-frequency MTF data requests often suffer from terminal loading gaps. A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as history is ready.

* **O(1) Live-Tick Calculation:** Historical Squeeze states are kept static. On every live tick, the latest HTF price elements are updated, and the calculators are executed incrementally on only the live index (`g_htf_count - 1`), optimizing CPU cycles.

---

## 4. Parameters

### A. Squeeze Settings

* **Lookback Length (`InpPeriod`):** The lookback period for both Bollinger Bands and Keltner Channels (Default: `20` bars).

* **Bollinger Multiplier (`InpBBMult`):** Standard Deviation multiplier for the Bollinger Bands (Default: `2.0`). High values require tighter compression to trigger a Squeeze.
* **Keltner Multiplier (`InpKCMult`):** ATR multiplier for the Keltner Channels (Default: `1.5`).
* **Price Source (`InpPrice`):** Standard price source used for the calculation (Default: `PRICE_CLOSE`).

### B. Momentum Settings

* **Momentum Period (`InpMomPeriod`):** The lookback window for the momentum/linear regression calculation (Default: `12`).

### C. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate volatility compression on (Default: `PERIOD_H1`).

---

## 5. Usage and Interpretation

### A. The Accumulation Phase (Red Dots)

A sequence of **Red Dots** on the zero line indicates a squeeze is active. Volatility is highly compressed, and liquidity is building up. This is a "No-Trade Zone" for trend-followers. Wait for the release.

### B. The Breakout Release (First Green Dot)

When the zero line transitions from **Red to Green**, the squeeze has fired.

* **Buy Trigger (Long):** If the momentum histogram is **Blue (above 0.0)** at the moment of the trigger.
* **Sell Trigger (Short):** If the momentum histogram is **Red/Crimson (below 0.0)** at the moment of the trigger.

### C. Exiting the Position

Consider scaling out of trend positions when the momentum histogram changes color shade (starts decreasing back toward the zero line) or when the momentum bars return to zero.

### D. Top-Down Macro Squeeze Plays (MTF Core Strategy)

1. **Macro Volatility Squeeze (H1/H4):** Apply `Squeeze_MTF_Pro` set to H1 or H4 on an M5 execution chart.
2. **The Setup:** Wait for **H1 MTF Squeeze** to turn **Red (ON)**. This signals a major institutional-level consolidation on the macro timeframe.
3. **The Trigger:** Monitor the lower timeframe execution chart. The moment the macro H1 Squeeze fires **Green**, execute a trade in the direction of the macro momentum on the lower timeframe, capturing the first momentum leg of a major macro expansion.
