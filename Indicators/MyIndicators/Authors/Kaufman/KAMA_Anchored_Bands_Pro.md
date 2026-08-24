# Session-Anchored Kaufman's Adaptive Moving Average (AKAMA) Bands Pro (v2.00)

Quantitative Session-Anchored Volatility & Statistical Dispersion Envelope Suite

---

## 1. Summary (Introduction)

**KAMA Anchored Bands Pro (AKAMA Bands)** is an innovative quantitative envelope indicator that unifies periodic session anchoring with **Perry Kaufman's Adaptive Moving Average** and cumulative **Standard Deviation ($\sigma$) Volatility Bands**.

While traditional Anchored VWAP (AVWAP) measures volume-weighted average price from an anchor point, **Anchored KAMA (AKAMA) measures directional-efficiency-weighted price dynamics**. It eliminates the overnight low-liquidity noise carryover by resetting its calculation at a user-defined market boundary (such as the **London Stock Exchange (LSE) Open**, **Frankfurt Open**, **New York Cash Open**, or Weekly/Monthly anchors).

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        AKAMA BANDS ARCHITECTURE                        │
├────────────────────────────────────────────────────────────────────────┤
│  Upper Band 3:  AKAMA(t) + [3.0 × σ(t)]  (Extreme Climax Ceiling)      │
│  Upper Band 2:  AKAMA(t) + [2.0 × σ(t)]  (Value Area High)             │
│  Upper Band 1:  AKAMA(t) + [1.0 × σ(t)]  (Dynamic Resistance)          │
│  Centerline:    Session-Anchored KAMA (Adaptive Equilibrium)           │
│  Lower Band 1:  AKAMA(t) - [1.0 × σ(t)]  (Dynamic Support)             │
│  Lower Band 2:  AKAMA(t) - [2.0 × σ(t)]  (Value Area Low)              │
│  Lower Band 3:  AKAMA(t) - [3.0 × σ(t)]  (Extreme Climax Floor)        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **Periodic & Custom Session Anchoring:** Automatically resets and seeds calculation at Daily Session Open, Weekly Open, Monthly Open, or Custom Institutional Windows (e.g., LSE `08:00 - 16:30`, London/NY Overlap `13:30 - 17:00`).
* **Intra-Session Efficiency Adaptation:** The KAMA centerline adapts exclusively to price action within the active session, preventing pre-market noise from polluting regular trading hours (RTH).
* **Anchored Standard Deviation Envelopes:** Projects running statistical dispersion bands ($\pm 1\sigma, \pm 2\sigma, \pm 3\sigma$) accumulated from the exact session anchor bar.
* **Gapped Odd/Even Line Architecture:** Uses dual alternating buffers (`BufKAMA_Odd`, `BufKAMA_Even`) to eliminate diagonal connecting lines across session resets.
* **2026 MTF Framework with DataSync Daemon:** Enables higher-timeframe session bands (e.g., M15 or H1 AKAMA Bands) to be mapped onto lower-timeframe execution charts (M1, M5) with flat, non-warping steps.

---

## 2. Mathematical Foundations

```text

          Anchor Bar (Session Open: σ = 0.0)
          │
          ├───► Upper Band 3: AKAMA + 3σ (Reversal Exhaustion)
          ├───► Upper Band 2: AKAMA + 2σ (Value Area High)
          ├───► Upper Band 1: AKAMA + 1σ
          ├───► Centerline:   AKAMA (Efficiency-Weighted Adaptive Mean)
          ├───► Lower Band 1: AKAMA - 1σ
          ├───► Lower Band 2: AKAMA - 2σ (Value Area Low)
          └───► Lower Band 3: AKAMA - 3σ (Reversal Exhaustion)

```

### 2.1. Anchor Reset & Local Efficiency Ratio

At each anchor boundary ($t = \text{Anchor Bar}$), the filter re-seeds from the opening price:
$$\text{AKAMA}_{\text{anchor}} = P_{\text{anchor}}$$

For any subsequent bar $t$ within the active session ($k_t = t - \text{Anchor Bar}$):
$$N_{\text{eff}} = \min(k_t, N_{\text{ER}})$$
$$\text{Direction}_t = | P_t - P_{t - N_{\text{eff}}} |$$
$$\text{Volatility}_t = \sum_{j=0}^{N_{\text{eff}}-1} | P_{t-j} - P_{t-j-1} |$$
$$\text{ER}_t = \begin{cases} \frac{\text{Direction}_t}{\text{Volatility}_t}, & \text{if } \text{Volatility}_t > 0 \\ 0.0, & \text{otherwise} \end{cases}$$

The dynamic smoothing constant is applied recursively from the anchor point:
$$\text{SC}_t = \left[ \text{ER}_t \cdot (\alpha_{\text{fast}} - \alpha_{\text{slow}}) + \alpha_{\text{slow}} \right]^2$$
$$\text{AKAMA}_t = \text{AKAMA}_{t-1} + \text{SC}_t \cdot (P_t - \text{AKAMA}_{t-1})$$

---

### 2.2. Cumulative Intra-Session Standard Deviation ($\sigma_t$)

Standard deviation is calculated by accumulating the squared deviations of price relative to the dynamic AKAMA line strictly within the session:
$$\text{Variance}_t = \frac{1}{k_t + 1} \sum_{j=\text{Anchor Bar}}^{t} \left( P_j - \text{AKAMA}_j \right)^2$$
$$\sigma_t = \sqrt{\text{Variance}_t}$$

### 2.3. Volatility Band Multipliers

$$\text{Upper Band } n_t = \text{AKAMA}_t + (M_n \cdot \sigma_t)$$
$$\text{Lower Band } n_t = \text{AKAMA}_t - (M_n \cdot \sigma_t)$$
*where $M_1 = \text{InpBand1Mult}$ (default: $1.0$), $M_2 = \text{InpBand2Mult}$ (default: $2.0$), and $M_3 = \text{InpBand3Mult}$ (default: $3.0$).*

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│               KAMA_Anchored_Calculator.mqh             │
│   (Core Engine: Stateless Anchor & Local KAMA Engine)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs AKAMA Odd/Even & Price Series (O(1))
                           ▼
┌────────────────────────────────────────────────────────┐
│               KAMA_Anchored_Bands_Pro.mq5              │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (8)       │   MTF & Session Management  │
│   • 2 Centerline Plots   │   • DataSync_Tools.mqh      │
│   • 6 Volatility Bands   │   • Staircase Flat-Force    │
│   • Current Session Mask │   • Odd/Even Gapped Engine  │
└──────────────────────────┴─────────────────────────────┘

```

1. **Stateless Deterministic Engine:** `CKamaAnchoredCalculator` processes session transitions deterministically, eliminating static variable corruption during real-time tick recalculations.
2. **Session Lifetime & Active Retention:** The indicator identifies the active or most recently completed session and maintains its bands continuously, ensuring the session range remains visible during post-session hours until the next session opens.
3. **2026 MTF Framework with Staircase Solution:** Higher-timeframe session bands map into flat, synchronized steps on lower-timeframe charts via `first_bar_of_forming_htf` anchoring and `DataSync_Tools.mqh`.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it runs in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### Anchor Settings

* `InpResetPeriod` (*default: `ANCHOR_PERIOD_SESSION`*): Anchor mode (`ANCHOR_PERIOD_SESSION`, `ANCHOR_PERIOD_WEEK`, `ANCHOR_PERIOD_MONTH`, `ANCHOR_PERIOD_CUSTOM_SESSION`).
* `InpTzShift` (*default: `0`*): Timezone offset in hours to align midnight resets with broker server time.
* `InpCustomStart` (*default: `"08:00"`*): Session start time (`HH:MM`) when using `ANCHOR_PERIOD_CUSTOM_SESSION` (e.g., LSE Open).
* `InpCustomEnd` (*default: `"17:00"`*): Session end time (`HH:MM`) when using `ANCHOR_PERIOD_CUSTOM_SESSION` (e.g., LSE Close).

### KAMA Core Settings

* `InpErPeriod` (*default: `10`*): Lookback period ($N$) for the KAMA Efficiency Ratio.
* `InpFastEmaPeriod` (*default: `2`*): Fastest smoothing period ($F$) during high directional efficiency.
* `InpSlowEmaPeriod` (*default: `30`*): Slowest smoothing period ($S$) during low efficiency.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price source (Standard OHLC or Synthetic Heikin Ashi).

### Standard Deviation Bands Settings

* `InpBand1Mult` (*default: `1.0`*): Multiplier for Band 1 ($\pm 1.0\sigma$).
* `InpBand2Mult` (*default: `2.0`*): Multiplier for Band 2 ($\pm 2.0\sigma$).
* `InpBand3Mult` (*default: `3.0`*): Multiplier for Band 3 ($\pm 3.0\sigma$).
* `InpCurrentSessionOnly` (*default: `true`*): When enabled, purges historical session bands to keep the chart clean and focused on the active session.

### Visual Settings

* Full independent customization for centerline color, style, and width, as well as distinct colors for Band 1, Band 2, and Band 3.

---

## 5. Institutional Trading Playbooks (LSE & Session Ranges)

```text

┌────────────────────────────────────────────────────────────────────────┐
│                 LSE & INSTITUTIONAL SESSION PLAYBOOKS                  │
├────────────────────────────────────────────────────────────────────────┤
│ 1. LSE Open Breakout: Enter in direction of candle close outside +1σ   │
│                       when AKAMA slope accelerates at 08:00 London.    │
│ 2. Value Area Fade:   When AKAMA is flat during midday, fade rejections│
│                       at +2σ / -2σ back toward the AKAMA centerline.   │
│ 3. Climax Exhaustion: Spikes into ±3σ indicate unsustainable momentum. │
│                       Look for mean-reversion reversal entries.        │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The London Opening Range Breakout (LSE ORB)

* **Configuration:** Set `InpResetPeriod = ANCHOR_PERIOD_CUSTOM_SESSION`, `InpCustomStart = "08:00"`, `InpCustomEnd = "16:30"`.
* **Execution:** At the 08:00 London open, watch the expansion of the AKAMA centerline. A strong candle break beyond `Upper Band 1 (+1.0σ)` with an accelerating AKAMA confirms that European institutional capital is driving a directional trend.

### 5.2. Session Value Area Mean Reversion

* **Context:** During midday trading (e.g., 11:30 - 13:30 London time), the AKAMA centerline flattens into horizontal equilibrium.
* **Short Trigger:** Price tests `Upper Band 2 (+2.0σ)` and forms a rejection candle $\rightarrow$ Target: AKAMA Centerline.
* **Long Trigger:** Price tests `Lower Band 2 (-2.0σ)` and forms a rejection candle $\rightarrow$ Target: AKAMA Centerline.

### 5.3. Statistical Climax Reversal ($\pm 3.0\sigma$)

* Price touching or exceeding `Band 3 (±3.0σ)` represents a 3-standard-deviation tail event for the active session ($99.7\%$ Gaussian probability threshold).
* When a $3.0\sigma$ extension coincides with exhaustion on `KAMA_Acceleration_Pro`, it signals an institutional blow-off top or panic flush, offering high-reward counter-trend reversal opportunities.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufKAMA_Odd` | `INDICATOR_DATA` | Anchored KAMA Centerline (Odd Periods) |
| **1** | `BufKAMA_Even` | `INDICATOR_DATA` | Anchored KAMA Centerline (Even Periods - Gapped) |
| **2** | `BufUp1` | `INDICATOR_DATA` | Upper Volatility Band 1 ($+1.0\sigma$) |
| **3** | `BufDn1` | `INDICATOR_DATA` | Lower Volatility Band 1 ($-1.0\sigma$) |
| **4** | `BufUp2` | `INDICATOR_DATA` | Upper Volatility Band 2 ($+2.0\sigma$) |
| **5** | `BufDn2` | `INDICATOR_DATA` | Lower Volatility Band 2 ($-2.0\sigma$) |
| **6** | `BufUp3` | `INDICATOR_DATA` | Upper Volatility Band 3 ($+3.0\sigma$) |
| **7** | `BufDn3` | `INDICATOR_DATA` | Lower Volatility Band 3 ($-3.0\sigma$) |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
