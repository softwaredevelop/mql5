# Ehlers Adaptive Smoother Pro (v1.00)

Quantitative Digital Signal Processing (DSP) Filter with Dynamic Cutoff Period Adaptation

---

## 1. Summary (Introduction)

**Ehlers Adaptive Smoother Pro (v1.00)** is an institutional-grade digital signal processing (DSP) trendline and smoothing engine that expands John Ehlers' critically damped **SuperSmoother** and **UltimateSmoother** filters with real-time **Adaptive Cutoff Period Scaling**.

While traditional electronic IIR filters in financial engineering operate with a fixed cutoff period ($P$), traders are constantly trapped in an operational dilemma: shorter static periods track breakout expansions closely but generate whipsaws in choppy markets, while longer static periods provide pristine noise elimination at the cost of severe phase delay during trend reversals.

**Ehlers Adaptive Smoother Pro resolves this trade-off dynamically:**
Rather than enforcing a static cutoff frequency, the indicator dynamically scales the filter's cutoff period on every single bar within user-defined boundaries ($P_t \in [P_{\text{min}}, P_{\text{max}}]$) based on real-time market kinematics:

* **High Efficiency / Trend Drive ($\text{Metric} \to 1.0$):** The cutoff period automatically drops to $P_{\text{min}}$ (e.g., $13$). The filter expands its passband, instantly hugging price action and capturing sharp trend runs with near-zero lag.
* **Low Efficiency / Range Chop ($\text{Metric} \to 0.0$):** The cutoff period automatically increases to $P_{\text{max}}$ (e.g., $34$). The passband contracts, suppressing high-frequency noise and freezing the curve into a **rigid horizontal support/resistance shelf**.

```text

┌────────────────────────────────────────────────────────────────────────┐
│             ADAPTIVE EHLERS SMOOTHER KINEMATIC REGIMES                 │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   CONSOLIDATION CHOP (ER → 0.0, Period → P_max = 34):                  │
│   Price  ──▶  Choppy oscillation, erratic false wicks.                 │
│   Filter ──▶  Flattens into a horizontal brick-wall support shelf.     │
│                                                                        │
│   WATERFALL BREAKOUT (ER → 1.0, Period → P_min = 13):                  │
│   Price  ──▶  Aggressive straight-line directional expansion.          │
│   Filter ──▶  Immediately accelerates downward, hugging price bars     │
│               ahead of traditional static moving averages.             │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **Dynamic 2-Pole Butterworth Architecture:** Modulates cutoff angular frequency ($\omega_{0, t}$) continuously on every bar while preserving critical damping and zero-overshoot characteristics.
* **Tri-Mode Adaptive Engine:** Select between Kaufman's **Efficiency Ratio (ER)**, **Average True Range (ATR)**, and **Standard Deviation (StDev)** pathways.
* **Guaranteed BIBO Stability:** Mathematical poles are constrained strictly inside the complex unit circle ($|z| < 1.0$) for any $P_t \ge 2$, guaranteeing zero risk of numerical divergence.
* **Zero-Lag MTF Fast-Path:** Higher-timeframe curves project onto lower-timeframe execution charts as crisp, non-warping flat steps via `DataSync_Tools.mqh` with zero `iBarShift` overhead on live ticks.
* **Synthetic Heikin Ashi Routing:** Fully compatible with filtered Heikin Ashi price series via `CHeikinAshi_Calculator` composition.

---

## 2. Mathematical Foundations & Dynamic Pole Modulation

```text

              RAW PRICE (Market Noise & Trend Vectors)
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │         Adaptive Pathway Normalization Engine          │
      │   Calculates Metric(t) ∈ [0.0, 1.0] (ER, ATR, or StDev)│
      └───────────────────────────┬────────────────────────────┘
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │             Dynamic Period Transfer Function           │
      │        P(t) = P_max - Metric(t) · (P_max - P_min)      │
      └───────────────────────────┬────────────────────────────┘
                                  │
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │     2-Pole Critically Damped Butterworth Filter        │
      │          ω_0(t) = (√2 · π) / P(t)                      │
      │          a_1(t) = exp( -ω_0(t) )                       │
      │          b_1(t) = 2 · a_1(t) · cos( ω_0(t) )           │
      └───────────────────────────┬────────────────────────────┘
                                  │
                  Adaptive Filter Line Output

```

### 2.1. Dynamic Cutoff Period Transfer Function

Given maximum lookback $P_{\text{max}} = \text{InpPeriodMax}$, minimum lookback $P_{\text{min}} = \text{InpPeriodMin}$, and precomputed range $\Delta P = P_{\text{max}} - P_{\text{min}}$:
$$P_t = \text{Clamp}\Big( P_{\text{max}} - (\text{Metric}_t \cdot \Delta P), \; P_{\text{min}}, \; P_{\text{max}} \Big)$$

* **When Market is in Chop ($\text{Metric}_t = 0.0$):** $P_t = P_{\text{max}}$ (Maximum smoothing, slowest response).
* **When Market is in Trend ($\text{Metric}_t = 1.0$):** $P_t = P_{\text{min}}$ (Minimum smoothing, fastest response).

---

### 2.2. The Three Adaptive Metric Pathways

#### Pathway A: Kaufman's Efficiency Ratio (`METHOD_EFFICIENCY_RATIO`)

Measures the ratio of net linear directional displacement to total cumulative distance traveled over period $P_{\text{adapt}} = \text{InpAdaptivePeriod}$:
$$\text{Direction}_t = |P_t - P_{t - P_{\text{adapt}}}|$$
$$\text{Volatility}_t = \sum_{k=0}^{P_{\text{adapt}} - 1} |P_{t-k} - P_{t-k-1}|$$
$$\text{Metric}_t = \begin{cases} \frac{\text{Direction}_t}{\text{Volatility}_t}, & \text{if } \text{Volatility}_t > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

#### Pathway B: Normalized ATR Volatility (`METHOD_ATR`)

Computes Wilder's ATR across period $P_{\text{adapt}}$, then maps the raw points into $[0.0, 1.0]$ via a sliding Min-Max normalizer:
$$\text{Metric}_t = \text{Normalize}(\text{ATR}_t, P_{\text{adapt}})$$

#### Pathway C: Accelerated Standard Deviation (`METHOD_STAND_DEV`)

Computes price dispersion around the arithmetic mean using single-cycle scalar squaring (zero `pow()` calls):
$$\mu_t = \frac{1}{P_{\text{adapt}}} \sum_{j=0}^{P_{\text{adapt}} - 1} P_{t-j}$$
$$\text{StDev}_t = \sqrt{\frac{1}{P_{\text{adapt}}} \sum_{j=0}^{P_{\text{adapt}} - 1} (P_{t-j} - \mu_t)^2}$$
$$\text{Metric}_t = \text{Normalize}(\text{StDev}_t, P_{\text{adapt}})$$

---

### 2.3. Mathematical Proof of BIBO Stability

In discrete filter theory, changing recursive coefficients dynamically can introduce instability if poles migrate outside the complex unit circle.

* The discrete Butterworth poles are located at radius:
  $$|z_p| = a_1(t) = \exp\left( -\frac{\sqrt{2} \cdot \pi}{P_t} \right)$$
* For all allowed parameters, the engine strictly enforces $P_t \ge 2.0$:
  $$P_t \ge 2.0 \implies \frac{\sqrt{2} \cdot \pi}{P_t} > 0 \implies 0 < a_1(t) < 1.0$$
* Because $|z_p| < 1.0$ is strictly guaranteed for every bar $t$, the filter is **provably Bounded-Input Bounded-Output (BIBO) stable** across all dynamic transitions.

---

### 2.4. Filter Difference Equations

Given dynamic angular frequency $\omega_{0, t} = \frac{\sqrt{2} \cdot \pi}{P_t}$:
$$a_1 = \exp(-\omega_{0, t}), \quad b_1 = 2 \cdot a_1 \cdot \cos(\omega_{0, t})$$
$$c_2 = b_1, \quad c_3 = -a_1^2$$

#### Model 1: SuperSmoother (2-Pole Critically Damped Butterworth)

$$c_1 = (1.0 - c_2 - c_3) \cdot 0.5$$
$$\text{Filt}_t = c_1 \cdot (P_t + P_{t-1}) + c_2 \cdot \text{Filt}_{t-1} + c_3 \cdot \text{Filt}_{t-2}$$

#### Model 2: UltimateSmoother (Zero-Phase High-Pass Subtraction)

$$c_1 = (1.0 + c_2 - c_3) \cdot 0.25$$
$$u_0 = 1.0 - c_1, \quad u_1 = 2c_1 - c_2, \quad u_2 = -(c_1 + c_3)$$
$$\text{Filt}_t = u_0 \cdot P_t + u_1 \cdot P_{t-1} + u_2 \cdot P_{t-2} + c_2 \cdot \text{Filt}_{t-1} + c_3 \cdot \text{Filt}_{t-2}$$

---

## 3. MQL5 Architecture & Computational Standards

```text

┌────────────────────────────────────────────────────────┐
│         Ehlers_Adaptive_Smoother_Calculator.mqh        │
│   (Instance-Isolated Member Buffers: Zero Static!)     │
└──────────────────────────┬─────────────────────────────┘
                           │ Delivers Adaptive Filter in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│             Ehlers_Adaptive_Smoother_Pro.mq5           │
│       (Unified Native & Zero-Lag MTF Fast-Path)        │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • Atomic CopyRates MTF    │
│   • Single Buffer Stream │   • Binary Search Snapping  │
└──────────────────────────┴─────────────────────────────┘

```

### Engineering Benchmark: Static Ehlers vs. Adaptive Ehlers

| Metric | Classic Static Ehlers (v3.00) | Enterprise Adaptive Ehlers (v1.00) | Quantitative Advantage |
| :--- | :---: | :---: | :--- |
| **Passband Cutoff** | Rigid fixed period (e.g., $P=34$) | **Self-tuning ($P_t \in [13, 34]$)** | **Optimal time-varying frequency** |
| **Consolidation State** | Gentle curve (can whipsaw) | **Horizontal rigid shelf ($\text{ER} \to 0$)** | **Eliminates chop false breaks** |
| **Waterfall Crash Lag** | Significant lag behind bars | **Instant acceleration downward** | **Immediate trend capture** |
| **V-Reversal Pivot** | Lags pivot by 3–5 bars | **Snaps to pivot within 1 bar** | **Near-zero phase reversal detection** |
| **MTF Performance** | Legacy `iBarShift` loop | **Zero-Lag MTF Fast-Path** | **Complete zero-stutter execution** |

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or choose a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_H4`) to activate the synchronized MTF engine.

### Smoother Model Settings

* `InpSmootherType` (*default: `SUPERSMOOTHER`*): Filter model selection (`SUPERSMOOTHER` for 2-pole Butterworth critical damping; `ULTIMATESMOOTHER` for zero-phase high-pass subtraction).
* `InpAdaptiveMethod` (*default: `METHOD_EFFICIENCY_RATIO`*): Market kinematics engine (`METHOD_EFFICIENCY_RATIO`, `METHOD_ATR`, `METHOD_STAND_DEV`).
* `InpAdaptivePeriod` (*default: `10`*): Lookback period for calculating the adaptive metric.
* `InpPeriodMin` (*default: `5`*): Minimum cutoff period applied during peak trend efficiency/volatility (fastest reaction, minimal lag).
* `InpPeriodMax` (*default: `30`*): Maximum cutoff period applied during consolidation/noise (maximum smoothing, horizontal shelf).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Visual Settings

* `InpColorFilter` (*default: `clrBlueViolet`*): Color of the indicator line plot.
* `InpStyleFilter` (*default: `STYLE_SOLID`*): Plot line style (Solid, Dash, Dot).
* `InpWidthFilter` (*default: `2`*): Visual line width.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│              ADAPTIVE EHLERS SMOOTHER QUANTITATIVE PLAYBOOKS           │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Adaptive-vs-Static Cross:   Trade directional momentum expansion    │
│                                when Adaptive (13-34) crosses Static 34.│
│ 2. Horizontal Shelf Breakout:  Enter breakouts when price expands away │
│                                from a flattened consolidation shelf.   │
│ 3. V-Reversal Bottom Snapping: Catch capitulation bottoms as the curve │
│                                snaps into inflection within 1 bar.     │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Adaptive-vs-Static Lead-Lag Cross Strategy (The Dual-Speed Edge)

* **Workspace Setup:**
  * **Fast Adaptive Line (Green):** `Ehlers_Adaptive_Smoother_Pro` (`P_min = 13, P_max = 34`, `clrMediumSeaGreen`, Width 2).
  * **Slow Static Line (Orange):** `Ehlers_Smoother_Pro` (`Period = 34`, `clrDarkOrange`, Width 1).
* **Execution Rules:**
  * **Bullish Markup Trigger:** The green Adaptive curve snaps upward and crosses strictly **above the orange Static 34 curve** $\rightarrow$ **Enter Long**. The adaptive curve leads price by multiple bars during acceleration.
  * **Bearish Markdown Trigger:** The green Adaptive curve plunges strictly **below the orange Static 34 curve** $\rightarrow$ **Enter Short**.

### 5.2. Horizontal Shelf Breakout Drive

* **Premise:** During quiet consolidation, $\text{ER} \to 0.0$ forces $P_t \to P_{\text{max}} = 34$. The Adaptive Smoother freezes into a completely horizontal shelf (Slope $\approx 0$).
* **Execution Rules:**
  * Wait for price to coil tightly around the horizontal shelf.
  * An expansion candle closes cleanly outside the shelf, causing the curve to unfreeze and bend sharply in the direction of the break $\rightarrow$ **Enter in direction of break**. Stop-loss placed just behind the flat shelf.

### 5.3. V-Reversal Bottom Snapping (Capitulation Pivot)

* **Premise:** During panic selling waterfalls, the adaptive line stays tightly pinned to the falling bars.
* **Execution:**
  * When price prints an extreme capitulation wick and immediately rebounds, the adaptive curve curves upward **within 1 single candle**, while static averages are still pointing steeply down.
  * **Trade:** High-R/R reversal long entry upon the first bar that bends the adaptive curve upward.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Visual Plot | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferFilter` | `INDICATOR_DATA` | Plot 1 (`DRAW_LINE`) | Dynamic Adaptive Ehlers Smoother curve. |

*The buffer strictly maintains non-series chronological order (`ArraySetAsSeries = false`), ensuring direct compatibility with automated Expert Advisors via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                           EA_Ehlers_Adaptive_Smoother_Interface  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Calculator Definitions
#include <MyIncludes\Ehlers_Adaptive_Smoother_Calculator.mqh>

//--- EA Inputs
input group "=== Adaptive Ehlers Smoother Parameters ==="
input ENUM_TIMEFRAMES           InpFilterTF       = PERIOD_CURRENT;          // Timeframe
input ENUM_SMOOTHER_TYPE        InpSmootherType   = SUPERSMOOTHER;           // Smoother Type
input ENUM_ADAPTIVE_METHOD      InpAdaptiveMethod = METHOD_EFFICIENCY_RATIO; // Adaptive Method
input int                       InpAdaptivePeriod = 10;                      // Period
input int                       InpPeriodMin      = 13;                      // Min Period (Speed)
input int                       InpPeriodMax      = 34;                      // Max Period (Smooth)
input ENUM_APPLIED_PRICE_HA_ALL InpPriceSource    = PRICE_CLOSE_STD;         // Price Source

//--- Global Indicator Handle
int g_filter_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_filter_handle != INVALID_HANDLE)
      IndicatorRelease(g_filter_handle);

   // Instantiate handle to Ehlers_Adaptive_Smoother_Pro via iCustom
   g_filter_handle = iCustom(_Symbol,
                             InpFilterTF,
                             "Ehlers_Adaptive_Smoother_Pro",
                             InpFilterTF,
                             InpSmootherType,
                             InpAdaptiveMethod,
                             InpAdaptivePeriod,
                             InpPeriodMin,
                             InpPeriodMax,
                             InpPriceSource);

   if(g_filter_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for Ehlers_Adaptive_Smoother_Pro. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: Ehlers_Adaptive_Smoother_Pro handle initialized successfully.");
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
   // Query completed closed candle (Shift = 1) and previous candle (Shift = 2) for slope evaluation
   double filter_vals[2];
   ArraySetAsSeries(filter_vals, true); // Index 0 = Shift 1, Index 1 = Shift 2

   if(CopyBuffer(g_filter_handle, 0, 1, 2, filter_vals) < 2)
      return; // Data synchronizing

   double filter_bar1 = filter_vals[0];
   double filter_bar2 = filter_vals[1];

   // Query corresponding closed price
   double close_prices[1];
   ArraySetAsSeries(close_prices, true);
   if(CopyClose(_Symbol, _Period, 1, 1, close_prices) < 1)
      return;

   double close_bar1 = close_prices[0];

   // Quantitative Slope & Shelf Analysis
   double slope_points = (filter_bar1 - filter_bar2) / _Point;
   bool is_rising      = (slope_points > 1.0);
   bool is_falling     = (slope_points < -1.0);
   bool is_shelf_flat  = (MathAbs(slope_points) <= 1.0);
   bool is_above_curve = (close_bar1 > filter_bar1);

   // Telemetry Output
   Comment(StringFormat("Adaptive Ehlers Smoother (%d-%d) Telemetry [Bar 1]:\n"
                        "Filter: %.*f | Close: %.*f\n"
                        "Slope: %.1f pts | Regime: %s | Position: %s",
                        InpPeriodMin, InpPeriodMax,
                        _Digits, filter_bar1,
                        _Digits, close_bar1,
                        slope_points,
                        is_shelf_flat ? "HORIZONTAL SHELF (Chop Filter Active)" :
                        (is_rising ? "RISING (Bullish Drive)" : "FALLING (Bearish Drive)"),
                        is_above_curve ? "ABOVE (Bullish Bias)" : "BELOW (Bearish Bias)"));
  }
//+------------------------------------------------------------------+
```
