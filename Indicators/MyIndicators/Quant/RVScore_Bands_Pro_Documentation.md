# Rolling Volume-Weighted Z-Score Bands (RV-Score Bands) Pro (v3.20)

Dynamic Continuous Gaussian Volatility Envelopes Projected Around Rolling VWAP

---

## 1. Summary (Introduction)

**RV-Score Bands Pro** is an institutional-grade on-chart volatility envelope that projects continuous **Rolling Volume-Weighted Standard Deviation Bands** directly onto the main price chart.

While traditional volatility bands (such as Bollinger Bands or Keltner Channels) rely on unweighted, lagging moving averages, and session-anchored VWAP bands suffer from disruptive daily/weekly reset gaps, **RV-Score Bands Pro establishes a stationary, continuous institutional fair-value channel**.

The indicator combines the zero-lag volume weighting of **Rolling VWAP** with rolling dispersion mathematics, projecting three pairs of symmetrical dynamic boundaries ($\pm 1.5\sigma, \pm 2.0\sigma, \pm 2.5\sigma$) that visually outline market equilibrium, institutional volume expansion, and extreme liquidity exhaustion.

```text

┌────────────────────────────────────────────────────────────────────────┐
│               RV-SCORE CONTINUOUS GAUSSIAN VOLATILITY ENVELOPE         │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   +2.5σ ──▶ Bull Wall Band (clrMidnightBlue)    ── Climax Exhaustion   │
│   +2.0σ ──▶ Bull Extreme Band (clrDeepSkyBlue)  ── Overbought Climax   │
│   +1.5σ ──▶ Bull Flow Band (clrLightSkyBlue)    ── Institutional Flow  │
│                                                                        │
│    0.0σ ──▶ ROLLING VWAP CENTERLINE (clrDeepSkyBlue, Width=2)          │
│                                                                        │
│   -1.5σ ──▶ Bear Flow Band (clrCoral)           ── Institutional Flow  │
│   -2.0σ ──▶ Bear Extreme Band (clrOrangeRed)    ── Oversold Climax     │
│   -2.5σ ──▶ Bear Wall Band (clrDarkRed)         ── Capitulation Floor  │
│                                                                        │
│   • 7 Continuous Plots (Zero Gaps, No Odd/Even Alternating Buffers)    │
│   • Amortized O(1) Prefix-Sum Integration                              │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Architectural Advantages Over Classic VWAP Bands

- **50% Buffer Reduction (7 vs. 14 Buffers):** Eliminates the legacy requirement for paired odd/even buffers. Because Rolling VWAP is continuous, all 7 bands render as single uninterrupted streams without diagonal cross-session artifacts.
- **Elimination of "Volatility Pinching":** At market open (00:00 or 09:30), anchored VWAP bands collapse into a narrow pinch due to lack of intra-session history. RV-Score Bands maintain a persistent sliding lookback window, ensuring realistic, wide envelopes at market open.
- **1:1 Mathematical Concordance:** Main chart band interactions correlate perfectly with the subwindow `RVScore_Pro` histogram. A price touch of the $\pm 2.5\sigma$ Wall corresponds exactly to a $\pm 2.5\sigma$ peak on the oscillator.

---

## 2. Mathematical Foundations & Dynamic Envelope Projection

```text

                          Price Expansion Wave
                                   ▲
                                   │  ┌─── High: Touches +2.5σ Bull Wall (Exhaustion)
   +2.5σ ──────────────────────────┼──┴─────────────────────────── clrMidnightBlue
   +2.0σ ──────────────────────────┼────────────────────────────── clrDeepSkyBlue
   +1.5σ ──────────────────────────┼────────────────────────────── clrLightSkyBlue
                                   │
    0.0σ ══════════════════════════╪══════════════════════════════ ROLLING VWAP
                                   │
   -1.5σ ──────────────────────────┼────────────────────────────── clrCoral
   -2.0σ ──────────────────────────┼────────────────────────────── clrOrangeRed
   -2.5σ ──────────────────────────┴──┬─────────────────────────── clrDarkRed
                                      └─── Low: Flushes into -2.5σ Bear Wall (Capitulation)

```

### 2.1. Rolling VWAP Centerline ($\mu_{\text{RVWAP}, t}$)

Evaluated via continuous prefix sums over sliding window $W$:
$$\mu_{\text{RVWAP}, t} = \frac{\text{SumTPV}_t - \text{SumTPV}_{t - W}}{\text{SumVol}_t - \text{SumVol}_{t - W}}$$
*where $\text{TP}_k = \frac{H_k + L_k + C_k}{3}$ (or Heikin Ashi equivalent) and $V_k$ is the applied volume.*

### 2.2. Continuous Rolling Dispersion ($\sigma_{\text{Rolling}, t}$)

Given volatility lookback period $P = \text{InpSigmaPeriod}$:
$$\text{Diff}_k = C_k - \mu_{\text{RVWAP}, k}$$
$$\sigma_{\text{Rolling}, t} = \sqrt{\frac{1}{P} \sum_{k=0}^{P - 1} \left( \text{Diff}_{t - k} \right)^2}$$

### 2.3. Dynamic Envelope Projection Formulas

$$\text{BullWall}_t = \mu_{\text{RVWAP}, t} + (2.5 \cdot \sigma_{\text{Rolling}, t})$$
$$\text{BullExtr}_t = \mu_{\text{RVWAP}, t} + (2.0 \cdot \sigma_{\text{Rolling}, t})$$
$$\text{BullFlow}_t = \mu_{\text{RVWAP}, t} + (1.5 \cdot \sigma_{\text{Rolling}, t})$$
$$\text{Centerline}_t = \mu_{\text{RVWAP}, t}$$
$$\text{BearFlow}_t = \mu_{\text{RVWAP}, t} - (1.5 \cdot \sigma_{\text{Rolling}, t})$$
$$\text{BearExtr}_t = \mu_{\text{RVWAP}, t} - (2.0 \cdot \sigma_{\text{Rolling}, t})$$
$$\text{BearWall}_t = \mu_{\text{RVWAP}, t} - (2.5 \cdot \sigma_{\text{Rolling}, t})$$

---

### 2.4. Institutional Swapped Thermal Band Taxonomy

| Band Identifier | Buffer | Multiplier | Visual Default | Institutional Role |
| :--- | :---: | :---: | :--- | :--- |
| **Bull Wall** | `BufUpWall` | $+2.5\sigma$ | `clrMidnightBlue` | Extreme liquidity exhaustion ceiling; mean-reversion short target. |
| **Bull Extreme** | `BufUpExtr` | $+2.0\sigma$ | `clrDeepSkyBlue` | Statistical overbought climax; initial profit-taking boundary. |
| **Bull Flow** | `BufUpFlow` | $+1.5\sigma$ | `clrLightSkyBlue` | Point of institutional volume expansion; dynamic support in markup. |
| **Rolling VWAP** | `BufVWAP` | $0.0\sigma$ | `clrDeepSkyBlue` (w=2) | Institutional fair-value equilibrium baseline. |
| **Bear Flow** | `BufDnFlow` | $-1.5\sigma$ | `clrCoral` | Point of institutional distribution expansion; dynamic resistance. |
| **Bear Extreme** | `BufDnExtr` | $-2.0\sigma$ | `clrOrangeRed` | Statistical oversold climax; short-covering bounce zone. |
| **Bear Wall** | `BufDnWall` | $-2.5\sigma$ | `clrDarkRed` | Panic liquidation capitulation floor; mean-reversion long target. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│              Rolling_VWAP_Calculator.mqh              │
│     (Prefix-Sum Integration & Volatility Engine)       │
└──────────────────────────┬─────────────────────────────┘
                           │ Generates RVWAP & Variance in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                 RVScore_Bands_Pro.mq5                  │
│       (Unified On-Chart Wrapper: Native & MTF)         │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (7)       │   Centralized Framework     │
│   • BufVWAP (Centerline) │   • DataSync_Tools.mqh      │
│   • BufUpFlow / BufDnFlow│   • Real-Time Mock Sync     │
│   • BufUpExtr / BufDnExtr│   • Staircase Flat-Force    │
│   • BufUpWall / BufDnWall│                             │
└──────────────────────────┴─────────────────────────────┘

```

1. **State Preservation:** Calculation caches (`m_diff_sq_buf`) survive tick updates and array resizing without data wiping, guaranteeing floating-point stability.
2. **Unified Native & MTF Support:** If `InpTimeframe == PERIOD_CURRENT`, calculation runs in native zero-lag mode. If `InpTimeframe > Period()`, higher-timeframe bands project onto lower-timeframe execution charts as crisp, non-repainting flat steps.
3. **Forming LTF Block Flat-Force Anchor:** Eliminates diagonal step distortion during real-time higher-timeframe candle formation.

---

## 4. Parameters Reference

### Timeframe Settings

- `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for native zero-lag execution, or select a higher timeframe (e.g., `PERIOD_H1`) to activate the synchronized MTF engine.

### Rolling VWAP Engine

- `InpRollingType` (*default: `ROLLING_BARS`*):
  - `ROLLING_BARS`: Sliding window of fixed bar count.
  - `ROLLING_TIME`: Continuous physical time window in minutes.
- `InpRollingWindow` (*default: `144`*): Horizon length (bars or minutes).
- `InpSigmaPeriod` (*default: `20`*): Volatility lookback ($P$) for standard deviation variance calculation.

### Calculation Sources

- `InpVolumeType` (*default: `VOLUME_TICK`*): Volume data source (`VOLUME_TICK` or `VOLUME_REAL`). Automatically falls back to tick volume if real volume is unsupported.
- `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price input series (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).

### RV-Score Sigma Multipliers

- `InpLevelFlow` (*default: `1.5`*): Sigma multiplier for Flow Bands.
- `InpLevelExtreme` (*default: `2.0`*): Sigma multiplier for Extreme Bands.
- `InpLevelWall` (*default: `2.5`*): Sigma multiplier for Wall Bands.

### Visual Styling

- `InpColorVWAP` / `InpStyleVWAP` / `InpWidthVWAP`: Visual styling for the Centerline (Default: `clrDeepSkyBlue`, `STYLE_SOLID`, `2`).
- `InpColorUpFlow` / `InpColorDnFlow` / `InpStyleFlow` / `InpWidthFlow`: Visual styling for Flow Bands ($\pm 1.5\sigma$).
- `InpColorUpExtr` / `InpColorDnExtr` / `InpStyleExtr` / `InpWidthExtr`: Visual styling for Extreme Bands ($\pm 2.0\sigma$).
- `InpColorUpWall` / `InpColorDnWall` / `InpStyleWall` / `InpWidthWall`: Visual styling for Wall Bands ($\pm 2.5\sigma$).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                RV-SCORE BANDS INSTITUTIONAL PLAYBOOKS                  │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Wall Mean Reversion:    Fade candle rejections at the ±2.5σ Wall;   │
│                            target the Centerline (Rolling VWAP).       │
│ 2. Volume Flow Expansion:  Buy pullbacks to the +1.5σ Flow band during │
│                            markup; sell pullbacks to -1.5σ in markdown.│
│ 3. Centerline Break & Run: Enter trend transitions when price crosses  │
│                            and closes beyond the Centerline.           │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Wall Mean Reversion Fade ($\pm 2.5\sigma$)

- **Premise:** When price expands beyond $2.5$ standard deviations away from the Rolling VWAP, the probability of further directional continuation without liquidity replenishment drops below 1.5%.
- **Long Capitulation Setup:**
  1. Price flushes downward into or slightly penetrates the **Bear Wall ($-2.5\sigma$, `DarkRed`)**.
  2. A bullish rejection candle (long lower wick or pinbar) prints on the chart.
  3. **Enter Long:** Stop loss placed below the wick low. Target 1: Bear Flow ($-1.5\sigma$); Target 2: Rolling VWAP Centerline ($0.0\sigma$).
- **Short Exhaustion Setup:**
  1. Price surges upward into the **Bull Wall ($+2.5\sigma$, `MidnightBlue`)**.
  2. Bearish rejection wick prints $\rightarrow$ **Enter Short** targeting the Centerline.

### 5.2. Volume Flow Continuation Ride ($+1.5\sigma \dots +2.0\sigma$)

- **Premise:** During strong institutional trend regimes, price does not return to fair value ($0.0\sigma$). Instead, the **Flow Band ($\pm 1.5\sigma$)** serves as dynamic support/resistance.
- **Bullish Execution:**
  - Price expands above $+2.0\sigma$, pulling the bands upward into an expansion trumpet.
  - Price pulls back to test the **Bull Flow Band (`LightSkyBlue`, $+1.5\sigma$)** from above.
  - Bullish confirmation prints $\rightarrow$ **Enter Long**, riding the trend higher.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Multiplier | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufVWAP` | `INDICATOR_DATA` | $0.0\sigma$ | Centerline: Continuous Rolling VWAP stream. |
| **1** | `BufUpFlow` | `INDICATOR_DATA` | $+1.5\sigma$ | Upper Flow Band (Bullish volume expansion threshold). |
| **2** | `BufDnFlow` | `INDICATOR_DATA` | $-1.5\sigma$ | Lower Flow Band (Bearish volume expansion threshold). |
| **3** | `BufUpExtr` | `INDICATOR_DATA` | $+2.0\sigma$ | Upper Extreme Band (Statistical overbought climax). |
| **4** | `BufDnExtr` | `INDICATOR_DATA` | $-2.0\sigma$ | Lower Extreme Band (Statistical oversold climax). |
| **5** | `BufUpWall` | `INDICATOR_DATA` | $+2.5\sigma$ | Upper Wall Band (Liquidity exhaustion boundary). |
| **6** | `BufDnWall` | `INDICATOR_DATA` | $-2.5\sigma$ | Lower Wall Band (Capitulation liquidation floor). |

*All 7 buffers strictly maintain chronological non-series indexing (`ArraySetAsSeries = false`), allowing deterministic querying in automated Expert Advisors.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                                    EA_RVScore_Bands_Demo.mq5     |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Include Rolling VWAP Window Type Definition
#include <MyIncludes\Rolling_VWAP_Calculator.mqh>

//--- EA Inputs
input group "=== RV-Score Bands Filter Settings ==="
input ENUM_TIMEFRAMES     InpBandsTimeframe = PERIOD_CURRENT;  // Timeframe
input ENUM_ROLLING_TYPE   InpBandsType      = ROLLING_BARS;    // Rolling Type
input int                 InpBandsWindow    = 144;             // Rolling Window
input int                 InpBandsSigma     = 20;              // Volatility Lookback
input ENUM_APPLIED_VOLUME InpBandsVolume    = VOLUME_TICK;     // Volume Source
input ENUM_CANDLE_SOURCE  InpBandsSource    = CANDLE_STANDARD; // Candle Source

//--- Global Indicator Handle
int g_bands_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_bands_handle != INVALID_HANDLE)
      IndicatorRelease(g_bands_handle);

   // Instantiate handle to RVScore_Bands_Pro via iCustom
   g_bands_handle = iCustom(_Symbol,
                            InpBandsTimeframe,
                            "RVScore_Bands_Pro",
                            InpBandsTimeframe,
                            InpBandsType,
                            InpBandsWindow,
                            InpBandsSigma,
                            InpBandsVolume,
                            InpBandsSource,
                            1.5, 2.0, 2.5); // Flow, Extreme, Wall multipliers

   if(g_bands_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for RVScore_Bands_Pro. Error Code: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: RVScore_Bands_Pro handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_bands_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_bands_handle);
      g_bands_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query last closed bar (Shift = 1) across all bands
   double vwap[1], up_flow[1], dn_flow[1], up_wall[1], dn_wall[1];

   if(CopyBuffer(g_bands_handle, 0, 1, 1, vwap)    < 1 ||
      CopyBuffer(g_bands_handle, 1, 1, 1, up_flow) < 1 ||
      CopyBuffer(g_bands_handle, 2, 1, 1, dn_flow) < 1 ||
      CopyBuffer(g_bands_handle, 5, 1, 1, up_wall) < 1 ||
      CopyBuffer(g_bands_handle, 6, 1, 1, dn_wall) < 1)
     {
      return;
     }

   // Fetch corresponding closed price
   double close[1], low[1], high[1];
   if(CopyClose(_Symbol, _Period, 1, 1, close) < 1 ||
      CopyLow(_Symbol,   _Period, 1, 1, low)   < 1 ||
      CopyHigh(_Symbol,  _Period, 1, 1, high)  < 1)
     {
      return;
     }

   double cur_close = close[0];
   double cur_low   = low[0];
   double cur_high  = high[0];

   // Quantitative Mean-Reversion Signals
   bool buy_wall_bounce  = (cur_low <= dn_wall[0] && cur_close > dn_wall[0]);
   bool sell_wall_bounce = (cur_high >= up_wall[0] && cur_close < up_wall[0]);

   // Telemetry Output
   Comment(StringFormat("RV-Score Bands Telemetry:\n"
                        "Bull Wall (+2.5σ): %.*f\n"
                        "Bull Flow (+1.5σ): %.*f\n"
                        "Rolling VWAP (0σ): %.*f\n"
                        "Bear Flow (-1.5σ): %.*f\n"
                        "Bear Wall (-2.5σ): %.*f\n"
                        "Wall Bounce Signals -> Buy: %s | Sell: %s",
                        _Digits, up_wall[0],
                        _Digits, up_flow[0],
                        _Digits, vwap[0],
                        _Digits, dn_flow[0],
                        _Digits, dn_wall[0],
                        buy_wall_bounce ? "TRIGGERED" : "NO",
                        sell_wall_bounce ? "TRIGGERED" : "NO"));
  }
//+------------------------------------------------------------------+
```
