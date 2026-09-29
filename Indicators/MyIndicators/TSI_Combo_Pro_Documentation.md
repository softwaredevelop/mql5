# True Strength Index (TSI) Combo Pro (v3.20)

William Blau's Double-Smoothed Momentum Suite with VWMA Volume Routing & Zero-Lag MTF Fast-Path

---

## 1. Summary (Introduction)

**TSI Combo Pro (v3.20)** is an institutional-grade momentum oscillator implementing William Blau's complete **True Strength Index (TSI)** tri-plot suite.

While conventional single-smoothed momentum indicators (such as Rate of Change, Momentum, or standard MACD) suffer from persistent high-frequency noise and false breakout whipsaws, **TSI applies a dual-stage Exponential Moving Average cascade (Double-Smoothing) to both directional price changes and absolute price changes**.

By normalizing double-smoothed price change against double-smoothed absolute volatility, TSI generates a bounded, responsive momentum curve that reflects true institutional capital drive without lag-induced phase distortion.

In high-density multi-chart workspaces—such as layouts operating **14 active chart windows with MTF TSI running in Subwindow 1**—legacy implementations cause severe UI freezing due to repetitive `iBarShift` queries and multi-step data copying. **Version 3.20 Enterprise Edition** eliminates this latency via a **Unified Atomic Data Pipeline** and **Zero-Lag MTF Fast-Path**.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                     TSI PRO ARCHITECTURAL EVOLUTION                    │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   LEGACY ENGINE (v3.10):                                               │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • 6 separate Copy API calls on every live MTF tick           │     │
│   │ • Up to 500 iBarShift API calls per tick in forming blocks   │     │
│   │ • Multi-step historical copy with dynamic array allocations  │     │
│   │ • UI Thread Saturation across 14 active chart windows        │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                  │                                     │
│                                  ▼ OPTIMIZED                           │
│   ENTERPRISE ENGINE (v3.20):                                           │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • 1 Atomic CopyRates call per live MTF tick (-83.3% API)     │     │
│   │ • 0 iBarShift calls on live ticks (ArrayBsearch Fast-Path)   │     │
│   │ • Single-call atomic historical HTF rate synchronization     │     │
│   │ • 5 Embedded Incremental Moving Average Engines in O(1)      │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

- **Complete Tri-Plot Momentum Suite:** Concurrently outputs the main **TSI Line** (Plot 2), smoothed **Signal Line** (Plot 3), and the differential **Oscillator Histogram** (Plot 1).
- **Double-Smoothed Momentum Engine:** Filters out market microstructure noise without the destructive phase delay typical of long-period single moving averages.
- **Full VWMA Volume Support:** Supports 8 moving average algorithms (including Volume-Weighted VWMA) across slow, fast, and signal smoothing stages.
- **Zero-Lag MTF Fast-Path:** Higher-timeframe TSI curves project as non-warping steps via `DataSync_Tools.mqh` with zero `iBarShift` overhead on live ticks.
- **Synthetic Heikin Ashi Support:** Direct composition with `CHeikinAshi_Calculator` for filtered price momentum evaluation.

---

## 2. Mathematical Foundations & Double-Smoothing Momentum Theory

```text

     Raw Price (P_t) ──▶ Momentum: m_t = P_t - P_{t-1} and |m_t|
                                    │
                                    ▼
     Stage 1: Slow Smoothing ──▶ EMA( m_t, SlowP ) and EMA( |m_t|, SlowP )
                                    │
                                    ▼
     Stage 2: Fast Smoothing ──▶ EMA_2( m_t, FastP ) and EMA_2( |m_t|, FastP )
                                    │
                                    ▼
     TSI Ratio = 100 · [ EMA_2( m_t ) / EMA_2( |m_t| ) ]
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
     Signal Line = EMA( TSI, SignalP )    Oscillator = TSI - Signal

```

### 2.1. Raw Momentum & Absolute Momentum

Given input price series $P_t$ (Standard or Heikin Ashi):
$$m_t = P_t - P_{t-1}$$
$$|m_t| = |P_t - P_{t-1}|$$

### 2.2. Stage 1: First Smoothing (Slow Period: $P_{\text{slow}}$)

The raw momentum and absolute momentum are smoothed independently using the selected moving average algorithm (`InpSlowMAType`, typically EMA or VWMA):
$$\text{SmoothMtm}_{1, t} = \text{MA}(m, P_{\text{slow}}, \text{InpSlowMAType})_t$$
$$\text{SmoothAbs}_{1, t} = \text{MA}(|m|, P_{\text{slow}}, \text{InpSlowMAType})_t$$

### 2.3. Stage 2: Second Smoothing (Fast Period: $P_{\text{fast}}$)

The first-stage smoothed series are smoothed a second time using `InpFastMAType`:
$$\text{DoubleMtm}_{2, t} = \text{MA}(\text{SmoothMtm}_1, P_{\text{fast}}, \text{InpFastMAType})_t$$
$$\text{DoubleAbs}_{2, t} = \text{MA}(\text{SmoothAbs}_1, P_{\text{fast}}, \text{InpFastMAType})_t$$

### 2.4. Normalized True Strength Index ($\text{TSI}_t$)

$$\text{TSI}_t = \begin{cases} \frac{\text{DoubleMtm}_{2, t}}{\text{DoubleAbs}_{2, t}} \cdot 100, & \text{if } \text{DoubleAbs}_{2, t} > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$
*The resulting TSI curve is bounded between $[-100.0, +100.0]$, oscillating symmetrically around the $0.0$ equilibrium centerline.*

### 2.5. Signal Line & Oscillator Difference

$$\text{Signal}_t = \text{MA}(\text{TSI}, P_{\text{signal}}, \text{InpSignalMAType})_t$$
$$\text{Oscillator}_t = \text{TSI}_t - \text{Signal}_t$$

---

### 2.6. Symmetrical 6-Level Indicator Matrix

| Level Value | Level Name | Market Momentum Regime | Institutional Interpretation |
| :---: | :---: | :--- | :--- |
| **+50.0** | **Bullish Wall (Extreme Climax)** | Parabolic momentum exhaustion ceiling. | Climax exhaustion; fade breakout longs; take profit. |
| **+37.5** | **Bullish Extreme** | Strong directional markup phase active. | Healthy trend acceleration; hold long positions. |
| **+25.0** | **Bullish Warning** | Initial bullish expansion threshold. | Bullish momentum established above baseline. |
| **0.0** | **Equilibrium Baseline** | Centerline inflection ($m_t$ net zero). | Directional pivot: $>0$ Bullish bias, $<0$ Bearish bias. |
| **-25.0** | **Bearish Warning** | Initial bearish markdown threshold. | Bearish momentum established below baseline. |
| **-37.5** | **Bearish Extreme** | Strong directional markdown phase active. | Healthy trend acceleration; hold short positions. |
| **-50.0** | **Bearish Wall (Extreme Climax)** | Capitulation liquidation floor. | Capitulation exhaustion; fade breakdown shorts. |

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│                   TSI_Calculator.mqh                   │
│   (5 Embedded Incremental Moving Average Engines)      │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers TSI, Signal & Osc in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                    TSI_Combo_Pro.mq5                   │
│        (Unified Native & Zero-Lag MTF Fast-Path)       │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • BufferOsc (Plot 1)   │   • DataSync_Tools.mqh      │
│   • BufferTSI (Plot 2)   │   • Atomic CopyRates MTF    │
│   • BufferSignal(Plot 3) │   • Binary Search Snapping  │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Legacy (v3.10) vs. Enterprise (v3.20)

| Metric | Legacy Implementation (v3.10) | Enterprise Refactor (v3.20) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **MTF Live-Tick `iBarShift`** | Up to 500 calls per tick | **0 calls on live ticks (`ArrayBsearch`)** | **Complete Zero-Lag** |
| **MTF Data Copy Calls** | 6 separate calls per tick | **1 atomic `CopyRates` query** | **-83.3% API Overhead** |
| **Historical HTF Copy Calls** | 6 separate calls + alloc | **1 bulk `CopyRates` call** | **Instantaneous Bulk Sync** |
| **Pointer Safety** | Slow `CheckPointer()` on ticks | **Fast `if(!g_calculator)` Guard** | **Optimized Branching** |
| **Multi-Window Scalability** | Noticeable UI lag on 14 charts | **Silky-smooth execution on >14 charts** | **Enterprise Certified** |

---

## 4. Parameters Reference

### Timeframe Settings

- `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or choose a higher timeframe (e.g., `PERIOD_M5`, `PERIOD_H1`) to activate the synchronized MTF engine.

### TSI Core Settings

- `InpSlowPeriod` (*default: `25`*): Lookback period for first-stage momentum smoothing ($P_{\text{slow}}$).
- `InpSlowMAType` (*default: `EMA`*): Moving average algorithm applied to the first smoothing stage (Supports SMA, EMA, VWMA, etc.).
- `InpFastPeriod` (*default: `13`*): Lookback period for second-stage momentum smoothing ($P_{\text{fast}}$).
- `InpFastMAType` (*default: `EMA`*): Moving average algorithm applied to the second smoothing stage.
- `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price series source. Supports all 7 Standard and 7 Heikin Ashi modes (`PRICE_HA_CLOSE`, `PRICE_HA_TYPICAL`, etc.).

### Signal Line Settings

- `InpSignalPeriod` (*default: `13`*): Lookback period for smoothing the TSI line into the Signal line ($P_{\text{signal}}$).
- `InpSignalMAType` (*default: `EMA`*): Moving average algorithm applied to the signal line.

### Indicator Levels

- `InpLevelWallHigh` (*default: `50.0`*): Extreme Climax Overbought ceiling.
- `InpLevelExtrHigh` (*default: `37.5`*): Strong Trend Overbought threshold.
- `InpLevelOverbought` (*default: `25.0`*): Overbought Warning threshold.
- `InpLevelOversold` (*default: `-25.0`*): Oversold Warning threshold.
- `InpLevelExtrLow` (*default: `-37.5`*): Strong Trend Oversold threshold.
- `InpLevelWallLow` (*default: `-50.0`*): Extreme Climax Oversold floor.
- `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
- `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

### Visual Settings

- `InpColorTSI` / `InpStyleTSI` / `InpWidthTSI`: Visual styling for the main TSI line (Default: `clrDodgerBlue`, `STYLE_SOLID`, `2`).
- `InpColorSignal` / `InpStyleSignal` / `InpWidthSignal`: Visual styling for the Signal line (Default: `clrOrangeRed`, `STYLE_SOLID`, `1`).
- `InpColorOsc` / `InpStyleOsc` / `InpWidthOsc`: Visual styling for the Oscillator histogram (Default: `clrSilver`, `STYLE_SOLID`, `1`).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                     TSI COMBO QUANTITATIVE PLAYBOOKS                   │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Zero-Line Centerline Cross: Structural trend bias confirmation when │
│                                TSI crosses strictly above/below 0.0.   │
│ 2. Signal Line Momentum Cross: Fast continuation entries when TSI      │
│                                crosses Signal in the direction of bias │
│ 3. Climax Wall Reversal Fade:  Fade statistical exhaustion when TSI    │
│                                exceeds ±37.5 / ±50.0 and hooks back.   │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Zero-Line Centerline Inflection (Structural Trend Bias)

- **Bullish Bias Confirmation:**
  - TSI line crosses strictly **above the 0.0 centerline**.
  - **Meaning:** Double-smoothed positive price changes exceed negative price changes across both lookback horizons.
  - **Execution:** Focus exclusively on Long setups on the execution chart.
- **Bearish Bias Confirmation:**
  - TSI line crosses strictly **below the 0.0 centerline**. Focus exclusively on Short setups.

### 5.2. Signal Line Momentum Crossover (Continuation Edge)

- **Bullish Setup:**
  1. TSI line is holding above the 0.0 centerline (Bullish structural bias).
  2. A minor pullback causes the Oscillator histogram to dip toward or slightly below zero.
  3. TSI crosses back strictly **above the Signal Line** while holding $> 0.0$ $\rightarrow$ **Enter Long**, placing stop loss below the recent local swing low.
- **Bearish Setup:**
  1. TSI line is holding below the 0.0 centerline.
  2. Pullback rally brings TSI near the Signal line.
  3. TSI crosses strictly **below the Signal Line** while holding $< 0.0$ $\rightarrow$ **Enter Short**.

### 5.3. Parabolic Climax & Wall Exhaustion Fade ($\pm 37.5 \dots \pm 50.0$)

- **Overbought Climax Fade:**
  - TSI surges beyond **$+37.5$** or reaches the **$+50.0$ Wall Level**.
  - The Oscillator histogram peaks and begins declining, followed by TSI crossing **below the Signal Line** $\rightarrow$ Scale out of long positions; enter mean-reversion counter-trend shorts targeting the 0.0 centerline.
- **Oversold Capitulation Fade:**
  - TSI flushes below **$-37.5$** or hits **$-50.0$**.
  - Oscillator histogram hooks upward, and TSI crosses **above the Signal Line** $\rightarrow$ Cover short positions; enter long bounce trades.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Visual Plot | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferOsc` | `INDICATOR_DATA` | Plot 1 (`DRAW_HISTOGRAM`) | Differential Oscillator ($\text{TSI} - \text{Signal}$). |
| **1** | `BufferTSI` | `INDICATOR_DATA` | Plot 2 (`DRAW_LINE`) | Main Double-Smoothed True Strength Index line. |
| **2** | `BufferSignal` | `INDICATOR_DATA` | Plot 3 (`DRAW_LINE`) | Smoothed Signal Line. |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring direct compatibility with automated Expert Advisors via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                                     EA_TSI_Combo_Interface.mq5   |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- EA Inputs
input group "=== TSI Combo Filter Parameters ==="
input ENUM_TIMEFRAMES InpTSITimeframe = PERIOD_CURRENT;  // Timeframe
input int             InpSlowPeriod   = 25;              // Slow Period
input int             InpFastPeriod   = 13;              // Fast Period
input int             InpSignalPeriod = 13;              // Signal Period

//--- Global Indicator Handle
int g_tsi_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_tsi_handle != INVALID_HANDLE)
      IndicatorRelease(g_tsi_handle);

   // Instantiate handle to TSI_Combo_Pro via iCustom
   g_tsi_handle = iCustom(_Symbol,
                          InpTSITimeframe,
                          "TSI_Combo_Pro",
                          InpTSITimeframe,
                          InpSlowPeriod, EMA,
                          InpFastPeriod, EMA,
                          0,                 // Standard Candle Source
                          InpSignalPeriod, EMA);

   if(g_tsi_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for TSI_Combo_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: TSI_Combo_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_tsi_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_tsi_handle);
      g_tsi_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed candle (Shift = 1) and previous candle (Shift = 2)
   double tsi_vals[2], signal_vals[2], osc_vals[1];
   ArraySetAsSeries(tsi_vals,    true); // Index 0 = Shift 1, Index 1 = Shift 2
   ArraySetAsSeries(signal_vals, true);
   ArraySetAsSeries(osc_vals,    true);

   if(CopyBuffer(g_tsi_handle, 1, 1, 2, tsi_vals)    < 2 || // Buffer 1 = TSI Line
      CopyBuffer(g_tsi_handle, 2, 1, 2, signal_vals) < 2 || // Buffer 2 = Signal Line
      CopyBuffer(g_tsi_handle, 0, 1, 1, osc_vals)    < 1)   // Buffer 0 = Oscillator
     {
      return; // Data synchronizing
     }

   double tsi_bar1 = tsi_vals[0];
   double sig_bar1 = signal_vals[0];
   double osc_bar1 = osc_vals[0];

   // Quantitative Momentum Regimes
   bool is_bullish_bias = (tsi_bar1 > 0.0);
   bool is_bearish_bias = (tsi_bar1 < 0.0);
   bool is_overbought   = (tsi_bar1 >= 25.0);
   bool is_oversold     = (tsi_bar1 <= -25.0);
   bool is_climax_high  = (tsi_bar1 >= 37.5);
   bool is_climax_low   = (tsi_bar1 <= -37.5);

   // Momentum Crossover Signals
   bool signal_crossed_up   = (tsi_vals[1] <= signal_vals[1] && tsi_vals[0] > signal_vals[0]);
   bool signal_crossed_down = (tsi_vals[1] >= signal_vals[1] && tsi_vals[0] < signal_vals[0]);

   // Telemetry Output
   Comment(StringFormat("TSI Combo Telemetry [Bar 1]:\n"
                        "TSI: %.2f | Signal: %.2f | Osc: %.2f\n"
                        "Structural Bias: %s | State: %s\n"
                        "Crossover Signals -> Buy: %s | Sell: %s",
                        tsi_bar1, sig_bar1, osc_bar1,
                        is_bullish_bias ? "BULLISH (> 0.0)" : (is_bearish_bias ? "BEARISH (< 0.0)" : "EQUILIBRIUM"),
                        is_climax_high ? "CLIMAX HIGH (>= 37.5)" :
                        (is_climax_low ? "CLIMAX LOW (<= -37.5)" :
                        (is_overbought ? "OVERBOUGHT (>= 25)" :
                        (is_oversold   ? "OVERSOLD (<= -25)" : "NORMAL RANGE"))),
                        (signal_crossed_up && is_bullish_bias) ? "TRIGGERED (Bullish Cross)" : "NO",
                        (signal_crossed_down && is_bearish_bias) ? "TRIGGERED (Bearish Cross)" : "NO"));
  }
//+------------------------------------------------------------------+
```
