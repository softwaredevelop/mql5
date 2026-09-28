# Kinematic Velocity Vector & Speed Suite Pro (v4.10)

Institutional Volatility-Normalized Kinematic Momentum & Speed Envelope Engine

---

## 1. Summary (Introduction)

**Velocity Pro (v4.10)** is an institutional-grade kinematic momentum engine that models financial price movements through the classical physics of motion.

While conventional momentum oscillators (such as Momentum, ROC, or MACD) simply subtract past prices without normalizing for changing market volatility, **Velocity Pro separates directional displacement (Velocity Vector) from total distance traveled (Speed Scalar Envelope)**, standardizing both by the current Average True Range (ATR).

This dual-metric framework allows systematic traders to quantify whether an asset is experiencing pure directional institutional flow, erratic high-friction volatility noise, or kinetic exhaustion climax.

In high-density multi-chart workspaces—such as setups operating **14 active chart windows with MTF Velocity running in Subwindow 3**—legacy implementations cause severe UI thread freezing due to repetitive `iBarShift` queries and multi-loop ATR traversals. **Version 4.10 Enterprise Edition** eliminates this latency via a **Fused Kinematic Pipeline** and **Zero-Lag MTF Fast-Path**.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   VELOCITY PRO ARCHITECTURAL EVOLUTION                 │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   LEGACY ENGINE (v4.00):                                               │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • 6 separate Copy API calls executed on every MTF tick       │     │
│   │ • Up to 500 iBarShift API calls per tick in forming blocks   │     │
│   │ • Dual-loop traversals in ATR Calculator with divisions      │     │
│   │ • 14 Charts × Subwindow 3 = Massive UI Thread Freezing       │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                  │                                     │
│                                  ▼ OPTIMIZED                           │
│   ENTERPRISE ENGINE (v4.10):                                           │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • 1 Atomic CopyRates call per live MTF tick (-83.3% API)     │     │
│   │ • 0 iBarShift calls on live ticks (ArrayBsearch Fast-Path)   │     │
│   │ • Fused Single-Pass ATR Engine with precalculated multipliers│     │
│   │ • Pipelined inverse kinematic multipliers (Zero divisions)   │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

- **Kinematic Vector vs. Scalar Decomposition:** Evaluates both the directional displacement vector ($v_t$) and the total path-length volatility envelope ($\pm s_t$) simultaneously.
- **True Volatility Normalization:** Both metrics scale dynamically in units of Average True Range (ATR), ensuring identical numerical sensitivity across all asset classes and market volatility regimes.
- **Fused ATR Engine Composition:** Directly encapsulates `CATRCalculator` v3.11, utilizing pipelined Wilder RMA multipliers and a fused single-pass output loop.
- **Zero-Lag MTF Fast-Path:** Higher-timeframe kinematic vectors (e.g., M5 on M1 charts) project as non-warping steps via `DataSync_Tools.mqh` with zero `iBarShift` overhead on live ticks.
- **Swapped Thermal 5-Zone Palette:** Visually differentiates between equilibrium noise, healthy directional flow expansion, and unsustainable parabolic climax.

---

## 2. Mathematical Foundations & Kinematics Theory

```text

                   +Speed Envelope (+s_t) ────────────────────── clrDarkOrange
                                          ┌─┐
                                          │ │   Velocity Vector (v_t)
                   +1.0 Climax Level  ────┼─┼────────────────── clrDeepSkyBlue
                                          │ │
                   +0.3 Flow Level    ────┼─┼────────────────── clrLightSkyBlue
                                          │ │
                    0.0 Centerline    ════╪═╪══════════════════ clrGray
                                          │ │
                   -0.3 Flow Level    ────┼─┼────────────────── clrCoral
                                          │ │
                   -1.0 Climax Level  ────┼─┼────────────────── clrOrangeRed
                                          └─┘
                   -Speed Envelope (-s_t) ────────────────────── clrDarkOrange

```

### 2.1. Directional Displacement Vector (Velocity: $v_t$)

Velocity measures the net directional change in position per unit of time, normalized by current ATR volatility:
$$\text{Displacement}_t = P_t - P_{t - \Delta t}$$
$$v_t = \frac{\text{Displacement}_t}{\text{ATR}_t \cdot \Delta t} = \frac{(P_t - P_{t - \Delta t}) \cdot \Delta t_{\text{inv}}}{\text{ATR}_t}$$
*where $\Delta t = \text{InpVelPeriod}$, $\Delta t_{\text{inv}} = \frac{1}{\Delta t}$, and $P$ is the selected price source (Standard or Heikin Ashi).*

### 2.2. Cumulative Path Length (Speed Scalar Envelope: $s_t$)

Speed measures the total distance traveled by price regardless of direction, quantifying internal friction:
$$\text{PathLength}_t = \sum_{k=0}^{\Delta t - 1} |P_{t-k} - P_{t-k-1}|$$
$$s_t = \frac{\text{PathLength}_t \cdot \Delta t_{\text{inv}}}{\text{ATR}_t}$$

The Speed Envelope is plotted symmetrically around the zero centerline:
$$\text{Upper Envelope} = +s_t, \quad \text{Lower Envelope} = -s_t$$

*Crucial Kinematic Insight: When $|v_t| \approx s_t$, price is moving in a frictionless, highly efficient straight-line trend. When $s_t \gg |v_t|$, price is churning violently with high friction and zero directional progress.*

---

### 2.3. Swapped Thermal 5-Zone Palette Classification

| State Index | Color | Classification | Threshold Trigger | Market Kinematics |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Noise / Neutral** | $\|v_t\| < 0.3$ | Consolidation; friction dominates displacement. |
| **1.0** | `clrLightSkyBlue` | **Bullish Flow** | $+0.3 \le v_t < +1.0$ | Sustained directional buying velocity expanding. |
| **2.0** | `clrDeepSkyBlue` | **Bullish Climax** | $v_t \ge +1.0$ | Parabolic velocity spike; kinetic exhaustion warning. |
| **3.0** | `clrCoral` | **Bearish Flow** | $-1.0 < v_t \le -0.3$ | Sustained directional selling velocity expanding. |
| **4.0** | `clrOrangeRed` | **Bearish Climax** | $v_t \le -1.0$ | Capitulation velocity flush; high short-squeeze risk. |

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│                   ATR_Calculator.mqh                   │
│   (Fused Wilder RMA Engine: Pipelined FMA Multipliers) │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers Normalized ATR Stream
                           ▼
┌────────────────────────────────────────────────────────┐
│                Velocity_Calculator.mqh                 │
│      (Pipelined Kinematic Vector & Speed Envelopes)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers Velocity & Speed in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                   Velocity_Pro.mq5                     │
│       (Unified Native & Zero-Lag MTF Fast-Path)        │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (5)       │   Centralized Framework     │
│   • BufVel / BufCol      │   • DataSync_Tools.mqh      │
│   • BufSpeedPos / Neg    │   • Atomic CopyRates MTF    │
│   • BufSignal (Plot 4)   │   • Binary Search Snapping  │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Legacy (v4.00) vs. Enterprise (v4.10)

| Metric | Legacy Implementation (v4.00) | Enterprise Refactor (v4.10) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **MTF Live-Tick `iBarShift`** | Up to 500 calls per tick | **0 calls on live ticks (`ArrayBsearch`)** | **Complete Zero-Lag** |
| **MTF Data Copy Calls** | 6 separate calls per tick | **1 atomic `CopyRates` query** | **-83.3% API Overhead** |
| **ATR Smoothing Loops** | 2 separate loops per tick | **1 fused loop pass** | **-50.0% Loop Overhead** |
| **Kinematic Divisions** | 2 divisions per bar | **0 divisions (Pipelined Multiplier)** | **Hardware FMA Accelerated** |
| **Multi-Window Scalability** | Severe UI freeze on 14 charts | **Silky-smooth execution on >14 charts** | **Enterprise Certified** |

---

## 4. Parameters Reference

### Timeframe Settings

- `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or choose a higher timeframe (e.g., `PERIOD_M5`, `PERIOD_H1`) to activate the synchronized MTF engine.

### Velocity Kinematics Settings

- `InpVelPeriod` (*default: `3`*): Velocity vector lookback window ($\Delta t$). Shorter periods yield instant reaction; longer periods track macro directional momentum.
- `InpATRPeriod` (*default: `14`*): Lookback period for underlying Average True Range (ATR) volatility normalization.
- `InpThresholdLow` (*default: `0.3`*): Threshold defining entry into the active Flow Zone (`LightSkyBlue` / `Coral`).
- `InpThresholdHigh` (*default: `1.0`*): Threshold defining entry into the Climax Zone (`DeepSkyBlue` / `OrangeRed`).
- `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price series source (Supports all 7 Standard and 7 Heikin Ashi modes).
- `InpATRSource` (*default: `ATR_SOURCE_STANDARD`*): Volatility calculation source (`ATR_SOURCE_STANDARD` or `ATR_SOURCE_HEIKIN_ASHI`).

### Speed Envelope Settings

- `InpShowSpeed` (*default: `true`*): Toggle visibility of dynamic Speed Envelopes ($\pm s_t$).
- `InpColorSpeed` (*default: `clrDarkOrange`*): Color applied to Speed Envelope lines.
- `InpStyleSpeed` (*default: `STYLE_SOLID`*): Line style of the envelopes.
- `InpWidthSpeed` (*default: `1`*): Line thickness.

### Signal Line Settings

- `InpShowSignal` (*default: `true`*): Toggle visibility of the smoothed Signal MA line.
- `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
- `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
- `InpColorSignal` (*default: `clrFireBrick`*): Color applied to the signal line plot.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   VELOCITY KINEMATIC PLAYBOOKS                         │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Frictionless Speed Breakout: Enter when Velocity pierces outside    │
│                                 the Speed Envelope (|v_t| > s_t).      │
│ 2. Parabolic Climax Fade:       Take profit when Velocity exceeds ±1.0 │
│                                 and crosses below the Signal MA line.  │
│ 3. Kinetic Squeeze Expansion:   Anticipate volatility breakout when    │
│                                 Speed Envelope collapses into zero.    │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Frictionless Speed Breakout (Trend Expansion Edge)

- **Premise:** When directional displacement equals or exceeds total path length ($v_t \ge s_t$), price is moving in a pure, frictionless institutional trend drive with zero opposing churn.
- **Execution Rules:**
  - **Bullish Drive:** The Velocity histogram bar expands **above the upper Speed Envelope (`+s_t`)**. Enter Long on the close of the breakout bar.
  - **Bearish Drive:** The Velocity histogram expands **below the lower Speed Envelope (`-s_t`)**. Enter Short.

### 5.2. Parabolic Kinetic Climax Fade ($\pm 1.0$)

- **Context:** Price surges aggressively, pushing Velocity beyond **`+1.0` (`clrDeepSkyBlue`)** or **`-1.0` (`clrOrangeRed`)**. This signifies that price is displacing more than 1 full ATR per unit of time—a statistically unsustainable rate.
- **Trigger:**
  - Velocity bar prints lower than the preceding bar and crosses **below** the Signal MA line $\rightarrow$ **Exit Longs**; initiate mean-reversion counter-trend shorts targeting the zero line.
  - Velocity bar prints higher than the preceding bar and crosses **above** the Signal MA line $\rightarrow$ **Cover Shorts**; initiate long bounce trades.

### 5.3. Multi-Timeframe Alignment (M5 MTF Velocity on M1 Execution)

- Load `Velocity_Pro` with `InpTimeframe = PERIOD_M5` onto an **M1 execution chart**.
- The non-warping flat staircase steps represent the 5-minute institutional displacement regime:
  - If M5 Velocity is in **Bullish Flow ($v_t \ge +0.3$)**: Filter M1 execution to **Long pullbacks only**.
  - If M5 Velocity is in **Bearish Flow ($v_t \le -0.3$)**: Filter M1 execution to **Short breakdowns only**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Visual Plot | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufVel` | `INDICATOR_DATA` | Plot 1 (`DRAW_COLOR_HISTOGRAM`) | Volatility-Normalized Velocity Vector ($v_t$). |
| **1** | `BufCol` | `INDICATOR_COLOR_INDEX` | Plot 1 Color Index | Swapped Thermal 5-Zone Palette Index ($0.0 \dots 4.0$). |
| **2** | `BufSpeedPos` | `INDICATOR_DATA` | Plot 2 (`DRAW_LINE`) | Positive Speed Envelope ($+s_t$). |
| **3** | `BufSpeedNeg` | `INDICATOR_DATA` | Plot 3 (`DRAW_LINE`) | Negative Speed Envelope ($-s_t$). |
| **4** | `BufSignal` | `INDICATOR_DATA` | Plot 4 (`DRAW_LINE`) | Smoothed Signal Moving Average Plot. |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring direct compatibility with automated Expert Advisors via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                                     EA_Velocity_Pro_Interface.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Enums & Definitions
#include <MyIncludes\Velocity_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- EA Inputs
input group "=== Velocity Filter Parameters ==="
input ENUM_TIMEFRAMES InpVelTF        = PERIOD_CURRENT;  // Timeframe
input int             InpVelPeriod    = 3;               // Velocity Period
input int             InpATRPeriod    = 14;              // ATR Period
input double          InpThresholdLow = 0.3;             // Flow Threshold
input double          InpThresholdHigh= 1.0;             // Climax Threshold

//--- Global Indicator Handle
int g_vel_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_vel_handle != INVALID_HANDLE)
      IndicatorRelease(g_vel_handle);

   // Instantiate handle to Velocity_Pro via iCustom
   g_vel_handle = iCustom(_Symbol,
                          InpVelTF,
                          "Velocity_Pro",
                          InpVelTF,
                          InpVelPeriod,
                          InpATRPeriod,
                          InpThresholdLow,
                          InpThresholdHigh,
                          0, // PRICE_CLOSE_STD
                          0, // ATR_SOURCE_STANDARD
                          true, clrDarkOrange, STYLE_SOLID, 1, // Speed Envelopes
                          true, 5, EMA, clrFireBrick);          // Signal Line

   if(g_vel_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for Velocity_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: Velocity_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_vel_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_vel_handle);
      g_vel_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed candle (Shift = 1) across all buffers
   double vel[1], col[1], speed_pos[1], speed_neg[1], signal[1];

   if(CopyBuffer(g_vel_handle, 0, 1, 1, vel)       < 1 ||
      CopyBuffer(g_vel_handle, 1, 1, 1, col)       < 1 ||
      CopyBuffer(g_vel_handle, 2, 1, 1, speed_pos) < 1 ||
      CopyBuffer(g_vel_handle, 3, 1, 1, speed_neg) < 1 ||
      CopyBuffer(g_vel_handle, 4, 1, 1, signal)    < 1)
     {
      return; // Data synchronizing
     }

   double cur_vel   = vel[0];
   double cur_sp_pos= speed_pos[0];
   double cur_sig   = signal[0];
   int    cur_state = (int)col[0];

   // Quantitative Kinematic Signals
   bool is_frictionless_bull = (cur_vel >= cur_sp_pos && cur_sp_pos > 0.0);
   bool is_bull_flow         = (cur_state == 1); // LightSkyBlue
   bool is_bull_climax       = (cur_state == 2); // DeepSkyBlue
   bool is_bear_flow         = (cur_state == 3); // Coral
   bool is_bear_climax       = (cur_state == 4); // OrangeRed

   // Telemetry Output
   Comment(StringFormat("Velocity Kinematics [Bar 1]:\n"
                        "Velocity: %.3f | Speed (+): %.3f | Signal: %.3f\n"
                        "Regime: %s | Frictionless Drive: %s",
                        cur_vel, cur_sp_pos, cur_sig,
                        is_bull_climax ? "BULL CLIMAX (Exhaustion)" :
                        (is_bear_climax ? "BEAR CLIMAX (Capitulation)" :
                        (is_bull_flow ? "BULL FLOW (Expansion)" :
                        (is_bear_flow ? "BEAR FLOW (Expansion)" : "EQUILIBRIUM NOISE"))),
                        is_frictionless_bull ? "YES (Velocity > Speed Envelope)" : "NO"));
  }
//+------------------------------------------------------------------+
```
