# Volume-Weighted Z-Score (V-Score) Projected Bands Pro (v3.10)

Quantitative Rolling Gaussian Volatility Envelopes & Dynamic Fair-Value Bands Suite

---

## 1. Summary (Introduction)

**V-Score Bands Pro** is an institutional-grade on-chart volatility envelope that projects the statistical deviation thresholds of the **V-Score (VWAP Z-Score)** directly onto the candlestick chart around the Volume-Weighted Average Price.

While standard Bollinger Bands project moving standard deviations around an unweighted, lagging Moving Average (SMA), **V-Score Bands Pro anchors its centerline to the true Volume-Weighted Average Price (VWAP)**. It projects three dynamic, rolling standard deviation bands above and below VWAP:

1. **Flow Bands ($\pm 1.50\sigma$):** The institutional momentum flow channel (Point of No Return).
2. **Extreme Bands ($\pm 2.00\sigma$):** Statistical overbought/oversold boundaries.
3. **Wall Bands ($\pm 2.50\sigma$):** Extreme climax exhaustion caps (Reversal Walls).

```text

┌────────────────────────────────────────────────────────────────────────┐
│                      V-SCORE BANDS ON-CHART ENVELOPE                   │
├────────────────────────────────────────────────────────────────────────┤
│  Upper Wall:    VWAP(t) + [2.50 × σ_rolling(t)]  (clrMidnightBlue)     │
│  Upper Extreme: VWAP(t) + [2.00 × σ_rolling(t)]  (clrDeepSkyBlue)      │
│  Upper Flow:    VWAP(t) + [1.50 × σ_rolling(t)]  (clrLightSkyBlue)     │
│  Centerline:    Volume-Weighted Average Price    (clrOrange)           │
│  Lower Flow:    VWAP(t) - [1.50 × σ_rolling(t)]  (clrCoral)            │
│  Lower Extreme: VWAP(t) - [2.00 × σ_rolling(t)]  (clrOrangeRed)        │
│  Lower Wall:    VWAP(t) - [2.50 × σ_rolling(t)]  (clrDarkRed)          │
└────────────────────────────────────────────────────────────────────────┘

```

### Core Architectural Distinctions

* **`VWAP_Bands_Pro` vs `VScore_Bands_Pro`:** `VWAP_Bands_Pro` calculates *cumulative* standard deviation anchored from the session open (bands start at $\sigma=0$ and widen over time). `VScore_Bands_Pro` calculates *rolling* standard deviation over the last $N = \text{InpPeriod}$ bars, providing an **open-ended, continuous volatility channel** across all session opens.
* **14-Buffer Synchronized Architecture:** Employs dual Odd/Even buffers for the VWAP centerline and all 6 band levels, guaranteeing zero diagonal connecting lines across session resets.
* **Open-Ended Session Sampling:** Intelligently samples across overnight non-session gaps to preserve authentic rolling market volatility at custom session opens (e.g. LSE 08:00).
* **Unified 2026 MTF Framework:** Synchronized with `DataSync_Tools.mqh` to project higher-timeframe V-Score envelopes (e.g. H1 or Daily) onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps.

---

## 2. Mathematical Foundations & Rolling Dispersion

```text

               Upper Wall:    VWAP + (2.50 · σ)
       ═══════════════════════════════════════════════════════════ clrMidnightBlue
               Upper Extreme: VWAP + (2.00 · σ)
       ─────────────────────────────────────────────────────────── clrDeepSkyBlue
               Upper Flow:    VWAP + (1.50 · σ)
       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - clrLightSkyBlue
               Centerline:    VWAP Equilibrium
       ─────────────────────────────────────────────────────────── clrOrange
               Lower Flow:    VWAP - (1.50 · σ)
       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - clrCoral
               Lower Extreme: VWAP - (2.00 · σ)
       ─────────────────────────────────────────────────────────── clrOrangeRed
               Lower Wall:    VWAP - (2.50 · σ)
       ═══════════════════════════════════════════════════════════ clrDarkRed

```

### 2.1. Volume-Weighted Centerline ($\mu_{\text{VWAP}, t}$)

$$\mu_{\text{VWAP}, t} = \frac{\sum_{k=\text{anchor}}^{t} \text{TP}_k \cdot V_k}{\sum_{k=\text{anchor}}^{t} V_k}$$

### 2.2. Rolling Standard Deviation Around VWAP ($\sigma_t$)

To maintain natural open ends across custom session boundaries, standard deviation samples the last $P = \text{InpPeriod}$ valid in-session bars:
$$\text{Diff}_k = C_k - \mu_{\text{VWAP}, k}$$
$$\sigma_t = \sqrt{\frac{1}{P} \sum_{k \in \text{valid session bars}}^{P} \left( \text{Diff}_k \right)^2}$$

### 2.3. Dynamic Envelope Band Projections

$$\text{Upper Flow}_t = \mu_{\text{VWAP}, t} + (L_{\text{Flow}} \cdot \sigma_t), \quad\quad \text{Lower Flow}_t = \mu_{\text{VWAP}, t} - (L_{\text{Flow}} \cdot \sigma_t)$$
$$\text{Upper Extr}_t = \mu_{\text{VWAP}, t} + (L_{\text{Extr}} \cdot \sigma_t), \quad\quad \text{Lower Extr}_t = \mu_{\text{VWAP}, t} - (L_{\text{Extr}} \cdot \sigma_t)$$
$$\text{Upper Wall}_t = \mu_{\text{VWAP}, t} + (L_{\text{Wall}} \cdot \sigma_t), \quad\quad \text{Lower Wall}_t = \mu_{\text{VWAP}, t} - (L_{\text{Wall}} \cdot \sigma_t)$$
*where $L_{\text{Flow}} = 1.50$, $L_{\text{Extr}} = 2.00$, and $L_{\text{Wall}} = 2.50$.*

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                  VWAP_Calculator.mqh                   │
│   (Core Engine: Deterministic Stateless VWAP Evaluator)│
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Base VWAP Odd/Even Buffers in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                 VScore_Bands_Pro.mq5                   │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (14)      │   Centralized Framework     │
│   • 2 Centerline Plots   │   • DataSync_Tools.mqh      │
│   • 12 Volatility Bands  │   • Staircase Flat-Force    │
│   • Gapped Odd/Even Lines│   • Open-Ended Sampling     │
└──────────────────────────┴─────────────────────────────┘

```

1. **14-Buffer Odd/Even Gapped Engine:** Prevents diagonal line artifacts across session resets by toggling odd session bars to `Buf..._Odd` and even session bars to `Buf..._Even`.
2. **Open-Ended In-Session Sampling:** Scans backward to collect genuine in-session variance across off-session gaps, ensuring the envelope begins with wide, natural boundaries on the opening bar of custom trading windows.
3. **2026 MTF Framework with Staircase Solution:** Maps higher-timeframe rolling envelopes onto lower-timeframe charts using `first_bar_of_forming_htf` dynamic anchoring and `DataSync_Tools.mqh`.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### V-Score Core Settings

* `InpPeriod` (*default: `20`*): Rolling lookback period ($P$) for computing standard deviation around VWAP.
* `InpVWAPReset` (*default: `PERIOD_SESSION`*): VWAP anchor reset mode (`PERIOD_SESSION`, `PERIOD_WEEK`, `PERIOD_MONTH`, `PERIOD_CUSTOM_SESSION`).
* `InpTzShift` (*default: `0`*): Timezone offset in hours vs broker server time.
* `InpCustomSessionStart` (*default: `"09:30"`*): Session start time (`HH:MM`).
* `InpCustomSessionEnd` (*default: `"16:00"`*): Session end time (`HH:MM`).

### Calculation Settings

* `InpVolumeType` (*default: `VOLUME_TICK`*): Volume data source (`VOLUME_TICK` or `VOLUME_REAL`).
* `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).

### V-Score Z-Levels (Standard Deviations)

* `InpLevelFlow` (*default: `1.5`*): Flow boundary multiplier ($\pm 1.50\sigma$).
* `InpLevelExtreme` (*default: `2.0`*): Extreme boundary multiplier ($\pm 2.00\sigma$).
* `InpLevelWall` (*default: `2.5`*): Climax Exhaustion Wall multiplier ($\pm 2.50\sigma$).

### Visual Settings

* Independent color, style, and width controls for the VWAP centerline and all three level-pairs (`Flow`, `Extreme`, `Wall`).

---

## 5. Institutional Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   V-SCORE BANDS TRADING PLAYBOOKS                      │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Flow Channel Breakout: Ride momentum when candles close beyond      │
│                           Upper/Lower Flow Band (±1.5σ).               │
│ 2. Extreme Reversal Fade: Look for pin-bar rejection at Extreme (±2.0σ)│
│                           targeting mean reversion back to VWAP.       │
│ 3. Wall Climax Bounce:    Touch of the ±2.5σ Wall represents an        │
│                           exhaustion ceiling; initiate counter-trades. │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The Flow Channel Trend Expansion ($\pm 1.50\sigma$)

* **Bullish Expansion:** Price breaks above the `Bull Flow Band (+1.50σ)` and holds $\rightarrow$ Institutional momentum markup is confirmed. Ride long positions with trailing stop anchored to the VWAP centerline.
* **Bearish Expansion:** Price breaks below the `Bear Flow Band (-1.50σ)` and holds $\rightarrow$ Institutional markdown is active.

### 5.2. The 2.0σ Extreme Mean Reversion Fade

* **Context:** Market is in a rotational or ranging regime.
* **Short Entry:** Price thrusts into the `Bull Extreme Band (+2.00σ)` and forms a rejection wick $\rightarrow$ Target: VWAP Centerline ($0.0\sigma$).
* **Long Entry:** Price drops into the `Bear Extreme Band (-2.00σ)` and rejects $\rightarrow$ Target: VWAP Centerline ($0.0\sigma$).

### 5.3. The 2.5σ Exhaustion Wall Reversal

* A sharp spike into the **`Bull Wall (+2.50σ)`** (`clrMidnightBlue`) or **`Bear Wall (-2.50σ)`** (`clrDarkRed`) represents a $99\%$ statistical tail event.
* When this coincides with volume exhaustion or divergence on `VScore_Pro`, it signals an institutional blow-off climax, offering prime asymmetrical risk-to-reward reversal opportunities.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufVWAP_Odd` | `INDICATOR_DATA` | VWAP Centerline (Odd Periods) |
| **1** | `BufVWAP_Even` | `INDICATOR_DATA` | VWAP Centerline (Even Periods - Gapped) |
| **2** | `BufUpFlow_Odd` | `INDICATOR_DATA` | Upper Flow Band ($+1.50\sigma$, Odd Periods) |
| **3** | `BufUpFlow_Even` | `INDICATOR_DATA` | Upper Flow Band ($+1.50\sigma$, Even Periods) |
| **4** | `BufDnFlow_Odd` | `INDICATOR_DATA` | Lower Flow Band ($-1.50\sigma$, Odd Periods) |
| **5** | `BufDnFlow_Even` | `INDICATOR_DATA` | Lower Flow Band ($-1.50\sigma$, Even Periods) |
| **6** | `BufUpExtr_Odd` | `INDICATOR_DATA` | Upper Extreme Band ($+2.00\sigma$, Odd Periods) |
| **7** | `BufUpExtr_Even` | `INDICATOR_DATA` | Upper Extreme Band ($+2.00\sigma$, Even Periods) |
| **8** | `BufDnExtr_Odd` | `INDICATOR_DATA` | Lower Extreme Band ($-2.00\sigma$, Odd Periods) |
| **9** | `BufDnExtr_Even` | `INDICATOR_DATA` | Lower Extreme Band ($-2.00\sigma$, Even Periods) |
| **10** | `BufUpWall_Odd` | `INDICATOR_DATA` | Upper Wall Band ($+2.50\sigma$, Odd Periods) |
| **11** | `BufUpWall_Even` | `INDICATOR_DATA` | Upper Wall Band ($+2.50\sigma$, Even Periods) |
| **12** | `BufDnWall_Odd` | `INDICATOR_DATA` | Lower Wall Band ($-2.50\sigma$, Odd Periods) |
| **13** | `BufDnWall_Even` | `INDICATOR_DATA` | Lower Wall Band ($-2.50\sigma$, Even Periods) |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring seamless integration with Expert Advisors via `iCustom()`.*
