# Money Flow Index (MFI) Pro (v2.00)

## Institutional Multi-Timeframe Volume-Weighted Momentum Oscillator Suite with Dual Volume Routing & 14 Signal Smoothing Models

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**Money Flow Index (MFI) Pro (v2.00)** is the institutional volume-weighted momentum oscillator of the Professional MQL5 Suite. Built upon the decoupled **Engine-Wrapper Component Architecture**, it synthesizes Gene Quong and Avrum Soudack’s classical Money Flow Index formulation with modern digital signal processing (DSP), multi-timeframe synchronization, dual-mode volume routing, and 14 pluggable moving average signal algorithms.

While standard RSI measures only price rate-of-change, **MFI incorporates trading volume to measure institutional capital flow into and out of an asset (often termed "Volume-Weighted RSI")**. Standard platform implementations suffer from division-by-zero crashes during strong trends where negative flow is absent, lack volume capability arbitration, and provide zero MTF support. **MFI Pro resolves these defects through an algebraically reduced zero-division engine, customizable Heikin Ashi pricing, and the zero-lag 2026 MTF Fast-Path protocol**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                     MFI PRO ARCHITECTURAL OVERVIEW                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Algebraic Zero-Division     • (100 · PosSum) / (PosSum + NegSum)    │
│    Immunity Engine             • Completely eliminates division-by-zero│
│                                • 50% ALU floating-point reduction      │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Dual Volume Routing Engine • Broker capability arbitration via      │
│                                 SYMBOL_VOLUME_LIMIT                    │
│                               • Real Volume (Equities/Futures) and     │
│                                 Tick Volume (Forex CFDs) support       │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Modular Signal Line Engine • 14 Pluggable Smoothing Models          │
│                                 (SMA, EMA, HMA, ZLEMA, VWMA...)        │
│                               • Powered by MovingAverage_Engine.mqh    │
├────────────────────────────────────────────────────────────────────────┤
│ 4. 2026 MTF Fast-Path Engine  • Atomic single-query CopyRates() sync   │
│                               • Two-Pointer Chronological Sweep (O(N)) │
│                               • Binary search snapping (ArrayBsearch)  │
├────────────────────────────────────────────────────────────────────────┤
│ 5. Decoupled Memory Core      • CMFICalculator headless math core      │
│                               • 2048-element capacity reservations     │
│                               • Sub-pip precision scaling (2 Digits)   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & Volumetric DSP Pipeline

```text
                  RAW PRICE & VOLUME INPUT: Real / Tick Volume
                                           │
       ┌───────────────────────────────────┴───────────────────────────────────┐
       ▼                                                                       ▼
Typical Price Derivation (TP)                                Volume Capability Router
(High + Low + Close) / 3                                 (Real Volume vs. Tick Volume)
       │                                                                       │
       └───────────────────────────────────┬───────────────────────────────────┘
                                           │
                                           ▼
                               Raw Money Flow (RMF)
                                   TP(t) · Volume(t)
                                           │
                                           ▼
                          Polarity Flow Splitting (O(1))
                           TP(t) > TP(t-1)  -> PosMF = RMF, NegMF = 0
                           TP(t) < TP(t-1)  -> PosMF = 0, NegMF = RMF
                                           │
                                           ▼
                           Rolling Summation Window (P)
                          PosSum = Σ PosMF,   NegSum = Σ NegMF
                                           │
                                           ▼
                        Algebraic Zero-Division MFI Formula
                        (100 · PosSum) / (PosSum + NegSum)
                                           │
               ┌───────────────────────────┴───────────────────────────┐
               ▼                                                       ▼
        Raw MFI Series Line                                 Signal Smoothing Engine
      Bounded Scale (0 to 100)                              (14 Selectable MA Models)
               │                                                       │
               ▼                                                       ▼
       BufferMFI Line (t)                                     BufferSignal Line (t)
```

### 2.1. Typical Price (TP) Derivation

The calculation begins by evaluating the central tendency of the candle. Supports all 7 standard Applied Price modes and 7 synthetic Heikin Ashi modes (`InpSourcePrice`):
$$\text{TP}_t = (\text{High}_t + \text{Low}_t + \text{Close}_t) \times 0.3333333333333333$$

### 2.2. Dual Volume Capability Routing

The engine queries broker asset specification to determine trade volume routing:
$$V_t = \begin{cases}
\text{RealVolume}_t & \text{if } \text{SymbolInfoDouble}(\text{SYMBOL\_VOLUME\_LIMIT}) > 0 \land \text{RealVolume}_t > 0 \\
\text{TickVolume}_t & \text{otherwise}
\end{cases}$$
*If $V_t \le 0$, the volume is safely clamped to $1.0$.*

### 2.3. Raw Money Flow & Directional Polarity
Raw Money Flow measures the nominal capital volume transacted at the Typical Price:
$$\text{RMF}_t = \text{TP}_t \times V_t$$

Money flow is assigned polarity based on whether the current Typical Price is higher or lower than the preceding bar:
$$\text{PosMF}_t = \begin{cases} \text{RMF}_t & \text{if } \text{TP}_t > \text{TP}_{t-1} \\ 0.0 & \text{otherwise} \end{cases}$$
$$\text{NegMF}_t = \begin{cases} \text{RMF}_t & \text{if } \text{TP}_t < \text{TP}_{t-1} \\ 0.0 & \text{otherwise} \end{cases}$$

### 2.4. Rolling Window Summation & Algebraic Zero-Division Reduction
Across the lookback period $P$ (`InpPeriodMFI`), the positive and negative capital flows are summed:
$$\text{PosSum}_t = \sum_{j=0}^{P-1} \text{PosMF}_{t-j}, \quad\quad \text{NegSum}_t = \sum_{j=0}^{P-1} \text{NegMF}_{t-j}$$

The classical formulation computes the Money Ratio ($MR = \text{PosSum} / \text{NegSum}$) followed by $\text{MFI} = 100 - (100 / (1 + MR))$. When $\text{NegSum} = 0$, this triggers a division-by-zero crash.

**MFI Pro implements an algebraic reduction that guarantees 100% numerical stability**:
$$\text{MFI}_t = 100 - \frac{100}{1 + \frac{\text{PosSum}}{\text{NegSum}}} = 100 - \frac{100 \times \text{NegSum}}{\text{PosSum} + \text{NegSum}} = \frac{100 \times \text{PosSum}_t}{\text{PosSum}_t + \text{NegSum}_t}$$

* **ALU Advantage:** Reduces two floating-point divisions to a single division.
* **Neutral Equilibrium Guard:** If $\text{PosSum} + \text{NegSum} = 0$, the engine safely defaults to $50.0$.

### 2.5. Modular Signal Line Derivation
To smooth out high-frequency volume noise and identify institutional crossover triggers, `CMFICalculator` composites `CMovingAverageCalculator` from `MovingAverage_Engine.mqh`:
$$\text{SignalLine}_t = \mathcal{M}_{\text{sig}}(\text{MFI}, \text{SignalPeriod})_t$$
Where $\mathcal{M}_{\text{sig}}$ represents any of the 14 supported algorithms (`InpSignalMAType`).

---

## 3. The 14 Signal Smoothing Models Matrix

The Signal Line can be configured using any of the 14 modular algorithms:

| Identifier | Algorithm Name | Smoothing Kernel Type | Phase Lag | Optimal Market Role in MFI |
| :--- | :--- | :---: | :---: | :--- |
| **`SMA`** | Simple Moving Average | Arithmetic Mean | High | Smooth, classical volume-weighted baseline. |
| **`EMA`** | Exponential Moving Average | First-Order IIR Filter | Medium | Classical default standard; balanced response. |
| **`SMMA`** | Smoothed MA (Wilder's RMA) | Infinite Recursive Smoothing | Very High | Macro accumulation/distribution baseline. |
| **`LWMA`** | Linear Weighted Moving Average | Linear Arithmetic Weights | Low | Front-loaded reaction to sudden liquidity spikes. |
| **`TMA`** | Triangular Moving Average | Cascaded SMA Convolution | Ultra-High | Eliminates high-frequency capital flow ripples. |
| **`DEMA`** | Double Exponential MA | Second-Order Zero-Lag | Very Low | Reduces 50% of classical EMA phase lag. |
| **`TEMA`** | Triple Exponential MA | Third-Order Zero-Lag | Near-Zero | High-frequency liquidity breakout triggers. |
| **`VWMA`** | Volume-Weighted MA | Volume-Proportional Weights | Dynamic | Double-weighted volume-on-volume confirmation. |
| **`HMA`** | Hull Moving Average | Square-Root WMA Composite | Near-Zero | Crisp, low-lag capital flow trend shifts. |
| **`ZLEMA`** | Zero-Lag Exponential MA | De-Lagged Momentum Injection | Low | Ehlers zero-lag tracking; early crossings. |
| **`MCGINLEY`** | McGinley Dynamic | 4th-Power Self-Adjusting | Adaptive | Hugs liquidity drops; damps false spikes. |
| **`EHMA`** | Exponential Hull MA | Recursive IIR Hull Composite | Low | Smoother, recursive alternative to HMA. |
| **`MEDIAN_MA`**| Median Moving Average | Order-Statistic Median | Medium | 100% immune to volume bad prints and spikes. |
| **`SWMA`** | Sine-Weighted MA | Half-Cycle Sine Kernel | Medium | Symmetric, bias-free center smoothing. |

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe MFI regimes onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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
Legacy indicators call multiple `Copy*` functions in chained sequences. This causes non-atomic race conditions during volatile live ticks.

`MFI_Pro` executes a single atomic `CopyRates()` query:
```mql5
MqlRates htf_bulk_rates[];
if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
   return 0;
```
All OHLCV and volume arrays are updated in cache simultaneously in nanoseconds.

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
      BufferMFI[i]    = EMPTY_VALUE;
      BufferSignal[i] = EMPTY_VALUE;
      continue;
     }

   while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
      htf_ptr++;

   BufferMFI[i]    = h_res_mfi[htf_ptr];
   BufferSignal[i] = h_res_signal[htf_ptr];
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
* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === MFI Core Settings ===
* **`InpPeriodMFI`** (*default: `14`*): Lookback smoothing period ($P$) for the Money Flow Index.
* **`InpSourcePrice`** (*default: `PRICE_TYPICAL_STD`*): Input price source. Defaults to classical Typical Price (`(H+L+C)/3`), with full support for all 7 standard and 7 synthetic Heikin Ashi price modes.
* **`InpDisplayMode`** (*default: `DISPLAY_MFI_AND_SIGNAL`*):
  - `DISPLAY_MFI_ONLY`: Plots only the primary MFI line (Signal line disabled).
  - `DISPLAY_MFI_AND_SIGNAL`: Plots both the MFI line and the Signal Moving Average.

### === Signal Line Settings ===
* **`InpSignalPeriod`** (*default: `9`*): Smoothing lookback window for the Signal Line.
* **`InpSignalMAType`** (*default: `EMA`*): Moving average algorithm used to smooth the MFI series (Selectable across all 14 modular models, including HMA and ZLEMA).

### === Visual Settings - MFI Line ===
* **`InpColorMFI`** (*default: `clrDodgerBlue`*): Line color for the primary MFI curve.
* **`InpStyleMFI`** (*default: `STYLE_SOLID`*): Line style for the MFI curve.
* **`InpWidthMFI`** (*default: `2`*): Line thickness for the MFI curve.

### === Visual Settings - Signal Line ===
* **`InpColorSignal`** (*default: `clrOrangeRed`*): Line color for the Signal Line.
* **`InpStyleSignal`** (*default: `STYLE_DOT`*): Line style for the Signal Line.
* **`InpWidthSignal`** (*default: `1`*): Line thickness for the Signal Line.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                         MFI TRADING PLAYBOOKS                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Institutional Exhaustion:   MFI reversing out of < 20 or > 80       │
│                                confirms climatic liquidity exhaustion. │
│ 2. Signal Crossover Trigger:   MFI crossing above its 9-period Signal  │
│                                Line triggers volume-momentum entries.  │
│ 3. Smart Money Divergence:     Price makes Higher High while MFI makes │
│                                Lower High -> Distribution Reversal.    │
│ 4. MTF Macro Step Alignment:   Only take M5 long breakouts when the    │
│                                H4 MFI is holding above its 50 midline. │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Institutional Extreme Exhaustion (20 / 80 Boundaries)
* **Market Context:** Parabolic trends or climatic sell-offs reaching extreme liquidity exhaustion.
* **Oversold Reversal ($< 20.0$):** Capital outflow has completely depleted selling pressure. When MFI hooks and crosses back **above 20.0**, trigger a high-probability mean-reversion long entry.
* **Overbought Reversal ($> 80.0$):** Capital inflow has reached a buying climax. When MFI hooks and crosses back **below 80.0**, trigger a short exhaustion entry.

### 6.2. Playbook 2: Signal Line Momentum Crossover
* **Bullish Crossover:** MFI line crosses **above** its Signal Line (`InpSignalMAType = EMA`, `InpSignalPeriod = 9`) $\rightarrow$ Short-term capital accumulation entry trigger.
* **Bearish Crossover:** MFI line crosses **below** its Signal Line $\rightarrow$ Short-term capital distribution entry trigger.
* **Asymmetric Risk/Reward Filter:** Crossovers occurring **below 50.0** that cross upward offer superior risk/reward entries during pullbacks in macro bull markets.

### 6.3. Playbook 3: Volume-Price Divergence (Smart Money Climax)
* **Bearish Divergence (Distribution):** Price rallies to make a new Higher High (HH), but MFI fails to exceed its previous peak and prints a Lower High (LH).
  - *Institutional Meaning:* Price is rising on drying liquidity; institutional smart money is distributing inventory into retail market orders.
  - *Trade:* Enter short upon MFI crossing below its Signal Line.
* **Bullish Divergence (Accumulation):** Price slides to a Lower Low (LL), but MFI prints a Higher Low (HL).
  - *Trade:* Enter long upon MFI crossing above its Signal Line.

### 6.4. Playbook 4: Multi-Timeframe Volume Step Alignment
* Attach an **H4-calculated MFI Pro** onto an **M5 execution chart**.
* **Quantitative Execution Rule:**
  $$\text{If } \text{BufferMFI}_{\text{H4 Step}} > 50.0 \land \text{BufferMFI}_{\text{H4 Step}} > \text{BufferSignal}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{BufferMFI}_{\text{H4 Step}} < 50.0 \land \text{BufferMFI}_{\text{H4 Step}} < \text{BufferSignal}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
* Eliminates counter-trend scalping against macro institutional capital accumulation.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 2 native `INDICATOR_DATA` buffers, maintaining sub-millisecond data query performance for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Value Range | Description |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferMFI` | `DRAW_LINE` | `clrDodgerBlue` | $0.0 \dots 100.0$ | Money Flow Index primary curve |
| **1** | `BufferSignal` | `DRAW_LINE` | `clrOrangeRed` | $0.0 \dots 100.0$ | Signal Moving Average curve (Active in Mode 1) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read MFI Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF MFI Pro
int handle = iCustom(_Symbol, _Period, "MFI_Pro",
                     PERIOD_CURRENT,             // InpTimeframe
                     14,                         // InpPeriodMFI
                     PRICE_TYPICAL_STD,          // InpSourcePrice (Typical Price)
                     DISPLAY_MFI_AND_SIGNAL,     // InpDisplayMode
                     9,                          // InpSignalPeriod
                     EMA                         // InpSignalMAType (ENUM_MA_TYPE)
                     // ... remaining visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create MFI_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double mfi_val[], signal_val[];
ArraySetAsSeries(mfi_val,    true);
ArraySetAsSeries(signal_val, true);

if(CopyBuffer(handle, 0, 1, 2, mfi_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, signal_val) == 2)
  {
   double mfi_curr    = mfi_val[0];       // Closed bar (Bar 1)
   double mfi_prev    = mfi_val[1];       // Prior closed bar (Bar 2)
   double signal_curr = signal_val[0];
   double signal_prev = signal_val[1];

   // Example Strategy: Bullish Signal Line Crossover below 50
   bool is_crossover_long = (mfi_prev <= signal_prev && mfi_curr > signal_curr);

   if(is_crossover_long && mfi_curr < 50.0)
     {
      // Execute Buy Order (Institutional Volume-Weighted Momentum Shift)
     }
  }
```
