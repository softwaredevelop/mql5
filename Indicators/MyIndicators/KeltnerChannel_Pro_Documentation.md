# Keltner Channel Pro (v5.00)

## Institutional Multi-Timeframe ATR Volatility Envelope Suite with 14 Centerline Smoothing Models, VWMA Routing & Hybrid Heikin Ashi

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**Keltner Channel Pro (v5.00)** is the institutional True Range volatility channel overlay of the Professional MQL5 Suite. Built upon the decoupled **Engine-Wrapper Component Architecture (`KeltnerChannel_Calculator.mqh` v5.00)**, it modernizes Chester Keltner’s (1960) and Linda Bradford Raschke’s classic ATR channel framework with 14 pluggable moving average centerlines, full volume routing, hybrid Standard/Heikin Ashi source decoupling, and the zero-lag 2026 MTF Fast-Path protocol.

Unlike standard Bollinger Bands that rely on price dispersion and balloon artificially during steep directional slopes, **Keltner Channels expand steadily based on realized Average True Range (ATR)—making them the premier mechanical channel for trend pullbacks and the external boundary for `Squeeze_Pro`**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│               KELTNER CHANNEL PRO ARCHITECTURAL OVERVIEW               │
├────────────────────────────────────────────────────────────────────────┤
│ 1. 14-Model Centerline Engine  • Powered by MovingAverage_Engine.mqh   │
│                                • Supports SMA, EMA, HMA, ZLEMA, VWMA.. │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Wilder's RMA ATR Envelope   • Powered by ATR_Calculator.mqh         │
│                                • Gap-sensitive True Range boundaries   │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Hybrid Heikin Ashi Matrix   • Independent Basis Price & ATR Sources │
│                                • Exact off-by-one free HA routing      │
├────────────────────────────────────────────────────────────────────────┤
│ 4. Volume Routing Pipeline     • Broker capability arbitration via     │
│                                  SYMBOL_VOLUME_LIMIT                   │
│                                • Real Volume & Tick Volume VWMA support│
├────────────────────────────────────────────────────────────────────────┤
│ 5. 2026 MTF Fast-Path Protocol • Atomic single-query CopyRates() sync  │
│                                • Two-Pointer Chronological Sweep (O(N))│
│                                • Binary search snapping (ArrayBsearch) │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & DSP Pipeline

```text
                  RAW MARKET OHLCV INPUT (Standard or Heikin Ashi)
                                           │
       ┌───────────────────────────────────┴───────────────────────────────────┐
       ▼                                                                       ▼
Centerline Moving Average Engine                                     Average True Range Engine
(14 Selectable MA Models + VWMA)                                     CATRCalculator (Std or HA)
(Period: InpMaPeriod, Price: InpSourcePrice)                         (Period: InpAtrPeriod)
       │                                                                       │
       ▼                                                                       ▼
Centerline Basis (t)                                                 Wilder's RMA ATR (t)
                                                                     Multiplied by InpMultiplier
       │                                                                       │
       └───────────────────────────────────┬───────────────────────────────────┘
                                           │
                                           ▼
                 Upper = Basis + Width,   Lower = Basis - Width
```

### 2.1. Stage 1: Centerline Moving Average (Basis) & VWMA Routing

The central tendency baseline $\text{Basis}_t$ is evaluated via `CMovingAverageCalculator` over `InpMaPeriod` ($P_{\text{ma}}$). Defaults to Linda Raschke's Typical Price `(H+L+C)/3` and 20-period EMA:
$$\text{Basis}_t = \mathcal{M}_{\text{type}}(P, P_{\text{ma}})_t$$
When `InpMaMethod == VWMA`, the engine queries `SYMBOL_VOLUME_LIMIT` to automatically weight price bars by Real Exchange Volume or Tick Volume:
$$\text{Basis}_{\text{VWMA}, t} = \frac{\sum_{j=0}^{P_{\text{ma}}-1} P_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{P_{\text{ma}}-1} V_{t-j}}$$

### 2.2. Stage 2: Wilder's Average True Range (ATR)

Channel half-width is governed by `CATRCalculator` (`ATR_Calculator.mqh`) across lookback `InpAtrPeriod` ($P_{\text{atr}}$). True Range captures both intra-bar excursion and overnight market gaps:
$$\text{TR}_t = \max\left(\text{High}_t - \text{Low}_t, \; |\text{High}_t - \text{Close}_{t-1}|, \; |\text{Low}_t - \text{Close}_{t-1}|\right)$$
$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \cdot (P_{\text{atr}} - 1) + \text{TR}_t}{P_{\text{atr}}}$$

### 2.3. Stage 3: Channel Envelope Boundaries

$$\text{Width}_t = \text{ATR}_t \times \text{InpMultiplier}$$
$$\text{UpperBand}_t = \text{Basis}_t + \text{Width}_t$$
$$\text{LowerBand}_t = \text{Basis}_t - \text{Width}_t$$

---

## 3. Hybrid Heikin Ashi & 14 Centerline Models Matrix

### 3.1. Hybrid Heikin Ashi Configuration Matrix

`KeltnerChannel_Pro` completely decouples the **Centerline Price Source** (`InpSourcePrice`) from the **ATR Volatility Source** (`InpAtrSource`):

| Centerline Source (`InpSourcePrice`) | ATR Source (`InpAtrSource`) | Quantitative Behavior & Optimal Role |
| :--- | :--- | :--- |
| **Standard Price** | `ATR_SOURCE_STANDARD` | **Classical Keltner:** Raw market tracking and gap sensitivity. |
| **Heikin Ashi Price** | `ATR_SOURCE_STANDARD` | **Institutional Hybrid (Recommended):** Smoothed HA trend basis + true gap-aware volatility boundaries. |
| **Standard Price** | `ATR_SOURCE_HEIKIN_ASHI` | **Smoothed Range Hybrid:** Tighter, wick-filtered ATR channels around a raw price basis. |
| **Heikin Ashi Price** | `ATR_SOURCE_HEIKIN_ASHI` | **Full Synthetic Noise Shield:** Completely eliminates microstructure wicks from both trend and volatility. |

### 3.2. Supported Centerline Algorithms (`InpMaMethod`)

Supports all 14 modular moving averages from `MovingAverage_Engine.mqh`:
`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`, `HMA`, `ZLEMA`, `MCGINLEY`, `EHMA`, `MEDIAN_MA`, `SWMA`.

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Keltner Channels onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Sweeps forward in a single linear pass, projecting `BufferUpper`, `BufferLower`, and `BufferMiddle` onto chart candles with zero `iBarShift()` API calls.
3. **Live-Tick Isolated RAM Mocking:** On incoming live ticks within an open HTF bar, only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is recalculated. An $O(\log N)$ binary search (`ArrayBsearch`) snaps to the forming block start and vector-assigns values in nanoseconds.

---

## 5. Parameters Reference

### === Timeframe Settings ===

* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Middle Line (MA) Settings ===

* **`InpMaPeriod`** (*default: `20`*): Lookback period for the Centerline Moving Average.

* **`InpMaMethod`** (*default: `EMA`*): Moving average algorithm used for the Centerline Basis (Selectable across all 14 modular models, including `VWMA` and `HMA`).
* **`InpSourcePrice`** (*default: `PRICE_TYPICAL_STD`*): Input price source for the Centerline. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Channel (ATR) Settings ===

* **`InpAtrPeriod`** (*default: `10`*): Lookback window for Wilder's Average True Range.

* **`InpMultiplier`** (*default: `2.0`*): Multiplier applied to ATR to define channel half-width.
* **`InpAtrSource`** (*default: `ATR_SOURCE_STANDARD`*): Selects Standard or Heikin Ashi True Range calculation.

### === Visual Settings - Outer Bands ===

* **`InpColorUpper`** (*default: `clrOliveDrab`*): Color of the Upper Band.

* **`InpColorLower`** (*default: `clrOliveDrab`*): Color of the Lower Band.
* **`InpStyleBands`** (*default: `STYLE_DOT`*): Line style for both outer bands.
* **`InpWidthBands`** (*default: `1`*): Line thickness for both outer bands.

### === Visual Settings - Centerline (Basis) ===

* **`InpShowMiddle`** (*default: `true`*): Toggles drawing the Centerline Basis.

* **`InpColorMiddle`** (*default: `clrOliveDrab`*): Color of the Centerline.
* **`InpStyleMiddle`** (*default: `STYLE_SOLID`*): Line style for the Centerline.
* **`InpWidthMiddle`** (*default: `2`*): Line thickness for the Centerline.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                     KELTNER CHANNEL PLAYBOOKS                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Classic Channel Breakout:   Decisive close outside Upper/Lower Band │
│                                confirms ATR volatility expansion.      │
│ 2. Raschke 20-EMA Pullback:    Following breakout, enter pullbacks     │
│                                rejecting the Centerline Basis.         │
│ 3. Gap-Aware Trailing Stop:    Trail stops strictly on the opposite    │
│                                band or Centerline (2.0 ATR buffer).    │
│ 4. MTF Macro Step Alignment:   Only take M5 long breakouts when price  │
│                                holds above the H4 Centerline Basis.    │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Classic Keltner Channel Breakout

* **Configuration:** `InpMaPeriod = 20`, `InpMaMethod = EMA`, `InpAtrPeriod = 10`, `InpMultiplier = 2.0`.

* **Mechanism:** Because ATR expands steadily without overreacting to single-bar outliers, a bar closing decisively outside the $+2.0 \text{ ATR}$ boundary signals true institutional initiative.
* **Execution:** Enter in the direction of the breakout candle; place protective stop at the **Centerline Basis**.

### 6.2. Playbook 2: Trend Pullback Continuation (The Raschke Setup)

* **Mechanism:** Linda Bradford Raschke popularized using Keltner Channels to enter established trends on low-risk retracements.

* **Setup:** Price tags or breaches the Upper Band ($+2.0 \text{ ATR}$), confirming strong upward momentum. Wait for price to pull back and tag the **20 EMA Centerline Basis**.
* **Execution:** Enter Long on the first bullish rejection candle off the Centerline, targeting the Upper Band.

### 6.3. Playbook 3: ATR-Normalized Dynamic Trailing Stop

* **Mechanism:** Once a strong trend develops, use the **Opposite Channel Band** or the **Centerline** as a volatility-adaptive trailing stop, preventing premature stop-outs during normal intraday volatility noise.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment

* Attach an **H4-calculated Keltner Channel Pro** onto an **M15 execution chart**.

* **Quantitative Execution Rule:**
  $$\text{If } \text{Bid} > \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{Bid} < \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
* Eliminates counter-trend scalping against macro higher-timeframe trend regimes.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 3 native `INDICATOR_DATA` buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferUpper` | `DRAW_LINE` | `clrOliveDrab` | Upper Keltner ATR Volatility Band |
| **1** | `BufferLower` | `DRAW_LINE` | `clrOliveDrab` | Lower Keltner ATR Volatility Band |
| **2** | `BufferMiddle` | `DRAW_LINE` | `clrOliveDrab` | Centerline Moving Average Basis |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the currently forming live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Keltner Channel Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Keltner Channel Pro (VWMA Basis + Standard ATR)
int handle = iCustom(_Symbol, _Period, "KeltnerChannel_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     20,                     // InpMaPeriod
                     VWMA,                   // InpMaMethod (Volume-Weighted Basis)
                     PRICE_TYPICAL_STD,      // InpSourcePrice (Typical Price)
                     10,                     // InpAtrPeriod
                     2.0,                    // InpMultiplier
                     ATR_SOURCE_STANDARD     // InpAtrSource
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create KeltnerChannel_Pro handle.");
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

   // Example Strategy: Bullish Channel Breakout above Upper ATR Band
   if(close_curr > upper_curr)
     {
      // Execute Buy Order (Keltner Channel Volatility Expansion)
     }
  }
```
