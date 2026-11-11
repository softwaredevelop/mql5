# MACD Pro (v6.00)

## Institutional Multi-Timeframe Moving Average Convergence/Divergence Suite with Full Volume Routing & 14 Smoothing Models

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**MACD Pro (v6.00)** is the institutional trend-momentum and divergence overlay of the Professional MQL5 Suite. Built upon the decoupled **Engine-Wrapper Component Architecture**, it synthesizes Gerald Appel’s classical Moving Average Convergence/Divergence framework with modern digital signal processing (DSP), multi-timeframe synchronization, and volume-weighted liquidity routing.

Standard MACD implementations are historically restricted to exponential moving averages (EMA) on closing prices, lack volume weighting, and suffer from severe UI latency when computing higher-timeframe trends via legacy `iBarShift()` loops. **MACD Pro eliminates these constraints by providing full interchangeability across 14 moving average algorithms, synthetic Heikin Ashi pricing, and the zero-lag 2026 MTF Fast-Path engine**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   MACD PRO ARCHITECTURAL OVERVIEW                      │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Modular Smoothing Filters  • Fast/Slow and Signal engines powered   │
│                                 by MovingAverage_Engine.mqh            │
│                               • 14 Algorithms (SMA, EMA, HMA, VWMA...) │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Volume Routing Pipeline    • Broker capability arbitration via      │
│                                 SYMBOL_VOLUME_LIMIT                    │
│                               • Real Volume (Equities/Futures) and     │
│                                 Tick Volume (Forex CFDs) support       │
├────────────────────────────────────────────────────────────────────────┤
│ 3. 2026 MTF Fast-Path Engine  • Atomic single-query CopyRates() sync   │
│                               • Two-Pointer Chronological Sweep (O(N)) │
│                               • Binary search snapping (ArrayBsearch)  │
├────────────────────────────────────────────────────────────────────────┤
│ 4. Decoupled Memory Engine    • CMACDCalculator headless math core     │
│                               • 2048-element capacity reservations     │
│                               • Sub-pip precision integrity (_Digits+2)│
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & Signal Processing Pipeline

```text
                  RAW PRICE INPUT: Standard / Synthetic Heikin Ashi
                                           │
       ┌───────────────────────────────────┴───────────────────────────────────┐
       ▼                                                                       ▼
Fast Smoothing Engine (Fast Period)                    Slow Smoothing Engine (Slow Period)
 (SMA, EMA, HMA, VWMA...)                               (SMA, EMA, HMA, VWMA...)
       │                                                                       │
       └───────────────────────────────────┬───────────────────────────────────┘
                                           │ Difference
                                           ▼
                                 MACD Value Line (t)
                            Fast MA(t) - Slow MA(t)
                                           │
                     ┌─────────────────────┴─────────────────────┐
                     │                                           │
                     ▼                                           ▼
           Signal Smoothing Engine                    Histogram Difference (t)
              (Signal Period)                      MACD Line(t) - Signal Line(t)
                     │
                     ▼
             Signal Line (t)
```

### 2.1. Price Input Series Preparation

The calculation begins by preparing the input price series $P_t$. If a synthetic Heikin Ashi price is selected (`InpSourcePrice <= PRICE_HA_CLOSE`), prices are synthesized in-place via `CHeikinAshi_Calculator`:
$$P_t = \text{PreparePriceSeries}(\text{Open}, \text{High}, \text{Low}, \text{Close}, \text{InpSourcePrice})$$

*ALU Optimization:* Standard price calculations use pipelined multiplications rather than divisions:
$$\text{PRICE\_MEDIAN} = (\text{High} + \text{Low}) \times 0.5$$
$$\text{PRICE\_TYPICAL} = (\text{High} + \text{Low} + \text{Close}) \times 0.3333333333333333$$
$$\text{PRICE\_WEIGHTED} = (\text{High} + \text{Low} + 2.0 \times \text{Close}) \times 0.25$$

### 2.2. Fast and Slow Smoothing Baselines

Two independent instances of `CMovingAverageCalculator` process the price vector $P_t$ across their respective lookbacks:
$$\text{FastMA}_t = \mathcal{M}_{\text{src}}(P, \text{FastPeriod})_t$$
$$\text{SlowMA}_t = \mathcal{M}_{\text{src}}(P, \text{SlowPeriod})_t$$
Where $\mathcal{M}_{\text{src}}$ represents any of the 14 supported algorithms (`InpSourceMAType`).

### 2.3. MACD Line Derivation

The primary MACD line measures the absolute spread between the short-term and long-term momentum baselines:
$$\text{MACD}_t = \text{FastMA}_t - \text{SlowMA}_t$$
*Initialization Alignment:* The calculation begins at bar $t = \text{SlowPeriod} - 1$. Prior bars are seeded with `EMPTY_VALUE`.

### 2.4. Signal Line Derivation

The Signal Line applies a secondary smoothing filter over the newly formed $\text{MACD}_t$ series:
$$\text{SignalLine}_t = \mathcal{M}_{\text{sig}}(\text{MACD}, \text{SignalPeriod})_t$$
Where $\mathcal{M}_{\text{sig}}$ represents the signal smoothing model (`InpSignalMAType`).

### 2.5. MACD Histogram (Divergence Oscillator)

The histogram represents the velocity difference between the MACD line and its Signal line:
$$\text{Histogram}_t = \text{MACD}_t - \text{SignalLine}_t$$

### 2.6. Full VWMA Volume Routing

When either `InpSourceMAType` or `InpSignalMAType` is set to `VWMA`, the engine queries broker capability:
$$\text{Volume}_t = \begin{cases}
\text{RealVolume}_t & \text{if } \text{SymbolInfoDouble}(\text{SYMBOL\_VOLUME\_LIMIT}) > 0 \land \text{RealVolume} > 0 \\
\text{TickVolume}_t & \text{otherwise}
\end{cases}$$
The volume-weighted moving average weights values proportionally to traded activity:
$$\text{VWMA}_t = \frac{\sum_{j=0}^{P-1} P_{t-j} \cdot \text{Volume}_{t-j}}{\sum_{j=0}^{P-1} \text{Volume}_{t-j}}$$

---

## 3. The 14 Smoothing Models Matrix

Both the source moving averages (Fast/Slow) and the signal line moving average can be independently configured using any of the 14 modular algorithms:

| Identifier | Algorithm Name | Smoothing Kernel Type | Phase Lag | Optimal Market Role in MACD |
| :--- | :--- | :---: | :---: | :--- |
| **`SMA`** | Simple Moving Average | Arithmetic Mean | High | Smooth, macro baseline; reduces whipsaws. |
| **`EMA`** | Exponential Moving Average | First-Order IIR Filter | Medium | Classical Gerald Appel default standard. |
| **`SMMA`** | Smoothed MA (Wilder's RMA) | Infinite Recursive Smoothing | Very High | Ultra-stable long-term trend baseline. |
| **`LWMA`** | Linear Weighted Moving Average | Linear Arithmetic Weights | Low | Fast, front-loaded reaction to price turns. |
| **`TMA`** | Triangular Moving Average | Cascaded SMA Convolution | Ultra-High | Eliminates high-frequency market ripples. |
| **`DEMA`** | Double Exponential MA | Second-Order Zero-Lag | Very Low | Reduces 50% of classical EMA phase lag. |
| **`TEMA`** | Triple Exponential MA | Third-Order Zero-Lag | Near-Zero | High-frequency scalping; instant reaction. |
| **`VWMA`** | Volume-Weighted MA | Volume-Proportional Weights | Dynamic | Institutional liquidity confirmation. |
| **`HMA`** | Hull Moving Average | Square-Root WMA Composite | Near-Zero | Crisp trend turns without TEMA noise. |
| **`ZLEMA`** | Zero-Lag Exponential MA | De-Lagged Momentum Injection | Low | Ehlers zero-lag tracking; early crossings. |
| **`MCGINLEY`** | McGinley Dynamic | 4th-Power Self-Adjusting | Adaptive | Hugs market selloffs; damps false spikes. |
| **`EHMA`** | Exponential Hull MA | Recursive IIR Hull Composite | Low | Smoother, recursive alternative to HMA. |
| **`MEDIAN_MA`**| Median Moving Average | Order-Statistic Median | Medium | 100% immune to bad prints and price spikes. |
| **`SWMA`** | Sine-Weighted MA | Half-Cycle Sine Kernel | Medium | Symmetric, bias-free center smoothing. |

---

## 4. Enterprise MTF Fast-Path Protocol

When configuring higher-timeframe MACD overlays on lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

```text
  HTF Domain (e.g. H1)
  [ HTF Bar 0 ]────────────────────────>[ HTF Bar 1 ]────────────────────────>[ HTF Forming ]
        │                                     │                                     │
        ▼ (Chronological 2-Pointer Projection)▼                                     ▼
  LTF Domain (e.g. M5)
  [m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5]
  └───────────────────┘ └───────────────────┘ └───────────────────┘ └───────────────────────┘
     Flat Step 0           Flat Step 1           Flat Step 2           Forming Block (Live)
```

### 4.1. Atomic Single-Query Rates Synchronization
Legacy indicators call `CopyTime()`, `CopyOpen()`, `CopyHigh()`, `CopyLow()`, `CopyClose()`, and `CopyTickVolume()` in chained sequences. This causes non-atomic race conditions during volatile live ticks.

`MACD_Pro` executes a single atomic `CopyRates()` query:
```mql5
MqlRates htf_bulk_rates[];
if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
   return 0;
```
All OHLCV arrays are updated in cache simultaneously in nanoseconds.

### 4.2. Two-Pointer Chronological Sweep ($O(N)$ Projection)
Instead of executing an $O(N \cdot M)$ loop calling `iBarShift()` on every chart candle, the engine sweeps chronologically forward using two moving pointers:
```mql5
int htf_ptr = 0;
datetime oldest_htf = h_time[0];

for(int i = 0; i < rates_total; i++)
  {
   datetime t = time[i];
   if(t < oldest_htf)
     {
      BufferMACD_Histogram[i] = 0.0;
      BufferMACDLine[i]       = EMPTY_VALUE;
      BufferSignalLine[i]     = EMPTY_VALUE;
      continue;
     }

   while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
      htf_ptr++;

   BufferMACD_Histogram[i] = h_res_hist[htf_ptr];
   BufferMACDLine[i]       = h_res_macd[htf_ptr];
   BufferSignalLine[i]     = h_res_signal[htf_ptr];
  }
```

### 4.3. Live-Tick RAM Mocking & Binary Snapping
During live market ticks where the HTF bar has not closed:
1. Only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is updated.
2. The engine recalculates bar `live_idx` locally.
3. An $O(\log N)$ binary search (`ArrayBsearch`) locates the first LTF bar of the forming HTF block:
   ```mql5
   int first_bar = ArrayBsearch(time, htf_time_current);
   ```
4. Values are direct-vector assigned across the forming block. **Zero `iBarShift()` API calls occur on live ticks.**

---

## 5. Parameters Reference

### === Timeframe Settings ===
* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Timeframe of calculation. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === MACD Core Settings ===
* **`InpFastPeriod`** (*default: `12`*): Lookback smoothing period for the Fast Moving Average.
* **`InpSlowPeriod`** (*default: `26`*): Lookback smoothing period for the Slow Moving Average.
* **`InpSignalPeriod`** (*default: `9`*): Lookback smoothing period for the Signal Line.
* **`InpSourceMAType`** (*default: `EMA`*): Moving average algorithm used for both Fast and Slow lines (Selectable across all 14 models, including VWMA and HMA).
* **`InpSignalMAType`** (*default: `EMA`*): Moving average algorithm used to smooth the Signal Line.
* **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Visual Settings - MACD Line ===
* **`InpColorMACD`** (*default: `clrDodgerBlue`*): Line color for the primary MACD Line.
* **`InpStyleMACD`** (*default: `STYLE_SOLID`*): Line style for the MACD Line.
* **`InpWidthMACD`** (*default: `2`*): Line thickness for the MACD Line.

### === Visual Settings - Signal Line ===
* **`InpColorSignal`** (*default: `clrOrangeRed`*): Line color for the Signal Line.
* **`InpStyleSignal`** (*default: `STYLE_SOLID`*): Line style for the Signal Line.
* **`InpWidthSignal`** (*default: `1`*): Line thickness for the Signal Line.

### === Visual Settings - Histogram ===
* **`InpColorHist`** (*default: `clrSilver`*): Bar color for the MACD Histogram.
* **`InpStyleHist`** (*default: `STYLE_SOLID`*): Style for the histogram bars.
* **`InpWidthHist`** (*default: `1`*): Thickness of the histogram bars.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        MACD TRADING PLAYBOOKS                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Centerline Regime Shift:    MACD crossing Zero confirms macro trend │
│                                direction and expansion momentum.       │
│ 2. Signal Crossover Trigger:   Fast MACD crossing Signal Line triggers │
│                                high-probability directional entries.   │
│ 3. Histogram Peak Contraction: Histogram rounding off at extreme peaks │
│                                signals momentum exhaustion before turn.│
│ 4. MTF Macro Trend Alignment:  Only take M5 long crossovers when the   │
│                                H1 MACD line is positive and rising.    │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Centerline (Zero-Line) Regime Shift
* **Market Context:** Transition between macro bullish expansion and bearish contraction.
* **Bullish Regime:** $\text{MACD Line} > 0.0$ confirms that the Fast MA is trading above the Slow MA.
* **Bearish Regime:** $\text{MACD Line} < 0.0$ confirms that the Fast MA is trading below the Slow MA.
* **Execution Rule:** Use zero-line crossings as an overarching directional filter. Avoid taking long trend-continuation setups when MACD is below zero.

### 6.2. Playbook 2: Signal Line Momentum Crossover
* **Bullish Crossover:** MACD Line crosses **above** the Signal Line while Histogram flips from negative to positive.
* **Bearish Crossover:** MACD Line crosses **below** the Signal Line while Histogram flips from positive to negative.
* **High-Conviction Filter:** Crossovers occurring **below zero** that cross upward offer asymmetric risk/reward long entries during deep pullbacks in macro bull markets.

### 6.3. Playbook 3: Histogram Momentum Peak Exhaustion
* **Mechanism:** The histogram ($\text{MACD} - \text{Signal}$) measures acceleration. When the histogram prints a peak and begins contracting toward zero, price momentum is stalling even if price continues to make marginal new extremes.
* **Exit Strategy:** Use the first declining histogram bar following a prolonged expansion to tighten trailing stops or scale out of trend positions.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment
* Attach an **H1-calculated MACD Pro** onto an **M5 execution chart**.
* **Quantitative Execution Rule:**
  $$\text{If } \text{BufferMACDLine}_{\text{H1 Step}} > 0.0 \land \text{BufferMACDLine}_{\text{H1 Step}} > \text{BufferSignalLine}_{\text{H1 Step}} \implies \text{Long Orders Allowed Only}$$
  $$\text{If } \text{BufferMACDLine}_{\text{H1 Step}} < 0.0 \land \text{BufferMACDLine}_{\text{H1 Step}} < \text{BufferSignalLine}_{\text{H1 Step}} \implies \text{Short Orders Allowed Only}$$
* Eliminates counter-trend scalping against higher-timeframe institutional momentum.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 3 native `INDICATOR_DATA` buffers, maintaining sub-millisecond data query performance for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferMACD_Histogram` | `DRAW_HISTOGRAM` | `clrSilver` | MACD Histogram ($\text{MACD} - \text{Signal}$) |
| **1** | `BufferMACDLine` | `DRAW_LINE` | `clrDodgerBlue` | Primary MACD Line ($\text{FastMA} - \text{SlowMA}$) |
| **2** | `BufferSignalLine` | `DRAW_LINE` | `clrOrangeRed` | Signal Moving Average Line |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read MACD Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF MACD Pro
int handle = iCustom(_Symbol, _Period, "MACD_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     12,                     // InpFastPeriod
                     26,                     // InpSlowPeriod
                     9,                      // InpSignalPeriod
                     EMA,                    // InpSourceMAType (ENUM_MA_TYPE)
                     EMA,                    // InpSignalMAType (ENUM_MA_TYPE)
                     PRICE_CLOSE_STD         // InpSourcePrice (ENUM_APPLIED_PRICE_HA_ALL)
                     // ... remaining visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create MACD_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double hist_val[], macd_val[], signal_val[];
ArraySetAsSeries(hist_val,   true);
ArraySetAsSeries(macd_val,   true);
ArraySetAsSeries(signal_val, true);

if(CopyBuffer(handle, 0, 1, 2, hist_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, macd_val) == 2 &&
   CopyBuffer(handle, 2, 1, 2, signal_val) == 2)
  {
   double hist_curr = hist_val[0];    // Closed bar (Bar 1)
   double hist_prev = hist_val[1];    // Prior closed bar (Bar 2)
   double macd_curr = macd_val[0];
   double sign_curr = signal_val[0];

   // Example Strategy: Bullish Signal Line Crossover below Zero
   bool is_bull_cross = (macd_val[1] <= signal_val[1] && macd_curr > sign_curr);

   if(is_bull_cross && macd_curr < 0.0)
     {
      // Execute Buy Order...
     }
  }
```
