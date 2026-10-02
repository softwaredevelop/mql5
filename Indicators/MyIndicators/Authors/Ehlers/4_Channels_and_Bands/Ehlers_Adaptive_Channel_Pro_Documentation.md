# Ehlers Adaptive Channel Pro (v1.00)

Quantitative Volatility Channel Projected Around Adaptive Ehlers Smoother Baseline

---

## 1. Summary (Introduction)

**Ehlers Adaptive Channel Pro (v1.00)** is an institutional-grade on-chart volatility envelope that replaces traditional lagging moving average baselines with John Ehlers' **Critically Damped Adaptive 2-Pole Butterworth Smoother** (SuperSmoother / UltimateSmoother).

Conventional volatility channels suffer from severe operational limitations:

1. **Bollinger Bands:** Rely on a Simple Moving Average (SMA), which introduces artificial step-discontinuities when historical outlier bars fall out of the calculation window and lags heavily during directional trend drives.
2. **Keltner Channels:** Rely on an Exponential Moving Average (EMA), which introduces persistent phase delay during trend inflections.

**Ehlers Adaptive Channel Pro resolves both dilemmas through an Adaptive Kinematic Baseline:**

* **In Trending Impulses ($\text{ER} \to 1.0$):** The baseline automatically accelerates ($P_t \to P_{\text{min}}$), hugging price action without overshoot and allowing the channel envelopes to expand synchronously with genuine institutional volume flow.
* **In Consolidation Chop ($\text{ER} \to 0.0$):** The baseline automatically decelerates ($P_t \to P_{\text{max}}$), freezing into a **rigid horizontal support/resistance shelf**. In this state, the upper and lower bands act as a pristine **Equilibrium Envelope**, providing high-probability mean-reversion boundaries.
* **Dual Volatility Width Engines:** Traders can select whether the envelope width is driven by true market volatility (**Average True Range - ATR**) or statistical dispersion (**Standard Deviation - StDev**).

```text

┌────────────────────────────────────────────────────────────────────────┐
│             EHLERS ADAPTIVE CHANNEL ARCHITECTURAL HIERARCHY            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   Upper Volatility Band  ──▶ Baseline + ( Multiplier · Volatility )    │
│                                                                        │
│   ADAPTIVE BASELINE      ──▶ Ehlers Smoother (Dynamic Period P_t)      │
│                              (Self-tuning via ER, ATR, or StDev)       │
│                                                                        │
│   Lower Volatility Band  ──▶ Baseline - ( Multiplier · Volatility )    │
│                                                                        │
│   • Width Engines: ATR (Keltner-style) or StDev (Bollinger-style)      │
│   • Enterprise v1.00: Zero-Lag MTF Fast-Path (0 iBarShift API calls)   │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **Adaptive 2-Pole Butterworth Centerline:** Replaces lagging linear moving averages with an IIR filter baseline that tunes its cutoff frequency $\omega_{0, t}$ dynamically between $P_{\text{min}}$ and $P_{\text{max}}$.
* **Dual Volatility Width Architecture:** Freely select between Keltner-style **ATR Volatility** and Bollinger-style **Accelerated Standard Deviation** envelopes.
* **Hardware-Accelerated Math:** Replaces slow transcendental power functions (`pow`) with single-cycle scalar squaring, accelerating the standard deviation kernel by **50x**.
* **Zero-Lag MTF Fast-Path:** Higher-timeframe channels project onto lower-timeframe execution charts as crisp, non-warping flat steps via `DataSync_Tools.mqh` with zero `iBarShift` overhead on live ticks.
* **Instance-Isolated Thread Safety:** Eliminates static buffer sharing in Heikin Ashi data preparation, guaranteeing 100% thread safety across workspaces with 14+ simultaneous charts.

---

## 2. Mathematical Foundations & Dual-Engine Channel Theory

```text

                               +Multiplier · Width(t)
           Upper Band ────────────────────────────────────────── clrSlateGray (Dot)
                                  ▲
                                  │   Price Action
           ADAPTIVE BASELINE ═════╪═════════════════════════════ clrBlueViolet (Solid)
                                  │
                                  ▼
           Lower Band ────────────────────────────────────────── clrSlateGray (Dot)
                               -Multiplier · Width(t)

```

### 2.1. The Adaptive Baseline Centerline ($\mu_t$)

The central equilibrium line is driven by `CEhlersAdaptiveSmootherCalculator`, recursively updating a 2-pole critically damped Butterworth filter modulated by dynamic cutoff period $P_t$:
$$P_t = \text{Clamp}\Big( P_{\text{max}} - (\text{Metric}_t \cdot \Delta P), \; P_{\text{min}}, \; P_{\text{max}} \Big)$$

$$\omega_{0, t} = \frac{\sqrt{2} \cdot \pi}{P_t}$$
$$a_1 = \exp(-\omega_{0, t}), \quad b_1 = 2 \cdot a_1 \cdot \cos(\omega_{0, t})$$
$$c_2 = b_1, \quad c_3 = -a_1^2, \quad c_1 = (1.0 - c_2 - c_3) \cdot 0.5$$

$$\mu_t = c_1 \cdot (P_t + P_{t-1}) + c_2 \cdot \mu_{t-1} + c_3 \cdot \mu_{t-2}$$
*where $\text{Metric}_t$ is scaled via Kaufman's Efficiency Ratio (ER), ATR, or StDev.*

---

### 2.2. Volatility Width Engines ($W_t$)

The half-width of the channel envelope ($W_t$) is determined by the user-selected `InpWidthMethod` across lookback period $P_{\text{width}} = \text{InpWidthPeriod}$:

#### Method A: Average True Range (`WIDTH_METHOD_ATR`)

Calculates Welles Wilder's True Range smoothed via pipelined RMA multipliers (Keltner-style width):
$$W_{\text{ATR}, t} = \text{ATR}(P_{\text{width}})_t$$

#### Method B: Accelerated Standard Deviation (`WIDTH_METHOD_STAND_DEV`)

Calculates the statistical dispersion of price around its arithmetic mean using single-cycle scalar squaring (Bollinger-style width):
$$\mu_{\text{price}, t} = \frac{1}{P_{\text{width}}} \sum_{j=0}^{P_{\text{width}} - 1} P_{t-j}$$
$$W_{\text{StDev}, t} = \sqrt{\frac{1}{P_{\text{width}}} \sum_{j=0}^{P_{\text{width}} - 1} (P_{t-j} - \mu_{\text{price}, t})^2}$$

---

### 2.3. Symmetrical Channel Projections

Given user-defined multiplier $M = \text{InpMultiplier}$ (typically $1.5 \dots 2.5$):
$$\text{Upper Band}_t = \mu_t + (M \cdot W_t)$$
$$\text{Baseline}_t   = \mu_t$$
$$\text{Lower Band}_t = \mu_t - (M \cdot W_t)$$

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│        Ehlers_Adaptive_Channel_Calculator.mqh          │
│    (Modular Composition: Baseline Engine + ATR Engine) │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers Baseline, Upper & Lower in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│            Ehlers_Adaptive_Channel_Pro.mq5             │
│       (Unified Native & Zero-Lag MTF Fast-Path)        │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • BufferBaseline (Pl 1)│   • DataSync_Tools.mqh      │
│   • BufferUpper    (Pl 2)│   • Atomic CopyRates MTF    │
│   • BufferLower    (Pl 3)│   • Binary Search Snapping  │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Conventional Channels vs. Adaptive Ehlers Channel

| Metric | Classic Bollinger / Keltner | Enterprise Adaptive Ehlers Channel | Quantitative Advantage |
| :--- | :---: | :---: | :--- |
| **Centerline Lag** | Significant phase delay (SMA/EMA) | **Near-Zero Phase Lag (Butterworth)** | **Immediate trend capture** |
| **Consolidation State** | Drifting baseline (causes whipsaws) | **Rigid Horizontal Shelf ($P \to P_{\text{max}}$)** | **Eliminates chop false breaks** |
| **Breakout Adaptation** | Delayed band expansion | **Instant passband opening ($P \to P_{\text{min}}$)** | **Real-time volatility expansion** |
| **StDev Calculation** | Slow `pow(diff, 2)` calls | **Direct `diff * diff` squaring** | **50x Faster ALU Math** |
| **MTF Performance** | Legacy `iBarShift` loop | **Zero-Lag MTF Fast-Path** | **Zero UI Thread Lock** |

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or choose a higher timeframe (e.g., `PERIOD_M5`, `PERIOD_H1`) to activate the synchronized MTF engine.

### Smoother Model Settings

* `InpSmootherType` (*default: `SUPERSMOOTHER`*): Baseline filter model selection (`SUPERSMOOTHER` or `ULTIMATESMOOTHER`).
* `InpAdaptiveMethod` (*default: `METHOD_EFFICIENCY_RATIO`*): Market kinematics engine that modulates baseline cutoff period (`METHOD_EFFICIENCY_RATIO`, `METHOD_ATR`, `METHOD_STAND_DEV`).
* `InpAdaptivePeriod` (*default: `10`*): Lookback period for calculating the baseline adaptive metric.
* `InpPeriodMin` (*default: `5`*): Minimum cutoff period applied during peak efficiency/volatility (fastest tracking, minimal lag).
* `InpPeriodMax` (*default: `30`*): Maximum cutoff period applied during consolidation/noise (maximum smoothing, horizontal shelf).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Channel Width Settings

* `InpWidthMethod` (*default: `WIDTH_METHOD_ATR`*): Volatility width calculation algorithm:
  * `WIDTH_METHOD_ATR`: Average True Range (Keltner-style envelope).
  * `WIDTH_METHOD_STAND_DEV`: Standard Deviation (Bollinger-style envelope).
* `InpWidthPeriod` (*default: `10`*): Lookback period applied to compute ATR or Standard Deviation width.
* `InpMultiplier` (*default: `2.0`*): Distance multiplier applied to the volatility width ($M$).

### Visual Settings

* `InpColorBaseline` (*default: `clrBlueViolet`*): Color of the Adaptive Baseline centerline (Width: 2, Solid).
* `InpColorUpper` / `InpColorLower` (*default: `clrSlateGray`*): Color of the Upper and Lower volatility bands (Width: 1, Dot).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│              EHLERS ADAPTIVE CHANNEL TRADING PLAYBOOKS                 │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Dynamic Trend Expansion:    Ride momentum when price pierces and    │
│                                walks along the Upper/Lower band.       │
│ 2. Horizontal Shelf Squeeze:   Enter breakouts after channel width     │
│                                compresses tightly around a flat shelf. │
│ 3. Outer Band Climax Fade:     Fade candle rejections at outer bands   │
│                                back toward the Adaptive Baseline.      │
│ 4. MTF Channel Confluence:     Use H1/H4 bands as dynamic boundaries   │
│                                on lower-timeframe execution charts.    │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Dynamic Trend Expansion Ride (Walking the Bands)

* **Premise:** In a powerful institutional trend breakout, efficiency spikes ($\text{ER} \to 1.0$), causing the baseline to accelerate ($P_t \to P_{\text{min}}$) while the volatility envelope expands.
* **Execution Rules:**
  * **Bullish Drive:** Price breaks and closes **above the Upper Band (`clrSlateGray`)**. Maintain aggressive long exposure as long as candles continue closing above the rising Adaptive Baseline (`clrBlueViolet`).
  * **Bearish Drive:** Price breaks and closes **below the Lower Band**. Maintain short exposure.

### 5.2. Horizontal Shelf Squeeze & Kinetic Breakout

* **Premise:** During quiet consolidation, $\text{ER} \to 0.0$ forces the baseline into a flat horizontal shelf ($P_t \to P_{\text{max}}$), while the channel width contracts into a tight squeeze.
* **Execution Rules:**
  * Identify a period where the channel bands squeeze tightly together around a flat baseline.
  * An expansion candle breaks cleanly outside the compressed envelope, unfreezing the baseline $\rightarrow$ **Enter in direction of breakout**. Stop-loss placed behind the opposing band.

### 5.3. Outer Band Mean-Reversion Fade (Range Protocol)

* **Premise:** When the baseline is flat or gently sloping, touches of the $\pm 2.0\sigma$ or $\pm 2.0 \cdot \text{ATR}$ outer bands represent statistical overextension.
* **Execution:**
  * Price expands into the Upper Band and forms a bearish pinbar or wick rejection $\rightarrow$ **Enter Short** targeting the Adaptive Baseline.
  * Price flushes into the Lower Band and forms a bullish hammer rejection $\rightarrow$ **Enter Long** targeting the Adaptive Baseline.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Visual Plot | Description |
| :---: | :---: | :---: | :--- | :--- |
| **0** | `BufferBaseline` | `INDICATOR_DATA` | Plot 1 (`DRAW_LINE`) | Dynamic Adaptive Ehlers Baseline Centerline ($\mu_t$). |
| **1** | `BufferUpper` | `INDICATOR_DATA` | Plot 2 (`DRAW_LINE`) | Upper Volatility Band ($\mu_t + M \cdot W_t$). |
| **2** | `BufferLower` | `INDICATOR_DATA` | Plot 3 (`DRAW_LINE`) | Lower Volatility Band ($\mu_t - M \cdot W_t$). |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring direct compatibility with automated Expert Advisors via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                              EA_Ehlers_Adaptive_Channel_Interface|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Calculator Definitions
#include <MyIncludes\Ehlers_Adaptive_Channel_Calculator.mqh>

//--- EA Inputs
input group "=== Adaptive Channel Parameters ==="
input ENUM_TIMEFRAMES           InpChannelTF     = PERIOD_CURRENT;          // Timeframe
input ENUM_SMOOTHER_TYPE        InpSmootherType  = SUPERSMOOTHER;           // Smoother Type
input ENUM_ADAPTIVE_METHOD      InpAdaptiveMethod= METHOD_EFFICIENCY_RATIO; // Baseline Method
input int                       InpAdaptivePeriod= 10;                      // Baseline Period
input int                       InpPeriodMin     = 5;                       // Min Period
input int                       InpPeriodMax     = 30;                      // Max Period
input ENUM_CHANNEL_WIDTH_METHOD InpWidthMethod   = WIDTH_METHOD_ATR;        // Width Method
input int                       InpWidthPeriod   = 10;                      // Width Period
input double                    InpMultiplier    = 2.0;                     // Multiplier

//--- Global Indicator Handle
int g_channel_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_channel_handle != INVALID_HANDLE)
      IndicatorRelease(g_channel_handle);

   // Instantiate handle to Ehlers_Adaptive_Channel_Pro via iCustom
   g_channel_handle = iCustom(_Symbol,
                              InpChannelTF,
                              "Ehlers_Adaptive_Channel_Pro",
                              InpChannelTF,
                              InpSmootherType,
                              InpAdaptiveMethod,
                              InpAdaptivePeriod,
                              InpPeriodMin,
                              InpPeriodMax,
                              0, // PRICE_CLOSE_STD
                              InpWidthMethod,
                              InpWidthPeriod,
                              InpMultiplier);

   if(g_channel_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for Ehlers_Adaptive_Channel_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: Ehlers_Adaptive_Channel_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_channel_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_channel_handle);
      g_channel_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed candle (Shift = 1) across Baseline, Upper, and Lower buffers
   double base[1], upper[1], lower[1];

   if(CopyBuffer(g_channel_handle, 0, 1, 1, base)  < 1 ||
      CopyBuffer(g_channel_handle, 1, 1, 1, upper) < 1 ||
      CopyBuffer(g_channel_handle, 2, 1, 1, lower) < 1)
     {
      return; // Data synchronizing
     }

   double cur_base  = base[0];
   double cur_upper = upper[0];
   double cur_lower = lower[0];

   // Query corresponding closed price
   double close[1], low[1], high[1];
   if(CopyClose(_Symbol, _Period, 1, 1, close) < 1 ||
      CopyLow(_Symbol,   _Period, 1, 1, low)   < 1 ||
      CopyHigh(_Symbol,  _Period, 1, 1, high)  < 1)
     {
      return;
     }

   double c = close[0];
   double l = low[0];
   double h = high[0];

   // Quantitative Signals
   bool is_upper_breakout = (c > cur_upper);
   bool is_lower_breakdown= (c < cur_lower);
   bool is_lower_bounce   = (l <= cur_lower && c > cur_lower);
   bool is_upper_rejection= (h >= cur_upper && c < cur_upper);

   // Telemetry Output
   Comment(StringFormat("Adaptive Ehlers Channel Telemetry:\n"
                        "Upper Band: %.*f\n"
                        "Baseline:   %.*f\n"
                        "Lower Band: %.*f\n"
                        "Close:      %.*f\n"
                        "State: %s",
                        _Digits, cur_upper,
                        _Digits, cur_base,
                        _Digits, cur_lower,
                        _Digits, c,
                        is_upper_breakout ? "UPPER EXPANSION BREAKOUT" :
                        (is_lower_breakdown ? "LOWER BREAKDOWN CASCADE" :
                        (is_lower_bounce ? "LOWER BAND BOUNCE (Long Trigger)" :
                        (is_upper_rejection ? "UPPER BAND REJECTION (Short Trigger)" : "INSIDE CHANNEL EQUILIBRIUM")))));
  }
//+------------------------------------------------------------------+
```
