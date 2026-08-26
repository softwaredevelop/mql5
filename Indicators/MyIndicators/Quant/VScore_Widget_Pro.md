# Volume-Weighted Z-Score (V-Score) Chart HUD Widget Pro (v2.00)

Quantitative Real-Time Single-Asset Volatility & Institutional Dispersion Telemetry Widget

---

## 1. Summary (Introduction)

**V-Score Widget Pro** is an institutional Heads-Up Display (HUD) telemetry tool designed to monitor higher-timeframe **Volume-Weighted Z-Score (V-Score)** directly on the primary price chart without occupying valuable subwindow screen real estate.

Positioned unobtrusively in the lower-left corner (`CORNER_LEFT_LOWER`), the widget continuously computes the exact statistical dispersion of the active asset relative to its **Volume-Weighted Average Price (VWAP)** in standardized Sigma units ($\sigma$). Utilizing a **7-Zone Super-Thermal color matrix**, it alerts traders instantly to institutional volume flow, parabolic climax expansions, and extreme mean-reverting exhaustion.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        HUD TELEMETRY INTERFACE                         │
├────────────────────────────────────────────────────────────────────────┤
│  [Header Row]  │ Symbol (M15)             │ V-Score                    │
│  [Data Row]    │ EURUSD                   │ +2.15 σ [DeepSkyBlue]      │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **Compact Single-Asset HUD:** Renders a clean 2-cell table displaying the active symbol, target MTF timeframe, and live volume-weighted Sigma dispersion.
* **7-Zone Super-Thermal Palette:** Provides clear visual contrast across 7 distinct thermodynamic states (Neutral, Bull Flow, Bull Climax, Bull Extreme Exhaustion, Bear Flow, Bear Climax, Bear Extreme Exhaustion).
* **Heap-Free Stack Execution Engine:** Instantiates `CVScoreCalculator` directly on the local thread stack, ensuring zero heap allocations (`new`/`delete`) and preventing memory leaks during rapid live tick streams.
* **Integrated 2026 DataSync Daemon:** Employs `DataSync_Tools.mqh` (`EnsureHTFDataReady`) for non-blocking, asynchronous higher-timeframe history retrieval.
* **Full Session & Volume Flexibility:** Supports Daily, Weekly, Monthly, and Custom Sessions (e.g., LSE `08:00 - 16:30`), Timezone Shifts, Real Volume (`VOLUME_REAL`), and Synthetic Heikin Ashi pricing.
* **Tick Throttling:** Built-in rate-limiter caps UI object redraws to a maximum of 5 updates per second (200 ms), preventing GUI thread saturation during high-frequency market volatility.

---

## 2. Mathematical Foundations & 7-Zone Thermal Matrix

```text

                        +2.5σ (Extreme Bull Exhaustion)
       ───────────────────────────────────────────────── clrMidnightBlue
                        +2.0σ (Bullish Climax)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrDeepSkyBlue
                        +1.5σ (Bullish Flow)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrLightSkyBlue
                         0.0σ (VWAP Fair-Value Baseline)
       ───────────────────────────────────────────────── clrWhite (Neutral Noise)
                        -1.5σ (Bearish Flow)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrCoral
                        -2.0σ (Bearish Climax)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrOrangeRed
                        -2.5σ (Extreme Bear Exhaustion)
       ───────────────────────────────────────────────── clrDarkRed

```

### 2.1. Underlying V-Score Telemetry Metric

$$V\text{Score} = \frac{\text{Close} - \mu_{\text{VWAP}}}{\sigma_V}$$
*where $\mu_{\text{VWAP}}$ is the volume-weighted mean price and $\sigma_V$ is the rolling standard deviation of price deviations from VWAP over period $P = \text{InpVScorePeriod}$.*

---

### 2.2. Symmetrical 7-Zone Super-Thermal Matrix

| Zone State | Background Color | Text Color | Sigma Trigger | Institutional Market Action |
| :--- | :--- | :--- | :--- | :--- |
| **Bull Extreme** | `clrMidnightBlue` | `clrWhite` | $V\text{Score} \ge +2.5\sigma$ | **Extreme Parabolic Exhaustion:** Unsustainable premium; prepare immediate scale-out or short reversal. |
| **Bull Climax** | `clrDeepSkyBlue` | `clrWhite` | $+2.0\sigma \le V\text{Score} < +2.5\sigma$ | **Overbought Climax:** Heavy institutional volume expansion; tighten trailing stops. |
| **Bull Flow** | `clrLightSkyBlue` | `clrBlack` | $+1.5\sigma \le V\text{Score} < +2.0\sigma$ | **Bullish Momentum Flow:** Institutional markup phase active; favor long continuation setups. |
| **Neutral Range** | `clrWhite` | `clrDarkGray` | $-1.5\sigma < V\text{Score} < +1.5\sigma$ | **Fair-Value Equilibrium:** Standard consolidation noise; market in balance around VWAP. |
| **Bear Flow** | `clrCoral` | `clrBlack` | $-2.0\sigma < V\text{Score} \le -1.5\sigma$ | **Bearish Momentum Flow:** Institutional markdown phase active; favor short continuation setups. |
| **Bear Climax** | `clrOrangeRed` | `clrWhite` | $-2.5\sigma < V\text{Score} \le -2.0\sigma$ | **Oversold Climax:** Heavy institutional selling push; prepare short-covering. |
| **Bear Extreme** | `clrDarkRed` | `clrWhite` | $V\text{Score} \le -2.5\sigma$ | **Panic Capitulation Floor:** Severe statistical discount; high-probability long bounce potential. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│               VScore_Widget_Pro.mq5 (HUD)              │
│    (Zero-Subwindow Telemetry & Graphical Layout Engine)│
├──────────────────────────┬─────────────────────────────┤
│   Heap-Free Execution    │   Centralized Framework     │
│   • Stack CVScoreCalc    │   • DataSync_Tools.mqh      │
│   • 200ms Rate Throttling│   • VScore_Calculator v3.00 │
│   • Dynamic Lookback     │   • 7-Zone Thermal Palette  │
└──────────────────────────┴─────────────────────────────┘

```

1. **Heap-Free Execution Model:** `GetVScoreValue()` instantiates `CVScoreCalculator calc;` on the local stack frame. All internal price/volume arrays are allocated safely in local scope, eliminating thread bloat and memory fragmentation.
2. **Standardized HUD Geometry:**
   * Anchor Corner: `CORNER_LEFT_LOWER`.
   * Data Row Y-coordinate: `InpTableY` (e.g., 30 px).
   * Header Row Y-coordinate: `InpTableY + row_h + 2` (e.g., 54 px, growing upwards).
3. **Dynamic History Lookback Scaling:** Automatically determines required historical depth based on the selected anchor mode (Session: ~1 day, Week: ~7 days, Month: ~31 days) up to a safety ceiling of 3000 bars.

---

## 4. Parameters Reference

### Heads-Up Display Settings

* `InpTimeframe` (*default: `PERIOD_M15`*): Target higher timeframe evaluated by the widget telemetry.
* `InpRefreshSeconds` (*default: `3`*): Background timer interval for periodic telemetry refresh.

### V-Score Settings

* `InpVScorePeriod` (*default: `20`*): Lookback period ($P$) for computing standard deviation variance around VWAP.
* `InpVWAPReset` (*default: `PERIOD_SESSION`*): VWAP anchor mode (`PERIOD_SESSION`, `PERIOD_WEEK`, `PERIOD_MONTH`, `PERIOD_CUSTOM_SESSION`).
* `InpTzShift` (*default: `0`*): Timezone offset in hours to align resets with broker server time.
* `InpCustomSessionStart` (*default: `"09:30"`*): Custom session start time (`HH:MM`).
* `InpCustomSessionEnd` (*default: `"16:00"`*): Custom session end time (`HH:MM`).

### Calculation Settings

* `InpVolumeType` (*default: `VOLUME_TICK`*): Volume source (`VOLUME_TICK` or `VOLUME_REAL`).
* `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).

### Indicator Levels (Sigma Units)

* `InpLevelFlowHigh` (*default: `1.5`*): Bullish Flow warning boundary (`LightSkyBlue`).
* `InpLevelFlowLow` (*default: `-1.5`*): Bearish Flow warning boundary (`Coral`).
* `InpLevelClimaxHigh` (*default: `2.0`*): Bullish Climax threshold (`DeepSkyBlue`).
* `InpLevelClimaxLow` (*default: `-2.0`*): Bearish Climax threshold (`OrangeRed`).
* `InpLevelExtremeHigh` (*default: `2.5`*): Extreme Bull Exhaustion threshold (`MidnightBlue`).
* `InpLevelExtremeLow` (*default: `-2.5`*): Extreme Bear Exhaustion threshold (`DarkRed`).

### Widget Placement (Pixels)

* `InpTableX` (*default: `20`*): Horizontal pixel offset from the left chart border.
* `InpTableY` (*default: `30`*): Vertical pixel offset from the bottom chart border.
* `InpFontSize` (*default: `9`*): Font size of the HUD button cells.

---

## 5. Tactical Trading & Execution Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   TACTICAL HUD TELEMETRY PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Macro Trend Confluence: Trade M1/M5 pullbacks only in the direction │
│                            of the M15/H1 HUD Widget Flow (+1.5σ).      │
│ 2. Parabolic Top Warning:  When HUD turns MidnightBlue (+2.5σ), abort  │
│                            new long entries and lock in partial gains. │
│ 3. Squeeze Breakout Alert: When HUD breaks from White (0σ) to LightBlue│
│                            (+1.5σ), enter in direction of session flow.│
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Intraday Scalping Macro Filter

* **Setup:** Place `VScore_Widget_Pro` on an `M1` or `M5` execution chart, configured to `InpTimeframe = PERIOD_M15` or `PERIOD_H1`.
* **Execution Rule:**
  * If the Widget cell is **`clrLightSkyBlue (+1.5σ)`**, only take long scalp entries on the lower timeframe.
  * If the Widget cell is **`clrCoral (-1.5σ)`**, only take short scalp entries.
  * If the Widget cell is **`clrWhite (Neutral)`**, trade range-bound mean-reversion setups.

### 5.2. The Extreme Exhaustion Scalp Fade ($\ge \pm 2.5\sigma$)

* **Trigger:** The Widget turns **`clrMidnightBlue`** ($\ge +2.5\sigma$) or **`clrDarkRed`** ($\le -2.5\sigma$).
* **Action:** This signifies a statistical 3-sigma tail risk event relative to committed volume. Look for lower-timeframe reversal candle patterns (such as pin bars or engulfing candles) to initiate high-reward mean-reversion counter-trades back toward the VWAP fair-value equilibrium.
