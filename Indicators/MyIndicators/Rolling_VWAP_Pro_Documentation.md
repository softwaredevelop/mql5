# Rolling Volume-Weighted Average Price (Rolling VWAP) Pro (v3.20)

Quantitative Continuous Volume-Weighted Benchmark & Institutional Fair-Value Engine

---

## 1. Summary (Introduction)

**Rolling VWAP Pro** is an institutional-grade algorithmic execution benchmark and trend filter that calculates a **continuous, non-resetting Volume-Weighted Average Price** across a dynamically sliding historical window.

Traditional VWAP indicators reset at fixed temporal boundaries (daily session open, weekly open, or monthly open). While useful for intraday session profiling, anchored VWAPs suffer from two major mathematical flaws:

1. **Morning Volatility Distortion:** At the session open, sparse volume causes extreme sensitivity and errant whip-sawing.
2. **Late-Day Inertia:** Towards market close, massive cumulative volume creates inertia, rendering the indicator unresponsive to fresh market-moving momentum.

**Rolling VWAP Pro eliminates both boundaries** by enforcing a constant rolling memory horizon (e.g., the last 144 bars or the last rolling 24 hours). The indicator produces a seamless, continuous institutional fair-value curve without the artificial breaks, boundary gaps, or odd/even buffer workarounds required by anchored versions.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   ROLLING VWAP SLIDING WINDOW MODEL                    │
├────────────────────────────────────────────────────────────────────────┤
│                     [ t - Window ] ────────────▶ [ t ]                 │
│                                                                        │
│   Rolling VWAP(t) =  ∑ (TypicalPrice(k) · Volume(k)) / ∑ Volume(k)     │
│                      where k ∈ [t - Window, t]                         │
│                                                                        │
│   Calculated via Cumulative Prefix-Sums in Amortized O(1) Time         │
└────────────────────────────────────────────────────────────────────────┘

```

### The Three VWAP Paradigms

- **Anchored / Session VWAP Pro:** Resets accumulators to zero at discrete boundaries (Session, Week, Month). Highly sensitive at open; inert at close.
- **Moving Average (SMA / EMA):** Volume-blind sliding averages. Measures price-time lag without accounting for traded liquidity.
- **Rolling VWAP Pro:** Continuous sliding-window volume-weighted average. Maintains homogeneous sensitivity, volume weighting, and reactivity across every hour of the trading week.

### Key Capabilities

- **Dual Rolling Window Architecture:** Supports both fixed bar-length horizons (`ROLLING_BARS`) and physical elapsed time horizons (`ROLLING_TIME`, e.g., continuous 24-hour window).
- **Amortized $O(1)$ Prefix-Sum Architecture:** Eliminates nested loops via running integral arrays, maintaining ultra-low CPU latency regardless of window size.
- **Seamless Heikin Ashi Engine:** Direct integration with `CHeikinAshi_Calculator` to filter out microstructure noise and erratic liquidity spikes.
- **Unified 2026 MTF Architecture:** Maps higher-timeframe Rolling VWAP lines onto lower-timeframe execution charts with non-warping, staircase flat-force synchronization via `DataSync_Tools.mqh`.
- **Single-Buffer Continuous Plot:** Eliminates diagonal cross-session artifacts and segmented buffer switching.

---

## 2. Mathematical Foundations & Continuous Integration

```text

                      Incoming Candle (t): + TPV(t), + Vol(t)
                                         │
                                         ▼
   ... ───┬───────────────[ ACTIVE ROLLING WINDOW ]───────────────┬─── ...
          │                                                       │
          ▼
   Outgoing Candle (t - Window): - TPV(t - Window), - Vol(t - Window)

   Rolling VWAP = [ SumTPV(t) - SumTPV(t - Window) ] / [ SumVol(t) - SumVol(t - Window) ]

```

### 2.1. Source Typical Price ($\text{TP}_k$)

For Standard OHLC Bars:
$$\text{TP}_k = \frac{\text{High}_k + \text{Low}_k + \text{Close}_k}{3}$$

For Heikin Ashi Mode (derived via `CHeikinAshi_Calculator`):
$$\text{TP}_{\text{HA}, k} = \frac{\text{High}_{\text{HA}, k} + \text{Low}_{\text{HA}, k} + \text{Close}_{\text{HA}, k}}{3}$$

### 2.2. Cumulative Prefix-Sum Integrals

To evaluate rolling sums in $O(1)$ time across continuous streams, the engine maintains two non-destructive cumulative integral buffers:
$$\text{SumTPV}_i = \sum_{k=0}^{i} \left( \text{TP}_k \cdot V_k \right) = \text{SumTPV}_{i-1} + (\text{TP}_i \cdot V_i)$$
$$\text{SumVol}_i = \sum_{k=0}^{i} V_k = \text{SumVol}_{i-1} + V_i$$
*where $V_k$ is either Tick Volume or Real Volume based on `InpVolumeType`.*

### 2.3. Sliding Window Formulations

#### Mode A: Bar-Based Window (`ROLLING_BARS`)

Given window size $W = \text{InpRollingWindow}$, the lookback boundary is defined by index $k_{\text{left}} = i - W$:
$$\text{RollingVWAP}_i = \begin{cases}
\frac{\text{SumTPV}_i}{\text{SumVol}_i}, & \text{if } i < W \quad \text{(Warmup Expansion)} \\
\frac{\text{SumTPV}_i - \text{SumTPV}_{i - W}}{\text{SumVol}_i - \text{SumVol}_{i - W}}, & \text{if } i \ge W
\end{cases}$$

#### Mode B: Physical Time-Based Window (`ROLLING_TIME`)
Given window duration $\Delta T = \text{InpRollingWindow} \times 60 \text{ seconds}$:
$$\text{CutoffTime}_i = \text{Time}_i - \Delta T$$

The left index $k_{\text{left}}$ is located via binary search ($O(\log N)$) such that:
$$k_{\text{left}} = \min \{ j \mid \text{Time}_j \ge \text{CutoffTime}_i \}$$

$$\text{RollingVWAP}_i = \begin{cases}
\frac{\text{SumTPV}_i}{\text{SumVol}_i}, & \text{if } k_{\text{left}} \le 0 \\
\frac{\text{SumTPV}_i - \text{SumTPV}_{k_{\text{left}} - 1}}{\text{SumVol}_i - \text{SumVol}_{k_{\text{left}} - 1}}, & \text{if } k_{\text{left}} > 0
\end{cases}$$

### 2.4. Floating-Point Stability & Zero-Division Safeguard

$$\text{Output}_i = \begin{cases} \frac{\Delta \text{SumTPV}}{\Delta \text{SumVol}}, & \text{if } \Delta \text{SumVol} > 10^{-9} \\ \text{TP}_i, & \text{otherwise} \end{cases}$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│              Rolling_VWAP_Calculator.mqh               │
│   (Core Math Engine - Prefix Sums & HA Processing)     │
└──────────────────────────┬─────────────────────────────┘
                           │ Returns Rolling VWAP in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                  Rolling_VWAP_Pro.mq5                  │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (1)       │   Centralized Framework     │
│   • BufferRollingVWAP    │   • DataSync_Tools.mqh      │
│     (Single Continuous)  │   • Staircase Flat-Force    │
│                          │   • Real-Time Mock Sync     │
└──────────────────────────┴─────────────────────────────┘

```

1. **Engine-Wrapper Decoupling:** `CRollingVWAPCalculator` handles pure numerical integration and sliding-window logic without touching visual buffers or chart objects.
2. **Deterministic Expanding Warmup:** Prior to reaching the full lookback horizon, the engine smoothly computes the cumulative VWAP from bar 0 without rendering gaps or generating uninitialized floating-point values.
3. **2026 Synchronized MTF Engine:** Incorporates `CDataSync::EnsureHTFDataReady()` with a 1-second asynchronous daemon and staircase flat-force snapping on the forming higher-timeframe bar to guarantee zero repainting on closed candles.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for zero-lag native mode, or select a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_H4`) to enable the synchronized MTF engine.

### Rolling Window Configuration

* `InpRollingType` (*default: `ROLLING_BARS`*):
  * `ROLLING_BARS`: Evaluates a fixed count of past bars (e.g., last 144 candles).
  * `ROLLING_TIME`: Evaluates a continuous physical time horizon in minutes (e.g., 1440 minutes = 24 hours).
* `InpRollingWindow` (*default: `144`*): Length of the rolling window (interpreted as bar count or minutes depending on `InpRollingType`).

### Calculation Sources

* `InpVolumeType` (*default: `VOLUME_TICK`*): Applied volume stream (`VOLUME_TICK` or `VOLUME_REAL`). Automatically falls back to tick volume if real volume is unsupported by the broker.
* `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price input series (`CANDLE_STANDARD` for regular OHLC typical price or `CANDLE_HEIKIN_ASHI` for smoothed typical price).

### Visual Styling

* `InpColorVWAP` (*default: `clrDeepSkyBlue`*): Color applied to the continuous line plot.
* `InpStyleVWAP` (*default: `STYLE_SOLID`*): Plot line style (`STYLE_SOLID`, `STYLE_DASH`, etc.).
* `InpWidthVWAP` (*default: `2`*): Visual line pixel width.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                 ROLLING VWAP INSTITUTIONAL PLAYBOOKS                   │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Dynamic Value Pullback:     Buy tests of Rolling VWAP in uptrends;  │
│                                fade below in sustained downtrends.     │
│ 2. Session-Open Arbitrage:     Exploit convergence between Anchored    │
│                                Session VWAP and 24h Rolling VWAP.      │
│ 3. Multi-Timeframe Alignment:  Align M5 execution with H1/H4 Rolling   │
│                                institutional fair-value slope.         │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Dynamic Institutional Value Pullback (Trend Following)

* **Premise:** In a persistent trend, institutional execution algorithms seek to accumulate liquidity at or near the rolling fair value.
* **Bullish Setup:**
  1. Price is trading above a rising Rolling VWAP ($W = 144$ bars or $1440$ min).
  2. Price pulls back and tests the Rolling VWAP line from above.
  3. Bullish rejection candle prints (e.g., wick rejection or Heikin Ashi color flip) $\rightarrow$ **Enter Long**, placing stop-loss beyond the local swing low. Target expansion towards recent highs.
* **Bearish Setup:**
  1. Price is trading below a descending Rolling VWAP line.
  2. Price pulls back upward into the Rolling VWAP from below.
  3. Bearish rejection prints $\rightarrow$ **Enter Short**.

### 5.2. Anchor-to-Rolling Spread Arbitrage (Session-Open Anomaly)

* **Premise:** At the daily market open (00:00 server or 09:30 equities open), Anchored VWAP resets to the opening print, while the **24-Hour Rolling VWAP** retains full memory of yesterday’s institutional commitment.
* **Execution:**
  - If market opens with a large gap that pushes Anchored VWAP far away from the 24-Hour Rolling VWAP, the spread represents market overextension.
  - Mean-reversion trades targeting the **Rolling VWAP** offer favorable risk-reward before the market establishes its new intraday equilibrium.

### 5.3. Multi-Timeframe Institutional Trend Alignment

* **Configuration:** Load `Rolling_VWAP_Pro` with `InpTimeframe = PERIOD_H1` and `InpRollingWindow = 120` (5-day rolling horizon) onto an **M5 execution chart**.
* **Filter Rule:**
  - When M5 Close is strictly above H1 Rolling VWAP: Execute **Long pullbacks only**.
  - When M5 Close is strictly below H1 Rolling VWAP: Execute **Short breakdowns only**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Color / Style | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferRollingVWAP` | `INDICATOR_DATA` | `InpColorVWAP` / Continuous | Continuous Volume-Weighted Average Price stream. |

*Note: The buffer is strictly configured chronologically (`ArraySetAsSeries = false`), meaning index `rates_total - 1` corresponds to the current forming bar, and `rates_total - 2` corresponds to the latest closed bar.*

---

### MQL5 EA Integration Interface Template

Below is the verified, zero-warning MQL5 integration snippet for automated Expert Advisors:

```mql5
//+------------------------------------------------------------------+
//|                                     EA_Rolling_VWAP_Demo.mq5     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
# property copyright "Copyright 2026, xxxxxxxx"
# property version   "1.00"
# property strict

//--- Include Rolling VWAP Window Type Definition
# include <MyIncludes\Rolling_VWAP_Calculator.mqh>

//--- EA Inputs
input group "=== Rolling VWAP Filter Settings ==="
input ENUM_TIMEFRAMES     InpVWAPTimeframe = PERIOD_CURRENT; // Timeframe
input ENUM_ROLLING_TYPE   InpVWAPType      = ROLLING_BARS;   // Window Type
input int                 InpVWAPWindow    = 144;            // Window Length
input ENUM_APPLIED_VOLUME InpVWAPVolume    = VOLUME_TICK;    // Volume Source
input ENUM_CANDLE_SOURCE  InpVWAPSource    = CANDLE_STANDARD;// Candle Source

//--- Global Indicator Handle
int g_vwap_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Release previously allocated handle if present
   if(g_vwap_handle != INVALID_HANDLE)
      IndicatorRelease(g_vwap_handle);

   // Instantiate handle to Rolling_VWAP_Pro via iCustom
   g_vwap_handle = iCustom(_Symbol,
                           InpVWAPTimeframe,
                           "Rolling_VWAP_Pro",
                           InpVWAPTimeframe,
                           InpVWAPType,
                           InpVWAPWindow,
                           InpVWAPVolume,
                           InpVWAPSource,
                           clrDeepSkyBlue,
                           STYLE_SOLID,
                           2);

   if(g_vwap_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for Rolling_VWAP_Pro. Error Code: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: Rolling_VWAP_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_vwap_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_vwap_handle);
      g_vwap_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query the last 2 completed bars and the active live bar (3 values)
   double vwap_values[3];
   ArraySetAsSeries(vwap_values, true); // Index 0 = current live bar, 1 = closed bar

   // Copy from Buffer Index 0 (BufferRollingVWAP)
   if(CopyBuffer(g_vwap_handle, 0, 0, 3, vwap_values) < 3)
     {
      // History or synchronization warmup guard
      return;
     }

   double current_vwap = vwap_values[0];
   double closed_vwap  = vwap_values[1];

   // Fetch corresponding Close prices
   double close_prices[2];
   ArraySetAsSeries(close_prices, true);
   if(CopyClose(_Symbol, _Period, 0, 2, close_prices) < 2)
      return;

   double current_close = close_prices[0];
   double closed_close  = close_prices[1];

   // Quantitative Execution Example: Trend Direction Evaluation
   bool is_bullish_regime = (closed_close > closed_vwap);
   bool is_bearish_regime = (closed_close < closed_vwap);

   // Output telemetry for algorithmic monitoring
   Comment(StringFormat("Rolling VWAP [Live]: %.*f | Close: %.*f | Regime: %s",
                        _Digits, current_vwap,
                        _Digits, current_close,
                        is_bullish_regime ? "BULLISH FLOW" : (is_bearish_regime ? "BEARISH FLOW" : "NEUTRAL")));
  }
//+------------------------------------------------------------------+
```
