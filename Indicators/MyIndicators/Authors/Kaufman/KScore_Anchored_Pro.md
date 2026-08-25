# Session-Anchored Kaufman's Adaptive Z-Score (AK-Score) Pro (v1.00)

Quantitative Session-Anchored Statistical Dispersion & Elasticity Oscillator

---

## 1. Summary (Introduction)

**KScore Anchored Pro (AK-Score Pro)** is an institutional-grade statistical momentum oscillator that measures intra-session price deviation from **Session-Anchored Kaufman's Adaptive Moving Average (AKAMA)** normalized in units of cumulative session standard deviation ($\sigma$).

While traditional rolling Z-Score indicators compute standard deviation across a fixed lookback window that inadvertently blends overnight low-volume drift with regular market hours, **AK-Score calculates dispersion strictly accumulated from the session anchor point**:

* **At Session Open (Anchor Bar):** AK-Score is initialized to $0.0\sigma$ (Neutral Gray), establishing an unpolluted baseline at market opens (such as the **London Stock Exchange (LSE)**, **Frankfurt**, or **New York Cash Open**).
* **During Session Expansion:** As institutional volume drives price away from the anchored mean, AK-Score measures whether the momentum is a healthy intra-session expansion ($+1.0\sigma \dots +1.5\sigma$) or has stretched into an unsustainable statistical climax ($> +2.0\sigma \dots +2.5\sigma$).
* **During Post-Session Hours:** When used with `ANCHOR_PERIOD_CUSTOM_SESSION`, the indicator cleanly disconnects during off-hours, ensuring that only valid institutional trading windows are evaluated.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        AK-SCORE DISPERSION MODEL                       │
├────────────────────────────────────────────────────────────────────────┤
│  AK-Score(t) = [ Price(t) - AKAMA(t) ] / IntraSession_StdDev(t)        │
│  Expressed in session-relative Standard Deviation multiples (σ)        │
└────────────────────────────────────────────────────────────────────────┘

```

---

## 2. Mathematical Foundations & Kinetic Dynamics

```text

                           +2.5σ (Extreme Session Climax)
          ───────────────────────────────────────────────────────────── DeepSkyBlue (Bull Climax)
                           +1.5σ (Bullish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - LightSkyBlue (Bull Flow)
                            0.0σ (Session Anchor / AKAMA Baseline)
          ───────────────────────────────────────────────────────────── Gray (Noise / Equilibrium)
                           -1.5σ (Bearish Flow Threshold)
          - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - Coral (Bear Flow)
                           -2.5σ (Extreme Session Climax)
          ───────────────────────────────────────────────────────────── OrangeRed (Bear Climax)

```

### 2.1. Anchor Reset & Intra-Session Lookback Expansion

At each session boundary bar ($t = \text{Anchor Bar}$), AKAMA initializes directly from the opening price:
$$\text{AKAMA}_{\text{anchor}} = P_{\text{anchor}}$$

For any subsequent bar within the active session ($k_t = t - \text{Anchor Bar}$):
$$N_{\text{eff}} = \min(k_t, N_{\text{ER}})$$
$$\text{Direction}_t = | P_t - P_{t - N_{\text{eff}}} |$$
$$\text{Volatility}_t = \sum_{j=0}^{N_{\text{eff}}-1} | P_{t-j} - P_{t-j-1} |$$
$$\text{ER}_t = \frac{\text{Direction}_t}{\text{Volatility}_t}$$
$$\text{AKAMA}_t = \text{AKAMA}_{t-1} + \text{SC}_t \cdot (P_t - \text{AKAMA}_{t-1})$$

---

### 2.2. Cumulative Intra-Session Standard Deviation ($\sigma_{\text{session}, t}$)

Standard deviation is calculated by accumulating the squared deviations of price relative to the evolving AKAMA line strictly within the session:
$$\text{Variance}_t = \frac{1}{k_t + 1} \sum_{j=\text{Anchor Bar}}^{t} \left( P_j - \text{AKAMA}_j \right)^2$$
$$\sigma_{\text{session}, t} = \sqrt{\text{Variance}_t}$$

### 2.3. Standardized AK-Score Formulation

$$AK\text{Score}_t = \begin{cases} \frac{P_t - \text{AKAMA}_t}{\sigma_{\text{session}, t}}, & \text{if } \sigma_{\text{session}, t} > 10^{-9} \\ 0.0, & \text{at anchor bar } (k_t = 0) \end{cases}$$

---

### 2.4. Swapped Thermal 5-Zone Color Palette

| State Index | Color | Classification | Sigma Level Trigger | Contextual Action |
| :---: | :---: | :--- | :--- | :--- |
| **0.0** | `clrGray` | **Neutral / Equilibrium** | $\|AK\text{Score}\| \le 1.5\sigma$ | Normal distribution around AKAMA; trend in balance. |
| **1.0** | `clrLightSkyBlue` | **Bullish Flow** | $+1.5\sigma < AK\text{Score} \le +2.0\sigma$ | Healthy intra-session upward impulse expansion. |
| **2.0** | `clrDeepSkyBlue` | **Bullish Climax** | $AK\text{Score} > +2.0\sigma$ | Parabolic intra-session exhaustion; prepare scale-out. |
| **3.0** | `clrCoral` | **Bearish Flow** | $-2.0\sigma \le AK\text{Score} < -1.5\sigma$ | Healthy intra-session downward impulse expansion. |
| **4.0** | `clrOrangeRed` | **Bearish Climax** | $AK\text{Score} < -2.0\sigma$ | Panic intra-session exhaustion; prepare short-covering. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│              KScore_Anchored_Calculator.mqh            │
│   (Core Engine: Encapsulated CKamaAnchoredCalculator)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Standardized AK-Score in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                 KScore_Anchored_Pro.mq5                │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (3)       │   Centralized Framework     │
│   • BufferAKScore (DATA) │   • DataSync_Tools.mqh      │
│   • BufferColors (INDEX) │   • MovingAverage_Engine    │
│   • BufferSignal (DATA)  │   • Dynamic Sigma Levels    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Defensive Memory & Auto-Resizing Engine:** `CKScoreAnchoredCalculator` implements auto-resizing safety guards for all internal dynamic arrays (`m_kama_odd`, `m_kama_even`, `m_price`, `out_akscore`), guaranteeing 100% crash-proof execution.
2. **Stateless Session Tracking:** Compares bar timestamps deterministically, ensuring that real-time tick recalculations never corrupt historical session registers.
3. **2026 MTF Framework (`DataSync_Tools.mqh`):** Higher-timeframe AK-Score histograms map into synchronized steps on lower-timeframe execution charts with zero step-warping.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### Anchor Settings

* `InpResetPeriod` (*default: `ANCHOR_PERIOD_SESSION`*): Anchor mode (`ANCHOR_PERIOD_SESSION`, `ANCHOR_PERIOD_WEEK`, `ANCHOR_PERIOD_MONTH`, `ANCHOR_PERIOD_CUSTOM_SESSION`).
* `InpTzShift` (*default: `0`*): Timezone offset in hours to align resets with broker server time.
* `InpCustomStart` (*default: `"08:00"`*): Session start time (`HH:MM`) when using `ANCHOR_PERIOD_CUSTOM_SESSION` (e.g., LSE Open).
* `InpCustomEnd` (*default: `"17:00"`*): Session end time (`HH:MM`) when using `ANCHOR_PERIOD_CUSTOM_SESSION` (e.g., LSE Close).

### KAMA Core Settings

* `InpErPeriod` (*default: `10`*): Lookback period ($N$) for the KAMA Efficiency Ratio.
* `InpFastEmaPeriod` (*default: `2`*): Fastest smoothing period ($F$) during strong directional efficiency.
* `InpSlowEmaPeriod` (*default: `30`*): Slowest smoothing period ($S$) during consolidation.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price series (Standard OHLC or Synthetic Heikin Ashi).

### Signal Line Settings

* `InpShowSignal` (*default: `true`*): Toggle visibility of the Signal Moving Average line.
* `InpSignalPeriod` (*default: `5`*): Lookback period for the signal line.
* `InpSignalType` (*default: `EMA`*): Smoothing algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpColorSignal` (*default: `clrFireBrick`*): Color applied to the signal line plot.

### Indicator Levels (Sigma Units)

* `InpLevelFlowHigh` (*default: `1.5`*): Bullish Flow warning boundary.
* `InpLevelFlowLow` (*default: `-1.5`*): Bearish Flow warning boundary.
* `InpLevelClimaxHigh` (*default: `2.0`*): Bullish Climax threshold (`DeepSkyBlue`).
* `InpLevelClimaxLow` (*default: `-2.0`*): Bearish Climax threshold (`OrangeRed`).
* `InpLevelExtremeHigh` (*default: `2.5`*): Extreme statistical exhaustion level.
* `InpLevelExtremeLow` (*default: `-2.5`*): Extreme statistical capitulation level.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

---

## 5. Institutional Trading Playbooks (The Custom Session Advantage)

```text

┌────────────────────────────────────────────────────────────────────────┐
│                 INSTITUTIONAL CUSTOM SESSION PLAYBOOKS                 │
├────────────────────────────────────────────────────────────────────────┤
│ 1. LSE Breakout Filter:  Confirm London opening breakout when AK-Score │
│                          crosses +1.5σ with Signal MA confirmation.    │
│ 2. Session Climax Fade:  When AK-Score hits +2.5σ in late session,     │
│                          prepare to fade back to the AKAMA mean.       │
│ 3. Squeeze Invalidation: In tight session ranges, spikes into ±2.0σ   │
│                          identify liquidity sweeps (false breakouts).  │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The London Opening Session Momentum Trigger (LSE Open)

* **Configuration:** `InpResetPeriod = ANCHOR_PERIOD_CUSTOM_SESSION`, `InpCustomStart = "08:00"`, `InpCustomEnd = "16:30"`.
* **Execution:** At the 08:00 London bell, AK-Score starts at $0.0\sigma$. If European institutional order flow drives price aggressively:
  * A cross above `+1.5σ (LightSkyBlue)` confirmed by the Signal MA line validates that institutional capital is actively expanding the session range $\rightarrow$ Enter Long.
  * A cross below `-1.5σ (Coral)` confirmed by the Signal MA validates downward expansion $\rightarrow$ Enter Short.

### 5.2. Session Climax & Late-Day Mean Reversion

* If AK-Score spikes above `+2.0σ` or `+2.5σ (DeepSkyBlue)` during midday or late session and then crosses **below** the Signal MA line:
  * **Action:** Close trend-following long positions or enter mean-reversion counter-trades targeting the session AKAMA baseline ($0.0\sigma$).

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufferAKScore` | `INDICATOR_DATA` | Standardized AK-Score Values in Session Sigma Multiples ($\sigma$) |
| **1** | `BufferColors` | `INDICATOR_COLOR_INDEX` | Swapped Thermal 5-Zone Palette Index ($0.0 \dots 4.0$) |
| **2** | `BufferSignal` | `INDICATOR_DATA` | Smoothed Signal Moving Average Plot |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with MetaTrader 5 Expert Advisors via `iCustom()`.*
