# Institutional Chaos-Weighted RSI Pro (Enterprise Ultra Edition v2.50)

## 1. Executive Summary & Microstructure Foundations

The **Institutional Chaos-Weighted RSI Pro (ChaosWeightedRSI_Pro)** is an institutional-grade adaptive momentum oscillator developed for MetaTrader 5 (Year 2026 Enterprise Edition). It resolves the classic limitations of J. Welles Wilder's Relative Strength Index (RSI, 1978) by dynamically modulating the internal smoothing factor using non-linear **Fractal Dimension (Chaos) Metrics**.

### The Flaw of the Classical Static RSI

Wilder's traditional RSI employs a static smoothing constant:
$$\alpha_{\text{base}} = \frac{1}{\text{Length}}$$

In electronic liquidity pools, this static factor creates an unavoidable structural dilemma:

* **During low-volatility, chaotic consolidation:** The static alpha overreacts to high-frequency micro-whipsaws, generating frequent false overbought/oversold extremes and premature counter-trend signals.
* **During explosive directional trends:** The static alpha rapidly saturates into extreme territory ($>70$ or $<30$), misleading traders into exiting winning runners prematurely.

### The Adaptive Chaos-Dampening Solution

`ChaosWeightedRSI_Pro` bridges fractal geometry with momentum:

* It continuously measures the **Fractal Dimension Index (FDI)** of the price path via the central `CFractalEngine`.
* When the market enters a **chaotic, noisy regime ($Chaos \to 1.0$)**, the smoothing alpha decays toward zero ($\alpha_{\text{adj}} \to 0.001$). The oscillator **dampens and freezes**, refusing to generate false whipsaws.
* When the market enters a **clean, persistent trend ($Chaos \to 0.0$)**, the smoothing alpha expands back to its maximum velocity, tracking directional order flow with instantaneous responsiveness.

---

## 2. Mathematical & DSP Engine Specifications

The calculation engine `CChaosWeightedRSI_Calculator` operates on chronological arrays (`ArraySetAsSeries(..., false)`) and embeds `CFractalEngine` alongside `CHeikinAshi_Calculator`.

```text

+-------------------------------------------------------------------------------+
|                       CHAOS-WEIGHTED RSI CALCULATION PIPELINE                 |
+-------------------------------------------------------------------------------+
  Price Stream: P_t (Standard or Heikin Ashi via ENUM_APPLIED_PRICE_HA_ALL)
         |
         v
  Central CFractalEngine:
    Compute Sevcik Path Length L over InpDisorderLength (default: 20)
    FDI_t = 1.0 + ln(L) / ln(2*(N-1))
         |
         v
  Normalized Chaos Ratio (Chaos_t in [0.0, 1.0]):
    Chaos_t = Clamp( (FDI_t - 1.0) / 0.5, 0.0, 1.0 )
         |
         v
  Modulated Smoothing Factor (alpha_adj):
    alpha_adj = Clamp( alpha_base* (1.0 - Chaos_t)^Sensitivity, 0.001, 1.0 )
         |
         v
  Pipelined Adaptive RMA Accumulators:
    AvgGain_t = AvgGain_{t-1} + alpha_adj *(Gain_t - AvgGain_{t-1})
    AvgLoss_t = AvgLoss_{t-1} + alpha_adj* (Loss_t - AvgLoss_{t-1})
         |
         v
  Chaos-Weighted RSI Output (WRSI_t in [0.0, 100.0]):
    RS = AvgGain_t / AvgLoss_t  -->  WRSI = 100.0 - (100.0 / (1.0 + RS))
         |
         v
  Unified Moving Average Engine (Optional Signal Line via MovingAverage_Engine.mqh)

```

### A. The Chaos-Modulated Smoothing Equation

The base smoothing alpha is derived from the user-defined RSI length:
$$\alpha_{\text{base}} = \frac{1}{\text{InpRSILength}}$$

The non-linear modulation equation adjusts the responsiveness based on market entropy:
$$\alpha_{\text{adj}} = \max\Big( 0.001, \, \min\big( 1.0, \, \alpha_{\text{base}} \cdot (1.0 - Chaos_t)^{\text{InpSensitivity}} \big) \Big)$$

* **In a Clean Trend ($Chaos = 0.0$):** $(1.0 - 0.0)^{\text{Sens}} = 1.0 \implies \alpha_{\text{adj}} = \alpha_{\text{base}}$. Full momentum tracking.
* **In Extreme Chaos ($Chaos = 1.0$):** $(1.0 - 1.0)^{\text{Sens}} = 0.0 \implies \alpha_{\text{adj}} = 0.001$. The recursive filter locks in place, acting as an automatic whipsaw brake.

### B. Gain and Loss Formulation

$$\text{Change}_t = P_t - P_{t-1}$$
$$\text{Gain}_t = \max(\text{Change}_t, \, 0.0), \quad \text{Loss}_t = \max(-\text{Change}_t, \, 0.0)$$

$$\text{AvgGain}_t = \text{AvgGain}_{t-1} + \alpha_{\text{adj}} \cdot (\text{Gain}_t - \text{AvgGain}_{t-1})$$
$$\text{AvgLoss}_t = \text{AvgLoss}_{t-1} + \alpha_{\text{adj}} \cdot (\text{Loss}_t - \text{AvgLoss}_{t-1})$$

$$\text{WRSI}_t = \begin{cases} 100.0 & \text{if } \text{AvgLoss}_t \le 1.0 \times 10^{-12} \\ 0.0 & \text{if } \text{AvgGain}_t \le 1.0 \times 10^{-12} \\ 100.0 - \left( \frac{100.0}{1.0 + \frac{\text{AvgGain}_t}{\text{AvgLoss}_t}} \right) & \text{otherwise} \end{cases}$$

---

## 3. Centralized `CFractalEngine` Integration

In accordance with Level 5 Enterprise Architecture conventions (Single Responsibility Principle & DRY), `CChaosWeightedRSI_Calculator` does not duplicate fractal dimension mathematics. Instead, it embeds **`<MyIncludes\Fractal_Engine.mqh>`**:

* The fractal engine precalculates coordinate invariants $(\Delta x)^2$ and denominator logs in `Init()`.
* On each bar, `m_fractal_engine.CalculateChaosPoint()` is evaluated in $O(\text{DisorderLength})$ time.
* Pipelined reciprocal multiplication ($inv\_range = 1.0 / \text{Range}$) eliminates runtime divisions.

---

## 4. Non-Repainting Divergence Engine & Subwindow Trendlines

The indicator includes a strictly non-repainting **Subwindow Divergence Engine** that detects structural discrepancies between price extremes and the Chaos-Weighted RSI:

```text

Regular Bullish Divergence (Subwindow Trendline: clrMediumSeaGreen, Dotted)
  Price Action:   Lower Low (P_2 < P_1)
  Chaos RSI:      Higher Low (WRSI_2 > WRSI_1)
  Interpretation: Selling momentum is exhausted despite lower price. Imminent reversal up.

Regular Bearish Divergence (Subwindow Trendline: clrCrimson, Dotted)
  Price Action:   Higher High (P_2 > P_1)
  Chaos RSI:      Lower High (WRSI_2 < WRSI_1)
  Interpretation: Buying momentum is exhausted despite higher price. Imminent reversal down.

```

### The $p + d$ Non-Repainting Protocol

* A pivot at bar $p$ requires $d$ confirmation bars to the left and $d$ bars to the right (`InpDivStrength`).
* Therefore, a pivot is **permanently confirmed and locked** at bar $p + d$.
* Once confirmed, a trendline is drawn connecting the confirmed pivot points in the subwindow (`OBJ_TREND`, Style: `STYLE_DOT`).
* **Zero Repaint Guarantee:** The trendline coordinates are anchored to historical timestamps. They will never move or disappear on future ticks.

---

## 5. High-Performance 2026 MTF Fast-Path & Multi-Instance Architecture

### A. True MTF Divergences (Eliminating the Stepped-Curve Paradox)

When viewing higher timeframe CWRSI on an execution chart (e.g., viewing H1 CWRSI on an M15 chart):

* Conventional indicators run divergence checks on the stepped lower timeframe curve, resulting in false triggers on flat steps.
* `ChaosWeightedRSI_Pro` evaluates divergences **strictly in the clean, unstepped HTF domain** (`h_time[]`, `h_high[]`, `h_low[]`, `h_res_wrsi[]`).
* Confirmed HTF divergence trendlines are anchored directly to the higher timeframe candle open timestamps (`h_time`), projecting clean, mathematically pure macro divergence lines onto the lower timeframe chart.

### B. Multi-Instance Namespace Isolation (`InpInstanceID`)

To enable multiple indicator instances on a single chart (e.g., H1 CWRSI in Subwindow 1 and H4 CWRSI in Subwindow 2):

* Every graphical object is prefixed with a deterministic instance-isolated token:

  ```mql5
  g_prefix = StringFormat("CWRSI_%I64d_%s_%d_%d_%d_",
                          ChartID(),
                          EnumToString(g_calc_timeframe),
                          InpRSILength,
                          InpDisorderLength,
                          InpInstanceID);
  ```

* Different instances will **never delete, overwrite, or collide with each other's graphical objects**.

* `GetIndicatorSubwindow()` automatically binds each instance's trendlines to its own designated subwindow.

---

## 6. Comprehensive Parameter Reference & Calibration Matrix

### Input Settings

| Parameter | Type | Default | Description | Operational Profile |
| :--- | :---: | :---: | :--- | :--- |
| `InpTimeframe` | `ENUM_TIMEFRAMES` | `PERIOD_CURRENT` | Calculation timeframe (Current or HTF). | Native $O(1)$ or Two-Pointer MTF. |
| `InpRSILength` | `int` | `14` | Base RSI analysis window length. | Governs momentum lookback. |
| `InpDisorderLength` | `int` | `20` | Fractal Dimension (Chaos) lookback window. | Governs noise filter sensitivity. |
| `InpSensitivity` | `double` | `1.0` | Chaos dampening exponent (0.1–5.0). | Higher = more aggressive freezing in chop. |
| `InpPriceSource` | `ENUM_APPLIED_PRICE_HA_ALL` | `PRICE_CLOSE_STD` | Applied price source (Standard / Heikin Ashi). | Full Heikin Ashi support. |
| `InpHistoryBars` | `int` | `1000` | Historical lookback limit (0 = Full Chart). | Eliminates cold-start freezes. |
| `InpColorRSI` | `color` | `clrDodgerBlue` | Monochrome CWRSI line color. | Primary indicator plot. |
| `InpWidthRSI` | `int` | `2` | CWRSI line thickness. | Visual width. |
| `InpShowSignal` | `bool` | `false` | Display Moving Average Signal Line. | Optional momentum overlay. |
| `InpSignalPeriod` | `int` | `9` | Signal Line smoothing period. | Governs signal responsiveness. |
| `InpSignalType` | `ENUM_MA_TYPE` | `EMA` | Signal Line MA Type (SMA, EMA, SMMA, etc.). | Unified Moving Average Engine. |
| `InpColorSignal` | `color` | `clrMagenta` | High-contrast Signal Line color. | Universal contrast on light/dark themes. |
| `InpWidthSignal` | `int` | `2` | Signal Line thickness. | Visual width. |
| `InpShowDivLines` | `bool` | `true` | Display subwindow divergence trendlines. | Toggles graphical lines. |
| `InpDivStrength` | `int` | `15` | Divergence pivot confirmation strength ($d$). | Bars required left and right. |
| `InpBullDivColor` | `color` | `clrMediumSeaGreen` | Bullish divergence trendline color. | Visual trendline styling. |
| `InpBearDivColor` | `color` | `clrCrimson` | Bearish divergence trendline color. | Visual trendline styling. |
| `InpInstanceID` | `int` | `1` | Unique instance identifier for multi-setups. | Prevents multi-indicator collisions. |

### Quantitative Calibration Matrix

| Trading Style | Asset Class | Base Chart | Target TF | RSI / FDI Length | Sensitivity | Price Source | Strategy Focus |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Micro-Scalping** | Crypto / Indices | M1 / M3 | `PERIOD_CURRENT` | `9` / `14` | `1.2` | `PRICE_MEDIAN_STD` | Ultra-fast momentum with tight noise freezing during order book sweeps. |
| **Day Trading** | Majors FX / Metals | M5 / M15 | M15 / H1 | `14` / `20` | `1.0` | `PRICE_CLOSE_STD` | Standard institutional calibration for session momentum and divergence fades. |
| **Swing Structure** | Equities / Crude Oil | H1 / H4 | H4 / D1 | `14` / `24` | `1.5` | `PRICE_HA_CLOSE` | Macro trend surfing filtered by Heikin Ashi smoothing to eliminate daily wicks. |

---

## 7. Quantitative Synergy Playbooks

### Playbook A: Chaos-Filtered Trend Momentum (RSI Cross 50)

```text
Price Action
  |                         [ACCELERATING TREND BREAKOUT] /=====> STRONG BUY ENTRY
  |                                                      /
  |-----------------------------------------------------/------------------------------ Resistance
CWRSI Subwindow
  | ----------------------------------------------------------------------------------- Level 70.0 (Overbought)
  |                              /======================> WRSI SURGES ABOVE 50.0
  | ============================/====================================================== Level 50.0 (Centerline)
  |                            ^
  |                            |-- BULLISH MOMENTUM CROSS (Market Order Confirmed)
  | ----------------------------------------------------------------------------------- Level 30.0 (Oversold)
```

1. **Setup:**
   * Market breaks out of a consolidation pattern.
   * `CWRSI` breaks cleanly above the `50.0` median centerline.
   * *Diagnosis:* Because the indicator dynamically dampens in noise, a cross above 50 occurs **only when the trend has sufficient directional efficiency**.
2. **Execution Trigger:**
   * Enter Long on the bar close confirming `BufferWRSI[1] > 50.0`.
   * (Optional: If `InpShowSignal = true`, verify `BufferWRSI[1] > BufferSignal[1]`).
3. **Exit:** Hold trade while `BufferWRSI` remains above 50.0. Exit on a close back below 50.0 or upon divergence formation.

---

### Playbook B: Non-Repainting Macro Divergence Reversal

1. **Setup:**
   * Load `ChaosWeightedRSI_Pro` on an **M15 chart** with `InpTimeframe = PERIOD_H1` and `InpShowDivLines = true`.
   * Price prints a higher high on the chart, but a dashed red trendline (`clrCrimson`) appears in the subwindow connecting a lower high on the H1 CWRSI.
2. **Execution Trigger:**
   * Wait for an M15 reversal candle (e.g., Bearish Engulfing or rejection wick) confirming the H1 macro divergence.
   * **SELL:** Enter Short targeting the opposing H1 pivot or the 30.0 oversold level.
3. **Risk Management:**
   * **Stop Loss:** 5 ticks above the H1 swing high.

---

### Playbook C: The Quad-Suite Gated Alignment

Combine all four core suite engines for institutional execution:

1. **Regime State (`Entropy_Pro`):** SampEn $< 0.80$ (Structural order confirmed).
2. **Volatility Trigger (`VolatilityRegime_Pro`):** Ratio surges from Blue ($< 0.75$) into Lime ($> 1.00$).
3. **Adaptive Momentum (`ChaosWeightedRSI_Pro`):** CWRSI crosses above 50.0 with no opposing bearish divergence.
4. **Trend Geometry (`KAMA_Bands_Pro`):** Price band-walks along $+1.0\sigma$.

* **Trade Quality:** Institutional Grade A+ Setup.

---

## 8. Developer Integration & Expert Advisor Guide

The indicator exposes its visual buffers directly to MetaTrader 5 Expert Advisors (EAs) via the native `iCustom()` API:

### Buffer Index Map

| Buffer Index | Identifier | Description | Range / Output |
| :---: | :--- | :--- | :--- |
| `0` | `BufferWRSI` | Chaos-Weighted RSI value. | Continuous double ($0.0 \dots 100.0$). |
| `1` | `BufferSignal` | Signal Line (Unified Moving Average). | Continuous double ($0.0 \dots 100.0$) or `EMPTY_VALUE`. |

### Example MQL5 EA Integration Snippet

```mql5
//+------------------------------------------------------------------+
//| Using ChaosWeightedRSI_Pro in an Automated Expert Advisor (EA)   |
//+------------------------------------------------------------------+
int h_cwrsi = INVALID_HANDLE;

int OnInit()
  {
   // Bind to ChaosWeightedRSI_Pro via iCustom
   h_cwrsi = iCustom(_Symbol, PERIOD_CURRENT, "ChaosWeightedRSI_Pro",
                     PERIOD_CURRENT,         // Timeframe
                     14,                     // RSI Length
                     20,                     // Disorder Length (FDI)
                     1.0,                    // Sensitivity
                     PRICE_CLOSE_STD,        // Price Source
                     1000,                   // History Bars Limit
                     clrDodgerBlue,          // RSI Line Color
                     2,                      // RSI Line Width
                     true,                   // Enable Signal Line
                     9,                      // Signal Period
                     EMA,                    // Signal MA Type (ENUM_MA_TYPE)
                     clrMagenta,             // Signal Color
                     STYLE_SOLID,            // Signal Style
                     2,                      // Signal Width
                     false,                  // Disable GUI Trendlines in EA for speed!
                     15,                     // Divergence Strength
                     clrMediumSeaGreen,      // Bullish Div Color
                     clrCrimson,             // Bearish Div Color
                     1);                     // Instance ID

   if(h_cwrsi == INVALID_HANDLE)
     {
      Print("Critical Error: Failed to create handle for ChaosWeightedRSI_Pro!");
      return INIT_FAILED;
     }
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   double wrsi[2], signal_line[2];
   // Read bar 1 and bar 2 (completed closed bars) for non-repainting execution
   if(CopyBuffer(h_cwrsi, 0, 1, 2, wrsi) <= 0 ||
      CopyBuffer(h_cwrsi, 1, 1, 2, signal_line) <= 0)
      return;

   double wrsi_curr   = wrsi[1];
   double wrsi_prev   = wrsi[0];
   double signal_curr = signal_line[1];
   double signal_prev = signal_line[0];

   // RULE 1: MOMENTUM ACCELERATION CROSSOVER
   bool bull_cross = (wrsi_prev <= signal_prev && wrsi_curr > signal_curr && wrsi_curr > 50.0);
   bool bear_cross = (wrsi_prev >= signal_prev && wrsi_curr < signal_curr && wrsi_curr < 50.0);

   if(bull_cross)
     {
      // Chaos-filtered bullish momentum confirmed! Execute Long.
      ExecuteOrder(ORDER_TYPE_BUY);
     }
   else if(bear_cross)
     {
      // Chaos-filtered bearish momentum confirmed! Execute Short.
      ExecuteOrder(ORDER_TYPE_SELL);
     }
  }
```

---
**Enterprise Quantitative Software Suite — 2026 Ultra Edition*
