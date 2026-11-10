# RSI Pro (v6.10)

## Institutional Multi-Timeframe Relative Strength Index, Volatility Envelopes & Dual-Chart Divergence Suite

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & Architecture Overview

**RSI Pro (v6.10)** is an institutional-grade momentum, volatility, and divergence analysis suite built for MetaTrader 5. Engineered under the **3-Tier Decoupled Component Architecture**, the suite separates low-level digital signal processing (DSP), statistical overlay modeling, and non-repainting geometric divergence detection into specialized, isolated modules.

Standard RSI implementations suffer from high ALU division overhead, division-by-zero runtime exceptions during illiquid bars, repainting divergence signals, and single-timeframe limitations. **RSI Pro solves these defects by synthesizing five enterprise technologies into a single unified indicator**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   RSI PRO 3-TIER ENGINE ARCHITECTURE                   │
├────────────────────────────────────────────────────────────────────────┤
│ 1. RSI_Engine.mqh            • Wilder's RMA with FMA Reciprocals       │
│                              • Zero-Division Algebraic Simplification  │
│                              • Full Synthetic Heikin Ashi Support      │
├────────────────────────────────────────────────────────────────────────┤
│ 2. RSI_Pro_Calculator.mqh    • Modular 14-Algorithm Signal Line        │
│                              • Transcendental-Free Bollinger Dispersion│
│                              • Dynamic Multi-Layer Display Modes       │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Divergence_Engine.mqh     • Asymmetric Non-Repainting Pivot Scanner │
│                              • 4-Regime Classification (Reg & Hidden)  │
│                              • Dual Projection (Subwindow & Main Chart)│
├────────────────────────────────────────────────────────────────────────┤
│ 4. RSI_Pro.mq5 (Wrapper)     • Two-Pointer MTF Fast-Path Protocol      │
│                              • 4 Native Output Buffers (EA Optimized) │
│                              • Resilient Subwindow Auto-Locator        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & DSP Optimizations

```text
                  RAW PRICE SERIES: Close, Median, Typical, HA Close
                                           │
                                           ▼
                            Change: Δ = Price[i] - Price[i-1]
                                ┌──────────┴──────────┐
                                ▼                     ▼
                       Positive: Gain        Negative: Loss
                                └──────────┬──────────┘
                                           ▼
                             Wilder's RMA Smoothing (FMA)
                                           │
                                           ▼
                             Optimized Algebraic RSI
                        (Gain · 100) / (Gain + Loss)
                                           │
               ┌───────────────────────────┴───────────────────────────┐
               ▼                                                       ▼
      14-Model Signal Line                                  Bollinger Dispersion Bands
   (SMA, EMA, HMA, VWMA...)                                MA ± Multiplier · StDev(RSI)
```

### 2.1. Wilder's RSI with Zero-Division Algebraic Simplification

The classical formulation of the Relative Strength Index relies on computing the Relative Strength ratio ($RS$) followed by a secondary division:
$$RS = \frac{\text{AvgGain}}{\text{AvgLoss}}, \quad\quad RSI = 100 - \frac{100}{1 + RS}$$

When $\text{AvgLoss} \to 0$ (e.g. during strong parabolic bull runs), standard code risks catastrophic division-by-zero exceptions or floating-point infinity (`+inf`).

**RSI Pro implements an algebraic reduction that eliminates the intermediate ratio entirely**:
$$RSI = 100 - \frac{100}{1 + \frac{\text{AvgGain}}{\text{AvgLoss}}} = 100 - \frac{100 \times \text{AvgLoss}}{\text{AvgGain} + \text{AvgLoss}} = \frac{100 \times \text{AvgGain}}{\text{AvgGain} + \text{AvgLoss}}$$

- **ALU Advantage:** Reduces two floating-point divisions to a single division.
- **Immunity Guard:** If $\text{AvgGain} + \text{AvgLoss} = 0$, the engine safely defaults to $50.0$ (neutral equilibrium).

### 2.2. FMA-Friendly Wilder Smoothing (RMA)

Wilder's smoothing is a first-order Infinite Impulse Response (IIR) filter. During `Init()`, the engine precomputes:
$$\alpha = \frac{1}{P}, \quad\quad \beta = \frac{P - 1}{P} = 1.0 - \alpha$$
The update equation on bar $i$ executes via pipelined Fused Multiply-Add (FMA) instructions without runtime divisions:
$$\text{AvgGain}_i = \text{AvgGain}_{i-1} \cdot \beta + \text{Gain}_i \cdot \alpha$$
$$\text{AvgLoss}_i = \text{AvgLoss}_{i-1} \cdot \beta + \text{Loss}_i \cdot \alpha$$

### 2.3. Transcendental-Free Bollinger Dispersion Bands

Standard deviations on moving averages frequently call `pow(diff, 2.0)`. In 64-bit CPU architectures, `pow()` is a transcendental function that is $\sim 50\times$ slower than direct arithmetic multiplication.

`RSI_Pro_Calculator.mqh` prunes all transcendental calls:
$$\text{diff} = \text{RSI}_{i-j} - \text{SignalMA}_i$$
$$\text{SumSq} = \sum_{j=0}^{M-1} (\text{diff} \cdot \text{diff})$$
$$\sigma_i = \sqrt{\text{SumSq} \times \frac{1}{M}}$$
$$\text{UpperBand}_i = \text{SignalMA}_i + D \cdot \sigma_i, \quad\quad \text{LowerBand}_i = \text{SignalMA}_i - D \cdot \sigma_i$$

### 2.4. Mathematical Divergence Classification

Divergences represent asynchronous decoupling between market price and internal momentum. The engine evaluates four distinct structural conditions between confirmed pivot pairs $(P_1, O_1)$ and $(P_2, O_2)$, where index 1 is historical and index 2 is current:

| Regime | Market Context | Price Structural Action | Oscillator Action | Trading Bias |
| :--- | :---: | :---: | :---: | :--- |
| **Regular Bullish** | Reversal | Lower Low: $P_2 < P_1$ | Higher Low: $O_2 > O_1$ | Long (Exhaustion) |
| **Regular Bearish** | Reversal | Higher High: $P_2 > P_1$ | Lower High: $O_2 < O_1$ | Short (Exhaustion) |
| **Hidden Bullish** | Continuation | Higher Low: $P_2 > P_1$ | Lower Low: $O_2 < O_1$ | Long (Trend Pullback) |
| **Hidden Bearish** | Continuation | Lower High: $P_2 < P_1$ | Higher High: $O_2 > O_1$ | Short (Trend Pullback) |

---

## 3. Strict Non-Repainting Divergence Mechanics

Standard commercial divergence indicators suffer from repainting: lines and signals appear on forming bars, only to disappear when the market creates a higher high or lower low.

**RSI Pro enforces strict, non-repainting geometric confirmation**:

```text
                  PIVOT FORMATION TIMELINE (Non-Repainting)
  Bar:       p - L        p (Pivot Peak)        p + R (Confirmation Bar)
               │                 │                        │
  Oscillator:  ▲                 ▲                        ▲
             Lower             PEAK                     Lower
                                 └────── R Bars ──────────┘
                                      (Right Filter)
```

1. **Asymmetric Fractal Radius:** A peak or valley at bar $p$ is evaluated against $L$ (`InpPivotLeftBars`) bars to the left and $R$ (`InpPivotRightBars`) bars to the right.
2. **Confirmation Point:** A pivot is officially registered **only when bar $p + R$ has closed**.
3. **Immutability Guarantee:** Once bar $p + R$ closes, the pivot point $(p, O_p)$ is permanently committed to history. It is mathematically impossible for the line to disappear, shift, or repaint.
4. **Distance Windows:** To eliminate irrelevant market noise, pivots are only paired if their distance $\Delta \text{Bars} = p_2 - p_1$ satisfies:
$$\text{InpMinDistance} \le \Delta \text{Bars} \le \text{InpMaxDistance}$$
5. **Dual Geometric Projection:**
   - **Subwindow Projection:** Draws a trendline directly across the two RSI peaks/valleys inside the indicator subwindow.
   - **Main Chart Projection:** Draws the corresponding trendline across the actual Highs/Lows on the main candle chart.

---

## 4. Multi-Timeframe (MTF) Two-Pointer Fast-Path Protocol

When `InpTimeframe > Period()`, the indicator activates the synchronized 2026 MTF Fast-Path engine:

```text
  HTF Domain (e.g. H1)
  [ HTF Bar 0 ]────────────────────────>[ HTF Bar 1 ]────────────────────────>[ HTF Forming ]
        │                                     │                                     │
        ▼ (Chronological 2-Pointer Projection)▼                                     ▼
  LTF Domain (e.g. M5)
  [m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5]
  └───────────────────┘ └───────────────────┘ └───────────────────┘ └───────────────────────┘
     Flat Step 0           Flat Step 1           Flat Step 2           Forming Block (Live)
```

1. **Atomic Bulk Rates Synchronization:** On HTF bar closure or initial startup, a single `CopyRates()` query synchronizes all required HTF bars into chronological caches.
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Maps computed HTF RSI, Signal MA, and Bands onto LTF chart bars in a single forward pass without calling the slow `iBarShift()` API:

   ```mql5
   int htf_ptr = 0;
   for(int i = 0; i < rates_total; i++)
     {
      while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= time[i])
         htf_ptr++;

      BufferRSI[i]       = h_rsi[htf_ptr];
      BufferSignalMA[i]  = h_ma[htf_ptr];
      BufferUpperBand[i] = h_upper[htf_ptr];
      BufferLowerBand[i] = h_lower[htf_ptr];
     }
   ```

3. **Live-Tick Isolated RAM Mocking:** On incoming live ticks within an open HTF bar, only the forming bar in RAM (`live_idx = g_htf_count - 1`) is refreshed. An $O(\log N)$ binary search locates the first LTF bar belonging to the forming HTF block and updates the values across the forming block in nanoseconds.

---

## 5. Parameters Reference

### === Timeframe Settings ===

- **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard native operation, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === RSI Core Settings ===

- **`InpPeriodRSI`** (*default: `14`*): Lookback smoothing period ($P$) for the Relative Strength Index.

- **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Overlay & Volatility Settings ===

- **`InpDisplayMode`** (*default: `DISPLAY_RSI_AND_BANDS`*):
  - `DISPLAY_RSI_ONLY`: Plots only the pure RSI line.
  - `DISPLAY_RSI_AND_MA`: Plots the RSI line and the Signal Moving Average.
  - `DISPLAY_RSI_AND_BANDS`: Plots the RSI line, Signal MA, and Bollinger Dispersion Bands.

- **`InpPeriodMA`** (*default: `20`*): Smoothing period for the Signal Moving Average line and Bollinger Bands.
- **`InpMethodMA`** (*default: `SMA`*): Moving average algorithm selection from the modular suite:
  `SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`, `HMA`, `ZLEMA`, `MCGINLEY`, `EHMA`, `MEDIAN_MA`, `SWMA`.
- **`InpBandsDev`** (*default: `2.0`*): Multiplier ($D$) for the Bollinger Dispersion Bands standard deviation.

### === Divergence Engine Settings ===

- **`InpEnableDivergence`** (*default: `true`*): Master toggle for the geometric divergence scanner.

- **`InpDivMode`** (*default: `DIV_FILTER_BOTH`*):
  - `DIV_FILTER_REGULAR_ONLY`: Scans only for reversal divergences.
  - `DIV_FILTER_HIDDEN_ONLY`: Scans only for trend-continuation divergences.
  - `DIV_FILTER_BOTH`: Scans and plots both regular and hidden divergences.
- **`InpPivotLeftBars`** (*default: `3`*): Number of confirmation bars required to the left of a pivot.
- **`InpPivotRightBars`** (*default: `2`*): Number of confirmation bars required to the right of a pivot before emission.
- **`InpMinDistance`** (*default: `5`*): Minimum bar distance between two consecutive pivots.
- **`InpMaxDistance`** (*default: `60`*): Maximum lookback window between two consecutive pivots.
- **`InpDrawSubwindowLines`** (*default: `true`*): Toggles drawing trendlines on the RSI subwindow.
- **`InpDrawMainChartLines`** (*default: `true`*): Toggles drawing trendlines on the main candle chart.

### === Divergence Visual Settings ===

- **`InpColorRegBull`** (*default: `clrDeepSkyBlue`*): Line color for Regular Bullish Divergences.

- **`InpColorRegBear`** (*default: `clrCrimson`*): Line color for Regular Bearish Divergences.
- **`InpColorHidBull`** (*default: `clrDodgerBlue`*): Line color for Hidden Bullish Divergences.
- **`InpColorHidBear`** (*default: `clrOrangeRed`*): Line color for Hidden Bearish Divergences.
- **`InpDivLineWidth`** (*default: `1`*): Line thickness for divergence trendlines.
- **`InpDivLineStyle`** (*default: `STYLE_SOLID`*): Line style for divergence trendlines.

### === Visual Settings (Core Lines) ===

- **`InpColorRSI`** (*default: `clrDodgerBlue`*): RSI line color.

- **`InpStyleRSI`** (*default: `STYLE_SOLID`*): RSI line style.
- **`InpWidthRSI`** (*default: `1`*): RSI line thickness.
- **`InpColorMA`** (*default: `clrOrangeRed`*): Signal MA line color.
- **`InpStyleMA`** (*default: `STYLE_DOT`*): Signal MA line style.
- **`InpWidthMA`** (*default: `1`*): Signal MA line thickness.
- **`InpColorBandsUpper`** (*default: `clrGray`*): Upper Bollinger Band line color.
- **`InpColorBandsLower`** (*default: `clrGray`*): Lower Bollinger Band line color.
- **`InpStyleBands`** (*default: `STYLE_DOT`*): Bollinger Bands line style.
- **`InpWidthBands`** (*default: `1`*): Bollinger Bands line thickness.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        RSI PRO TRADING PLAYBOOKS                       │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Volatility Squeeze Breakout: RSI pinching inside narrow Bollinger   │
│                                 Bands followed by an explosive expansion│
│ 2. Regular Reversal Divergence: Price Lower Low + RSI Higher Low       │
│                                 at oversold boundary (< 30) -> Long.   │
│ 3. Hidden Trend Continuation:   Price Higher Low + RSI Lower Low       │
│                                 during an established bull markup phase.│
│ 4. MTF Macro Step Alignment:    Only take M5 long breakouts when the   │
│                                 H1 RSI is holding above its 50 midline.│
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Volatility Squeeze & Dynamic Band Expansion

- **Market Context:** Market enters a tight consolidation phase where volatility contracts.

- **Setup:** Bollinger Bands on the RSI contract tightly around the Signal MA.
- **Trigger:** RSI breaks sharply out of the Bollinger Band envelope:
  - **Bullish Expansion:** RSI breaks **above** the Upper Band $\rightarrow$ Momentum breakout trigger.
  - **Bearish Expansion:** RSI breaks **below** the Lower Band $\rightarrow$ Momentum breakdown trigger.

### 6.2. Playbook 2: Regular Divergence Exhaustion Reversal

- **Market Context:** End of an extended trend or climatic selloff.

- **Setup:** Price prints a Lower Low (LL), but the RSI prints a Higher Low (HL) inside or near the oversold zone ($< 30$).
- **Execution:** Wait for the confirmation bar (trendline painted). Enter long upon RSI crossing back above its **Signal MA**.
- **Protective Stop:** Placed just below the recent swing low on the price chart.

### 6.3. Playbook 3: Hidden Divergence Trend Continuation

- **Market Context:** Established macro trend experiencing a healthy corrective pullback.

- **Setup (Bullish):** During an uptrend, price creates a Higher Low (HL), but the RSI pulls back deeply to print a Lower Low (LL).
- **Execution:** The deep RSI pullback indicates that sellers used excessive momentum to push price only a small distance. Enter long in the direction of the macro trend when RSI hooks back upward.

### 6.4. Playbook 4: Multi-Timeframe Macro Alignment Filter

- Attach an **H1-calculated RSI Pro** onto an **M5 execution chart**.

- **Quantitative Execution Rule:**
  $$\text{If } \text{BufferRSI}_{\text{H1}} > 50.0 \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{BufferRSI}_{\text{H1}} < 50.0 \implies \text{Short Trades Permitted Only}$$
- Prevents scalpers from entering counter-trend positions against institutional higher-timeframe order flow.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its core mathematical values through 4 native `INDICATOR_DATA` buffers, maintaining sub-millisecond data query performance for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Type | Display Mode Dependency | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferRSI` | `INDICATOR_DATA` | Always Active | Relative Strength Index value line ($0.0 \dots 100.0$) |
| **1** | `BufferSignalMA` | `INDICATOR_DATA` | Active in Modes 1 & 2 | Signal Moving Average value line |
| **2** | `BufferUpperBand` | `INDICATOR_DATA` | Active in Mode 2 | Upper Bollinger Dispersion Band |
| **3** | `BufferLowerBand` | `INDICATOR_DATA` | Active in Mode 2 | Lower Bollinger Dispersion Band |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the currently forming live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read RSI Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF RSI Pro
int handle = iCustom(_Symbol, _Period, "RSI_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     14,                     // InpPeriodRSI
                     PRICE_CLOSE_STD,        // InpSourcePrice
                     DISPLAY_RSI_AND_BANDS,  // InpDisplayMode
                     20,                     // InpPeriodMA
                     SMA,                    // InpMethodMA (ENUM_MA_TYPE)
                     2.0                     // InpBandsDev
                     // ... remaining visual & divergence inputs use defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create RSI_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double rsi_val[], signal_val[], upper_band[], lower_band[];
ArraySetAsSeries(rsi_val,    true);
ArraySetAsSeries(signal_val, true);
ArraySetAsSeries(upper_band, true);
ArraySetAsSeries(lower_band, true);

if(CopyBuffer(handle, 0, 1, 1, rsi_val) == 1 &&
   CopyBuffer(handle, 1, 1, 1, signal_val) == 1 &&
   CopyBuffer(handle, 2, 1, 1, upper_band) == 1 &&
   CopyBuffer(handle, 3, 1, 1, lower_band) == 1)
  {
   double rsi    = rsi_val[0];
   double signal = signal_val[0];
   double upper  = upper_band[0];
   double lower  = lower_band[0];

   // Example Execution: Bullish Volatility Breakout
   if(rsi > upper && rsi > signal)
     {
      // Open Long Order / Close Short
     }
  }
```
