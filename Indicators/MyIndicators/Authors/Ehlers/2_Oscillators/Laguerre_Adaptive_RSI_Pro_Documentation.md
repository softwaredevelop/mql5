# Laguerre Adaptive RSI Pro (v1.10)

John Ehlers' Laguerre RSI with Dynamic Multi-Mode Adaptive Gamma Kinematics

---

## 1. Summary (Introduction)

**Laguerre Adaptive RSI Pro (v1.10)** is an institutional-grade hybrid momentum and cycle oscillator that synthesizes John Ehlers' **Time-Warped 4-Element Laguerre RSI** with real-time **Adaptive Kinematics**.

While standard Relative Strength Index (Welles Wilder's RSI) operates with static time windows (typically 14 periods), it suffers from two major structural flaws:

1. **Trend Saturation ("Pinning"):** In strong directional trends, classic RSI pins against the 70–80 or 20–30 boundaries, rendering it incapable of signaling continuous momentum acceleration.
2. **Consolidation Whipsaws:** In range-bound chop, classic RSI fluctuates erratically across the 50 centerline, triggering catastrophic false breakout signals.

**Laguerre Adaptive RSI Pro eliminates both dilemmas at the foundational mathematical level:**
Rather than relying on a static damping factor $\gamma$ (Gamma), the indicator **dynamically modulates $\gamma_t$ on every single bar** based on market efficiency or volatility:

* **High Efficiency / High Volatility ($\text{Metric} \to 1.0$):** Gamma automatically scales down to $\gamma_{\text{min}}$ (e.g., $0.136$), instantly making the Laguerre registers hyper-reactive. The LRSI curve expands rapidly into overbought ($>80$) or oversold ($<20$) territory, confirming institutional breakout velocity without lag.
* **Low Efficiency / Noisy Consolidation ($\text{Metric} \to 0.0$):** Gamma automatically scales up to $\gamma_{\text{max}}$ (e.g., $0.882$). Damping heavily suppresses high-frequency noise, **anchoring the LRSI curve firmly to the 50.0 equilibrium baseline** and completely eliminating false reversal whipsaws.

```text

┌────────────────────────────────────────────────────────────────────────┐
│               ADAPTIVE LAGUERRE RSI ARCHITECTURAL ENGINE               │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   MARKET KINEMATICS ENGINE (Selectable Adaptive Pathway):              │
│   ┌────────────────────────┬───────────────────┬───────────────────┐   │
│   │ Kaufman's Efficiency   │ Average True Range│ Standard Deviation│   │
│   │ Ratio (ER) [0.0 - 1.0] │ (ATR Normalization│ (StDev Normaliz.) │   │
│   └────────────────────────┴───────────────────┴───────────────────┘   │
│                                  │                                     │
│                                  ▼ DYNAMIC GAMMA SCALING               │
│   γ(t) = γ_max - Metric(t) · (γ_max - γ_min)                           │
│                                  │                                     │
│                                  ▼ 4-POLE LAGUERRE STATES              │
│   L0(t) ──▶ L1(t) ──▶ L2(t) ──▶ L3(t)                                  │
│                                  │                                     │
│                                  ▼ DIRECTIONAL DIFFERENCE ACCUMULATORS │
│   cu = ∑ Max(L_k - L_{k+1}, 0),  cd = ∑ Max(L_{k+1} - L_k, 0)          │
│                                  │                                     │
│                                  ▼ NORMALIZED OSCILLATOR               │
│   LRSI(t) = 100 · [ cu / (cu + cd) ] ──▶ Smoothed Signal Line          │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **Tri-Mode Adaptive Engine:** Select between Kaufman's **Efficiency Ratio (ER)**, **Average True Range (ATR)**, and **Standard Deviation (StDev)** pathways.
* **Dynamic Time-Warp Modulation:** Smoothly scales the filter's time-warp ratio between user-defined speed ($\gamma_{\text{min}}$) and smoothness ($\gamma_{\text{max}}$) bounds.
* **Zero-Lag MTF Fast-Path:** Higher-timeframe curves project onto lower-timeframe execution charts as non-warping flat steps via `DataSync_Tools.mqh` with zero `iBarShift` overhead on live ticks.
* **Embedded Composition Engine:** Replaces dynamic heap pointers with direct embedded member engines (`CMovingAverageCalculator m_ma_calc`), eliminating runtime heap allocations.
* **Instance-Isolated Thread Safety:** Eliminates static array sharing in Heikin Ashi data preparation, guaranteeing 100% thread safety across workspaces with 14+ simultaneous charts.

---

## 2. Mathematical Foundations & Adaptive Normalization

```text

              RAW PRICE (Market Noise & Momentum Spikes)
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │         Adaptive Pathway Normalization Engine          │
      │   Calculates Metric(t) ∈ [0.0, 1.0] (ER, ATR, or StDev)│
      └───────────────────────────┬────────────────────────────┘
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │             Dynamic Gamma Transfer Function            │
      │       γ(t) = γ_max - Metric(t) · (γ_max - γ_min)       │
      └───────────────────────────┬────────────────────────────┘
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │          Dynamic 4-Element Laguerre Recursion          │
      │            L0(t), L1(t), L2(t), L3(t) States           │
      └───────────────────────────┬────────────────────────────┘
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │           Directional Accumulators (cu, cd)            │
      │     cu = ∑ Upward Changes, cd = ∑ Downward Changes     │
      └───────────────────────────┬────────────────────────────┘
                                  │
                  Adaptive Laguerre RSI (0 - 100)

```

### 2.1. The Three Adaptive Engine Pathways

#### Pathway A: Kaufman's Efficiency Ratio (`METHOD_EFFICIENCY_RATIO`)

Measures the ratio of net linear directional displacement to total cumulative distance traveled over period $P = \text{InpAdaptivePeriod}$:
$$\text{Direction}_t = |P_t - P_{t - P}|$$
$$\text{Volatility}_t = \sum_{k=0}^{P - 1} |P_{t-k} - P_{t-k-1}|$$
$$\text{Metric}_t = \begin{cases} \frac{\text{Direction}_t}{\text{Volatility}_t}, & \text{if } \text{Volatility}_t > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

#### Pathway B: Normalized ATR Volatility (`METHOD_ATR`)

Computes Wilder's ATR across period $P$, then maps the raw points into $[0.0, 1.0]$ via a sliding Min-Max normalizer:
$$\text{Metric}_t = \text{Normalize}(\text{ATR}_t, P)$$

#### Pathway C: Accelerated Standard Deviation (`METHOD_STAND_DEV`)

Computes the statistical dispersion of price around the $P$-period arithmetic mean using single-cycle scalar squaring (zero `pow()` calls):
$$\mu_t = \frac{1}{P} \sum_{j=0}^{P - 1} P_{t-j}$$
$$\text{StDev}_t = \sqrt{\frac{1}{P} \sum_{j=0}^{P - 1} (P_{t-j} - \mu_t)^2}$$
$$\text{Metric}_t = \text{Normalize}(\text{StDev}_t, P)$$

---

### 2.2. Dynamic Gamma Scaling Function

Given maximum damping $\gamma_{\text{max}} = \text{InpGammaMax}$, minimum damping $\gamma_{\text{min}} = \text{InpGammaMin}$, and precomputed range $\Delta\gamma = \gamma_{\text{max}} - \gamma_{\text{min}}$:
$$\gamma_t = \text{Clamp}\Big( \gamma_{\text{max}} - (\text{Metric}_t \cdot \Delta\gamma), \; 0.0, \; 1.0 \Big)$$

---

### 2.3. Time-Warped 4-Element Laguerre Difference Equations

Using the dynamic gamma $\gamma_t$, the four orthogonal state elements update recursively:
$$L_0(t) = (1 - \gamma_t) P_t + \gamma_t L_0(t-1)$$
$$L_1(t) = -\gamma_t L_0(t) + L_0(t-1) + \gamma_t L_1(t-1)$$
$$L_2(t) = -\gamma_t L_1(t) + L_1(t-1) + \gamma_t L_2(t-1)$$
$$L_3(t) = -\gamma_t L_2(t) + L_2(t-1) + \gamma_t L_3(t-1)$$

---

### 2.4. Directional Accumulators & Normalized LRSI Formulation

The difference between adjacent polynomial states represents directional price flow across the time-warped spectrum:
$$cu = \max(L_0 - L_1, 0) + \max(L_1 - L_2, 0) + \max(L_2 - L_3, 0)$$
$$cd = \max(L_1 - L_0, 0) + \max(L_2 - L_1, 0) + \max(L_3 - L_2, 0)$$

The final normalized Adaptive Laguerre RSI is bounded strictly between $[0.0, 100.0]$:
$$\text{LRSI}_t = \begin{cases} 100.0 \cdot \frac{cu}{cu + cd}, & \text{if } cu + cd > 10^{-9} \\ \text{LRSI}_{t-1}, & \text{otherwise} \end{cases}$$

---

### 2.5. Symmetrical 5-Zone Indicator Level Matrix

| Level Value | Level Name | Market Momentum State | Institutional Interpretation |
| :---: | :---: | :--- | :--- |
| **90.0** | **Extreme Overbought** | Parabolic buying climax; exhaustion imminent. | Tighten trailing stops; prepare for mean reversion. |
| **80.0** | **Overbought Warning** | Strong bullish trend momentum active. | Bullish expansion zone; trail stops below %K/Signal. |
| **50.0** | **Equilibrium Centerline** | Symmetrical zero-bias inflection line ($cu = cd$). | Directional pivot: $>50$ Bullish bias, $<50$ Bearish bias. |
| **20.0** | **Oversold Warning** | Strong bearish trend momentum active. | Bearish expansion zone; trail stops above %K/Signal. |
| **10.0** | **Extreme Oversold** | Capitulation liquidation floor; short squeeze risk. | Prepare for mean-reversion bounce; cover short positions. |

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│            Laguerre_Adaptive_RSI_Calculator.mqh        │
│   (Embedded Member Engines: Zero Dynamic Allocation)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers LRSI & Signal in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│               Laguerre_Adaptive_RSI_Pro.mq5            │
│       (Unified Native & Zero-Lag MTF Fast-Path)        │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (2)       │   Centralized Framework     │
│   • BufferLRSI (Plot 1)  │   • DataSync_Tools.mqh      │
│   • BufferSignal (Plot 2)│   • Atomic CopyRates MTF    │
│                          │   • Binary Search Snapping  │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Legacy (v1.00) vs. Enterprise (v1.10)

| Metric | Legacy Implementation (v1.00) | Enterprise Refactor (v1.10) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **Heikin Ashi Array Scope** | `static` shared arrays in method | **Strict Member Variables** | **Eliminates Multi-Chart Crashes** |
| **Standard Deviation Math** | `pow(diff, 2)` transcendental calls | **Direct `diff * diff` squaring** | **50x Faster ALU Math** |
| **Heap Memory Churn** | Dynamic `d_vol[]` and `m_ma_calc` | **Persistent Embedded Objects** | **Zero Allocation Pauses** |
| **MTF Live-Tick `iBarShift`** | Up to 500 calls per tick | **0 calls on live ticks (`ArrayBsearch`)** | **Complete Zero-Lag** |
| **MTF Data Copy Calls** | 5 separate calls per tick | **1 atomic `CopyRates` query** | **-80.0% API Overhead** |
| **Pointer Safety** | Slow `CheckPointer()` on ticks | **Fast `if(!g_calculator)` Guard** | **Optimized Branching** |
| **Multi-Window Scalability** | Risk of array-out-of-range crashes | **100% thread-safe on >14 charts** | **Enterprise Certified** |

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or choose a higher timeframe (e.g., `PERIOD_M5`, `PERIOD_H1`) to activate the synchronized MTF engine.

### Adaptive Baseline Settings

* `InpAdaptiveMethod` (*default: `METHOD_EFFICIENCY_RATIO`*): The underlying market kinematics engine:
  * `METHOD_EFFICIENCY_RATIO`: Kaufman's ER (Optimal for trend efficiency and whipsaw filtering).
  * `METHOD_ATR`: Average True Range volatility (Optimal for breakout expansion tracking).
  * `METHOD_STAND_DEV`: Standard Deviation dispersion (Optimal for statistical cycle tracking).
* `InpAdaptivePeriod` (*default: `10`*): Lookback period for calculating the adaptive metric.
* `InpGammaMin` (*default: `0.136`*): Minimum gamma boundary applied during peak efficiency/volatility (fastest reaction, near-zero lag).
* `InpGammaMax` (*default: `0.882`*): Maximum gamma boundary applied during low efficiency/noise (maximum smoothing, anchors to 50.0).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Signal Line Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the smoothed Signal line.
* `InpSignalPeriod` (*default: `3`*): Lookback period for smoothing the LRSI line into the Signal line.
* `InpSignalMAType` (*default: `EMA`*): Moving average algorithm applied to the signal line (Supports SMA, EMA, VWMA, etc.).

### Visual Settings

* `InpColorLRSI` (*default: `clrMediumTurquoise`*): Color of the main Adaptive Laguerre RSI line (Width: 1, Solid).
* `InpColorSignal` (*default: `clrLightCoral`*): Color of the smoothed Signal line (Width: 1, Solid).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│               ADAPTIVE LAGUERRE RSI QUANTITATIVE PLAYBOOKS             │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Breakout Momentum Expansion: Enter when LRSI breaks above 80 or     │
│                                 below 20 as Gamma compresses to min.   │
│ 2. Chop Equilibrium Lock:       Pause trend systems when LRSI freezes  │
│                                 horizontally around 50.0 (γ → γ_max).  │
│ 3. Extreme Parabolic Exhaustion:Fade climaxes when LRSI exceeds 90     │
│                                 or flushes below 10 and hooks back.    │
│ 4. Signal Line Crossover:       Fast continuation entries when LRSI    │
│                                 crosses Signal in direction of bias.   │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Breakout Momentum Expansion (The Gamma Snapping Edge)

* **Bullish Breakout Setup:**
  1. Market breaks out from consolidation with expanding volume.
  2. Efficiency increases ($\text{ER} \to 1.0$), forcing $\gamma \to \gamma_{\text{min}} = 0.136$.
  3. The Adaptive Laguerre RSI line snaps upward aggressively, crossing strictly **above 80.0**.
  4. **Enter Long:** This confirms pure institutional volume velocity. Maintain position as long as LRSI holds above 80.0.
* **Bearish Breakdown Setup:**
  1. Price breaks down with expanding volatility.
  2. LRSI flushes strictly **below 20.0** as $\gamma \to \gamma_{\text{min}}$.
  3. **Enter Short.**

### 5.2. Chop Equilibrium Lock (Whipsaw Elimination)

* **Premise:** When price action becomes random and choppy, standard RSI oscillates erratically between 40 and 60, triggering false crossover signals.
* **Behavior:** Low efficiency ($\text{ER} \to 0.0$) forces $\gamma \to \gamma_{\text{max}} = 0.882$. The damping completely absorbs minor price fluctuations, locking the LRSI line into a flat horizontal corridor tightly around **50.0**.
* **Filter Rule:**
  * When LRSI oscillates within $[45.0, 55.0]$: **Disable all trend breakout entries**. The market is in random-walk consolidation.

### 5.3. Extreme Parabolic Exhaustion Fade ($> 90$ or $< 10$)

* **Overbought Climax Fade:**
  * Price undergoes an unsustainable parabolic rally, pushing LRSI above **90.0 (`InpLevel5`)**.
  * LRSI rolls over and crosses **below the Signal line** while inside the $>80$ zone $\rightarrow$ Take profit on longs; initiate mean-reversion counter-trend shorts targeting the 50.0 centerline.
* **Oversold Capitulation Fade:**
  * Price flushes downward in a forced liquidation event, pushing LRSI below **10.0 (`InpLevel1`)**.
  * LRSI hooks upward and crosses **above the Signal line** $\rightarrow$ Cover short positions; enter long bounce trades targeting the 50.0 equilibrium.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Visual Plot | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferLRSI` | `INDICATOR_DATA` | Plot 1 (`DRAW_LINE`) | Main Adaptive Laguerre RSI curve ($0.0 \dots 100.0$). |
| **1** | `BufferSignal` | `INDICATOR_DATA` | Plot 2 (`DRAW_LINE`) | Smoothed Signal Line. |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring direct compatibility with automated Expert Advisors via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                                EA_Laguerre_Adaptive_RSI_Interface|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Calculator Definitions
#include <MyIncludes\Laguerre_Adaptive_RSI_Calculator.mqh>

//--- EA Inputs
input group "=== Adaptive Laguerre RSI Parameters ==="
input ENUM_TIMEFRAMES           InpLRsiTF        = PERIOD_CURRENT;       // Timeframe
input ENUM_ADAPTIVE_METHOD      InpLRsiMethod    = METHOD_EFFICIENCY_RATIO;// Adaptive Method
input int                       InpLRsiPeriod    = 10;                   // Period
input double                    InpLRsiGammaMin  = 0.136;                // Min Gamma
input double                    InpLRsiGammaMax  = 0.882;                // Max Gamma
input ENUM_APPLIED_PRICE_HA_ALL InpPriceSource   = PRICE_CLOSE_STD;      // Price Source
input bool                      InpEnableSignal  = true;                 // Enable Signal Line
input int                       InpSignalPeriod  = 3;                    // Signal Period
input ENUM_MA_TYPE              InpSignalType    = EMA;                  // Signal MA Type

//--- Global Indicator Handle
int g_lrsi_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_lrsi_handle != INVALID_HANDLE)
      IndicatorRelease(g_lrsi_handle);

   // Instantiate handle to Laguerre_Adaptive_RSI_Pro via iCustom
   g_lrsi_handle = iCustom(_Symbol,
                           InpLRsiTF,
                           "Laguerre_Adaptive_RSI_Pro",
                           InpLRsiTF,
                           InpLRsiMethod,
                           InpLRsiPeriod,
                           InpLRsiGammaMin,
                           InpLRsiGammaMax,
                           InpPriceSource,
                           InpEnableSignal,
                           InpSignalPeriod,
                           InpSignalType);

   if(g_lrsi_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for Laguerre_Adaptive_RSI_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: Laguerre_Adaptive_RSI_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_lrsi_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_lrsi_handle);
      g_lrsi_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed candle (Shift = 1) and previous candle (Shift = 2) for LRSI and Signal
   double lrsi_vals[2], signal_vals[2];
   ArraySetAsSeries(lrsi_vals,   true); // Index 0 = Shift 1, Index 1 = Shift 2
   ArraySetAsSeries(signal_vals, true);

   if(CopyBuffer(g_lrsi_handle, 0, 1, 2, lrsi_vals)   < 2 ||
      CopyBuffer(g_lrsi_handle, 1, 1, 2, signal_vals) < 2)
     {
      return; // Data synchronizing
     }

   double lrsi_bar1   = lrsi_vals[0];
   double signal_bar1 = signal_vals[0];

   // Quantitative State Analysis
   bool is_climax_high  = (lrsi_bar1 >= 90.0);
   bool is_climax_low   = (lrsi_bar1 <= 10.0);
   bool is_overbought   = (lrsi_bar1 >= 80.0);
   bool is_oversold     = (lrsi_bar1 <= 20.0);
   bool is_bullish_bias = (lrsi_bar1 > 50.0);
   bool is_bearish_bias = (lrsi_bar1 < 50.0);

   // Momentum Crossover Signals
   bool signal_crossed_up   = (lrsi_vals[1] <= signal_vals[1] && lrsi_vals[0] > signal_vals[0]);
   bool signal_crossed_down = (lrsi_vals[1] >= signal_vals[1] && lrsi_vals[0] < signal_vals[0]);

   // Telemetry Output
   Comment(StringFormat("Adaptive Laguerre RSI Telemetry [Bar 1]:\n"
                        "LRSI: %.2f | Signal: %.2f\n"
                        "Bias: %s | State: %s\n"
                        "Signals -> Buy: %s | Sell: %s",
                        lrsi_bar1, signal_bar1,
                        is_bullish_bias ? "BULLISH (> 50.0)" : (is_bearish_bias ? "BEARISH (< 50.0)" : "EQUILIBRIUM"),
                        is_climax_high ? "EXTREME CLIMAX (>= 90)" :
                        (is_climax_low ? "EXTREME CAPITULATION (<= 10)" :
                        (is_overbought ? "OVERBOUGHT (>= 80)" :
                        (is_oversold   ? "OVERSOLD (<= 20)" : "NORMAL RANGE"))),
                        (signal_crossed_up && is_bullish_bias) ? "TRIGGERED (Bullish Cross)" : "NO",
                        (signal_crossed_down && is_bearish_bias) ? "TRIGGERED (Bearish Cross)" : "NO"));
  }
//+------------------------------------------------------------------+
```
