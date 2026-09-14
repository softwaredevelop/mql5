# Rolling Volume-Weighted Z-Score (RV-Score) Pro (v3.20)

Quantitative Continuous Volume-Weighted Dispersion & Stationary Fair-Value Oscillator

---

## 1. Summary (Introduction)

**RV-Score Pro** is an institutional-grade statistical momentum oscillator that measures normalized price dispersion from a **continuous Rolling Volume-Weighted Average Price (Rolling VWAP)** in standardized units of standard deviation ($\sigma$).

While traditional session-anchored indicators (such as standard V-Score) reset their memory at daily or weekly boundaries—causing artificial volatility pinching at session opens and late-day inertia—**RV-Score evaluates price against a continuously moving, volume-weighted institutional liquidity anchor**.

By calculating dispersion over a rolling historical horizon (e.g., last 144 bars or continuous 24 hours), RV-Score generates a **strictly stationary, zero-boundary oscillator** that eliminates opening-bell distortion while preserving volume-weighted market truth.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                       RV-SCORE DISPERSION MODEL                        │
├────────────────────────────────────────────────────────────────────────┤
│  RV-Score(t) = [ Close(t) - RollingVWAP(t) ] / RollingStdDev(t)        │
│  Expressed in standardized Sigma Multiples (σ)                         │
│                                                                        │
│  • Continuous Zero-Boundary Horizon (No Session Cutoff Distortion)     │
│  • Amortized O(1) Prefix-Sum Integration                               │
└────────────────────────────────────────────────────────────────────────┘

```

### The Four Z-Score Indicator Paradigms

- **Z-Score Pro:** Measures Gaussian dispersion from a static Moving Average (Price/Time axis).
- **K-Score Pro:** Measures kinetic elasticity from Kaufman's Adaptive Moving Average (Efficiency/Regime axis).
- **V-Score Pro:** Measures statistical overextension from Anchored/Session VWAP (Session-Volume axis).
- **RV-Score Pro:** Measures continuous statistical dispersion from Rolling VWAP (Stationary Volume-Weighted axis).

### Key Capabilities

- **Stationary Volume-Weighted Baseline:** Eliminates session-open false spikes and late-day paralysis by continuously sliding both the VWAP anchor and volatility lookback window.
- **Swapped Thermal 5-Zone Palette:** Visually classifies market states into noise/equilibrium, active institutional flow, and statistical climax exhaustion.
- **Integrated Signal Smoothing Engine:** Direct composition with `CMovingAverageCalculator`, providing 8 advanced smoothing algorithms (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA) over the raw RV-Score histogram.
- **Unified 2026 MTF Architecture:** Maps higher-timeframe RV-Score histograms (e.g., H1 RV-Score) onto lower-timeframe execution charts (M5, M1) via `DataSync_Tools.mqh` with non-warping staircase flat-force synchronization.

---

## 2. Mathematical Foundations & Continuous Normalization

```text

                           +2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── DeepSkyBlue (Bull Climax)
                           +1.5σ (Bullish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - LightSkyBlue (Bull Flow)
                            0.0σ (Rolling VWAP Equilibrium)
          ───────────────────────────────────────────────────────────── Gray (Noise / Fair Value)
                           -1.5σ (Bearish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Coral (Bear Flow)
                           -2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── OrangeRed (Bear Climax)

```

### 2.1. Continuous Rolling VWAP Baseline ($\mu_{\text{RVWAP}, t}$)

Calculated via cumulative prefix sums over the sliding window $W$ (bars or elapsed seconds):
$$\mu_{\text{RVWAP}, t} = \frac{\text{SumTPV}_t - \text{SumTPV}_{t - W}}{\text{SumVol}_t - \text{SumVol}_{t - W}}$$
*where $\text{TP}_k = \frac{H_k + L_k + C_k}{3}$ and $V_k$ is the applied volume.*

### 2.2. Continuous Deviation Metric ($\text{Diff}_k$)

$$\text{Diff}_k = C_k - \mu_{\text{RVWAP}, k}$$

### 2.3. Rolling Standard Deviation Around Rolling VWAP ($\sigma_{\text{Rolling}, t}$)

Given the volatility lookback period $P = \text{InpSigmaPeriod}$:
$$\sigma_{\text{Rolling}, t} = \sqrt{\frac{1}{P} \sum_{k=0}^{P - 1} \left( \text{Diff}_{t - k} \right)^2}$$

### 2.4. Normalized RV-Score Formulation

$$\text{RVScore}_t = \begin{cases} \frac{C_t - \mu_{\text{RVWAP}, t}}{\sigma_{\text{Rolling}, t}}, & \text{if } \sigma_{\text{Rolling}, t} > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

---

### 2.5. Swapped Thermal 5-Zone Color Palette

| State Index | Color | Classification | Sigma Level Trigger | Institutional Market Action |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Noise / Equilibrium** | $\|\text{RVScore}\| \le 1.5\sigma$ | Price oscillating within stationary fair-value bounds. |
| **1.0** | `clrLightSkyBlue` | **Bullish Flow** | $+1.5\sigma < \text{RVScore} \le +2.0\sigma$ | Sustained institutional volume expansion to the upside. |
| **2.0** | `clrDeepSkyBlue` | **Bullish Climax** | $\text{RVScore} > +2.0\sigma$ | Overbought statistical extremity; liquidity absorption warning. |
| **3.0** | `clrCoral` | **Bearish Flow** | $-2.0\sigma \le \text{RVScore} < -1.5\sigma$ | Sustained institutional selling pressure active. |
| **4.0** | `clrOrangeRed` | **Bearish Climax** | $\text{RVScore} < -2.0\sigma$ | Capitulation liquidation floor; high short-squeeze probability. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                 RVScore_Calculator.mqh                 │
│      (Core Math Engine - Prefix Sums & Dispersion)     │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs RV-Score Values in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                     RVScore_Pro.mq5                    │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • ExtRVScoreBuffer     │   • Rolling_VWAP_Engine     │
│   • ExtColorsBuffer      │   • MovingAverage_Engine    │
│   • ExtSignalBuffer      │   • DataSync_Tools.mqh      │
└──────────────────────────┴─────────────────────────────┘

```

1. **Zero Boundary Artifacts:** Unlike anchored VWAP systems, the absence of session cutoffs completely prevents array index desynchronization and variance pinching.
2. **Separation of Concerns:** `CRVScoreCalculator` embeds `CRollingVWAPCalculator` via composition, maintaining independent memory spaces for volume integration and volatility standard deviation.
3. **2026 MTF Framework (`DataSync_Tools.mqh`):** Higher-timeframe RV-Score histograms are projected onto lower-timeframe charts using flat-force step synchronization, guaranteeing zero repainting on closed candles.

---

## 4. Parameters Reference

### Timeframe Settings

- `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or choose a higher timeframe (e.g., `PERIOD_H1`) to activate the synchronized MTF engine.

### Rolling VWAP Engine

- `InpRollingType` (*default: `ROLLING_BARS`*):
  - `ROLLING_BARS`: Sliding window of fixed bar length.
  - `ROLLING_TIME`: Continuous physical time window in minutes.
- `InpRollingWindow` (*default: `144`*): Window length (bar count or minutes).
- `InpSigmaPeriod` (*default: `20`*): Lookback period ($P$) for computing standard deviation variance around the Rolling VWAP.

### Calculation Sources

- `InpVolumeType` (*default: `VOLUME_TICK`*): Applied volume source (`VOLUME_TICK` or `VOLUME_REAL`).
- `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price series source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).

### Signal Line Settings

- `InpShowSignal` (*default: `true`*): Toggles visibility of the smoothed Signal MA line.
- `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
- `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
- `InpColorSignal` (*default: `clrFireBrick`*): Color applied to the signal line plot.

### Indicator Levels (Sigma Multiples)

- `InpLevelFlowHigh` (*default: `1.5`*): Bullish Flow threshold boundary.
- `InpLevelFlowLow` (*default: `-1.5`*): Bearish Flow threshold boundary.
- `InpLevelClimaxHigh` (*default: `2.0`*): Bullish Climax threshold (`DeepSkyBlue`).
- `InpLevelClimaxLow` (*default: `-2.0`*): Bearish Climax threshold (`OrangeRed`).
- `InpLevelExtremeHigh` (*default: `2.5`*): Extreme statistical expansion ceiling.
- `InpLevelExtremeLow` (*default: `-2.5`*): Extreme statistical capitulation floor.
- `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
- `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   RV-SCORE INSTITUTIONAL PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Continuous Climax Fade: Fade statistical overextensions when        │
│                            RV-Score > +2.0σ and hooks back.            │
│ 2. Volume Flow Expansion:  Trend continuation when RV-Score holds      │
│                            between +1.5σ and +2.0σ (Flow Zone).        │
│ 3. Signal Line Crossover:  Zero-lag trend confirmation upon Signal MA  │
│                            crossings inside/outside the flow zones.    │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Continuous Climax Mean Reversion ($\pm 2.0\sigma \dots \pm 2.5\sigma$)

- **Context:** Price aggressively expands away from the Rolling VWAP, pushing the RV-Score into the Climax zone ($> +2.0\sigma$, `DeepSkyBlue` or $< -2.0\sigma$, `OrangeRed`).
- **Short Reversal Setup:**
  1. RV-Score exceeds $+2.0\sigma$.
  2. Histogram bar prints lower than the preceding bar and crosses **below** the Signal MA line.
  3. Enter Short targeting the zero-line fair value ($0.0\sigma$).
- **Long Capitulation Bounce:**
  1. RV-Score flushes below $-2.0\sigma$ or $-2.5\sigma$ during a panic selloff.
  2. Histogram prints a higher low and crosses **above** the Signal MA line.
  3. Enter Long targeting the $0.0\sigma$ equilibrium.

### 5.2. Volume Flow Expansion Continuation ($+1.5\sigma \dots +2.0\sigma$)

- **Context:** In strong institutional markup/markdown phases, prices stay persistently overextended without snapping back.
- **Bullish Momentum Rule:**
  - As long as RV-Score holds between $+1.5\sigma$ (`LightSkyBlue`) and $+2.0\sigma$, maintain long trend-following exposure.
  - Exit or tighten trailing stops only when the histogram falls back below $+1.5\sigma$ into the neutral gray zone.

### 5.3. Multi-Timeframe Alignment (H1 RV-Score on M5 Execution)

- Load `RVScore_Pro` with `InpTimeframe = PERIOD_H1` on an M5 trading chart.
- If H1 RV-Score is positive and above $+1.5\sigma$: Institutional money flow on the hourly horizon is bullish $\rightarrow$ Filter M5 execution to **Long signals only**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `ExtRVScoreBuffer` | `INDICATOR_DATA` | Standardized RV-Score Values in Sigma Units ($\sigma$) |
| **1** | `ExtColorsBuffer` | `INDICATOR_COLOR_INDEX` | Swapped Thermal 5-Zone Palette Index ($0.0 \dots 4.0$) |
| **2** | `ExtSignalBuffer` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers maintain strict chronological indexing (`ArraySetAsSeries = false`), ensuring direct compatibility with Expert Advisors and multi-asset scanner dashboards.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                                         EA_RVScore_Interface.mq5 |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Rolling VWAP Window Type Definition
#include <MyIncludes\Rolling_VWAP_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- EA Inputs
input group "=== RV-Score Filter Settings ==="
input ENUM_TIMEFRAMES     InpRVTimeframe   = PERIOD_CURRENT;  // Timeframe
input ENUM_ROLLING_TYPE   InpRVType        = ROLLING_BARS;    // Rolling Type
input int                 InpRVWindow      = 144;             // Rolling Window
input int                 InpRVSigmaPeriod = 20;              // Volatility Lookback (Sigma)
input ENUM_APPLIED_VOLUME InpRVVolume      = VOLUME_TICK;     // Volume Type
input ENUM_CANDLE_SOURCE  InpRVSource      = CANDLE_STANDARD; // Candle Source
input bool                InpShowSignal    = true;            // Enable Signal Line
input int                 InpSignalPeriod  = 5;               // Signal Period
input ENUM_MA_TYPE        InpSignalType    = EMA;             // Signal MA Type

//--- Global Indicator Handle
int g_rvscore_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_rvscore_handle != INVALID_HANDLE)
      IndicatorRelease(g_rvscore_handle);

   // Instantiate handle to RVScore_Pro via iCustom
   g_rvscore_handle = iCustom(_Symbol,
                              InpRVTimeframe,
                              "RVScore_Pro",
                              InpRVTimeframe,
                              InpRVType,
                              InpRVWindow,
                              InpRVSigmaPeriod,
                              InpRVVolume,
                              InpRVSource,
                              InpShowSignal,
                              InpSignalPeriod,
                              InpSignalType,
                              clrFireBrick,
                              1.5, -1.5, 2.0, -2.0, 2.5, -2.5,
                              clrSilver, STYLE_DOT);

   if(g_rvscore_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for RVScore_Pro. Error Code: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: RVScore_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_rvscore_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_rvscore_handle);
      g_rvscore_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query last 2 closed bars and active live bar (3 values)
   double score_val[3], color_val[3], signal_val[3];
   ArraySetAsSeries(score_val,  true); // Index 0 = Live, 1 = Closed bar
   ArraySetAsSeries(color_val,  true);
   ArraySetAsSeries(signal_val, true);

   // Read Buffer 0 (RV-Score), Buffer 1 (Colors), Buffer 2 (Signal)
   if(CopyBuffer(g_rvscore_handle, 0, 0, 3, score_val)  < 3 ||
      CopyBuffer(g_rvscore_handle, 1, 0, 3, color_val)  < 3 ||
      CopyBuffer(g_rvscore_handle, 2, 0, 3, signal_val) < 3)
     {
      return;
     }

   double closed_score  = score_val[1];
   double closed_signal = signal_val[1];
   int    closed_color  = (int)color_val[1];

   // Quantitative Signals
   bool is_bullish_climax = (closed_color == 2); // DeepSkyBlue (> +2.0σ)
   bool is_bearish_climax = (closed_color == 4); // OrangeRed   (< -2.0σ)
   bool is_bullish_flow   = (closed_color == 1); // LightSkyBlue (+1.5σ to +2.0σ)
   bool is_bearish_flow   = (closed_color == 3); // Coral        (-1.5σ to -2.0σ)

   // Signal Crossover Execution Logic
   bool signal_cross_down = (score_val[2] >= signal_val[2] && score_val[1] < signal_val[1]);
   bool signal_cross_up   = (score_val[2] <= signal_val[2] && score_val[1] > signal_val[1]);

   // Telemetry Output
   Comment(StringFormat("RV-Score [Bar 1]: %.2fσ | Signal: %.2fσ | State: %s\n"
                        "Climax Fade Short: %s | Climax Fade Long: %s",
                        closed_score, closed_signal,
                        is_bullish_climax ? "BULL CLIMAX" : (is_bearish_climax ? "BEAR CLIMAX" : (is_bullish_flow ? "BULL FLOW" : (is_bearish_flow ? "BEAR FLOW" : "EQUILIBRIUM"))),
                        (is_bullish_climax && signal_cross_down) ? "TRIGGERED" : "NO",
                        (is_bearish_climax && signal_cross_up) ? "TRIGGERED" : "NO"));
  }
//+------------------------------------------------------------------+
```
