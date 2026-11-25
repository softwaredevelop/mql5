# Ehlers Channel Pro (v2.00)

## Institutional Multi-Timeframe ATR Volatility Channel Suite (Keltner Concept) Around Zero-Lag Ehlers Centerlines

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & The Ehlers-Keltner Synthesis

**Ehlers Channel Pro (v2.00)** is the standalone Average True Range (ATR) volatility channel overlay of the Professional MQL5 Suite. Built upon the decoupled **Engine-Wrapper Architecture (`Ehlers_Channel_Calculator.mqh` v2.00)**, it upgrades the classical Keltner Channel (Chester Keltner / Linda Bradford Raschke) by replacing the lagging 20-period EMA centerline with John Ehlers’ advanced 2-pole DSP smoothers (**SuperSmoother** and **UltimateSmoother**).

While standard Keltner Channels lag heavily during rapid directional regime shifts, **Ehlers Channel Pro provides instantaneous or critically damped centerline tracking paired with gap-sensitive True Range boundaries—and serves as the Single Source of Truth (SSOT) engine for Keltner mode inside `Ehlers_Unified_Channel_Pro`**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                  EHLERS CHANNEL ARCHITECTURAL OVERVIEW                 │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Ehlers Centerline Core     • SuperSmoother (-12 dB/oct Butterworth) │
│                               • UltimateSmoother (Zero-Lag Lead Filter)│
│                               • Explicit price-source injection (No HA │
│                                 fallback bugs)                         │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Wilder's RMA ATR Envelope  • True Range sensitivity captures gaps   │
│                               • Constant, smooth channel width during  │
│                                 runaway trends without ballooning      │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Hybrid Heikin Ashi Matrix  • Independent Price & ATR sources        │
│                               • Supports HA Centerline + Standard ATR  │
│                                 for optimal noise/gap balance          │
├────────────────────────────────────────────────────────────────────────┤
│ 4. 2026 MTF Fast-Path Protocol• Atomic single-query CopyRates() sync   │
│                               • Two-Pointer Chronological Sweep (O(N)) │
│                               • Binary search snapping (ArrayBsearch)  │
├────────────────────────────────────────────────────────────────────────┤
│ 5. Persistent Memory Core     • 2048-element capacity reservations     │
│                               • Pre-warmup EMPTY_VALUE cleanup         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & ATR Envelope Pipeline

```text
                  RAW MARKET OHLC INPUT (Standard or Heikin Ashi)
                                           │
       ┌───────────────────────────────────┴───────────────────────────────────┐
       ▼                                                                       ▼
Centerline Engine                                                    True Range Engine
SuperSmoother / UltimateSmoother                                     CATRCalculator (Std or HA)
(Period: InpPeriod, Price: InpSourcePrice)                           (Period: InpAtrPeriod)
       │                                                                       │
       ▼                                                                       ▼
Centerline Line (t)                                                  Wilder's RMA ATR (t)
                                                                     Multiplied by InpMultiplier
       │                                                                       │
       └───────────────────────────────────┬───────────────────────────────────┘
                                           │
                                           ▼
                 Upper = Centerline + Offset,   Lower = Centerline - Offset
```

### 2.1. Stage 1: Ehlers Smoother Centerline

The centerline baseline $\text{Centerline}_t$ is calculated via `CEhlersSmootherCalculator` over lookback `InpPeriod` ($P$) using the exact configured price source (`InpSourcePrice`):

- **`SUPERSMOOTHER`:** 2-pole critically damped Butterworth IIR filter eliminating Nyquist aliasing noise ($-12\text{ dB/oct}$) with minimal phase delay.
- **`ULTIMATESMOOTHER`:** Feedforward lead-injected 2-pole filter eliminating 100% of recursive phase lag for instantaneous turns.

### 2.2. Stage 2: Wilder's Average True Range (ATR)

Channel width is governed by `CATRCalculator` (`ATR_Calculator.mqh`) across lookback `InpAtrPeriod` ($P_{\text{atr}}$). First, True Range captures both intra-bar range and overnight gaps:
$$\text{TR}_t = \max\left(\text{High}_t - \text{Low}_t, \; |\text{High}_t - \text{Close}_{t-1}|, \; |\text{Low}_t - \text{Close}_{t-1}|\right)$$
Next, Wilder's Smoothed Moving Average (RMA) computes the persistent average volatility:
$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \cdot (P_{\text{atr}} - 1) + \text{TR}_t}{P_{\text{atr}}}$$

### 2.3. Stage 3: Channel Boundaries

The channel boundaries expand and contract symmetrically around the Ehlers centerline:
$$\text{Offset}_t = \text{ATR}_t \times \text{InpMultiplier}$$
$$\text{UpperBand}_t = \text{Centerline}_t + \text{Offset}_t$$
$$\text{LowerBand}_t = \text{Centerline}_t - \text{Offset}_t$$

---

## 3. Hybrid Heikin Ashi Matrix (Centerline vs. ATR)

A unique architectural feature of `Ehlers Channel Pro` is the complete decoupling of the **Centerline Price Source** (`InpSourcePrice`) from the **ATR Volatility Source** (`InpAtrSource`). This creates four distinct quantitative operating configurations:

| Centerline Source (`InpSourcePrice`) | ATR Source (`InpAtrSource`) | Quantitative Behavior & Optimal Use Case |
| :--- | :--- | :--- |
| **Standard Price** | `ATR_SOURCE_STANDARD` | **Pure Market Profile:** Instantaneous response to raw market prints and true gaps. |
| **Heikin Ashi Price** | `ATR_SOURCE_STANDARD` | **Institutional Hybrid (Recommended):** Smoothed HA trend centerline combined with true gap-aware volatility boundaries. |
| **Standard Price** | `ATR_SOURCE_HEIKIN_ASHI` | **Smoothed Range Hybrid:** Tighter, wick-filtered ATR channels around an unsmoothed price centerline. |
| **Heikin Ashi Price** | `ATR_SOURCE_HEIKIN_ASHI` | **Full Synthetic Noise Shield:** Completely eliminates microstructure wicks from both trend and volatility calculations. |

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Ehlers Channels onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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

1. **Atomic Single-Query Rates Synchronization:** A single `CopyRates()` query acquires all OHLC bars for the HTF domain simultaneously in nanoseconds.
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Sweeps forward in a single linear pass, projecting Upper, Lower, and Centerline values onto chart candles with zero `iBarShift()` API calls.
3. **Live-Tick Isolated RAM Mocking:** On incoming live ticks within an open HTF bar, only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is recalculated. An $O(\log N)$ binary search (`ArrayBsearch`) snaps to the forming block start and vector-assigns values in nanoseconds.

---

## 5. Parameters Reference

### === Timeframe Settings ===

- **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Smoother Centerline Settings ===

- **`InpSmootherType`** (*default: `SUPERSMOOTHER`*): Selects between `SUPERSMOOTHER` (critically damped 2-pole Butterworth) and `ULTIMATESMOOTHER` (zero-lag lead-injected filter).

- **`InpPeriod`** (*default: `20`*): Cutoff smoothing period for the Centerline.
- **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source for the Centerline. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Channel (ATR) Settings ===

- **`InpAtrPeriod`** (*default: `14`*): Lookback window for Wilder's Average True Range.

- **`InpMultiplier`** (*default: `2.0`*): Multiplier applied to ATR to define channel half-width.
- **`InpAtrSource`** (*default: `ATR_SOURCE_STANDARD`*):
  - `ATR_SOURCE_STANDARD`: Computes ATR from raw market OHLC data.
  - `ATR_SOURCE_HEIKIN_ASHI`: Computes ATR from smoothed Heikin Ashi candles.

### === Visual Settings - Outer Bands ===

- **`InpColorUpper`** (*default: `clrMediumSlateBlue`*): Color of the Upper Band.

- **`InpColorLower`** (*default: `clrMediumSlateBlue`*): Color of the Lower Band.
- **`InpStyleBands`** (*default: `STYLE_DOT`*): Line style for both outer bands.
- **`InpWidthBands`** (*default: `1`*): Line width for both outer bands.

### === Visual Settings - Centerline ===

- **`InpShowMiddle`** (*default: `true`*): Toggles drawing the Centerline.

- **`InpColorMiddle`** (*default: `clrCrimson`*): Line color for the Centerline.
- **`InpStyleMiddle`** (*default: `STYLE_SOLID`*): Line style for the Centerline.
- **`InpWidthMiddle`** (*default: `1`*): Line thickness for the Centerline.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      EHLERS CHANNEL PLAYBOOKS                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Zero-Lag Keltner Breakout: UltimateSmoother + ATR(14) -> Early      │
│                               breakout close outside Upper/Lower Band. │
│ 2. Pullback to SuperSmoother: In strong trend -> Enter pullbacks when  │
│                               price rejects the SuperSmoother midline. │
│ 3. Hybrid Gap-Safe Trailing:  Use HA Centerline + Standard ATR to stay │
│                               in trends while respecting true gaps.    │
│ 4. MTF Macro Step Alignment:  Only take M5 long breakouts when price   │
│                               is holding above H4 Centerline.          │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Zero-Lag Keltner Breakout

- **Configuration:** `InpSmootherType = ULTIMATESMOOTHER`, `InpPeriod = 20`, `InpAtrPeriod = 14`, `InpMultiplier = 2.0`.

- **Mechanism:** When volatility expands after consolidation, price breaks aggressively out of the ATR channel. Because UltimateSmoother reacts with zero lag, the channel tilts immediately into the breakout.
- **Execution:** Enter long on a decisive bar close above the Upper Band; trail stop-loss along the Centerline.

### 6.2. Playbook 2: Trend Pullback Continuation

- **Configuration:** `InpSmootherType = SUPERSMOOTHER`, `InpSourcePrice = PRICE_HA_CLOSE`, `InpAtrSource = ATR_SOURCE_STANDARD`.

- **Execution:** After a breakout above the Upper Band confirms a bull trend, wait for price to pull back into the **SuperSmoother Centerline**. Enter long on bullish rejection wicks, targeting the Upper Band ($+2.0 \text{ ATR}$).

### 6.3. Playbook 3: ATR-Normalized Volatility Stop

- **Mechanism:** Place initial hard stop losses at the **opposite channel boundary** or strictly at the Centerline ($\pm 1.0 \text{ to } 2.0 \text{ ATR}$ away from fair value), ensuring stops automatically widen during high-volatility regimes and tighten during quiet regimes.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment

- Attach an **H4-calculated Ehlers Channel Pro** onto an **M15 execution chart**.

- **Quantitative Execution Rule:**
  $$\text{If } \text{Bid} > \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{Bid} < \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
- Eliminates counter-trend scalping against higher-timeframe institutional volatility channels.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 3 native `INDICATOR_DATA` buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferUpper` | `DRAW_LINE` | `clrMediumSlateBlue` | Upper ATR Volatility Channel Band |
| **1** | `BufferLower` | `DRAW_LINE` | `clrMediumSlateBlue` | Lower ATR Volatility Channel Band |
| **2** | `BufferMiddle` | `DRAW_LINE` | `clrCrimson` | Ehlers Centerline (`SuperSmoother` / `UltimateSmoother`) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Ehlers Channel Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Ehlers Channel Pro (Hybrid HA + Standard ATR)
int handle = iCustom(_Symbol, _Period, "Ehlers_Channel_Pro",
                     PERIOD_CURRENT,             // InpTimeframe
                     SUPERSMOOTHER,              // InpSmootherType
                     20,                         // InpPeriod
                     PRICE_HA_CLOSE,             // InpSourcePrice (HA Centerline)
                     14,                         // InpAtrPeriod
                     2.0,                        // InpMultiplier
                     ATR_SOURCE_STANDARD         // InpAtrSource (Hybrid Standard ATR)
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Ehlers_Channel_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
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

   // Example Strategy: Bullish Breakout above Upper ATR Band
   if(close_curr > upper_curr)
     {
      // Execute Long Breakout / Momentum Expansion Order
     }
  }
```
