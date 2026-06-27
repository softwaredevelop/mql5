# KAMA Anchored Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **KAMA Anchored Pro Suite** is an institutional-grade, high-performance trend-following suite comprising two advanced indicators: `KAMA_Anchored_Pro` (Standard) and `KAMA_Anchored_MTF_Pro` (Multi-Timeframe).

Standard technical moving averages—including Perry Kaufman's classic Adaptive Moving Average (KAMA)—carry the mathematical memory of past historical data infinitely. Over time, extreme historical price spikes can cause significant price drift and lagging distortions in current calculations.

The KAMA Anchored Suite resolves this limitation by introducing **VWAP-style Anchored Resets** (Session, Weekly, Monthly, and Custom Session). The indicators reset their calculation baseline and efficiency measurements on specific calendar events. This completely eliminates long-term price drift and overnight gap distortions, delivering a pristine, highly responsive, and localized adaptive trendline.

To ensure visual clarity, both standard and MTF indicators implement a **segmented, gapped drawing method (Odd/Even Parity Mapping)**. This prevents the messy, steep vertical connecting lines traditionally drawn across reset boundaries.

---

## 2. Mathematical Foundations and Anchoring Logic

The core mathematical engine adapts its smoothing speed dynamically based on Kaufman's Efficiency Ratio (ER), which represents the market's signal-to-noise ratio.

### A. Kaufman's Adaptive Recurrence

For each bar $t$, the ER evaluates price direction relative to absolute volatility over lookback window $N$ (`InpErPeriod`):

$$\text{Direction}_t = |P_t - P_{t-N}|$$

$$\text{Volatility}_t = \sum_{i=0}^{N-1} |P_{t-i} - P_{t-i-1}|$$

$$\text{ER}_t = \frac{\text{Direction}_t}{\text{Volatility}_t} \quad \text{clamped between } 0.0 \text{ and } 1.0$$

The Scaled Smoothing Constant (SSC) scales the exponential smoothing factor between a fastest limit ($SC_{\text{fast}}$, default 2-period EMA) and a slowest limit ($SC_{\text{slow}}$, default 30-period EMA):

$$SC_{\text{fast}} = \frac{2}{\text{FastPeriod} + 1} \quad \text{and} \quad SC_{\text{slow}} = \frac{2}{\text{SlowPeriod} + 1}$$

$$SC_t = \left[ \text{ER}_t \times (SC_{\text{fast}} - SC_{\text{slow}}) + SC_{\text{slow}} \right]^2$$

$$\text{KAMA}_t = \text{KAMA}_{t-1} + SC_t \times (P_t - \text{KAMA}_{t-1})$$

### B. Anchored Reset & Dynamic Lookback Mathematics

When a naptári anchor event is triggered at bar $t_{\text{anchor}}$, the calculator resets the cumulative state to prevent drift:

1. **Baseline Initialization:** At the reset bar, KAMA is initialized to the current price:
   $$\text{KAMA}_{t_{\text{anchor}}} = P_{t_{\text{anchor}}}$$
2. **Dyanmic ER Lookback Scaling:** To prevent the lookback window from leaking into the previous session's data, the lookback period $N_{\text{active}}$ is scaled dynamically based on the number of elapsed bars since the anchor:
   $$\text{Elapsed Bars} = t - t_{\text{anchor}}$$
   $$N_{\text{active}} = \min(\text{InpErPeriod}, \text{Elapsed Bars})$$
   $$\text{Direction}_t = |P_t - P_{t-N_{\text{active}}}| \quad \text{and} \quad \text{Volatility}_t = \sum_{i=0}^{N_{\text{active}}-1} |P_{t-i} - P_{t-i-1}|$$

---

## 3. Visual & Architectural Highlights (Odd/Even Gapped Mappings)

### A. The Connecting Line Problem

Standard MT5 trendlines are continuous. When an indicator resets its calculation value sharply at a session boundary, a continuous buffer draws a steep, messy diagonal connecting line from the end of the previous session to the start of the new one. This clutters the chart and distorts price analysis.

### B. The paired Buffer Gapped Segment Solution

To eliminate connecting lines and create clean visual gaps at reset boundaries, the suite splits the indicator into **two independent data buffers** mapped to two separate plots:

* `BufferKAMA_Odd` (Plots 1st, 3rd, 5th, etc., anchored sessions)
* `BufferKAMA_Even` (Plots 2nd, 4th, 6th, etc., anchored sessions)

To coordinate this without interrupting the recursive exponential smoothing, the calculator utilizes a dual-buffer mapping pipeline:

1. **`m_period_idx[]` State Buffer:** Tracks the active period index, incrementing by 1 on every reset.
2. **`m_kama_internal[]` State Buffer:** Smoothly calculates and stores the continuous, uninterrupted KAMA values recursively, completely independent of the visual outputs.
3. **Parity Mapping:** On each bar $i$, the calculator reads the period index parity:
   * If `m_period_idx[i]` is **Odd**, the value is written to `BufferKAMA_Odd[i]`, and `BufferKAMA_Even[i]` is assigned `EMPTY_VALUE`.
   * If `m_period_idx[i]` is **Even**, the value is written to `BufferKAMA_Even[i]`, and `BufferKAMA_Odd[i]` is assigned `EMPTY_VALUE`.

The MT5 graphic engine leaves a clean visual gap (no connecting line) wherever a buffer receives `EMPTY_VALUE`, resulting in pristine, segmented session corridors.

---

## 4. Advanced MQL5 MTF Implementation Details

### A. Forming LTF Block Flat-Force (The Warping Solution)

`KAMA_Anchored_MTF_Pro` resolves the classic MTF live-bar warping bug by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start index of the forming HTF step block on lower TF chart

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

By forcing a full-block rewrite on every live tick, the active HTF step (both Odd and Even bands) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### B. Non-Repainting State Safety on MTF Live Ticks (State Mocking)

Adaptive moving averages are highly stateful. To support real-time updating without modifying closed historical wave states (which would cause severe repainting and backtesting discrepancies), the MTF indicators utilize a highly sophisticated state-mocking call. During live updates on every tick, we pass `prev_calculated = g_htf_count` (which equals `rates_total` inside the calculator).

This forces the loop inside the calculator to run **only once** for the active live index, using the stable closed-bar registers, without overwriting, double-accumulating, or corrupting any historical states inside the recursive KAMA and ER registers.

### C. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

---

## 5. Parameters

### A. KAMA Settings

* **ER Period (`InpErPeriod`):** The lookback period used to compute Kaufman's Efficiency Ratio (Default: `10`).

* **Fastest EMA Period (`InpFastEmaPeriod`):** The lookback window for the fastest EMA limit (Default: `2`).
* **Slowest EMA Period (`InpSlowEmaPeriod`):** The lookback window for the slowest EMA limit (Default: `30`).
* **Price Source (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Anchor Settings

* **Reset Anchor Period (`InpAnchor`):** The dynamic calendar reset period (`ANCHOR_NONE`, `ANCHOR_SESSION`, `ANCHOR_WEEK`, `ANCHOR_MONTH`, `ANCHOR_CUSTOM_SESSION`). Default: `ANCHOR_SESSION` (Daily Reset).

* **Custom Session Start (`InpCustomStart`):** Session start time (HH:MM) for custom anchoring (Default: `"09:00"`).
* **Custom Session End (`InpCustomEnd`):** Session end time (HH:MM) for custom anchoring (Default: `"18:00"`).

### C. MTF Specific Parameters

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate KAMA on (Default: `PERIOD_H1`).

---

## 6. Advanced Quantitative Trading Strategies

### A. Intraday VWAP-Style Trend Following

In intraday trading, the standard Daily Reset (`ANCHOR_SESSION`) is highly effective:

* **The Concept:** At the market open, KAMA resets, and begins calculating price direction purely from the new day's action.
* **Buy Signal:** If the price trades consistently above the rising Anchored KAMA line during the session, the intraday momentum is bullish. Seek long pullback entries.
* **Sell Signal:** If the price trades consistently below the falling Anchored KAMA line, the intraday momentum is bearish.

### B. Top-Down Macro Corridor Trading (MTF Strategy)

1. **Macro Volatility Corridor (H1/H4):** Apply `KAMA_Anchored_MTF_Pro` set to H1 or H4 on an M5 execution chart, configured to Daily reset (`ANCHOR_SESSION`).
2. **The Trend Alignment:** Identify the macro trend direction based on the slope of the **H1 MTF KAMA**. If the macro KAMA is sloping upward, only seek buy setups on the lower timeframe.
3. **The Local Entry:** Because the macro KAMA segment is segmented and flat-forced, it creates clean, stable horizontal price support lines. When the local M5 price pulls back and tests the macro H1 MTF KAMA line, execute high-probability **BUY** entries, using the macro line as an absolute stop-loss barrier.
