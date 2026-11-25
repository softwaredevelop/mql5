# Volume Pressure Pro (v2.00)

## Institutional Multi-Timeframe Money Flow Multiplier (CLV) & Intra-Bar Buying/Selling Pressure Suite with 14-MA Smoothing & VWMA Routing

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & Microstructure Pressure Theory

**Volume Pressure Pro (v2.00)** is the microstructure buying/selling pressure oscillator of the Professional MQL5 Suite. Directly implementing **Marc Chaikin’s Close Location Value (CLV / Money Flow Multiplier)**, it serves as an ultra-responsive, normalized **Tick Volume Delta Proxy** bounded strictly within $[-1.0, +1.0]$.

In decentralized spot markets (Forex CFDs) or during fast intraday auctions, pure Level-2 bid/ask order book delta is often unavailable or broker-fragmented. **Volume Pressure Pro resolves this limitation by quantifying where price settled relative to the candle's high-low auction range, optionally weighting that pressure by real or tick volume via VWMA smoothing and filtering microstructure noise via Synthetic Heikin Ashi**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                  VOLUME PRESSURE ARCHITECTURAL OVERVIEW                │
├────────────────────────────────────────────────────────────────────────┤
│ 1. CLV Microstructure Engine   • Bounded [-1.0, +1.0] buying/selling   │
│                                  pressure proxy                        │
│                                • 1e-9 range epsilon shield & clamps    │
├────────────────────────────────────────────────────────────────────────┤
│ 2. 14-Model MA & VWMA Weighting• Raw mode (Period 1) or smoothed (> 1) │
│                                • Supports VWMA (True Volume-Weighted   │
│                                  Buying/Selling Pressure!)             │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Synthetic Heikin Ashi Mode  • Optional VP_CANDLE_HEIKIN_ASHI filter │
│                                • Eliminates erratic intra-bar wicks    │
├────────────────────────────────────────────────────────────────────────┤
│ 4. 3-Color Neutral Chop Zone   • Optional [-Z, +Z] neutral gray zone   │
│                                • Filters meaningless zero-line noise   │
├────────────────────────────────────────────────────────────────────────┤
│ 5. 2026 MTF Fast-Path Protocol • Atomic single-query CopyRates() sync  │
│                                • Two-Pointer Chronological Sweep (O(N))│
│                                • Binary search snapping (ArrayBsearch) │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & Volumetric DSP Pipeline

```text
                  RAW MARKET OHLCV INPUT (Standard or Heikin Ashi)
                                           │
                                           ▼
                       Candle Selection (Standard vs. Heikin Ashi)
                                           │
                                           ▼
                  Money Flow Multiplier (Close Location Value / CLV)
                     MFM[t] = (2·Close[t] - High[t] - Low[t]) / (High[t] - Low[t])
                                           │
               ┌───────────────────────────┴───────────────────────────┐
               ▼                                                       ▼
    Mode A: Raw Mode (Period = 1)                           Mode B: Smoothed Mode (Period > 1)
         Direct CLV Output                                  14-Model MovingAverage_Engine.mqh
                                                            (Incl. Real/Tick Volume via VWMA)
               │                                                       │
               └───────────────────────────┬───────────────────────────┘
                                           │
                                           ▼
                        3-Color Neutral Chop Zone Classifier
                       [ Green (> +Z) | Red (< -Z) | Gray ([-Z,+Z]) ]
```

### 2.1. Stage 1: Candle Selection (Standard vs. Heikin Ashi)

The engine prepares the High, Low, and Close series:

- **`VP_CANDLE_STANDARD`:** Evaluates raw market auction extremes ($\text{High}_t, \text{Low}_t, \text{Close}_t$).
- **`VP_CANDLE_HEIKIN_ASHI`:** Synthesizes smoothed Heikin Ashi candles in-place via `CHeikinAshi_Calculator` ($\text{HA\_High}_t, \text{HA\_Low}_t, \text{HA\_Close}_t$) to eliminate erratic single-bar stop-hunt wicks.

### 2.2. Stage 2: Money Flow Multiplier (Close Location Value)

Computes the internal directional balance of each bar:
$$\text{Range}_t = \text{High}_t - \text{Low}_t$$
$$\text{MFM}_t = \begin{cases}
\frac{(\text{Close}_t - \text{Low}_t) - (\text{High}_t - \text{Close}_t)}{\text{Range}_t} = \frac{2.0 \cdot \text{Close}_t - \text{High}_t - \text{Low}_t}{\text{Range}_t} & \text{if } \text{Range}_t > 1.0\text{e-}9 \\
0.0 & \text{otherwise (Flat Doji)}
\end{cases}$$
The output is clamped strictly to $[-1.0, +1.0]$:
* **$+1.0$:** Close at absolute High (100% Buyer dominance).
* **$-1.0$:** Close at absolute Low (100% Seller dominance).
* **$0.0$:** Close at exact midpoint (50/50 Balance).

### 2.3. Stage 3: 14-Model Smoothing & VWMA Volume Routing
* **Raw Mode (`InpSmoothPeriod = 1`):** Outputs unsmoothed bar-by-bar $\text{MFM}_t$ directly.
* **Smoothed Mode (`InpSmoothPeriod > 1`):** Routes $\text{MFM}_t$ into `CMovingAverageCalculator::CalculateOnArray()` supporting all 14 algorithms (`SMA`, `EMA`, `HMA`, `ZLEMA`, `VWMA`, etc.).
* **VWMA Volume Weighting (`InpMAType = VWMA`):** Queries `SYMBOL_VOLUME_LIMIT` to automatically route Real Volume (`VOLUME_REAL`) or Tick Volume (`VOLUME_TICK`):
  $$\text{V\_PRES}_{\text{VWMA}, t} = \frac{\sum_{j=0}^{P-1} \text{MFM}_{t-j} \cdot \text{Volume}_{t-j}}{\sum_{j=0}^{P-1} \text{Volume}_{t-j}}$$
  *Quantitative Significance:* High-volume breakout candles exert dramatically higher weight on the oscillator than low-volume quiet bars!

---

## 3. The 3-Color Neutral Chop Zone Matrix

When `InpNeutralZone > 0.0` (e.g., `0.15`), the histogram separates actionable institutional order flow from balanced market chop:

| Color Index | Default Color | Condition (`InpNeutralZone > 0`) | Classic Mode (`InpNeutralZone = 0`) | Quantitative Interpretation |
| :---: | :---: | :--- | :--- | :--- |
| **`1.0`** | `clrMediumSeaGreen` | $\text{V\_PRES}_t > +Z$ | $\text{V\_PRES}_t \ge 0.0$ | **Bullish Buying Pressure:** Buyers control the auction close. |
| **`0.0`** | `clrCrimson` | $\text{V\_PRES}_t < -Z$ | $\text{V\_PRES}_t < 0.0$ | **Bearish Selling Pressure:** Sellers control the auction close. |
| **`2.0`** | `clrDarkGray` | $-Z \le \text{V\_PRES}_t \le +Z$ | Unused | **Neutral Chop Zone:** Balanced auction; avoid directional chasing. |

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Volume Pressure onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Sweeps forward in a single linear pass, projecting `BufVal` and `BufCol` onto chart candles with zero `iBarShift()` API calls.
3. **Live-Tick Isolated RAM Mocking:** On incoming live ticks within an open HTF bar, only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is recalculated. An $O(\log N)$ binary search (`ArrayBsearch`) snaps to the forming block start and vector-assigns values in nanoseconds.

---

## 5. Parameters Reference

### === Timeframe Settings ===
* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Volume Pressure Core Settings ===
* **`InpCandleSource`** (*default: `VP_CANDLE_STANDARD`*):
  - `VP_CANDLE_STANDARD`: Raw market OHLC data.
  - `VP_CANDLE_HEIKIN_ASHI`: Synthetic Heikin Ashi OHLC candles.
* **`InpSmoothPeriod`** (*default: `1`*): Smoothing lookback period. Set to `1` for unsmoothed raw bar-by-bar CLV; set `> 1` (e.g., 5, 10, 20) to smooth pressure regimes.
* **`InpMAType`** (*default: `EMA`*): Moving average algorithm used when `InpSmoothPeriod > 1` (Selectable across all 14 modular models, including `VWMA`, `HMA`, `SMA`).

### === Visual & Threshold Settings ===
* **`InpNeutralZone`** (*default: `0.0`*): Half-width around `0.0` (e.g., `0.15`). Bars inside $[-Z, +Z]$ are colored gray to highlight neutral chop. Set to `0.0` for standard 2-color display.
* **`InpColorBull`** (*default: `clrMediumSeaGreen`*): Bullish histogram bar color.
* **`InpColorBear`** (*default: `clrCrimson`*): Bearish histogram bar color.
* **`InpColorNeutral`** (*default: `clrDarkGray`*): Neutral zone histogram bar color.
* **`InpWidthHist`** (*default: `2`*): Histogram bar thickness.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                     VOLUME PRESSURE PLAYBOOKS                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Absorption Rejection:      Raw V_PRES printing >= +0.85 at support  │
│                               confirms aggressive limit buy absorption.│
│ 2. Smoothed Regime Shift:     Smoothed V_PRES (EMA 5) crossing above   │
│                               +0.15 triggers directional continuation. │
│ 3. VWMA Liquidity Climax:     V_PRES with VWMA(10) highlights true     │
│                               volume-backed institutional breakouts.   │
│ 4. MTF Pressure Alignment:    Only take M5 long breakouts when the H1  │
│                               Volume Pressure is positive (> +0.15).   │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Intra-Bar Absorption & Rejection Wicks (`InpSmoothPeriod = 1`)
* **Market Context:** Price sweeps a key daily support/resistance level or Initial Balance boundary.
* **Setup:** A candle spikes below support intraday, but closes near its absolute high, printing **`V_PRES >= +0.80`** (Bright Green bar).
* **Interpretation:** Passive institutional limit buyers absorbed all retail panic selling and drove price back up before bar close. Enter Long on the next bar open.

### 6.2. Playbook 2: Smoothed Momentum Shift (`InpSmoothPeriod = 5..10`)
* **Configuration:** `InpSmoothPeriod = 8`, `InpMAType = EMA`, `InpNeutralZone = 0.15`.
* **Execution:** Wait while histogram bars remain Gray inside $[-0.15, +0.15]$. Trigger a directional trade the moment smoothed Volume Pressure breaks decisively above `+0.15` (Green) or below `-0.15` (Red).

### 6.3. Playbook 3: Volume-Weighted Buying/Selling Pressure (`InpMAType = VWMA`)
* **Configuration:** `InpSmoothPeriod = 10`, `InpMAType = VWMA`.
* **Mechanism:** Weighting CLV by actual transacted volume prevents low-liquidity off-hours bars from distorting the pressure trend. Only sustained high-volume closes near candle highs will drive the indicator above `+0.30`.

### 6.4. Playbook 4: Multi-Timeframe Pressure Step Alignment
* Attach an **H1-calculated Volume Pressure Pro (`InpSmoothPeriod = 5`, `EMA`)** onto an **M5 execution chart**.
* **Quantitative Execution Rule:**
  $$\text{If } \text{BufVal}_{\text{H1 Step}} > +0.15 \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{BufVal}_{\text{H1 Step}} < -0.15 \implies \text{Short Trades Permitted Only}$$
* Eliminates counter-trend scalping against higher-timeframe institutional auction pressure.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 2 native buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Buffer Type | Plot Role | Value Range / Meaning |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufVal` | `INDICATOR_DATA` | Histogram Height | Volume Pressure value ($-1.0 \dots +1.0$) |
| **1** | `BufCol` | `INDICATOR_COLOR_INDEX` | Color State | `0.0` = Bear (Red), `1.0` = Bull (Green), `2.0` = Neutral (Gray) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Volume Pressure Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Volume Pressure Pro (VWMA Smoothed)
int handle = iCustom(_Symbol, _Period, "VolumePressure_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     VP_CANDLE_STANDARD,     // InpCandleSource
                     8,                      // InpSmoothPeriod
                     VWMA,                   // InpMAType (Volume-Weighted Smoothing)
                     0.15                    // InpNeutralZone
                     // ... visual color parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create VolumePressure_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values (Bar 1 and Bar 2)
double vp_val[], vp_col[];
ArraySetAsSeries(vp_val, true);
ArraySetAsSeries(vp_col, true);

if(CopyBuffer(handle, 0, 1, 2, vp_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, vp_col) == 2)
  {
   double vp_curr = vp_val[0];     // Closed bar (Bar 1)
   double vp_prev = vp_val[1];     // Prior closed bar (Bar 2)
   double col_curr = vp_col[0];    // 1.0 = Bull, 0.0 = Bear, 2.0 = Neutral

   // Example Strategy: Bullish Pressure Breakout above Neutral Zone (+0.15)
   bool is_pressure_bull = (vp_prev <= 0.15 && vp_curr > 0.15 && col_curr == 1.0);

   if(is_pressure_bull)
     {
      // Execute Buy Order (Institutional Buying Pressure Breakout)
     }
  }
```
