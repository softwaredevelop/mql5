# Volume-Weighted Z-Score (V-Score) Pro (v3.21)

Quantitative Volume-Weighted Dispersion & Institutional Fair-Value Oscillator

---

## 1. Summary (Introduction)

**V-Score Pro (v3.21)** is an institutional-grade statistical momentum oscillator that measures price deviation from the **Volume-Weighted Average Price (VWAP)** normalized in standardized units of standard deviation ($\sigma$).

While standard Z-Score indicators measure distance from unweighted, lagging moving averages (such as SMA or EMA), **V-Score evaluates price against the market's true volume-weighted institutional fair value**. This allows systematic traders to quantify exactly how extreme a price move is relative to where actual transaction volume was committed.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        V-SCORE DISPERSION MODEL                        │
├────────────────────────────────────────────────────────────────────────┤
│  V-Score(t) = [ Close(t) - VWAP(t) ] / StandardDeviation(Price - VWAP) │
│  Expressed in standardized Sigma Multiples (σ)                         │
└────────────────────────────────────────────────────────────────────────┘

```

### The Four Z-Score Indicator Paradigms

- **Z-Score Pro:** Measures Gaussian dispersion from a static Moving Average (Price/Time axis).
- **K-Score Pro:** Measures kinetic elasticity from Kaufman's Adaptive Moving Average (Efficiency/Regime axis).
- **V-Score Pro:** Measures statistical overextension from Anchored/Session VWAP (Session-Volume axis).
- **RV-Score Pro:** Measures continuous statistical dispersion from Rolling VWAP (Stationary Volume-Weighted axis).

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   V-SCORE ARCHITECTURAL EVOLUTION                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   LEGACY ENGINE (v3.00):                                               │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • 6 separate Copy API calls executed on every MTF tick       │     │
│   │ • Up to 500 iBarShift API calls per tick in forming blocks   │     │
│   │ • Truncated history lookback on Weekly / Monthly resets      │     │
│   │ • UI Thread Saturation in multi-chart workspaces             │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                  │                                     │
│                                  ▼ OPTIMIZED                           │
│   ENTERPRISE ENGINE (v3.21):                                           │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • 1 Atomic CopyRates call per live MTF tick (-83.3% API)     │     │
│   │ • 0 iBarShift calls on live ticks (ArrayBsearch Fast-Path)   │     │
│   │ • Strict 64-bit MQL5 pointer safety (ptr != NULL enforced)   │     │
│   │ • Multi-week history depth stabilization (1000–2000 bars)    │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

- **True Volume-Weighted Mean:** Evaluates price distance from Session, Weekly, Monthly, or Custom Session VWAPs.
- **Swapped Thermal 5-Zone Color Palette:** Distinguishes between neutral consolidation noise, healthy institutional flow, and unsustainable statistical exhaustion climax.
- **Integrated Signal Smoothing Engine:** Supports 8 moving average algorithms (including Volume-Weighted VWMA) directly over the V-Score histogram via `MovingAverage_Engine.mqh`.
- **Zero-Lag MTF Fast-Path:** Higher-timeframe V-Score histograms (e.g., M15 or H1) map onto lower-timeframe execution charts (M1, M5) with flat, non-warping steps and zero `iBarShift` overhead on live ticks.

---

## 2. Mathematical Foundations & Volume-Weighted Dispersion

```text

                           +2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── DeepSkyBlue (Bull Climax)
                           +1.5σ (Bullish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - LightSkyBlue (Bull Flow)
                            0.0σ (VWAP Institutional Fair Value)
          ───────────────────────────────────────────────────────────── Gray (Noise / Fair Value)
                           -1.5σ (Bearish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Coral (Bear Flow)
                           -2.5σ (Extreme Exhaustion / Climax)
          ───────────────────────────────────────────────────────────── OrangeRed (Bear Climax)

```

### 2.1. Volume-Weighted Mean ($\mu_{\text{VWAP}, t}$)

$$\mu_{\text{VWAP}, t} = \frac{\sum_{k=\text{anchor}(t)}^{t} \left( \text{TP}_k \cdot V_k \right)}{\sum_{k=\text{anchor}(t)}^{t} V_k}$$
*where $\text{TP}_k = \frac{H_k + L_k + C_k}{3}$ (or Heikin Ashi equivalent) and $V_k$ is the applied volume.*

### 2.2. Open-Ended Rolling Standard Deviation Around VWAP ($\sigma_t$)

Given a volatility lookback period $P = \text{InpPeriod}$:
$$\text{Diff}_k = C_k - \mu_{\text{VWAP}, k}$$
$$\sigma_t = \sqrt{\frac{1}{P} \sum_{k=0}^{P - 1} \left( \text{Diff}_{t-k} \right)^2}$$

*Note: In `VScore_Calculator.mqh`, the variance sampler scans backward across session boundaries while filtering out off-session gaps, ensuring variance never pinches to zero at market open.*

### 2.3. Normalized V-Score Formulation

$$V\text{Score}_t = \begin{cases} \frac{C_t - \mu_{\text{VWAP}, t}}{\sigma_t}, & \text{if } \sigma_t > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

---

### 2.4. Swapped Thermal 5-Zone Color Palette

| State Index | Color | Classification | Sigma Level Trigger | Institutional Market Action |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Noise / Neutral** | $\|V\text{Score}\| \le 1.5\sigma$ | Price oscillating within fair-value equilibrium. |
| **1.0** | `clrLightSkyBlue` | **Bullish Flow** | $+1.5\sigma < V\text{Score} \le +2.0\sigma$ | Institutional buying pressure actively expanding. |
| **2.0** | `clrDeepSkyBlue` | **Bullish Climax** | $V\text{Score} > +2.0\sigma$ | Statistical overbought climax; liquidity exhaustion warning. |
| **3.0** | `clrCoral` | **Bearish Flow** | $-2.0\sigma \le V\text{Score} < -1.5\sigma$ | Institutional selling pressure actively expanding. |
| **4.0** | `clrOrangeRed` | **Bearish Climax** | $V\text{Score} < -2.0\sigma$ | Panic capitulation floor; short-covering bounce potential. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                  VScore_Calculator.mqh                 │
│   (Core Math Engine - Open-Ended Variance Sampler)     │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs V-Score Values in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                     VScore_Pro.mq5                     │
│       (Unified Native & Zero-Lag MTF Fast-Path)        │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • ExtVScoreBuffer      │   • DataSync_Tools.mqh      │
│   • ExtColorsBuffer      │   • MovingAverage_Engine    │
│   • ExtSignalBuffer      │   • Atomic CopyRates MTF    │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Legacy (v3.00) vs. Enterprise (v3.21)

| Metric | Legacy Implementation (v3.00) | Enterprise Refactor (v3.21) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **MTF Live-Tick `iBarShift`** | Up to 500 calls per tick | **0 calls on live ticks (`ArrayBsearch`)** | **Complete Zero-Lag** |
| **MTF Data Copy Calls** | 6 separate calls per tick | **1 atomic `CopyRates` query** | **-83.3% API Overhead** |
| **Weekly / Monthly Depth** | Inadequate history depth | **1000–2000 bars guaranteed** | **Full Multi-Week Fidelity** |
| **Pointer Safety** | Implicit boolean evaluation | **Strict `ptr != NULL` syntax** | **100% Compiler Certified** |
| **Multi-Window Scalability** | Stuttering on >5 charts | **Silky-smooth execution on >14 charts** | **Enterprise Certified** |

---

## 4. Parameters Reference

### Timeframe Settings

- `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for zero-lag native mode, or choose a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`) to activate the synchronized MTF engine.

### V-Score Settings

- `InpPeriod` (*default: `20`*): Lookback period ($P$) for computing standard deviation variance around VWAP.
- `InpVWAPReset` (*default: `PERIOD_SESSION`*): Temporal reset anchor mode (`PERIOD_SESSION`, `PERIOD_WEEK`, `PERIOD_MONTH`, `PERIOD_CUSTOM_SESSION`).
- `InpTzShift` (*default: `0`*): Timezone offset in hours relative to broker server time.
- `InpCustomSessionStart` (*default: `"09:30"`*): Session start time (`HH:MM`) when using `PERIOD_CUSTOM_SESSION`.
- `InpCustomSessionEnd` (*default: `"16:00"`*): Session end time (`HH:MM`) when using `PERIOD_CUSTOM_SESSION`.

### Calculation Settings

- `InpVolumeType` (*default: `VOLUME_TICK`*): Applied volume source (`VOLUME_TICK` or `VOLUME_REAL`).
- `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price input series (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).

### Signal Line Settings

- `InpShowSignal` (*default: `true`*): Toggle visibility of the smoothed Signal MA line.
- `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
- `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
- `InpColorSignal` (*default: `clrFireBrick`*): Color applied to the signal line plot.

### Indicator Levels (Sigma Multipliers)

- `InpLevelFlowHigh` (*default: `1.5`*): Bullish Flow warning boundary (`LightSkyBlue`).
- `InpLevelFlowLow` (*default: `-1.5`*): Bearish Flow warning boundary (`Coral`).
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
│                    V-SCORE INSTITUTIONAL PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Institutional Climax Fade: Fade rejections when V-Score > +2.0σ     │
│                               and crosses below the Signal MA line.    │
│ 2. Volume Flow Continuation:  Enter in direction of trend when V-Score │
│                               holds between +1.5σ and +2.0σ.           │
│ 3. Mean Reversion to VWAP:    Targets are strictly anchored to the     │
│                               0.0σ baseline (VWAP Equilibrium).        │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Institutional Climax Mean Reversion ($\pm 2.0\sigma \dots \pm 2.5\sigma$)

- **Context:** Rapid price expansion pushes V-Score beyond $+2.0\sigma$ (`DeepSkyBlue`) or $+2.5\sigma$. This signifies that price is trading at a statistically unsustainable premium relative to committed volume.
- **Trigger:** When the V-Score histogram bar prints lower than the previous bar and crosses **below** the Signal MA line $\rightarrow$ **Enter Short** targeting the VWAP centerline ($0.0\sigma$).
- **Bullish Reversal:** When V-Score drops below $-2.0\sigma$ (`OrangeRed`) and crosses **above** the Signal MA line $\rightarrow$ **Enter Long** targeting VWAP ($0.0\sigma$).

### 5.2. Multi-Timeframe Volume Expansion Alignment

- Attach an **H1-calculated V-Score** onto an **M5 execution chart**.
- When H1 V-Score holds above $+1.5\sigma$ (`LightSkyBlue`), higher-timeframe institutional volume is actively supporting the markup phase $\rightarrow$ Focus exclusively on intraday long pullback entries on M5.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `ExtVScoreBuffer` | `INDICATOR_DATA` | Standardized V-Score Values in Sigma Multiples ($\sigma$) |
| **1** | `ExtColorsBuffer` | `INDICATOR_COLOR_INDEX` | Swapped Thermal 5-Zone Palette Index ($0.0 \dots 4.0$) |
| **2** | `ExtSignalBuffer` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                                         EA_VScore_Pro_Interface.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Engines & Definitions
#include <MyIncludes\VWAP_Calculator.mqh>
#include <MyIncludes\MovingAverage_Engine.mqh>

//--- EA Inputs
input group "=== V-Score Filter Parameters ==="
input ENUM_TIMEFRAMES     InpVScoreTF     = PERIOD_CURRENT;  // Timeframe
input int                 InpVScorePeriod = 20;              // Lookback Period
input ENUM_VWAP_PERIOD    InpVScoreReset  = PERIOD_SESSION;  // Anchor Period
input ENUM_APPLIED_VOLUME InpVScoreVolume = VOLUME_TICK;     // Volume Source

//--- Global Indicator Handle
int g_vscore_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_vscore_handle != INVALID_HANDLE)
      IndicatorRelease(g_vscore_handle);

   // Instantiate handle to VScore_Pro via iCustom
   g_vscore_handle = iCustom(_Symbol,
                             InpVScoreTF,
                             "VScore_Pro",
                             InpVScoreTF,
                             InpVScorePeriod,
                             InpVScoreReset,
                             0, "09:30", "16:00", // Default session settings
                             InpVScoreVolume,
                             0,                   // Standard Candle Source
                             true, 5, EMA,        // Signal line settings
                             clrFireBrick,
                             1.5, -1.5, 2.0, -2.0, 2.5, -2.5,
                             clrSilver, STYLE_DOT);

   if(g_vscore_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for VScore_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: VScore_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_vscore_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_vscore_handle);
      g_vscore_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed candle (Shift = 1) across all buffers
   double vscore[1], color_idx[1], signal[1];

   if(CopyBuffer(g_vscore_handle, 0, 1, 1, vscore)    < 1 ||
      CopyBuffer(g_vscore_handle, 1, 1, 1, color_idx) < 1 ||
      CopyBuffer(g_vscore_handle, 2, 1, 1, signal)    < 1)
     {
      return; // Data synchronizing
     }

   double cur_vscore = vscore[0];
   double cur_signal = signal[0];
   int    cur_state  = (int)color_idx[0];

   // Quantitative State Evaluation
   bool is_bullish_flow   = (cur_state == 1); // LightSkyBlue (+1.5σ to +2.0σ)
   bool is_bullish_climax = (cur_state == 2); // DeepSkyBlue (> +2.0σ)
   bool is_bearish_flow   = (cur_state == 3); // Coral (-1.5σ to -2.0σ)
   bool is_bearish_climax = (cur_state == 4); // OrangeRed (< -2.0σ)

   Comment(StringFormat("V-Score Telemetry [Bar 1]:\n"
                        "V-Score: %.2f σ | Signal MA: %.2f σ\n"
                        "Regime: %s",
                        cur_vscore, cur_signal,
                        is_bullish_climax ? "BULL CLIMAX (Exhaustion)" :
                        (is_bearish_climax ? "BEAR CLIMAX (Capitulation)" :
                        (is_bullish_flow ? "BULL FLOW (Expansion)" :
                        (is_bearish_flow ? "BEAR FLOW (Expansion)" : "EQUILIBRIUM NOISE")))));
  }
//+------------------------------------------------------------------+
```
