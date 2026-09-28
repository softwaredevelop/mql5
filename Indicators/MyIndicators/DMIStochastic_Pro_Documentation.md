# DMI Stochastic Suite Pro (v3.10)

Barbara Star's Hybrid Directional Movement & Stochastic Momentum Oscillator

---

## 1. Summary (Introduction)

**DMI Stochastic Pro (v3.10)** is an institutional-grade hybrid momentum oscillator developed by Barbara Star, Ph.D. It uniquely synthesizes J. Welles Wilder's **Directional Movement System (DMI)** with George Lane's **Stochastic Oscillator**.

Standard Stochastic oscillators evaluate price directly relative to the high-low price range, which frequently generates severe whipsaws and premature overbought/oversold signals during sustained directional trends. **DMI Stochastic resolves this by normalizing the Directional Movement Index ($+DI$ minus $-DI$) through the Stochastic algorithm**.

The result is a bounded (0 to 100) trend-momentum oscillator that filters out counter-trend noise, identifies high-conviction trend pullbacks, and pinpoints statistical exhaustion extremes with remarkable fidelity.

In high-density multi-chart workspaces—such as setups operating **14 active chart windows with MTF DMI Stochastic running in Subwindow 2**—legacy implementations cause severe UI freezing due to repetitive `iBarShift` queries and tick-by-tick heap memory churn. **Version 3.10 Enterprise Edition** eliminates this latency via a **Persistent Memory Architecture** and **Zero-Lag MTF Fast-Path**.

```text

┌────────────────────────────────────────────────────────────────────────┐
│               DMI STOCHASTIC ARCHITECTURAL EVOLUTION                   │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   LEGACY ENGINE (v3.00):                                               │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • 5 separate Copy API calls executed on every MTF tick       │     │
│   │ • Up to 500 iBarShift API calls per tick in forming blocks   │     │
│   │ • Dynamic heap reallocations (vol_double[]) on every tick    │     │
│   │ • 14 Charts × Subwindow 2 = Massive UI Thread Freezing       │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                  │                                     │
│                                  ▼ OPTIMIZED                           │
│   ENTERPRISE ENGINE (v3.10):                                           │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • 1 Atomic CopyRates call per live MTF tick (-80% API calls) │     │
│   │ • 0 iBarShift calls on live ticks (ArrayBsearch Fast-Path)   │     │
│   │ • Persistent Member Buffers (Zero heap allocations on ticks) │     │
│   │ • Direct Fused DMI Integration (Precomputed RMA math)        │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

- **Hybrid Trend-Momentum Synthesis:** Normalizes directional force ($+DI$ vs. $-DI$) into a standardized 0–100 bounded scale.
- **Persistent Memory Pipeline:** Eliminates dynamic array allocations on live ticks, ensuring zero garbage-collection pauses.
- **Fused DMI Engine Composition:** Inherits the v1.30 `DMI_Engine` optimizations, utilizing precomputed Wilder multipliers and fused single-pass smoothing.
- **Zero-Lag MTF Fast-Path:** Higher-timeframe curves (e.g., M5 DMI Stoch on M1 charts) project as non-warping steps via `DataSync_Tools.mqh` with zero `iBarShift` overhead on live ticks.
- **Selectable Smoothing Algorithms:** Supports 8 moving average algorithms for %K slowing and %D signal lines (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA).

---

## 2. Mathematical Foundations & DMI-Stochastic Hybridization

```text

     Raw Price (OHLC) ──▶ [ Fused DMI Engine ] ──▶ +DI(t) and -DI(t)
                                                    │
                                                    ▼
                       DMI Oscillator = +DI(t) - -DI(t)
                                                    │
                                                    ▼
                       Stochastic Normalization (0 - 100)
                                                    │
                                 ┌──────────────────┴──────────────────┐
                                 ▼                                     ▼
                           Fast %K (Raw)                      Slow %K & Signal %D

```

### 2.1. DMI Differential Oscillator ($\text{DmiOsc}_t$)

First, the indicator computes the Directional Indicators ($+\text{DI}_t$ and $-\text{DI}_t$) using Welles Wilder's True Range and Directional Movement formulas across period $P_{\text{DMI}} = \text{InpDMIPeriod}$:
$$\text{DmiOsc}_t = \begin{cases} (+\text{DI}_t) - (-\text{DI}_t), & \text{if } \text{InpOscType} = \text{OSC\_PDI\_MINUS\_NDI} \\ (-\text{DI}_t) - (+\text{DI}_t), & \text{if } \text{InpOscType} = \text{OSC\_NDI\_MINUS\_PDI} \end{cases}$$
*The resulting oscillator oscillates around an equilibrium zero-line within theoretical bounds of $[-100, +100]$.*

### 2.2. Stochastic Normalization Kernel (Fast %K)

The Stochastic algorithm is then applied directly to the $\text{DmiOsc}$ series across a lookback window $K_{\text{fast}} = \text{InpFastKPeriod}$:
$$\text{HighestOsc}_t = \max_{j=0 \dots K_{\text{fast}}-1} (\text{DmiOsc}_{t-j})$$
$$\text{LowestOsc}_t  = \min_{j=0 \dots K_{\text{fast}}-1} (\text{DmiOsc}_{t-j})$$
$$\text{Range}_t = \text{HighestOsc}_t - \text{LowestOsc}_t$$

$$\text{FastK}_t = \begin{cases} \frac{\text{DmiOsc}_t - \text{LowestOsc}_t}{\text{Range}_t} \cdot 100, & \text{if } \text{Range}_t > 10^{-9} \\ 50.0, & \text{otherwise} \end{cases}$$

### 2.3. Slow %K and %D Signal Smoothing Equations

To eliminate high-frequency whipsaws, $\text{FastK}$ is smoothed using the selected `InpStochMethod` across $K_{\text{slow}} = \text{InpSlowKPeriod}$:
$$\%K_t = \text{MovingAverage}(\text{FastK}, K_{\text{slow}}, \text{InpStochMethod})$$

The %D signal line is generated by smoothing $\%K$ across period $D_{\text{smooth}} = \text{InpSmoothPeriod}$ using `InpSignalMethod`:
$$\%D_t = \text{MovingAverage}(\%K, D_{\text{smooth}}, \text{InpSignalMethod})$$

---

### 2.4. Symmetrical 5-Zone Indicator Level Matrix

| Level Threshold | Level Name | Market State | Institutional Action |
| :---: | :---: | :--- | :--- |
| **90.0** | **Extreme Overbought** | Parabolic buying climax; exhaustion imminent. | Tighten trailing stops; avoid fresh breakout longs. |
| **80.0** | **Overbought Warning** | Strong bullish trend momentum active. | Bullish continuation zone; trail stops behind %K. |
| **50.0** | **Equilibrium Center** | Zero-bias inflection line ($+DI \approx -DI$). | Directional pivot: $>50$ Bullish bias, $<50$ Bearish bias. |
| **20.0** | **Oversold Warning** | Strong bearish trend momentum active. | Bearish continuation zone; trail stops above %K. |
| **10.0** | **Extreme Oversold** | Capitulation selling floor; short covering risk. | Prepare for mean-reversion bounce; cover short positions. |

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│                     DMI_Engine.mqh                     │
│    (Fused TR/DM Smoothing + Normalized DI in 1 Pass)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers +DI and -DI in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│              DMIStochastic_Calculator.mqh              │
│  (Persistent Memory Pipeline: Zero Dynamic Allocation) │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers %K and %D in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                 DMIStochastic_Pro.mq5                  │
│       (Unified Native & Zero-Lag MTF Fast-Path)        │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (2)       │   Centralized Framework     │
│   • BufferK (Plot 1: %K) │   • DataSync_Tools.mqh      │
│   • BufferD (Plot 2: %D) │   • Atomic CopyRates MTF    │
│                          │   • Binary Search Snapping  │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Legacy (v3.00) vs. Enterprise (v3.10)

| Metric | Legacy Implementation (v3.00) | Enterprise Refactor (v3.10) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **MTF Live-Tick `iBarShift`** | Up to 500 calls per tick | **0 calls on live ticks (`ArrayBsearch`)** | **Complete Zero-Lag** |
| **MTF Data Copy Calls** | 5 separate calls per tick | **1 atomic `CopyRates` query** | **-80.0% API Overhead** |
| **Heap Memory Churn** | Dynamic `vol_double[]` every tick | **Persistent Member Cache** | **Zero Allocation Pauses** |
| **Pointer Safety** | Slow `CheckPointer()` on every tick | **Fast `if(!g_calculator)` Guard** | **Optimized Branching** |
| **Multi-Window Scalability** | Severe UI lag on 14 charts | **Silky-smooth execution on >14 charts** | **Enterprise Certified** |

---

## 4. Parameters Reference

### Timeframe Settings

- `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or choose a higher timeframe (e.g., `PERIOD_M5`, `PERIOD_H1`) to activate the synchronized MTF engine.

### DMI & Stochastic Settings

- `InpCandleSource` (*default: `CANDLE_STANDARD`*): Input price series source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).
- `InpOscType` (*default: `OSC_PDI_MINUS_NDI`*): Differential formula (`OSC_PDI_MINUS_NDI` for standard $+DI - -DI$ orientation; `OSC_NDI_MINUS_PDI` for inverted view).
- `InpDMIPeriod` (*default: `10`*): Lookback period for underlying DMI $+DI$ and $-DI$ calculation.
- `InpFastKPeriod` (*default: `10`*): Stochastic lookback window for finding Highest/Lowest of the DMI Oscillator.
- `InpSlowKPeriod` (*default: `3`*): Smoothing period to transform Fast %K into Slow %K.
- `InpStochMethod` (*default: `SMA`*): Moving average algorithm applied to %K (Supports SMA, EMA, VWMA, etc.).
- `InpSmoothPeriod` (*default: `3`*): Smoothing period to generate the %D signal line from %K.
- `InpSignalMethod` (*default: `SMA`*): Moving average algorithm applied to %D.

### Indicator Levels (0-100 Range)

- `InpLevelExtrHigh` (*default: `90.0`*): Extreme Overbought threshold.
- `InpLevelHigh` (*default: `80.0`*): Standard Overbought Warning threshold.
- `InpLevelMid` (*default: `50.0`*): Equilibrium Baseline.
- `InpLevelLow` (*default: `20.0`*): Standard Oversold Warning threshold.
- `InpLevelExtrLow` (*default: `10.0`*): Extreme Oversold threshold.
- `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
- `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

### Visual Settings

- `InpColorK` / `InpStyleK` / `InpWidthK`: Visual styling for the %K main line (Default: `clrDodgerBlue`, `STYLE_SOLID`, `2`).
- `InpColorD` / `InpStyleD` / `InpWidthD`: Visual styling for the %D signal line (Default: `clrCoral`, `STYLE_SOLID`, `1`).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   DMI STOCHASTIC QUANTITATIVE PLAYBOOKS                │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Trend Continuation Pullback: Buy pullbacks when %K bounces off the  │
│                                 50 or 20 level in an established trend.│
│ 2. Parabolic Exhaustion Fade:   Fade extreme climaxes when %K > 90     │
│                                 and crosses below %D.                  │
│ 3. Regime Inflection Cross:     Enter structural trend shifts when %K  │
│                                 cleanly crosses the 50.0 center-line.  │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Trend Continuation Pullback (The Institutional Edge)

- **Bullish Trend Setup:**
  1. Market is in an established uptrend (price trading above SuperSmoother / VWAP).
  2. DMI Stochastic pulls back downward, dipping into the **50.0 equilibrium level** or momentarily testing the **20.0 oversold level**.
  3. %K crosses back strictly **above %D** while holding above 20.0 $\rightarrow$ **Enter Long**. This represents a high-probability continuation entry where directional selling has exhausted.
- **Bearish Trend Setup:**
  1. Market is in a confirmed downtrend.
  2. %K rallies upward to test the 50.0 or 80.0 resistance levels.
  3. %K crosses strictly **below %D** $\rightarrow$ **Enter Short**.

### 5.2. Parabolic Climax & Capitulation Reversal

- **Extreme Bullish Exhaustion Fade:**
  - %K expands beyond **90.0 (`InpLevelExtrHigh`)**, indicating extreme directional overextension.
  - %K rolls over and crosses **below %D** while inside the $>80$ zone $\rightarrow$ Take profit on longs; initiate mean-reversion counter-trend shorts targeting the 50.0 median.
- **Extreme Bearish Capitulation Bounce:**
  - %K flushes below **10.0 (`InpLevelExtrLow`)**, signaling forced liquidation selling.
  - %K hooks upward and crosses **above %D** $\rightarrow$ Cover short positions; enter long targeting the 50.0 equilibrium.

### 5.3. Multi-Timeframe Alignment (M5 MTF DMI Stoch on M1 Execution)

- Load `DMIStochastic_Pro` with `InpTimeframe = PERIOD_M5` onto an **M1 execution chart**.
- The non-warping flat staircase steps represent the 5-minute directional momentum:
  - If M5 %K is holding above 50.0: Focus exclusively on **Long execution on M1**.
  - If M5 %K is holding below 50.0: Focus exclusively on **Short execution on M1**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Visual Plot | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferK` | `INDICATOR_DATA` | Plot 1 (`DRAW_LINE`) | Main DMI Stochastic %K line. |
| **1** | `BufferD` | `INDICATOR_DATA` | Plot 2 (`DRAW_LINE`) | Smoothed Signal %D line. |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring direct compatibility with automated Expert Advisors via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                               EA_DMI_Stochastic_Interface.mq5    |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Calculator Definitions
#include <MyIncludes\DMIStochastic_Calculator.mqh>

//--- EA Inputs
input group "=== DMI Stochastic Filter Parameters ==="
input ENUM_TIMEFRAMES InpDMIStochTF    = PERIOD_CURRENT;    // Timeframe
input int             InpDMIPeriod     = 10;                // DMI Period
input int             InpFastKPeriod   = 10;                // Fast %K Period
input int             InpSlowKPeriod   = 3;                 // Slow %K Period
input int             InpSmoothPeriod  = 3;                 // %D Period
input ENUM_MA_TYPE    InpMethod        = SMA;               // Smoothing Method

//--- Global Indicator Handle
int g_dmistoch_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_dmistoch_handle != INVALID_HANDLE)
      IndicatorRelease(g_dmistoch_handle);

   // Instantiate handle to DMIStochastic_Pro via iCustom
   g_dmistoch_handle = iCustom(_Symbol,
                               InpDMIStochTF,
                               "DMIStochastic_Pro",
                               InpDMIStochTF,
                               0,                   // Standard Candle Source
                               OSC_PDI_MINUS_NDI,   // Oscillator Formula
                               InpDMIPeriod,
                               InpFastKPeriod,
                               InpSlowKPeriod,
                               InpMethod,
                               InpSmoothPeriod,
                               InpMethod);

   if(g_dmistoch_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for DMIStochastic_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: DMIStochastic_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_dmistoch_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_dmistoch_handle);
      g_dmistoch_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed candle (Shift = 1) and previous candle (Shift = 2) for %K and %D
   double k_vals[2], d_vals[2];
   ArraySetAsSeries(k_vals, true); // Index 0 = Shift 1, Index 1 = Shift 2
   ArraySetAsSeries(d_vals, true);

   if(CopyBuffer(g_dmistoch_handle, 0, 1, 2, k_vals) < 2 ||
      CopyBuffer(g_dmistoch_handle, 1, 1, 2, d_vals) < 2)
     {
      return; // Data synchronizing
     }

   double k_bar1 = k_vals[0];
   double d_bar1 = d_vals[0];

   // Quantitative Momentum Signals
   bool is_overbought = (k_bar1 >= 80.0);
   bool is_oversold   = (k_bar1 <= 20.0);
   bool is_bullish    = (k_bar1 > 50.0);
   bool is_bearish    = (k_bar1 < 50.0);

   // Momentum Crossover Signals
   bool k_crossed_up   = (k_vals[1] <= d_vals[1] && k_vals[0] > d_vals[0]);
   bool k_crossed_down = (k_vals[1] >= d_vals[1] && k_vals[0] < d_vals[0]);

   // Telemetry Output
   Comment(StringFormat("DMI Stochastic Telemetry [Bar 1]:\n"
                        "%%K: %.2f | %%D: %.2f\n"
                        "Bias: %s | State: %s\n"
                        "Signals -> Buy: %s | Sell: %s",
                        k_bar1, d_bar1,
                        is_bullish ? "BULLISH (> 50.0)" : (is_bearish ? "BEARISH (< 50.0)" : "EQUILIBRIUM"),
                        is_overbought ? "OVERBOUGHT (>= 80)" : (is_oversold ? "OVERSOLD (<= 20)" : "NORMAL RANGE"),
                        (k_crossed_up && !is_overbought) ? "TRIGGERED (Bullish Cross)" : "NO",
                        (k_crossed_down && !is_oversold) ? "TRIGGERED (Bearish Cross)" : "NO"));
  }
//+------------------------------------------------------------------+
```
