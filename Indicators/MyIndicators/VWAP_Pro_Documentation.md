# Volume Weighted Average Price (VWAP) Pro (v3.30)

Institutional Anchored Fair-Value Benchmark with Multi-Timeframe Fast-Path & Odd/Even Gapped Engine

---

## 1. Summary (Introduction)

**VWAP Pro** is an institutional-grade algorithmic price-volume benchmark that computes the **Volume-Weighted Average Price (VWAP)** anchored to discrete, deterministic temporal cycles (Daily Sessions, Weekly Opens, Monthly Opens, or Custom Intraday Windows).

Unlike standard unweighted moving averages that treat all bars equally, **VWAP reflects the true average price at which all market volume was committed**. In institutional trading and execution algorithms (TWAP/VWAP algorithms), this level represents the definitive liquidity equilibrium of the active session.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   ANCHORED VWAP ODD/EVEN GAPPED MODEL                  │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   Day 1 (Odd Period: Buffer 0 Active, Buffer 1 = EMPTY_VALUE)          │
│   ════════════════════════════════════════                             │
│                                           │ (Clean Gap across 00:00)   │
│                                           ▼                            │
│                               Day 2 (Even Period: Buffer 1 Active)     │
│                               ════════════════════════════════════     │
│                                                                        │
│   • Eliminates Diagonal Connector Lines Across Session Resets          │
│   • Enterprise v3.30: Zero-Lag MTF Fast-Path (0 iBarShift API calls)   │
└────────────────────────────────────────────────────────────────────────┘

```

### The Odd/Even Gapped Alternation Paradigm

Traditional charting software often renders ugly, diagonal "connector lines" across midnight or weekend session resets because a single `DRAW_LINE` buffer tries to connect the session close directly to the newly reset opening price.

**VWAP Pro cures this completely via an Alternating Odd/Even Dual-Buffer Architecture:**

- **Odd Sessions (1, 3, 5...):** Plot 1 (`BufferVWAP_Odd`) draws the active line, while Plot 2 is set to `EMPTY_VALUE`.
- **Even Sessions (2, 4, 6...):** Plot 2 (`BufferVWAP_Even`) draws the active line, while Plot 1 is set to `EMPTY_VALUE`.
- **Result:** Pristine, segmented, gap-safe session lines with zero graphical artifacts across time boundaries.

---

## 2. Mathematical Foundations & Reset Anchoring

```text

     Incoming Bar (t): + TPV(t), + Vol(t)
                         │
                         ▼
   ... ───[ RESET BOUNDARY (00:00 or Custom Open) ]───▶ CumTPV = 0, CumVol = 0
                         │
                         ▼
   VWAP(t) = ∑ ( TypicalPrice(k) · Volume(k) ) / ∑ Volume(k)
             where k ∈ [ SessionOpen, t ]

```

### 2.1. Source Typical Price ($\text{TP}_k$)

For Standard OHLC:
$$\text{TP}_k = \frac{\text{High}_k + \text{Low}_k + \text{Close}_k}{3}$$

For Heikin Ashi Mode (driven by `CHeikinAshi_Calculator`):
$$\text{TP}_{\text{HA}, k} = \frac{\text{High}_{\text{HA}, k} + \text{Low}_{\text{HA}, k} + \text{Close}_{\text{HA}, k}}{3}$$

### 2.2. Cumulative Volume-Weighted Formulation

$$\mu_{\text{VWAP}, t} = \frac{\sum_{k=\text{anchor}(t)}^{t} \left( \text{TP}_k \cdot V_k \right)}{\sum_{k=\text{anchor}(t)}^{t} V_k}$$
*where $V_k$ is Real Traded Volume (or Tick Volume if real volume is unsupported by the broker).*

---

### 2.3. Temporal Reset Modes & Boundary Detection

1. **`PERIOD_SESSION` (Daily Reset):**
   Resets when day of year increments in shifted broker time:
   $$\text{Reset} \iff \text{DayOfYear}(t + \Delta T_{\text{shift}}) \ne \text{DayOfYear}(t-1 + \Delta T_{\text{shift}})$$
2. **`PERIOD_WEEK` (Weekly Reset):**
   Resets when day of week rolls over (Monday open):
   $$\text{Reset} \iff \text{DayOfWeek}(t) < \text{DayOfWeek}(t-1)$$
3. **`PERIOD_MONTH` (Monthly Reset):**
   Resets on the first calendar bar of a new month:
   $$\text{Reset} \iff \text{Month}(t) \ne \text{Month}(t-1)$$
4. **`PERIOD_CUSTOM_SESSION` (Intraday Custom Hours):**
   Evaluates an exact time window (e.g., `09:30 - 16:00`). Resets accumulators to zero at the exact bar that enters the active session:
   $$\text{Reset} \iff \text{InSession}(t) = \text{true} \;\land\; \text{InSession}(t-1) = \text{false}$$

---

### 2.4. Alternating Buffer Allocation Logic

$$\text{PeriodIndex} = \text{Count of session resets since bar } 0$$
$$\text{Plot Selection} = \begin{cases}
\text{BufferVWAP\_Odd}[t] = \mu_{\text{VWAP}, t}, \;\; \text{BufferVWAP\_Even}[t] = \text{EMPTY\_VALUE}, & \text{if } \text{PeriodIndex} \pmod 2 \ne 0 \\
\text{BufferVWAP\_Even}[t] = \mu_{\text{VWAP}, t}, \;\; \text{BufferVWAP\_Odd}[t] = \text{EMPTY\_VALUE}, & \text{if } \text{PeriodIndex} \pmod 2 = 0
\end{cases}$$

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│                  VWAP_Calculator.mqh                   │
│   (True O(1) Incremental Engine with State Caching)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers VWAP Odd/Even Streams
                           ▼
┌────────────────────────────────────────────────────────┐
│                      VWAP_Pro.mq5                      │
│      (Unified Native & Zero-Lag MTF Fast-Path)         │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (2)       │   Centralized Framework     │
│   • BufferVWAP_Odd       │   • DataSync_Tools.mqh      │
│   • BufferVWAP_Even      │   • Binary Search Snapping  │
│                          │   • Atomic CopyRates        │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Legacy (v3.00) vs. Enterprise (v3.30)

| Metric | Legacy Implementation (v3.00) | Enterprise Refactor (v3.30) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **Engine Complexity** | $O(N)$ (50,000 bars scanned on every tick) | **Strict $O(1)$ (1 bar recalculated on live ticks)** | **50,000x Speedup** |
| **MTF Forming Bar API Calls** | 6 separate calls (`CopyOpen`, `CopyHigh`, etc.) | **1 atomic `CopyRates` call** | **-83.3% API Overhead** |
| **`iBarShift` Calls per Tick** | Up to 500 calls in `while` and `for` loops | **0 calls on live ticks (`ArrayBsearch` Fast-Path)** | **Complete Zero-Lag** |
| **Historical Repainting** | Zero repainting on closed bars | **Zero repainting on closed bars** | **100% Fidelity** |
| **Real Volume Broker Guard** | Silent fallback to tick volume | **Automated `PrintFormat` Console Notification** | **Institutional Diagnostic** |

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for zero-lag native mode, or choose a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`) to enable the synchronized MTF engine.

### Period Settings

* `InpResetPeriod` (*default: `PERIOD_SESSION`*): Temporal reset anchor mode:
  * `PERIOD_SESSION`: Resets daily at 00:00 (subject to `InpSessionTimezoneShift`).
  * `PERIOD_WEEK`: Resets weekly at Monday market open.
  * `PERIOD_MONTH`: Resets monthly at the first trading day of the month.
  * `PERIOD_CUSTOM_SESSION`: Resets strictly at `InpCustomSessionStart`.
* `InpSessionTimezoneShift` (*default: `0`*): Timezone offset in hours relative to broker server time (useful for aligning Asian, European, or US sessions to 00:00).
* `InpCustomSessionStart` (*default: `"09:30"`*): Session opening time (`HH:MM`) when using `PERIOD_CUSTOM_SESSION`.
* `InpCustomSessionEnd` (*default: `"16:00"`*): Session closing time (`HH:MM`) when using `PERIOD_CUSTOM_SESSION`.

### Calculation Settings

* `InpVolumeType` (*default: `VOLUME_TICK`*): Applied volume source (`VOLUME_TICK` or `VOLUME_REAL`). If `VOLUME_REAL` is selected but unsupported by the broker, the indicator automatically falls back to tick volume and outputs a diagnostic warning.
* `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price input series (`CANDLE_STANDARD` for regular OHLC typical price or `CANDLE_HEIKIN_ASHI` for smoothed typical price).

### Visual Settings

* `InpColorVWAP` (*default: `clrOrange`*): Color applied to both Odd and Even line plots.
* `InpStyleVWAP` (*default: `STYLE_SOLID`*): Line style of the plots.
* `InpWidthVWAP` (*default: `2`*): Visual pixel width of the VWAP curve.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                     VWAP INSTITUTIONAL PLAYBOOKS                       │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Session Open Gap Fade:      Fade opening gap overextension back to  │
│                                the newly establishing VWAP line.       │
│ 2. Institutional Value Retest: Buy pullbacks to VWAP during an active  │
│                                markup phase; sell bounces in markdown. │
│ 3. Multi-Timeframe Alignment:  Align M5 execution with H1/D1 VWAP      │
│                                institutional fair-value regime.        │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Session Open Mean Reversion Fade

* **Premise:** When market opens with an aggressive gap away from previous close, early price action is far removed from the developing VWAP.
* **Execution:**
  - As volume accumulates in the first 30–60 minutes, VWAP acts as a magnetic fair-value center of gravity.
  - Fade extreme initial expansions when lower-timeframe reversal structure prints, targeting the developing VWAP centerline.

### 5.2. Institutional Value Retest (Trend Continuation)

* **Bullish Setup:**
  1. Price expands above VWAP and establishes higher highs.
  2. A corrective pullback brings price down to touch or test the VWAP line from above.
  3. Bullish rejection prints (wick rejection or Heikin Ashi color flip) $\rightarrow$ **Enter Long**, placing stop loss below the VWAP swing low.
* **Bearish Setup:**
  1. Price is trading below a descending VWAP line.
  2. Upward corrective bounce tests VWAP from below.
  3. Bearish rejection prints $\rightarrow$ **Enter Short**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Visual Plot | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferVWAP_Odd` | `INDICATOR_DATA` | Plot 1 (`DRAW_LINE`) | VWAP values for odd-numbered sessions (1, 3, 5...). |
| **1** | `BufferVWAP_Even` | `INDICATOR_DATA` | Plot 2 (`DRAW_LINE`) | VWAP values for even-numbered sessions (2, 4, 6...). |

*Note: Because VWAP resets segment the line to prevent diagonal graphical connector artifacts, only ONE buffer contains an active value at any given bar $i$, while the other buffer is set to `EMPTY_VALUE`.*

---

### Critical EA Integration Pattern: Merged Value Extraction

When integrating `VWAP_Pro` into automated Expert Advisors via `iCustom()`, developers must evaluate **both Buffer 0 and Buffer 1** using a clean ternary fallback to obtain the true active VWAP value:

```mql5
//+------------------------------------------------------------------+
//|                                         EA_VWAP_Pro_Interface.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
# property copyright "Copyright 2026, xxxxxxxx"
# property version   "1.00"
# property strict

//--- Include VWAP Period Definition
# include <MyIncludes\VWAP_Calculator.mqh>

//--- EA Inputs
input group "=== VWAP Indicator Parameters ==="
input ENUM_TIMEFRAMES     InpVWAPTimeframe = PERIOD_CURRENT;  // Timeframe
input ENUM_VWAP_PERIOD    InpVWAPReset     = PERIOD_SESSION;  // Reset Period
input int                 InpVWAPTzShift   = 0;               // Timezone Shift
input ENUM_APPLIED_VOLUME InpVWAPVolume    = VOLUME_TICK;     // Volume Source
input ENUM_CANDLE_SOURCE  InpVWAPSource    = CANDLE_STANDARD; // Candle Source

//--- Global Indicator Handle
int g_vwap_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_vwap_handle != INVALID_HANDLE)
      IndicatorRelease(g_vwap_handle);

   // Instantiate handle to VWAP_Pro via iCustom
   g_vwap_handle = iCustom(_Symbol,
                           InpVWAPTimeframe,
                           "VWAP_Pro",
                           InpVWAPTimeframe,
                           InpVWAPReset,
                           InpVWAPTzShift,
                           "09:30", "16:00", // Custom session defaults
                           InpVWAPVolume,
                           InpVWAPSource,
                           clrOrange, STYLE_SOLID, 2);

   if(g_vwap_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for VWAP_Pro. Error Code: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: VWAP_Pro handle initialized successfully.");
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
//| Helper: Extract Merged Active VWAP Value from Odd/Even Buffers   |
//+------------------------------------------------------------------+
double GetActiveVWAP(const int shift)
  {
   double odd_buf[1], even_buf[1];

   // Copy Buffer 0 (Odd) and Buffer 1 (Even) for the target shift
   if(CopyBuffer(g_vwap_handle, 0, shift, 1, odd_buf)  < 1 ||
      CopyBuffer(g_vwap_handle, 1, shift, 1, even_buf) < 1)
     {
      return EMPTY_VALUE;
     }

   // Ternary Fallback: Pick whichever buffer holds a valid price
   if(odd_buf[0] != EMPTY_VALUE && odd_buf[0] > 0.0)
      return odd_buf[0];
   else if(even_buf[0] != EMPTY_VALUE && even_buf[0] > 0.0)
      return even_buf[0];

   return EMPTY_VALUE;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Fetch merged active VWAP for closed bar (Shift = 1) and forming bar (Shift = 0)
   double closed_vwap = GetActiveVWAP(1);
   double live_vwap   = GetActiveVWAP(0);

   if(closed_vwap == EMPTY_VALUE || closed_vwap <= 0.0)
      return; // Data still synchronizing

   // Query corresponding Close prices
   double close[2];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, _Period, 0, 2, close) < 2)
      return;

   double closed_close = close[1];

   // Quantitative Signals
   bool is_above_vwap = (closed_close > closed_vwap);
   bool is_below_vwap = (closed_close < closed_vwap);

   // Telemetry Output
   Comment(StringFormat("VWAP Telemetry:\n"
                        "Live VWAP (Shift 0): %.*f\n"
                        "Closed VWAP (Shift 1): %.*f | Closed Close: %.*f\n"
                        "Institutional Regime: %s",
                        _Digits, live_vwap,
                        _Digits, closed_vwap, _Digits, closed_close,
                        is_above_vwap ? "BULLISH BIAS (Above VWAP)" : (is_below_vwap ? "BEARISH BIAS (Below VWAP)" : "EQUILIBRIUM")));
  }
//+------------------------------------------------------------------+
```
