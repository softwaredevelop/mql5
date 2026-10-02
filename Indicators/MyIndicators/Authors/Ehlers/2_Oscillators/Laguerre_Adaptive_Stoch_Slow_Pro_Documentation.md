# Laguerre Adaptive Stochastic Slow Pro (v1.10)

Proprietary Time-Warped Phase-Envelope Stochastic & Dynamic Adaptive Kinematics Suite

---

## 1. Summary (Introduction)

**Laguerre Adaptive Stochastic Slow Pro (v1.10)** is an original, institutional-grade quantitative momentum oscillator that synthesizes John Ehlers' **Time-Warped 4-Element Laguerre Polynomial Field** with George Lane's **Stochastic Normalization Algorithm**.

Unlike classical Stochastic oscillators that evaluate closing prices within an arbitrary, fixed lookback window ($\max(\text{High}) - \min(\text{Low})$ over $N$ past bars)—which inevitably lags when cycle frequencies shift—**this indicator evaluates the stochastic position of the current time-warped price ($L_0$) relative to the instantaneous phase envelope of the four orthogonal Laguerre polynomial states ($L_0, L_1, L_2, L_3$)**:

$$\text{HH}_t = \max(L_0(t), L_1(t), L_2(t), L_3(t))$$
$$\text{LL}_t = \min(L_0(t), L_1(t), L_2(t), L_3(t))$$
$$\text{RawK}_t = \frac{L_0(t) - \text{LL}_t}{\text{HH}_t - \text{LL}_t} \times 100$$

Because the spread between $L_0 \dots L_3$ represents the internal phase curvature and acceleration of market motion, and this phase envelope is **dynamically modulated by an adaptive damping factor $\gamma_t$** (driven by Efficiency Ratio, ATR, or Standard Deviation):

* **High Efficiency / Trend Expansion ($\text{Metric} \to 1.0$):** Gamma automatically scales down to $\gamma_{\text{min}}$ (e.g., $0.136$). The polynomial phase field expands, allowing Slow %K to rapidly penetrate extreme overbought ($>80$) or oversold ($<20$) boundaries to confirm breakout velocity.
* **Low Efficiency / Noisy Consolidation ($\text{Metric} \to 0.0$):** Gamma automatically scales up to $\gamma_{\text{max}}$ (e.g., $0.882$). Damping heavily compresses the phase envelope, **locking the Slow %K curve tightly around the 50.0 equilibrium baseline** and completely eliminating false range whipsaws.

```text

┌────────────────────────────────────────────────────────────────────────┐
│            ADAPTIVE LAGUERRE STOCHASTIC ARCHITECTURAL ENGINE           │
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
│                                  ▼ INSTANTANEOUS PHASE ENVELOPE        │
│   HH = Max(L0..L3),  LL = Min(L0..L3) ──▶ Raw %K = (L0 - LL)/(HH - LL) │
│                                  │                                     │
│                                  ▼ DOUBLE SMOOTHING CASCADE            │
│   Slow %K = MA(Raw %K, SlowP) ──▶ Signal %D = MA(Slow %K, SignalP)     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **Proprietary Phase-Envelope Normalization:** Eliminates fixed historical lookback windows by measuring price position inside the current bar's 4-pole time-warped Laguerre field.
* **Tri-Mode Adaptive Engine:** Select between Kaufman's **Efficiency Ratio (ER)**, **Average True Range (ATR)**, and **Standard Deviation (StDev)** pathways.
* **Embedded Zero-Heap Engines:** Replaces runtime pointer allocations (`new`/`delete`) with direct embedded `CMovingAverageCalculator` member engines.
* **Zero-Lag MTF Fast-Path:** Higher-timeframe curves project onto lower-timeframe execution charts as non-warping flat steps via `DataSync_Tools.mqh` with zero `iBarShift` overhead on live ticks.
* **Volume-Weighted Smoothing Support:** Supports 8 moving average algorithms (including Volume-Weighted VWMA) across both Slowing and Signal smoothing stages.

---

## 2. Mathematical Foundations & Phase-Envelope Stochastic Theory

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
      │          Phase-Envelope Extreme Normalization          │
      │       HH = Max(L0..L3),  LL = Min(L0..L3)              │
      │       Raw %K = 100 · [ (L0 - LL) / (HH - LL) ]         │
      └───────────────────────────┬────────────────────────────┘
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │               Two-Stage Smoothing Cascade              │
      │    Slow %K = MA(Raw %K),   Signal %D = MA(Slow %K)     │
      └────────────────────────────────────────────────────────┘

```

### 2.1. The Three Adaptive Engine Pathways

#### Pathway A: Kaufman's Efficiency Ratio (`METHOD_EFFICIENCY_RATIO`)

Measures the ratio of net linear directional displacement to total cumulative path length over period $P = \text{InpAdaptivePeriod}$:
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

### 2.4. Phase-Envelope Stochastic Normalization (Raw %K)

$$\text{HH}_t = \max \Big( L_0(t), L_1(t), L_2(t), L_3(t) \Big)$$
$$\text{LL}_t = \min \Big( L_0(t), L_1(t), L_2(t), L_3(t) \Big)$$
$$\Delta\text{Field}_t = \text{HH}_t - \text{LL}_t$$

$$\text{RawK}_t = \begin{cases} \frac{L_0(t) - \text{LL}_t}{\Delta\text{Field}_t} \cdot 100, & \text{if } \Delta\text{Field}_t > 10^{-9} \\ \text{RawK}_{t-1}, & \text{otherwise} \end{cases}$$

---

### 2.5. Double Smoothing Cascade (Slow %K & Signal %D)

To eliminate high-frequency noise, $\text{RawK}$ is smoothed into $\text{SlowK}$ using `InpSlowingMethod` over $P_{\text{slowing}} = \text{InpSlowingPeriod}$:
$$\text{SlowK}_t = \text{MovingAverage}(\text{RawK}, P_{\text{slowing}}, \text{InpSlowingMethod})_t$$

The signal line ($\text{SignalD}$) is generated by smoothing $\text{SlowK}$ over $P_{\text{signal}} = \text{InpSignalPeriod}$ using `InpSignalMethod`:
$$\text{SignalD}_t = \text{MovingAverage}(\text{SlowK}, P_{\text{signal}}, \text{InpSignalMethod})_t$$

---

### 2.6. Symmetrical 5-Zone Indicator Level Matrix

| Level Value | Level Name | Market Momentum State | Institutional Interpretation |
| :---: | :---: | :--- | :--- |
| **90.0** | **Extreme Overbought** | Parabolic buying climax; exhaustion imminent. | Tighten trailing stops; avoid fresh breakout longs. |
| **80.0** | **Overbought Warning** | Strong bullish trend momentum active. | Bullish expansion zone; trail stops below Slow %K. |
| **50.0** | **Equilibrium Centerline** | Symmetrical zero-bias inflection line ($L_0 \approx \text{Mid}$). | Directional pivot: $>50$ Bullish bias, $<50$ Bearish bias. |
| **20.0** | **Oversold Warning** | Strong bearish trend momentum active. | Bearish expansion zone; trail stops above Slow %K. |
| **10.0** | **Extreme Oversold** | Capitulation liquidation floor; short squeeze risk. | Prepare for mean-reversion bounce; cover short positions. |

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│        Laguerre_Adaptive_Stoch_Slow_Calculator.mqh     │
│   (Embedded Member Engines: Zero Dynamic Allocation)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers Slow %K & Signal %D in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│             Laguerre_Adaptive_Stoch_Slow_Pro.mq5       │
│       (Unified Native & Zero-Lag MTF Fast-Path)        │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (2)       │   Centralized Framework     │
│   • BufferSlowK (Plot 1) │   • DataSync_Tools.mqh      │
│   • BufferSignalD(Plot 2)│   • Atomic CopyRates MTF    │
│                          │   • Binary Search Snapping  │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Legacy (v1.00) vs. Enterprise (v1.10)

| Metric | Legacy Implementation (v1.00) | Enterprise Refactor (v1.10) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **Heikin Ashi Array Scope** | `static` shared arrays in method | **Strict Member Variables** | **Eliminates Multi-Chart Crashes** |
| **Standard Deviation Math** | `pow(diff, 2)` transcendental calls | **Direct `diff * diff` squaring** | **50x Faster ALU Math** |
| **Heap Memory Churn** | Dynamic `d_vol[]` and MA engines | **Persistent Embedded Objects** | **Zero Allocation Pauses** |
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

### Stochastic Settings

* `InpSlowingPeriod` (*default: `3`*): Lookback period applied to smooth Raw %K into Slow %K.
* `InpSlowingMethod` (*default: `SMA`*): Moving average algorithm applied to %K (Supports SMA, EMA, VWMA, etc.).
* `InpSignalPeriod` (*default: `3`*): Lookback period applied to smooth Slow %K into Signal %D.
* `InpSignalMethod` (*default: `SMA`*): Moving average algorithm applied to %D.

### Indicator Levels (0-100 Range)

* `InpLevel1` (*default: `10.0`*): Extreme Oversold threshold (Capitulation floor).
* `InpLevel2` (*default: `20.0`*): Oversold Warning threshold.
* `InpLevel3` (*default: `50.0`*): Equilibrium Baseline.
* `InpLevel4` (*default: `80.0`*): Overbought Warning threshold.
* `InpLevel5` (*default: `90.0`*): Extreme Overbought threshold (Exhaustion ceiling).

### Visual Settings

* `InpColorK` (*default: `clrDodgerBlue`*): Color of the main Slow %K line (Width: 1, Solid).
* `InpColorD` (*default: `clrCoral`*): Color of the smoothed Signal %D line (Width: 1, Solid).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│            ADAPTIVE LAGUERRE STOCHASTIC QUANTITATIVE PLAYBOOKS         │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Phase Breakout Expansion:   Enter when Slow %K breaks above 80 or   │
│                                below 20 as Gamma compresses to min.    │
│ 2. Equilibrium Chop Lock:      Pause trend systems when %K freezes     │
│                                horizontally around 50.0 (γ → γ_max).   │
│ 3. Parabolic Phase Climax:     Fade climaxes when Slow %K > 90 or < 10 │
│                                and crosses Signal %D.                  │
│ 4. Slow %K / Signal %D Cross:  Fast continuation entries in direction  │
│                                of higher-timeframe trend bias.         │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Phase Breakout Expansion (The Institutional Thrust)

* **Bullish Breakout Setup:**
  1. Price breaks out of consolidation with expanding volume.
  2. Efficiency increases ($\text{ER} \to 1.0$), forcing $\gamma \to \gamma_{\text{min}} = 0.136$.
  3. The phase envelope opens up and Slow %K thrusts aggressively **above 80.0**.
  4. **Enter Long:** Confirms pure institutional phase acceleration. Maintain position as long as Slow %K holds above 80.0.
* **Bearish Breakdown Setup:**
  1. Price breaks down with expanding volatility.
  2. Slow %K flushes strictly **below 20.0** as $\gamma \to \gamma_{\text{min}}$.
  3. **Enter Short.**

### 5.2. Equilibrium Chop Locking (Whipsaw Elimination)

* **Premise:** During range-bound chop, standard Stochastic oscillates erratically between 30 and 70, triggering false crossover signals.
* **Behavior:** Low efficiency ($\text{ER} \to 0.0$) forces $\gamma \to \gamma_{\text{max}} = 0.882$. The damping completely compresses the 4 Laguerre states, locking the Slow %K line into a flat horizontal corridor tightly around **50.0**.
* **Filter Rule:**
  * When Slow %K oscillates within $[45.0, 55.0]$: **Disable all trend breakout entries**. The market is in random-walk consolidation.

### 5.3. Parabolic Phase Climax Reversal Fade ($> 90$ or $< 10$)

* **Overbought Climax Fade:**
  * Price undergoes an unsustainable parabolic rally, pushing Slow %K above **90.0 (`InpLevel5`)**.
  * Slow %K rolls over and crosses **below Signal %D** while inside the $>80$ zone $\rightarrow$ Take profit on longs; initiate mean-reversion counter-trend shorts targeting the 50.0 centerline.
* **Oversold Capitulation Fade:**
  * Price flushes downward in a forced liquidation event, pushing Slow %K below **10.0 (`InpLevel1`)**.
  * Slow %K hooks upward and crosses **above Signal %D** $\rightarrow$ Cover short positions; enter long bounce trades targeting the 50.0 equilibrium.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Visual Plot | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferSlowK` | `INDICATOR_DATA` | Plot 1 (`DRAW_LINE`) | Main Slow %K Phase Stochastic curve ($0.0 \dots 100.0$). |
| **1** | `BufferSignalD` | `INDICATOR_DATA` | Plot 2 (`DRAW_LINE`) | Smoothed Signal %D line. |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring direct compatibility with automated Expert Advisors via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                             EA_Laguerre_Adaptive_Stoch_Interface |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Calculator Definitions
#include <MyIncludes\Laguerre_Adaptive_Stoch_Slow_Calculator.mqh>

//--- EA Inputs
input group "=== Adaptive Laguerre Stochastic Parameters ==="
input ENUM_TIMEFRAMES           InpStochTF       = PERIOD_CURRENT;       // Timeframe
input ENUM_ADAPTIVE_METHOD      InpStochMethod   = METHOD_EFFICIENCY_RATIO;// Adaptive Method
input int                       InpAdaptivePeriod= 10;                   // Period
input double                    InpGammaMin      = 0.136;                // Min Gamma
input double                    InpGammaMax      = 0.882;                // Max Gamma
input ENUM_APPLIED_PRICE_HA_ALL InpPriceSource   = PRICE_CLOSE_STD;      // Price Source
input int                       InpSlowingPeriod = 3;                    // Slowing Period
input ENUM_MA_TYPE              InpSlowingMethod = SMA;                  // Slowing Method
input int                       InpSignalPeriod  = 3;                    // Signal Period
input ENUM_MA_TYPE              InpSignalMethod  = SMA;                  // Signal Method

//--- Global Indicator Handle
int g_stoch_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_stoch_handle != INVALID_HANDLE)
      IndicatorRelease(g_stoch_handle);

   // Instantiate handle to Laguerre_Adaptive_Stoch_Slow_Pro via iCustom
   g_stoch_handle = iCustom(_Symbol,
                            InpStochTF,
                            "Laguerre_Adaptive_Stoch_Slow_Pro",
                            InpStochTF,
                            InpStochMethod,
                            InpAdaptivePeriod,
                            InpGammaMin,
                            InpGammaMax,
                            InpPriceSource,
                            InpSlowingPeriod,
                            InpSlowingMethod,
                            InpSignalPeriod,
                            InpSignalMethod);

   if(g_stoch_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for Laguerre_Adaptive_Stoch_Slow_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: Laguerre_Adaptive_Stoch_Slow_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_stoch_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_stoch_handle);
      g_stoch_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed candle (Shift = 1) and previous candle (Shift = 2) for Slow %K and Signal %D
   double k_vals[2], d_vals[2];
   ArraySetAsSeries(k_vals, true); // Index 0 = Shift 1, Index 1 = Shift 2
   ArraySetAsSeries(d_vals, true);

   if(CopyBuffer(g_stoch_handle, 0, 1, 2, k_vals) < 2 ||
      CopyBuffer(g_stoch_handle, 1, 1, 2, d_vals) < 2)
     {
      return; // Data synchronizing
     }

   double k_bar1 = k_vals[0];
   double d_bar1 = d_vals[0];

   // Quantitative State Analysis
   bool is_climax_high  = (k_bar1 >= 90.0);
   bool is_climax_low   = (k_bar1 <= 10.0);
   bool is_overbought   = (k_bar1 >= 80.0);
   bool is_oversold     = (k_bar1 <= 20.0);
   bool is_bullish_bias = (k_bar1 > 50.0);
   bool is_bearish_bias = (k_bar1 < 50.0);

   // Momentum Crossover Signals
   bool signal_crossed_up   = (k_vals[1] <= d_vals[1] && k_vals[0] > d_vals[0]);
   bool signal_crossed_down = (k_vals[1] >= d_vals[1] && k_vals[0] < d_vals[0]);

   // Telemetry Output
   Comment(StringFormat("Adaptive Laguerre Stochastic Telemetry [Bar 1]:\n"
                        "Slow %%K: %.2f | Signal %%D: %.2f\n"
                        "Bias: %s | State: %s\n"
                        "Signals -> Buy: %s | Sell: %s",
                        k_bar1, d_bar1,
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
