# Bollinger Bands Pro (v4.00)

## Institutional Multi-Timeframe Volatility Envelope Suite with 14 Centerline Smoothing Models, VWMA Routing & Synthetic Heikin Ashi

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**Bollinger Bands Pro (v4.00)** is the foundational statistical volatility envelope of the Professional MQL5 Suite. Built upon the decoupled **Engine-Wrapper Component Architecture (`Bollinger_Bands_Calculator.mqh` v5.10)**, it pairs John Bollinger’s classic standard deviation dispersion framework with modern digital signal processing (DSP), 14 pluggable moving average centerlines, full volume routing, and the zero-lag 2026 MTF Fast-Path protocol.

Beyond serving as a standalone chart overlay, `Bollinger_Bands_Calculator.mqh` acts as the **Single Source of Truth (SSOT)** mathematical engine powering `Bollinger_Bands_PercentB` and `Squeeze_Pro`:

```text
┌────────────────────────────────────────────────────────────────────────┐
│               BOLLINGER BANDS PRO ARCHITECTURAL OVERVIEW               │
├────────────────────────────────────────────────────────────────────────┤
│ 1. 14-Model Centerline Engine  • Powered by MovingAverage_Engine.mqh   │
│                                • Supports SMA, EMA, HMA, ZLEMA, VWMA.. │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Volume Routing Pipeline     • Broker capability arbitration via     │
│                                  SYMBOL_VOLUME_LIMIT                   │
│                                • Real Volume (Equities/Futures) and    │
│                                  Tick Volume (Forex CFDs) support      │
├────────────────────────────────────────────────────────────────────────┤
│ 3. ALU-Optimized StDev Kernel  • Transcendental-free (diff * diff) math│
│                                • Precomputed m_inv_period reciprocal   │
├────────────────────────────────────────────────────────────────────────┤
│ 4. 2026 MTF Fast-Path Protocol • Atomic single-query CopyRates() sync  │
│                                • Two-Pointer Chronological Sweep (O(N))│
│                                • Binary search snapping (ArrayBsearch) │
├────────────────────────────────────────────────────────────────────────┤
│ 5. Authentic Heikin Ashi Core  • Exact off-by-one free price mapping   │
│                                • 2048-element memory capacity reserves │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & DSP Pipeline

```text
                  RAW MARKET OHLCV INPUT (Standard or Heikin Ashi)
                                           │
                                           ▼
                       Price Input Preparation (Single-Pass)
                                           │
                                           ▼
                                Centerline Smoothing Engine
                          (14 Selectable MA Models + VWMA Volume)
                                           │
                                           ▼
                             Rolling Standard Deviation (σ)
                         √( Σ (Price[t-j] - Centerline[t])² · (1 / P) )
                                           │
                                           ▼
                       Upper = Centerline + D·σ,   Lower = Centerline - D·σ
```

### 2.1. Price Input Preparation & Synthetic Heikin Ashi

Prepares the input price vector $P_t$ (supporting all 7 Standard Applied Prices and 7 Synthetic Heikin Ashi prices). Standard weighted/typical/median computations execute via pipelined multiplications (`* 0.5`, `* 0.3333333333333333`, `* 0.25`) instead of divisions.

### 2.2. Centerline Moving Average & VWMA Routing

The central tendency baseline $\text{Centerline}_t$ is evaluated via `CMovingAverageCalculator::CalculateOnArray()` over `InpPeriod` ($P$):
$$\text{Centerline}_t = \mathcal{M}_{\text{type}}(P, P_{\text{len}})_t$$
When `InpMAType == VWMA`, the engine queries `SYMBOL_VOLUME_LIMIT` to automatically weight price bars by Real Exchange Volume or Tick Volume:
$$\text{Centerline}_{\text{VWMA}, t} = \frac{\sum_{j=0}^{P-1} P_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{P-1} V_{t-j}}$$

### 2.3. ALU-Optimized Population Standard Deviation ($\sigma$)

Computes statistical dispersion around the centerline across the trailing $P$ bars. All transcendental `pow()` calls are pruned in favor of direct `diff * diff` multiplication, and division by $P$ is replaced with precomputed `m_inv_period` multiplication:
$$\sigma_t = \sqrt{\left(\sum_{j=0}^{P-1} (P_{t-j} - \text{Centerline}_t)^2\right) \times \text{m\_inv\_period}}$$

### 2.4. Volatility Envelope Boundaries

$$\text{BandDev}_t = \text{InpDeviation} \times \sigma_t$$
$$\text{UpperBand}_t = \text{Centerline}_t + \text{BandDev}_t$$
$$\text{LowerBand}_t = \text{Centerline}_t - \text{BandDev}_t$$

---

## 3. The 14 Centerline Smoothing Models Matrix

The Centerline can be configured using any of the 14 modular algorithms:

| Identifier | Algorithm Name | Smoothing Kernel Type | Phase Lag | Optimal Role in Bollinger Bands |
| :--- | :--- | :---: | :---: | :--- |
| **`SMA`** | Simple Moving Average | Arithmetic Mean | High | John Bollinger's classical default standard. |
| **`EMA`** | Exponential Moving Average | First-Order IIR Filter | Medium | Responsive trend baseline; faster band tilting. |
| **`SMMA`** | Smoothed MA (Wilder's RMA) | Infinite Recursive Smoothing | Very High | Ultra-stable macro volatility baseline. |
| **`LWMA`** | Linear Weighted Moving Average | Linear Arithmetic Weights | Low | Front-loaded reaction to recent price surges. |
| **`TMA`** | Triangular Moving Average | Cascaded SMA Convolution | Ultra-High | Smooth center anchor suppressing short ripples. |
| **`DEMA`** | Double Exponential MA | Second-Order Zero-Lag | Very Low | Reduces 50% of classical EMA lag. |
| **`TEMA`** | Triple Exponential MA | Third-Order Zero-Lag | Near-Zero | Ultra-fast centerline for microstructure scalping. |
| **`VWMA`** | Volume-Weighted MA | Volume-Proportional Weights | Dynamic | Anchors bands directly to institutional liquidity. |
| **`HMA`** | Hull Moving Average | Square-Root WMA Composite | Near-Zero | Crisp trend turns without whipsaw noise. |
| **`ZLEMA`** | Zero-Lag Exponential MA | De-Lagged Momentum Injection | Low | Ehlers zero-lag tracking; early centerline crosses. |
| **`MCGINLEY`** | McGinley Dynamic | 4th-Power Self-Adjusting | Adaptive | Hugs fast market drops; damps false spikes. |
| **`EHMA`** | Exponential Hull MA | Recursive IIR Hull Composite | Low | Smoother, recursive alternative to HMA. |
| **`MEDIAN_MA`** | Median Moving Average | Order-Statistic Median | Medium | 100% immune to bad prints and price spikes. |
| **`SWMA`** | Sine-Weighted MA | Half-Cycle Sine Kernel | Medium | Symmetric, bias-free center smoothing. |

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Bollinger Bands onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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

1. **Atomic Single-Query Rates Synchronization:** A single `CopyRates()` query acquires all OHLCV bars (including Real and Tick volume) for the HTF domain simultaneously in nanoseconds.
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Sweeps forward in a single linear pass, projecting `BufferUpperBand`, `BufferLowerBand`, and `BufferCenterLine` onto chart candles with zero `iBarShift()` API calls.
3. **Live-Tick Isolated RAM Mocking:** On incoming live ticks within an open HTF bar, only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is recalculated. An $O(\log N)$ binary search (`ArrayBsearch`) snaps to the forming block start and vector-assigns values in nanoseconds.

---

## 5. Parameters Reference

### === Timeframe Settings ===

* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Bollinger Bands Core Settings ===

* **`InpPeriod`** (*default: `20`*): Lookback window for both the Centerline Moving Average and Standard Deviation calculation.

* **`InpDeviation`** (*default: `2.0`*): Standard deviation multiplier ($D$) defining the outer band envelope distance.
* **`InpMAType`** (*default: `SMA`*): Moving average algorithm used for the Centerline (Selectable across all 14 modular models, including `VWMA` and `HMA`).
* **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Visual Settings - Outer Bands ===

* **`InpColorUpper`** (*default: `clrOliveDrab`*): Color of the Upper Band.

* **`InpColorLower`** (*default: `clrOliveDrab`*): Color of the Lower Band.
* **`InpStyleBands`** (*default: `STYLE_DOT`*): Line style for both outer bands.
* **`InpWidthBands`** (*default: `1`*): Line thickness for both outer bands.

### === Visual Settings - Centerline ===

* **`InpShowMiddle`** (*default: `true`*): Toggles drawing the Centerline Basis.

* **`InpColorMiddle`** (*default: `clrOliveDrab`*): Color of the Centerline.
* **`InpStyleMiddle`** (*default: `STYLE_SOLID`*): Line style for the Centerline.
* **`InpWidthMiddle`** (*default: `2`*): Line thickness for the Centerline.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                     BOLLINGER BANDS PLAYBOOKS                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. The Volatility Squeeze:     Bands narrow to multi-week lows ->      │
│                                Enter decisive bar close outside band.  │
│ 2. Walking the Bands:          Strong trend closes outside Upper Band  │
│                                repeatedly -> Trail along Centerline.   │
│ 3. W-Bottom & M-Top Reversals: 1st extreme tags outer band; 2nd extreme│
│                                holds inside band -> Divergence turn.   │
│ 4. MTF Macro Step Alignment:   Only take M5 long breakouts when price  │
│                                holds above the H4 Centerline Basis.    │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Volatility Squeeze Breakout

* **Market Context:** Volatility contracts sharply; Upper and Lower Bands pinch tightly around the Centerline.

* **Execution:** Enter in the direction of the first bar that closes aggressively outside the Upper or Lower Band as the opposite band flares outward in confirmation.

### 6.2. Playbook 2: Walking the Bands (Trend Continuation)

* **Mechanism:** In powerful directional breakouts, price "walks the band"—printing successive closes along or outside the Upper Band ($+2\sigma$) while pullbacks find support at the **Centerline Basis** (e.g. `20 EMA` or `20 VWMA`).

* **Rule:** Never fade a band tag if the bands are actively flaring outward. Trail stops behind the Centerline Basis.

### 6.3. Playbook 3: W-Bottom & M-Top Mean Reversals

* **Bullish W-Bottom:** Price breaks below the Lower Band ($-2\sigma$), bounces toward the Centerline, then retests or slightly undercuts the prior price low while **staying strictly inside the Lower Band**. Enter long upon breaking the Centerline upward.

* **Bearish M-Top:** Price breaks above the Upper Band ($+2\sigma$), pulls back, then tests or exceeds the prior high while **holding strictly inside the Upper Band**. Enter short upon breaking the Centerline downward.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment

* Attach an **H4-calculated Bollinger Bands Pro** onto an **M15 execution chart**.

* **Quantitative Execution Rule:**
  $$\text{If } \text{Bid} > \text{BufferCenterLine}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{Bid} < \text{BufferCenterLine}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
* Prevents intraday scalpers from entering counter-trend trades against macro higher-timeframe trend regimes.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 3 native `INDICATOR_DATA` buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferUpperBand` | `DRAW_LINE` | `clrOliveDrab` | Upper Bollinger Volatility Band |
| **1** | `BufferLowerBand` | `DRAW_LINE` | `clrOliveDrab` | Lower Bollinger Volatility Band |
| **2** | `BufferCenterLine` | `DRAW_LINE` | `clrOliveDrab` | Centerline Moving Average Basis |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the currently forming live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Bollinger Bands Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Bollinger Bands Pro (VWMA Centerline)
int handle = iCustom(_Symbol, _Period, "Bollinger_Bands_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     20,                     // InpPeriod
                     2.0,                    // InpDeviation
                     VWMA,                   // InpMAType (Volume-Weighted Basis)
                     PRICE_CLOSE_STD         // InpSourcePrice (Standard Close)
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Bollinger_Bands_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values (Bar 1 and Bar 2)
double upper_val[], lower_val[], mid_val[];
ArraySetAsSeries(upper_val, true);
ArraySetAsSeries(lower_val, true);
ArraySetAsSeries(mid_val,   true);

if(CopyBuffer(handle, 0, 1, 2, upper_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, lower_val) == 2 &&
   CopyBuffer(handle, 2, 1, 2, mid_val)   == 2)
  {
   double upper_curr = upper_val[0];    // Closed bar (Bar 1)
   double lower_curr = lower_val[0];
   double mid_curr   = mid_val[0];
   double close_curr = iClose(_Symbol, _Period, 1);

   // Example Strategy: Bullish Volatility Breakout above Upper Band
   if(close_curr > upper_curr)
     {
      // Execute Buy Order (Bollinger Band Expansion Breakout)
     }
  }
```
