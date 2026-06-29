# Moving Average Anchored Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Moving Average Anchored Pro Suite** represents a major technological leap in financial charting. While standard moving averages (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA) accumulate historical price memory infinitely—carrying old price spikes and gaps across days or weeks—the Anchored MA Suite introduces **VWAP-style Anchored Resets** (Session, Weekly, Monthly, and Custom Session).

At each dynamic calendar reset, the indicator completely flushes its historical smoothing memory, resetting its baseline to the current price. It then dynamically scales its lookback period ($P_{\text{active}}$) to adapt purely to the current active session, delivering a highly localized, responsive, and gap-independent trendline.

To prevent ugly visual connecting lines across reset boundaries, the indicators implement a **segmented, gapped drawing method (Odd/Even Parity Mapping)**, leaving clean visual gaps at every reset point.

---

## 2. Mathematical Foundations and Dynamic Lookback Scaling

Instead of a fixed, rigid lookback period, the Anchored MA Engine dynamically scales its lookback window ($P_{\text{active}}$) based on the number of elapsed bars since the latest anchor reset bar ($t_{\text{anchor}}$):

$$\text{Elapsed Bars} = t - t_{\text{anchor}}$$

$$P_{\text{active}} = \min(\text{InpPeriod}, \text{Elapsed Bars} + 1)$$

### A. Dynamic Initialization

At the exact reset bar ($t = t_{\text{anchor}}$, where $P_{\text{active}} = 1$), the moving average is initialized directly to the source price:

$$\text{MA}_{t_{\text{anchor}}} = P_{t_{\text{anchor}}}$$

### B. Adaptive Moving Average Formulations (On the Fly)

For all subsequent bars where $t > t_{\text{anchor}}$, the engine dynamically adapts the mathematical calculations using the changing $P_{\text{active}}$ window:

- **Simple Moving Average (SMA):**
  $$\text{SMA}_t = \frac{1}{P_{\text{active}}} \sum_{k=0}^{P_{\text{active}}-1} P_{t-k}$$

- **Exponential Moving Average (EMA):**
  The smoothing constant ($pr$) scales dynamically on every bar:
  $$pr_t = \frac{2.0}{P_{\text{active}} + 1.0}$$
  The state is seeded on the anchor boundary or when the historical state register is uninitialized:
  $$\text{EMA}_t = \begin{cases}
    P_t & \text{if } t = t_{\text{anchor}} \text{ or } \text{EMA}_{t-1} = \text{EMPTY\_VALUE} \\
    P_t \times pr_t + \text{EMA}_{t-1} \times (1.0 - pr_t) & \text{otherwise}
  \end{cases}$$

- **Smoothed Moving Average (SMMA):**
  The smoothing constant ($pr$) scales dynamically:
  $$pr_t = \frac{1.0}{P_{\text{active}}}$$
  $$\text{SMMA}_t = P_t \times pr_t + \text{SMMA}_{t-1} \times (1.0 - pr_t)$$

- **Linear Weighted Moving Average (LWMA):**
  The weights are adjusted dynamically based on the current $P_{\text{active}}$ depth:
  $$\text{LWMA}_t = \frac{\sum_{k=0}^{P_{\text{active}}-1} P_{t-k} \times (P_{\text{active}} - k)}{\sum_{k=1}^{P_{\text{active}}} k}$$

- **Double Exponential Moving Average (DEMA):**
  Calculates a dynamic double EMA recursively using the dynamic EMA engine:
  $$\text{DEMA}_t = 2.0 \times \text{EMA1}_t - \text{EMA2}_t$$

- **Triple Exponential Moving Average (TEMA):**
  $$\text{TEMA}_t = 3.0 \times \text{EMA1}_t - 3.0 \times \text{EMA2}_t + \text{EMA3}_t$$

- **Volume-Weighted Moving Average (VWMA):**
  Calculates the volume-weighted price sum over the dynamic $P_{\text{active}}$ window:
  $$\text{VWMA}_t = \frac{\sum_{k=0}^{P_{\text{active}}-1} P_{t-k} \times \text{Volume}_{t-k}}{\sum_{k=0}^{P_{\text{active}}-1} \text{Volume}_{t-k}}$$

---

## 3. Visual & Architectural Highlights (Odd/Even Gapped Mappings)

### A. The Paired Buffer Gapped Segment Solution

Standard MT5 trendlines are continuous. When an indicator resets its calculation value sharply at a session boundary, a continuous buffer draws a steep, messy diagonal connecting line from the end of the previous session to the start of the new one. This clutters the chart and distorts price analysis.

To eliminate connecting lines and create clean visual gaps at reset boundaries, the suite splits the indicator into **two independent data buffers** mapped to two separate plots:

- `BufferMA_Odd` (Plots 1st, 3rd, 5th, etc., anchored sessions)
- `BufferMA_Even` (Plots 2nd, 4th, 6th, etc., anchored sessions)

To coordinate this without interrupting the recursive calculations, the calculator utilizes a dual-buffer mapping pipeline:

1. **`m_period_idx[]` State Buffer:** Tracks the active period index, incrementing by 1 on every reset.
2. **`m_ma_internal[]` State Buffer:** Smoothly calculates and stores the continuous, uninterrupted MA values recursively, completely independent of the visual outputs. This is crucial for recursive smoothing methods (EMA, SMMA, DEMA, TEMA) to maintain their memory.
3. **Parity Mapping:** On each bar $i$, the calculator reads the period index parity:
   - If `m_period_idx[i]` is **Odd**, the value is written to `BufferMA_Odd[i]`, and `BufferMA_Even[i]` is assigned `EMPTY_VALUE`.
   - If `m_period_idx[i]` is **Even**, the value is written to `BufferMA_Even[i]`, and `BufferMA_Odd[i]` is assigned `EMPTY_VALUE`.

The MT5 graphic engine leaves a clean visual gap (no connecting line) wherever a buffer receives `EMPTY_VALUE`, resulting in pristine, segmented session corridors.

---

## 4. Advanced MQL5 MTF Implementation Details

### A. Forming LTF Block Flat-Force (The Warping Solution)

`MovingAverage_Anchored_MTF_Pro` resolves the classic MTF live-bar warping bug by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block. This ensures the entire active HTF block (both Odd and Even bands) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### B. Strict Non-Repainting State Safety on MTF Live Ticks (State Mocking)

Adaptive/recursive moving averages (EMA, SMMA, DEMA, TEMA, VWMA) are highly stateful. To support real-time updating without modifying closed historical wave states (which would cause severe repainting and backtesting discrepancies), the MTF indicators utilize a highly sophisticated state-mocking call. During live updates on every tick, we pass `prev_calculated = g_htf_count` (which equals `rates_total` inside the calculator).

This forces the loop inside the calculator to run **only once** for the active live index, using the stable closed-bar registers, without overwriting, double-accumulating, or corrupting any historical states inside the recursive registers.

### C. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

### D. Strict Array Direction Alignment

To prevent data alignment issues and array index corruption under variable client-terminal environment setups, all price arrays, input arrays, and the global cached higher timeframe volume buffer (`h_vol`) are explicitly coerced into standard chronological order using `ArraySetAsSeries(..., false)` prior to calculation. This ensures flawless index alignment ($O(1)$ mapping operations) and guarantees that index $0$ consistently represents the oldest historical bar.

### E. Memory Safety and Pointer Guard

To guarantee bulletproof operational stability and prevent terminal-level runtime exceptions (specifically Access Violations), the `OnCalculate` entry point in both the standard and multi-timeframe wrappers includes a dedicated validation layer. If the dynamic calculator instance `g_calculator` is uninitialized or becomes invalid (`POINTER_INVALID`), all calculation pathways are bypassed, safely exiting with a fallback return value of `0` until state restoration is achieved.

---

## 5. Parameters

### A. MA Settings

- **Lookback Period (`InpPeriod`):** The lookback period ($N$) used to calculate the moving average baseline (Default: `20`).
- **Moving Average Type (`InpMAType`):** Select the baseline moving average type (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA). Default: `SMA`.
- **Price Source (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Anchor Settings

- **Reset Anchor Period (`InpAnchor`):** The dynamic calendar reset period (`ANCHOR_NONE`, `ANCHOR_SESSION`, `ANCHOR_WEEK`, `ANCHOR_MONTH`, `ANCHOR_CUSTOM_SESSION`). Default: `ANCHOR_SESSION` (Daily Reset).
- **Custom Session Start (`InpCustomStart`):** Session start time (HH:MM) for custom anchoring (Default: `"09:00"`).
- **Custom Session End (`InpCustomEnd`):** Session end time (HH:MM) for custom anchoring (Default: `"18:00"`).

### C. MTF Specific Parameters

- **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate KAMA on (Default: `PERIOD_H1`).

---

## 6. Strategic Quantitative Usage

### A. Intraday VWAP-Style Trend Following

In intraday trading, the standard Daily Reset (`ANCHOR_SESSION`) is highly effective:

- **The Concept:** At the market open, the selected moving average resets, and begins calculating price direction purely from the new day's action, filtering out historical overhead.
- **Buy Signal:** If the price trades consistently above the rising Anchored MA line during the session, the intraday momentum is bullish. Seek long pullback entries.
- **Sell Signal:** If the price trades consistently below the falling Anchored MA line, the intraday momentum is bearish.

### B. Top-Down Macro Corridor Trading (MTF Strategy)

1. **Macro Volatility Corridor (H1/H4):** Apply `MovingAverage_Anchored_MTF_Pro` set to H1 or H4 on an M5 execution chart, configured to Daily reset (`ANCHOR_SESSION`).
2. **The Trend Alignment:** Identify the macro trend direction based on the slope of the **H1 MTF Anchored MA**. If the macro MA is sloping upward, only seek buy setups on the lower timeframe.
3. **The Local Entry:** Because the macro MA segment is segmented and flat-forced, it creates clean, stable horizontal price support lines. When the local M5 price pulls back and tests the macro H1 MTF MA line, execute high-probability **BUY** entries, using the macro line as an absolute stop-loss barrier.
