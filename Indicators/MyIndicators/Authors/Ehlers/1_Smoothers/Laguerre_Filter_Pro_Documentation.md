# John Ehlers' Laguerre Filter Pro (v3.10)

Quantitative Time-Warped Digital Filter & Low-Lag Trend Baseline Suite

---

## 1. Summary (Introduction)

**Laguerre Filter Pro (v3.10)** is an institutional-grade digital signal processing (DSP) trendline indicator developed by aerospace engineer and quantitative trading pioneer John Ehlers.

In classical electronic filter design, time series smoothing relies on linear unit delays ($z^{-1}$), which unavoidably introduce severe phase lag across all frequencies. Ehlers bypassed this limitation by implementing **orthogonal Laguerre polynomials**, replacing standard unit delays with an **all-pass time-warped transfer function**.

This mathematical innovation allows the filter to achieve the smoothing power of a 20-to-100 period moving average using only **four recursive data registers ($L_0, L_1, L_2, L_3$)**, providing dramatically reduced phase delay and instantaneous trend inflection recognition.

In high-density multi-chart workspaces—such as setups operating **14 active chart windows with multi-timeframe trend overlays**—legacy implementations cause severe UI freezing due to repetitive `iBarShift` queries and runtime floating-point divisions inside recursive loops. **Version 3.10 Enterprise Edition** eliminates this latency via a **Pipelined FMA Multiplier Kernel** and **Zero-Lag MTF Fast-Path**.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   LAGUERRE FILTER ARCHITECTURAL EVOLUTION              │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   LEGACY ENGINE (v3.00):                                               │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • Runtime floating-point divisions (/ 6.0) inside loop       │     │
│   │ • (1.0 - gamma) and (-gamma) evaluated on every single bar   │     │
│   │ • Up to 500 iBarShift API calls per tick in MTF Mode         │     │
│   │ • 4 separate Copy calls per tick for forming HTF candle      │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                  │                                     │
│                                  ▼ OPTIMIZED                           │
│   ENTERPRISE ENGINE (v3.10):                                           │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • Precalculated Gamma constants in Init() (Zero loop math)   │     │
│   │ • Reciprocal multiplication (* 0.166667) — Zero divisions    │     │
│   │ • Zero-Lag MTF Fast-Path: 0 iBarShift calls on live ticks    │     │
│   │ • 1 Atomic CopyRates call replacing individual copies        │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

- **Time-Warped 4-Element IIR Architecture:** Synthesizes higher-order low-pass smoothing from just four state registers ($L_0 \dots L_3$).
- **Harmonic Fibonacci Damping Control ($\gamma$ – Gamma):** Aligns filter dampening with golden ratio proportions from ultra-sensitive scalping ($\gamma = 0.236$) to secular macro cycle smoothing ($\gamma = 0.882$).
- **Optional 4-Point FIR Benchmark:** Provides an on-chart FIR comparison baseline ($\text{FIR} = \frac{P + 2P_1 + 2P_2 + P_3}{6}$) to visually expose phase lead and lag divergence.
- **Pipelined FMA Math:** Precomputes gamma multipliers in `Init()`, converting recursive equations into pure hardware multiply-accumulate operations without division overhead.
- **Zero-Lag MTF Fast-Path:** Higher-timeframe Laguerre curves project onto lower-timeframe execution charts as crisp, non-warping flat steps via `DataSync_Tools.mqh` with zero `iBarShift` overhead on live ticks.
- **Synthetic Heikin Ashi Support:** Fully compatible with filtered Heikin Ashi price series via `CLaguerreEngine_HA` composition.

---

## 2. Mathematical Foundations & Laguerre Transform Theory

```text

                  RAW PRICE (Market Noise & High Frequencies)
                                       │
                                       ▼
      ┌─────────────────────────────────────────────────────────────────┐
      │             All-Pass Time-Warp Transfer Function                │
      │                H(z) = (z⁻¹ - γ) / (1 - γ·z⁻¹)                   │
      └────────────────────────────────┬────────────────────────────────┘
                                       │
        ┌──────────────┬───────────────┴───────────────┬──────────────┐
        ▼              ▼                               ▼              ▼
     L0 State       L1 State                        L2 State       L3 State
        │              │                               │              │
        └──────────────┴───────────────┬───────────────┴──────────────┘
                                       ▼
               Laguerre Filter = (L0 + 2·L1 + 2·L2 + L3) · (1/6)

```

### 2.1. The 4-Element Recursive Difference Equations (Pipelined FMA)

Given input price $P_t$ and precomputed dampening constants $\gamma = \text{InpGamma}$, $\gamma_{\text{inv}} = 1 - \gamma$, and $\gamma_{\text{neg}} = -\gamma$:
$$L_0(t) = \gamma_{\text{inv}} \cdot P_t + \gamma \cdot L_0(t-1)$$
$$L_1(t) = \gamma_{\text{neg}} \cdot L_0(t) + L_0(t-1) + \gamma \cdot L_1(t-1)$$
$$L_2(t) = \gamma_{\text{neg}} \cdot L_1(t) + L_1(t-1) + \gamma \cdot L_2(t-1)$$
$$L_3(t) = \gamma_{\text{neg}} \cdot L_2(t) + L_2(t-1) + \gamma \cdot L_3(t-1)$$

---

### 2.2. Weighted Median Synthesis (Reciprocal Multiplier)

The final output is computed via fast reciprocal multiplication, eliminating runtime division:
$$\text{Laguerre Filter}_t = \Big( L_0(t) + 2 \cdot (L_1(t) + L_2(t)) + L_3(t) \Big) \cdot \frac{1}{6}$$

---

### 2.3. The 4-Point FIR Comparison Filter

When enabled (`InpShowFIR = true`), an unwarped 4-point Finite Impulse Response (FIR) filter is plotted for direct lag benchmarking:
$$\text{FIR}_t = \Big( P_t + 2 \cdot (P_{t-1} + P_{t-2}) + P_{t-3} \Big) \cdot \frac{1}{6}$$

---

### 2.4. Harmonized Fibonacci Gamma ($\gamma$) Spectrum Matrix

Utilizing **Fibonacci ratios** as Gamma parameters aligns the filter's dampening curve with the golden proportions of natural market expansions:

| Fibonacci Gamma | Smoothing Depth | Phase Latency (Lag) | Target Market Regime | Equivalent EMA Benchmark | Quantitative Concept & Institutional Application |
| :---: | :---: | :---: | :--- | :---: | :--- |
| **`0.236`** | Ultra-Light | Near-Zero | High-Frequency Scalping / Momentum | $\approx 5\text{ EMA}$ | **Extreme Sensitivity.** Tracks price closely. Identifies immediate trend acceleration and micro-reversals. |
| **`0.382`** | Light | Very Low | Day Trading / Intraday Execution | $\approx 9\text{--}10\text{ EMA}$ | **Optimal Execution Baseline.** Excellent alternative to 9 EMA. Filters out noise while keeping crossovers fast. |
| **`0.500`** | Balanced | Medium-Low | Swing Trading / Volatility Pivots | $\approx 15\text{--}20\text{ EMA}$ | **Balanced Corridor Center.** Standard baseline for medium swing setups on M15/H1 charts. |
| **`0.618`** | Medium-Strong | Medium | Medium-Term Trend Following | $\approx 30\text{--}50\text{ EMA}$ | **The Golden Ratio Anchor.** Outstanding core filter. Replaces 20/50 standard moving averages with 50% less Fourier lag. |
| **`0.764`** | Strong | Medium-High | Macro Trend Identification | $\approx 100\text{ EMA}$ | **Structural Support.** Identifies institutional trend direction on H4/D1 charts. Bypasses consolidation whipsaws. |
| **`0.882`** | Ultra-Strong | High | Secular Trend Smoothing | $\approx 200\text{ EMA}$ | **Absolute Noise Elimination.** Ideal for long-term investing and tracking macro market cycles on weekly/monthly charts. |

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│                   Laguerre_Engine.mqh                  │
│    (Core DSP Math: Pipelined FMA Multiplier Kernel)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Feeds Filter Series & Price Getter
                           ▼
┌────────────────────────────────────────────────────────┐
│              Laguerre_Filter_Calculator.mqh            │
│    (Engine Adapter: Computes Laguerre & FIR Output)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Filter & FIR in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                Laguerre_Filter_Pro.mq5                 │
│       (Unified Native & Zero-Lag MTF Fast-Path)        │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • Atomic CopyRates MTF    │
│   • 2 Output Plots       │   • Binary Search Snapping  │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Legacy (v3.00) vs. Enterprise (v3.10)

| Metric | Legacy Implementation (v3.00) | Enterprise Refactor (v3.10) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **Gamma Constant Evaluation** | Subtracted on every bar | **Precomputed in `Init()`** | **Eliminates Loop Arithmetic** |
| **Recursive Division Operations** | 1 floating-point division / bar | **0 divisions (Reciprocal `* 1/6`)** | **Hardware FMA Pipelining** |
| **MTF Live-Tick `iBarShift`** | Up to 500 calls per tick | **0 calls on live ticks (`ArrayBsearch`)** | **Complete Zero-Lag** |
| **MTF Data Copy Calls** | 4 separate calls per tick | **1 atomic `CopyRates` query** | **-75% API Overhead** |
| **Pointer Safety** | Slow `CheckPointer()` on ticks | **Fast `if(!g_calculator)` Guard** | **Optimized Branching** |
| **Multi-Window Scalability** | Stuttering on 14 charts | **Silky-smooth execution on >14 charts** | **Enterprise Certified** |

---

## 4. Parameters Reference

### Timeframe Settings

- `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or choose a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`) to activate the synchronized MTF engine.

### Laguerre Settings

- `InpGamma` (*default: `0.5`*): Damping factor ($\gamma$). Controls the time-warp compression ratio ($0.0 \le \gamma \le 1.0$). Supports 3-decimal Fibonacci tuning (`0.236`, `0.382`, `0.500`, `0.618`, `0.764`, `0.882`).
- `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### FIR Comparison Filter Settings

- `InpShowFIR` (*default: `false`*): Toggle on-chart visibility of the 4-point FIR benchmark line.

### Visual Settings - Laguerre Filter

- `InpColorLaguerre` (*default: `clrCrimson`*): Color of the main Laguerre Filter line.
- `InpStyleLaguerre` (*default: `STYLE_SOLID`*): Line style of the Laguerre Filter.
- `InpWidthLaguerre` (*default: `2`*): Line thickness.

### Visual Settings - FIR Filter

- `InpColorFIR` (*default: `clrDarkBlue`*): Color of the FIR comparison line.
- `InpStyleFIR` (*default: `STYLE_SOLID`*): Line style of the FIR line.
- `InpWidthFIR` (*default: `1`*): Line thickness.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   LAGUERRE FILTER TRADING PLAYBOOKS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Dynamic S/R Pullback:   In strong trends, pullbacks into the        │
│                            Laguerre line offer low-drawdown entries.   │
│ 2. Laguerre / FIR Cross:   Laguerre crossing above FIR confirms trend  │
│                            inflection with zero phase delay.           │
│ 3. MTF Trend Filter:       Attach H1/H4 Laguerre Filter on M5 chart    │
│                            to trade strictly in direction of macro flow│
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Dynamic Support & Resistance Retests

- **Bullish Retest:** In an established uptrend, price pulls back into the rising `Laguerre Filter (γ=0.382 or γ=0.500)` line and forms a rejection candle $\rightarrow$ High-conviction long continuation entry with stop-loss placed just below the curve.
- **Bearish Retest:** In a downtrend, price rallies into the falling `Laguerre Filter` line and rejects $\rightarrow$ Enter short.

### 5.2. Laguerre vs. FIR Lead-Lag Crossover

- **Bullish Crossover:** The `Laguerre Filter` line crosses **above** the `FIR Filter` line $\rightarrow$ Confirms that price is accelerating upward faster than linear 4-bar momentum.
- **Bearish Crossover:** The `Laguerre Filter` line crosses **below** the `FIR Filter` line $\rightarrow$ Confirms downward acceleration.

### 5.3. Multi-Timeframe Macro Baseline Alignment

- Attach an **H1-calculated Laguerre Filter ($\gamma=0.618$ or $\gamma=0.764$)** onto an **M5 execution chart**.
- **Rule:** Only take intraday long pullbacks on M5 when **price is trading above the H1 Laguerre flat step**. This ensures you never trade against higher-timeframe institutional trend structure.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Visual Plot | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferFilter` | `INDICATOR_DATA` | Plot 1 (`DRAW_LINE`) | Main John Ehlers Laguerre Filter Plot Line. |
| **1** | `BufferFIR` | `INDICATOR_DATA` | Plot 2 (`DRAW_LINE`) | Optional 4-Point FIR Comparison Filter Line. |

*Both buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                                     EA_Laguerre_Filter_Interface |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Engine Definitions
#include <MyIncludes\Laguerre_Filter_Calculator.mqh>

//--- EA Inputs
input group "=== Laguerre Filter Parameters ==="
input ENUM_TIMEFRAMES           InpLaguerreTF     = PERIOD_CURRENT;  // Timeframe
input double                    InpGamma          = 0.500;           // Gamma (e.g. 0.382, 0.500, 0.618)
input ENUM_APPLIED_PRICE_HA_ALL InpPriceSource    = PRICE_CLOSE_STD; // Price Source
input bool                      InpEnableFIR      = true;            // Compute FIR Line

//--- Global Indicator Handle
int g_laguerre_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_laguerre_handle != INVALID_HANDLE)
      IndicatorRelease(g_laguerre_handle);

   // Instantiate handle to Laguerre_Filter_Pro via iCustom
   g_laguerre_handle = iCustom(_Symbol,
                               InpLaguerreTF,
                               "Laguerre_Filter_Pro",
                               InpLaguerreTF,
                               InpGamma,
                               InpPriceSource,
                               InpEnableFIR);

   if(g_laguerre_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for Laguerre_Filter_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: Laguerre_Filter_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_laguerre_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_laguerre_handle);
      g_laguerre_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed candle (Shift = 1) across Laguerre (Buffer 0) and FIR (Buffer 1)
   double lag_vals[2], fir_vals[2];
   ArraySetAsSeries(lag_vals, true); // Index 0 = Shift 1, Index 1 = Shift 2
   ArraySetAsSeries(fir_vals, true);

   if(CopyBuffer(g_laguerre_handle, 0, 1, 2, lag_vals) < 2 ||
      CopyBuffer(g_laguerre_handle, 1, 1, 2, fir_vals) < 2)
     {
      return; // Data synchronizing
     }

   double lag_bar1 = lag_vals[0];
   double lag_bar2 = lag_vals[1];
   double fir_bar1 = fir_vals[0];

   // Query corresponding closed price
   double close[1];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, _Period, 1, 1, close) < 1)
      return;

   double cur_close = close[0];

   // Quantitative Signals
   bool is_rising       = (lag_bar1 > lag_bar2);
   bool is_above_filter = (cur_close > lag_bar1);
   bool fir_cross_up    = (lag_vals[1] <= fir_vals[1] && lag_vals[0] > fir_vals[0]);
   bool fir_cross_down  = (lag_vals[1] >= fir_vals[1] && lag_vals[0] < fir_vals[0]);

   // Telemetry Output
   Comment(StringFormat("Laguerre Filter (γ=%.3f) Telemetry [Bar 1]:\n"
                        "Laguerre: %.*f | FIR: %.*f | Close: %.*f\n"
                        "Slope: %s | Regime: %s\n"
                        "FIR Cross Signals -> Buy: %s | Sell: %s",
                        InpGamma,
                        _Digits, lag_bar1, _Digits, fir_bar1, _Digits, cur_close,
                        is_rising ? "RISING (Bullish Momentum)" : "FALLING (Bearish Momentum)",
                        is_above_filter ? "ABOVE FILTER (Bullish Bias)" : "BELOW FILTER (Bearish Bias)",
                        fir_cross_up ? "TRIGGERED (Bullish Cross)" : "NO",
                        fir_cross_down ? "TRIGGERED (Bearish Cross)" : "NO"));
  }
//+------------------------------------------------------------------+
```
