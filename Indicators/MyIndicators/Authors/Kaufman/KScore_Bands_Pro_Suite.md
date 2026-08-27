# Kaufman's Adaptive Z-Score (K-Score) Projected Bands Pro Suite

*Quantitative Rolling & Session-Anchored Adaptive Volatility Envelopes Suite*
*(Covering: KScore_Bands_Pro & KScore_Anchored_Bands_Pro - Version 1.00)*

---

## 1. Summary (Introduction)

The **K-Score Projected Bands Suite** comprises two institutional on-chart volatility envelope indicators that project the statistical deviation thresholds of the **K-Score (KAMA Z-Score)** directly onto the candlestick chart:

1. **`KScore_Bands_Pro` (Continuous Rolling Bands):** A 7-buffer continuous envelope that projects rolling standard deviation bands around the standard, rolling **KAMA Pro** baseline.
2. **`KScore_Anchored_Bands_Pro` (Session-Anchored Bands):** A 14-buffer gapped envelope that projects rolling standard deviation bands around the session-anchored **AKAMA Pro** baseline (Daily, Weekly, Monthly, or Custom Session anchors such as LSE/NYSE).

Both indicators translate non-linear, efficiency-weighted statistical overextension into clear on-chart price boundaries:

* **Flow Bands ($\pm 1.50\sigma$):** Institutional momentum flow boundary (Point of No Return).
* **Extreme Bands ($\pm 2.00\sigma$):** Statistical overbought/oversold exhaustion zones.
* **Wall Bands ($\pm 2.50\sigma$):** Extreme climax exhaustion caps (Reversal Walls).

```text

┌────────────────────────────────────────────────────────────────────────┐
│                     K-SCORE BANDS ON-CHART ENVELOPE                    │
├────────────────────────────────────────────────────────────────────────┤
│  Upper Wall:    KAMA(t) + [2.50 × σ_rolling(t)]  (clrMidnightBlue)     │
│  Upper Extreme: KAMA(t) + [2.00 × σ_rolling(t)]  (clrDeepSkyBlue)      │
│  Upper Flow:    KAMA(t) + [1.50 × σ_rolling(t)]  (clrLightSkyBlue)     │
│  Centerline:    Kaufman's Adaptive Moving Average(clrCrimson / clrOrange│
│  Lower Flow:    KAMA(t) - [1.50 × σ_rolling(t)]  (clrCoral)            │
│  Lower Extreme: KAMA(t) - [2.00 × σ_rolling(t)]  (clrOrangeRed)        │
│  Lower Wall:    KAMA(t) - [2.50 × σ_rolling(t)]  (clrDarkRed)          │
└────────────────────────────────────────────────────────────────────────┘

```

---

## 2. Mathematical Foundations & Kinetic Dispersion

```text

               Upper Wall:    Centerline + (2.50 · σ)
       ═══════════════════════════════════════════════════════════ clrMidnightBlue
               Upper Extreme: Centerline + (2.00 · σ)
       ─────────────────────────────────────────────────────────── clrDeepSkyBlue
               Upper Flow:    Centerline + (1.50 · σ)
       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - clrLightSkyBlue
               Centerline:    Adaptive Equilibrium Mean (KAMA / AKAMA)
       ─────────────────────────────────────────────────────────── clrCrimson / clrOrange
               Lower Flow:    Centerline - (1.50 · σ)
       - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - clrCoral
               Lower Extreme: Centerline - (2.00 · σ)
       ─────────────────────────────────────────────────────────── clrOrangeRed
               Lower Wall:    Centerline - (2.50 · σ)
       ═══════════════════════════════════════════════════════════ clrDarkRed

```

### 2.1. Centerline Formulations

#### 1. Continuous Rolling Centerline (`KScore_Bands_Pro`)

$$\text{Middle}_t = \text{KAMA}_t = \text{KAMA}_{t-1} + \text{SC}_t \cdot (P_t - \text{KAMA}_{t-1})$$
*where $\text{SC}_t = \left[ \text{ER}_t \cdot (\alpha_{\text{fast}} - \alpha_{\text{slow}}) + \alpha_{\text{slow}} \right]^2$.*

#### 2. Session-Anchored Centerline (`KScore_Anchored_Bands_Pro`)

$$\text{AKAMA}_{\text{anchor}} = P_{\text{anchor}}$$
$$\text{Middle}_t = \text{AKAMA}_t = \text{AKAMA}_{t-1} + \text{SC}_t \cdot (P_t - \text{AKAMA}_{t-1})$$
*where $\text{ER}_t$ is computed using the dynamic lookback $N_{\text{eff}} = \min(t - \text{Anchor Bar}, N_{\text{ER}})$.*

---

### 2.2. Rolling Standard Deviation Around Centerline ($\sigma_t$)

#### 1. Continuous Rolling Sampling (`KScore_Bands_Pro`)

Given standard deviation lookback window $P = \text{InpStDevPeriod}$:
$$\text{Diff}_k = C_k - \text{KAMA}_k$$
$$\sigma_t = \sqrt{\frac{1}{P} \sum_{k=0}^{P - 1} \left( \text{Diff}_{t-k} \right)^2}$$

#### 2. Open-Ended In-Session Sampling (`KScore_Anchored_Bands_Pro`)

To ensure natural open ends without artificial pinching at session opens (such as LSE `08:00`), standard deviation samples the last $P = \text{InpStDevPeriod}$ valid in-session bars across overnight gaps:
$$\sigma_{\text{session}, t} = \sqrt{\frac{1}{P} \sum_{k \in \text{valid session bars}}^{P} \left( C_k - \text{AKAMA}_k \right)^2}$$

---

### 2.3. Dynamic Envelope Band Projections

$$\text{Upper Flow}_t = \text{Middle}_t + (L_{\text{Flow}} \cdot \sigma_t), \quad\quad \text{Lower Flow}_t = \text{Middle}_t - (L_{\text{Flow}} \cdot \sigma_t)$$
$$\text{Upper Extr}_t = \text{Middle}_t + (L_{\text{Extr}} \cdot \sigma_t), \quad\quad \text{Lower Extr}_t = \text{Middle}_t - (L_{\text{Extr}} \cdot \sigma_t)$$
$$\text{Upper Wall}_t = \text{Middle}_t + (L_{\text{Wall}} \cdot \sigma_t), \quad\quad \text{Lower Wall}_t = \text{Middle}_t - (L_{\text{Wall}} \cdot \sigma_t)$$
*where $L_{\text{Flow}} = 1.50$, $L_{\text{Extr}} = 2.00$, and $L_{\text{Wall}} = 2.50$.*

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                  KScore_Bands_Pro Suite                │
│    (Continuous & Session-Anchored On-Chart Envelopes)  │
├──────────────────────────┬─────────────────────────────┤
│   KScore_Bands_Pro       │   KScore_Anchored_Bands_Pro │
│   • Continuous 7 Buffers │   • 14 Odd/Even Buffers     │
│   • KAMA_Calculator.mqh  │   • KAMA_Anchored_Calc.mqh  │
│   • Zero Session Resets  │   • Open-Ended Sampling     │
├──────────────────────────┴─────────────────────────────┤
│   Shared 2026 MTF Framework: DataSync_Tools.mqh        │
│   • Asynchronous 1-Second Timer Daemon (OnTimerUpdate) │
│   • Real-Time Live Bar Mocking (live_idx = htf_count-1)│
│   • Forming LTF Block Flat-Force (Staircase Solution)  │
└────────────────────────────────────────────────────────┘

```

1. **Continuous vs Gapped Architecture:**
   * `KScore_Bands_Pro` utilizes a streamlined 7-buffer architecture for continuous trend-following strategies.
   * `KScore_Anchored_Bands_Pro` utilizes a 14-buffer Odd/Even alternating architecture to guarantee clean, gapped line transitions across session resets without diagonal artifacts.
2. **Open-Ended In-Session Sampling Engine:** Scans backward to collect genuine in-session variance across off-session gaps, ensuring the envelope begins with wide, natural boundaries on the opening bar of custom trading windows.
3. **2026 MTF Framework with Staircase Solution:** Maps higher-timeframe rolling envelopes onto lower-timeframe execution charts using `first_bar_of_forming_htf` dynamic anchoring and `DataSync_Tools.mqh`.

---

## 4. Parameters Reference

### 4.1. `KScore_Bands_Pro.mq5` (Continuous Rolling)

| Parameter Group | Name | Default | Description |
| :--- | :--- | :--- | :--- |
| **Timeframe** | `InpTimeframe` | `PERIOD_CURRENT` | Calculation timeframe (Current or Higher Timeframe). |
| **KAMA Core** | `InpErPeriod` | `10` | Efficiency Ratio lookback period ($N$). |
| | `InpFastEmaPeriod` | `2` | Fastest smoothing period ($F$). |
| | `InpSlowEmaPeriod` | `30` | Slowest smoothing period ($S$). |
| | `InpStDevPeriod` | `20` | Volatility lookback period ($P$) for standard deviation. |
| | `InpSourcePrice` | `PRICE_CLOSE_STD` | Price series (Standard OHLC or Synthetic Heikin Ashi). |
| **Z-Levels** | `InpLevelFlow` | `1.5` | Flow boundary multiplier ($\pm 1.50\sigma$). |
| | `InpLevelExtreme` | `2.0` | Extreme boundary multiplier ($\pm 2.00\sigma$). |
| | `InpLevelWall` | `2.5` | Climax Exhaustion Wall multiplier ($\pm 2.50\sigma$). |
| **Visual Settings** | `InpColorKAMA` | `clrCrimson` | KAMA centerline color (Width: 2, Solid). |
| | `InpColorUp/DnFlow` | `LightSkyBlue / Coral` | Flow bands colors ($\pm 1.50\sigma$). |
| | `InpColorUp/DnExtr` | `DeepSkyBlue / OrangeRed` | Extreme bands colors ($\pm 2.00\sigma$). |
| | `InpColorUp/DnWall` | `MidnightBlue / DarkRed` | Wall bands colors ($\pm 2.50\sigma$). |

---

### 4.2. `KScore_Anchored_Bands_Pro.mq5` (Session-Anchored)

| Parameter Group | Name | Default | Description |
| :--- | :--- | :--- | :--- |
| **Timeframe** | `InpTimeframe` | `PERIOD_CURRENT` | Calculation timeframe (Current or Higher Timeframe). |
| **Anchor Settings** | `InpResetPeriod` | `ANCHOR_PERIOD_SESSION` | Anchor mode (`SESSION`, `WEEK`, `MONTH`, `CUSTOM`). |
| | `InpTzShift` | `0` | Timezone offset in hours vs broker server time. |
| | `InpCustomStart` | `"08:00"` | Custom session start time (`HH:MM`, e.g., LSE Open). |
| | `InpCustomEnd` | `"17:00"` | Custom session end time (`HH:MM`, e.g., LSE Close). |
| **KAMA Core** | `InpErPeriod` | `10` | Efficiency Ratio lookback period ($N$). |
| | `InpFastEmaPeriod` | `2` | Fastest smoothing period ($F$). |
| | `InpSlowEmaPeriod` | `30` | Slowest smoothing period ($S$). |
| | `InpStDevPeriod` | `20` | Volatility lookback period ($P$) for standard deviation. |
| | `InpSourcePrice` | `PRICE_CLOSE_STD` | Price series (Standard OHLC or Synthetic Heikin Ashi). |
| **Z-Levels** | `InpLevelFlow` | `1.5` | Flow boundary multiplier ($\pm 1.50\sigma$). |
| | `InpLevelExtreme` | `2.0` | Extreme boundary multiplier ($\pm 2.00\sigma$). |
| | `InpLevelWall` | `2.5` | Climax Exhaustion Wall multiplier ($\pm 2.50\sigma$). |
| **Visual Settings** | `InpColorKAMA` | `clrOrange` | AKAMA centerline color (Width: 2, Solid). |
| | `InpColorUp/DnFlow` | `LightSkyBlue / Coral` | Flow bands colors ($\pm 1.50\sigma$). |
| | `InpColorUp/DnExtr` | `DeepSkyBlue / OrangeRed` | Extreme bands colors ($\pm 2.00\sigma$). |
| | `InpColorUp/DnWall` | `MidnightBlue / DarkRed` | Wall bands colors ($\pm 2.50\sigma$). |

---

## 5. Institutional Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   K-SCORE BANDS TRADING PLAYBOOKS                      │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Adaptive Flow Breakout:  Ride trend when candles close outside      │
│                             Upper/Lower Flow Band (±1.5σ).             │
│ 2. Extreme Reversal Fade:   Fade pin-bar rejections at Extreme (±2.0σ) │
│                             targeting mean reversion back to KAMA.     │
│ 3. Wall Climax Bounce:      Touch of the ±2.5σ Wall represents an      │
│                             exhaustion ceiling; initiate counter-trades│
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The Adaptive Flow Trend Expansion ($\pm 1.50\sigma$)

* **Bullish Momentum Markup:** Price decisively closes above the `Bull Flow Band (+1.50σ)` and holds while KAMA is sloping upward $\rightarrow$ Institutional momentum expansion active. Enter long with a dynamic trailing stop anchored to the KAMA centerline.
* **Bearish Momentum Markdown:** Price decisively closes below the `Bear Flow Band (-1.50σ)` and holds $\rightarrow$ Enter short.

### 5.2. The 2.0σ Extreme Mean Reversion Fade

* **Context:** Market is in a ranging or rotational regime (KAMA is flat).
* **Short Entry:** Price spikes into the `Bull Extreme Band (+2.00σ)` and prints a rejection wick $\rightarrow$ Target: KAMA Centerline.
* **Long Entry:** Price drops into the `Bear Extreme Band (-2.00σ)` and prints a rejection wick $\rightarrow$ Target: KAMA Centerline.

### 5.3. The 2.5σ Exhaustion Wall Reversal

* A sharp thrust touching the **`Bull Wall (+2.50σ)`** (`clrMidnightBlue`) or **`Bear Wall (-2.50σ)`** (`clrDarkRed`) represents a $99\%$ statistical tail event relative to the adaptive baseline.
* When this coincides with volume exhaustion or divergence on `KScore_Pro`, it signals an institutional blow-off climax, offering prime asymmetrical risk-to-reward reversal entries.

---

## 6. Indicator Buffer Maps (For Developers & EA Integration)

### 6.1. `KScore_Bands_Pro.mq5` (7 Buffers)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferMiddle` | `INDICATOR_DATA` | KAMA Equilibrium Centerline |
| **1** | `BufferUpFlow` | `INDICATOR_DATA` | Upper Flow Band ($+1.50\sigma$) |
| **2** | `BufferDnFlow` | `INDICATOR_DATA` | Lower Flow Band ($-1.50\sigma$) |
| **3** | `BufferUpExtr` | `INDICATOR_DATA` | Upper Extreme Band ($+2.00\sigma$) |
| **4** | `BufferDnExtr` | `INDICATOR_DATA` | Lower Extreme Band ($-2.00\sigma$) |
| **5** | `BufferUpWall` | `INDICATOR_DATA` | Upper Wall Band ($+2.50\sigma$) |
| **6** | `BufferDnWall` | `INDICATOR_DATA` | Lower Wall Band ($-2.50\sigma$) |

---

### 6.2. `KScore_Anchored_Bands_Pro.mq5` (14 Buffers)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufAKAMA_Odd` | `INDICATOR_DATA` | AKAMA Centerline (Odd Periods) |
| **1** | `BufAKAMA_Even` | `INDICATOR_DATA` | AKAMA Centerline (Even Periods - Gapped) |
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

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
