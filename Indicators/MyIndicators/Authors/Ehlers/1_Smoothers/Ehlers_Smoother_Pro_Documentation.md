# Ehlers Smoother Pro (v3.10)

Quantitative Digital Signal Processing (DSP) Smoothing & Low-Lag Filter Suite

---

## 1. Summary (Introduction)

**Ehlers Smoother Pro (v3.10)** is an institutional-grade trend and smoothing engine implementing two of John Ehlers' most renowned Digital Signal Processing (DSP) algorithms: the **SuperSmoother** and the **UltimateSmoother**.

Traditional moving averages (such as SMA, EMA, or SMMA) suffer from an unavoidable mathematical trade-off: increasing smoothing to eliminate market noise introduces severe phase lag, while shortening lookback periods to reduce lag creates errant false breakout whipsaws. John Ehlers resolved this dilemma by applying electronic communication filter theory to financial price series, modeling price action through critically damped **Infinite Impulse Response (IIR)** low-pass transfer functions.

In high-density multi-chart workspaces—such as layouts utilizing **14 open charts with dual smoothers per chart (e.g., SuperSmoother 13 and 21 simultaneously = 28 active instances)**—standard DSP indicators cause severe CPU throttling by re-evaluating complex trigonometric functions on every incoming tick.

**Version 3.10 Enterprise Edition** eliminates this bottleneck entirely via **Precomputed Filter Coefficients** and a **Zero-Lag MTF Fast-Path**, delivering pure hardware-pipelined performance with zero UI latency.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   EHLERS SMOOTHER ARCHITECTURAL EVOLUTION              │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   LEGACY ENGINE (v3.00):                                               │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • MathExp() and MathCos() recalculated ON EVERY SINGLE TICK  │     │
│   │ • Runtime floating-point divisions inside recursive loops   │     │
│   │ • Up to 500 iBarShift API calls per tick in MTF Mode         │     │
│   │ • Dynamic heap allocations (new/delete) in OnInit            │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                  │                                     │
│                                  ▼ OPTIMIZED                           │
│   ENTERPRISE ENGINE (v3.10):                                           │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ • DSP Coefficients precomputed ONCE in Init() (0 MathExp/tick│     │
│   │ • Hardware-pipelined FMA (Fused-Multiply-Add) loop math      │     │
│   │ • Zero iBarShift calls on live MTF ticks (ArrayBsearch Path) │     │
│   │ • Static BSS Global Instantiation (Zero Heap Allocation)     │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

- **2-in-1 Adaptive Engine:** Instantly toggle between maximum noise attenuation (`SUPERSMOOTHER`) and ultra-responsive low-lag tracking (`ULTIMATESMOOTHER`).
- **Precomputed Analytical Tuning:** Filter damping factors are solved analytically in `Init()`, completely eliminating runtime transcendental function calls (`MathExp`, `MathCos`).
- **Hardware-Pipelined Math:** Difference equations are factorized into pure multiplication kernels, allowing CPU scalar execution without division pipeline stalls.
- **Zero-Lag MTF Fast-Path:** Higher-timeframe curves project onto lower-timeframe execution charts with non-warping flat steps via `DataSync_Tools.mqh`, bypassing `iBarShift` on live ticks.
- **Synthetic Heikin Ashi Support:** Fully compatible with filtered Heikin Ashi price sources via `CHeikinAshi_Calculator` composition.

---

## 2. Mathematical Foundations & DSP Filter Theory

```text

                  RAW PRICE (Market Noise & Aliasing)
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │         2-Pole Butterworth Transfer Function           │
      │    Cutoff Frequency: ω_c = (√2 · π) / Period           │
      └───────────────────────────┬────────────────────────────┘
                                  │
                  Filtered Low-Frequency Trendline

```

### 2.1. Analytical DSP Filter Coefficients (Precomputed in `Init`)

For a selected cutoff period $P = \text{InpPeriod}$, the damping factors are calculated **strictly once during initialization**:
$$\omega_c = \frac{\sqrt{2} \cdot \pi}{P}$$
$$a_1 = \exp(-\omega_c), \quad b_1 = 2 \cdot a_1 \cdot \cos(\omega_c)$$
$$c_2 = b_1, \quad c_3 = -a_1^2$$

---

### 2.2. Filter Difference Equations (Pipelined Multiplication)

#### 1. The SuperSmoother Filter (2-Pole Critical Damping)

The SuperSmoother is a second-order Butterworth low-pass filter engineered to suppress high-frequency market noise while strictly preventing transient overshoot.

Precomputed multiplier:
$$c_1 = 1 - c_2 - c_3, \quad C_{1\text{half}} = c_1 \cdot 0.5$$

Recursive difference equation (evaluated in $O(1)$ on live ticks):
$$\text{Filt}_t = C_{1\text{half}} \cdot (P_t + P_{t-1}) + c_2 \cdot \text{Filt}_{t-1} + c_3 \cdot \text{Filt}_{t-2}$$

#### 2. The UltimateSmoother Filter (Zero-Phase High-Pass Subtraction)

The UltimateSmoother is derived by mathematically subtracting the high-pass filter response from the raw price series, achieving near-zero phase lag in the dominant trend component.

Precomputed multipliers:
$$c_1 = (1 + c_2 - c_3) \cdot 0.25$$
$$u_0 = 1 - c_1, \quad u_1 = 2c_1 - c_2, \quad u_2 = -(c_1 + c_3)$$

Recursive difference equation (pure multiply-accumulate):
$$\text{Filt}_t = u_0 \cdot P_t + u_1 \cdot P_{t-1} + u_2 \cdot P_{t-2} + c_2 \cdot \text{Filt}_{t-1} + c_3 \cdot \text{Filt}_{t-2}$$

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│              Ehlers_Smoother_Calculator.mqh            │
│  (Precomputed DSP Filter Kernel: Static BSS Allocation)│
└──────────────────────────┬─────────────────────────────┘
                           │ Computes Filter Values in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                 Ehlers_Smoother_Pro.mq5                │
│       (Unified Native & Zero-Lag MTF Fast-Path)        │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • Atomic CopyRates        │
│   • Zero-Overhead Bypass │   • Binary Search Snapping  │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Legacy (v3.00) vs. Enterprise (v3.10)

| Metric | Legacy Implementation (v3.00) | Enterprise Refactor (v3.10) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **Transcendental Calls per Tick** | 2 calls (`MathExp`, `MathCos`) / tick | **0 calls on live ticks (Precomputed)** | **-100% Math Overhead** |
| **Recursive Division Operations** | 1–2 floating-point divisions / bar | **0 divisions (Pipelined Multipliers)** | **Hardware SIMD Acceleration** |
| **MTF Live-Tick `iBarShift`** | Up to 500 calls in `while` & `for` loops | **0 calls on live ticks (`ArrayBsearch`)** | **Zero UI Thread Lock** |
| **MTF Data Copy Calls** | 4 separate calls (`CopyOpen`, `CopyHigh`..) | **1 atomic `CopyRates` query** | **-75% API Overhead** |
| **Memory Allocation** | Dynamic `new CEhlersSmootherCalculator` | **Static BSS Global Object** | **Zero Heap Fragmentation** |
| **Multi-Window Scalability** | Noticeable stuttering on 14 charts | **Silky-smooth execution on >14 charts** | **Enterprise Certified** |

---

## 4. Parameters Reference

### Timeframe Settings

- `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or choose a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_H4`) to enable the synchronized MTF engine.

### Smoother Settings

- `InpSmootherType` (*default: `SUPERSMOOTHER`*): Filter model selection:
  - `SUPERSMOOTHER`: 2-pole Butterworth critical damping (Optimal for noise suppression and EMA replacement).
  - `ULTIMATESMOOTHER`: High-pass subtraction response (Optimal for fast pullbacks and dynamic S/R).
- `InpPeriod` (*default: `20`*): The critical cutoff period ($P$). Shorter periods increase responsiveness; longer periods provide smoother macroeconomic filtering.
- `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price series source. Supports all 7 Standard and 7 Heikin Ashi price modes (`PRICE_HA_CLOSE`, `PRICE_HA_TYPICAL`, etc.).

### Visual Settings

- `InpColorFilter` (*default: `clrBlueViolet`*): Color of the indicator line plot.
- `InpStyleFilter` (*default: `STYLE_SOLID`*): Plot line style (Solid, Dash, Dot).
- `InpWidthFilter` (*default: `2`*): Visual line width.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   EHLERS SMOOTHER QUANTITATIVE PLAYBOOKS               │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Dual-Smoother (13 vs 21) Cross: Trade directional momentum expansion│
│                                     when fast 13 crosses slow 21.      │
│ 2. SuperSmoother Trend Baseline:   Use as a zero-overshoot replacement │
│                                     for traditional 20/50/200 EMAs.    │
│ 3. UltimateSmoother Dynamic S/R:    Fade rapid pullbacks into the line │
│                                     during established trend regimes.  │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Dual-Smoother Momentum Alignment (13 vs. 21 Strategy)

- **Workspace Setup:** Attach two instances of `Ehlers_Smoother_Pro` onto the chart:
  - **Fast Filter:** `InpPeriod = 13` (e.g., `clrDeepSkyBlue`, Width 2)
  - **Slow Filter:** `InpPeriod = 21` (e.g., `clrBlueViolet`, Width 2)
- **Execution Rules:**
  - **Bullish Regime:** When the 13 SuperSmoother crosses strictly above the 21 SuperSmoother and price action holds above both curves $\rightarrow$ Enter/maintain **Long exposure**.
  - **Bearish Regime:** When the 13 SuperSmoother crosses below the 21 SuperSmoother and price action trades below both lines $\rightarrow$ Enter/maintain **Short exposure**.
  - **Compression Filter:** When the 13 and 21 curves intertwine horizontally, market is in choppy consolidation $\rightarrow$ Invalidate breakout signals.

### 5.2. SuperSmoother: Macro Noise-Free Trend Baseline

- **Best Applied For:** Swing trading, macro trend filtering, and replacement for traditional 20/50/200 EMAs.
- **Quantitative Edge:** Unlike standard EMAs, which allow high-frequency aliasing to pass through, SuperSmoother features a brick-wall frequency cutoff that prevents noise from penetrating the curve without introducing phase lag.

### 5.3. Multi-Timeframe Alignment (H1 SuperSmoother on M5 Execution)

- Load `Ehlers_Smoother_Pro` with `InpTimeframe = PERIOD_H1` and `InpPeriod = 20` onto an **M5 execution chart**.
- The non-warping staircase steps reflect the hourly institutional consensus:
  - When M5 price is above the H1 step: Focus exclusively on **Long pullbacks**.
  - When M5 price is below the H1 step: Focus exclusively on **Short breakdowns**.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufferFilter` | `INDICATOR_DATA` | Smoothed Filter Stream (SuperSmoother / UltimateSmoother). |

*All buffers maintain strict chronological indexing (`ArraySetAsSeries = false`), ensuring instant compatibility with automated Expert Advisors via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                                  EA_Ehlers_Smoother_Interface.mq5|
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Calculator Definitions
#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//--- EA Inputs
input group "=== Ehlers Smoother Parameters ==="
input ENUM_TIMEFRAMES           InpFilterTF     = PERIOD_CURRENT;  // Timeframe
input ENUM_SMOOTHER_TYPE        InpFilterType   = SUPERSMOOTHER;   // Smoother Type
input int                       InpFilterPeriod = 20;              // Smoothing Period
input ENUM_APPLIED_PRICE_HA_ALL InpPriceSource  = PRICE_CLOSE_STD; // Price Source

//--- Global Indicator Handle
int g_filter_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_filter_handle != INVALID_HANDLE)
      IndicatorRelease(g_filter_handle);

   // Instantiate handle to Ehlers_Smoother_Pro via iCustom
   g_filter_handle = iCustom(_Symbol,
                             InpFilterTF,
                             "Ehlers_Smoother_Pro",
                             InpFilterTF,
                             InpFilterType,
                             InpFilterPeriod,
                             InpPriceSource);

   if(g_filter_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for Ehlers_Smoother_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: Ehlers_Smoother_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_filter_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_filter_handle);
      g_filter_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed bar (Shift = 1) and previous bar (Shift = 2) for slope direction
   double filter_vals[2];
   ArraySetAsSeries(filter_vals, true); // Index 0 = Shift 1, Index 1 = Shift 2

   if(CopyBuffer(g_filter_handle, 0, 1, 2, filter_vals) < 2)
      return; // Data synchronizing

   double filter_bar1 = filter_vals[0];
   double filter_bar2 = filter_vals[1];

   // Query corresponding Close price
   double close_prices[1];
   ArraySetAsSeries(close_prices, true);
   if(CopyClose(_Symbol, _Period, 1, 1, close_prices) < 1)
      return;

   double close_bar1 = close_prices[0];

   // Quantitative Filter Analysis
   bool is_rising      = (filter_bar1 > filter_bar2);
   bool is_falling     = (filter_bar1 < filter_bar2);
   bool is_above_curve = (close_bar1 > filter_bar1);
   bool is_below_curve = (close_bar1 < filter_bar1);

   // Telemetry Output
   Comment(StringFormat("Ehlers Smoother (%d) Telemetry:\n"
                        "Smoother: %.*f | Close: %.*f\n"
                        "Slope: %s | Position: %s",
                        InpFilterPeriod,
                        _Digits, filter_bar1,
                        _Digits, close_bar1,
                        is_rising ? "RISING (Bullish Momentum)" : (is_falling ? "FALLING (Bearish Momentum)" : "FLAT"),
                        is_above_curve ? "ABOVE (Bullish Bias)" : (is_below_curve ? "BELOW (Bearish Bias)" : "AT EQUILIBRIUM")));
  }
//+------------------------------------------------------------------+
```
