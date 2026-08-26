# Volume-Weighted Z-Score (V-Score) Chart HUD Widgets Pro Suite

*Quantitative Single-Asset & Dual-Horizon Volatility Dispersion Telemetry Suite*
*(Covering: VScore_Widget_Pro & VScore_Dual_Widget_Pro - Version 2.00)*

---

## 1. Summary (Introduction)

The **V-Score HUD Widget Suite** comprises two institutional Heads-Up Display (HUD) telemetry tools designed to deliver real-time statistical volume dispersion intelligence directly on the primary chart:

1. **`VScore_Widget_Pro` (Single-Slot HUD):** A compact 2-cell table monitoring a single user-defined higher-timeframe V-Score.
2. **`VScore_Dual_Widget_Pro` (Dual-Slot HUD):** A 3-cell dual-horizon table monitoring both **Tactical Intraday Flow** (e.g., Daily Session on M15) and **Strategic Macro Context** (e.g., Weekly Session on H1) side-by-side.

Both widgets anchor directly to the lower-left corner (`CORNER_LEFT_LOWER`) of the primary price chart, eliminating the requirement to sacrifice chart window height for auxiliary oscillator subwindows.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   DUAL-SLOT HUD TELEMETRY INTERFACE                    │
├───────────────┬────────────────────────┬───────────────────────────────┤
│ [Header Row]  │ Symbol                 │ Daily (M15)  │ Weekly (H1)    │
│ [Data Row]    │ EURUSD                 │ -1.91 σ [CO] │ -2.34 σ [OR]   │
└───────────────┴────────────────────────┴───────────────────────────────┘
  *CO = Coral (Bear Flow) | OR = OrangeRed (Bear Climax)

```

### Core Value Proposition

* **Zero Subwindow Clutter:** Delivers instant, multi-timeframe volume-weighted statistical awareness while leaving the chart window 100% dedicated to price action and structure.
* **Instant Multi-Horizon Confluence:** Exposes whether an intraday price move is a healthy trend continuation or an over-extended statistical climax relative to larger institutional horizons.
* **7-Zone Super-Thermal Telemetry:** Provides immediate visual recognition across 7 thermodynamic states ranging from neutral equilibrium to extreme 3-sigma exhaustion.
* **Heap-Free Stack Execution:** Operates with zero dynamic memory allocation (`new`/`delete`) inside update loops, guaranteeing zero thread bloat and memory stability.

---

## 2. The Dual-Horizon Confluence Model

In systematic trading, evaluating a single timeframe often creates a false-exhaustion paradox. An intraday move on M15 may appear over-extended at $-2.0\sigma$, yet on the H1 Weekly timeframe, the market may just be initiating a major structural trend breakout. The Dual Widget resolves this by contrasting both horizons simultaneously:

```text

┌───────────────────────────┬───────────────────────────┬────────────────────────────────────────┐
│ Slot 1: Tactical (M15)    │ Slot 2: Strategic (H1)    │ Systematic Market Action               │
├───────────────────────────┼───────────────────────────┼────────────────────────────────────────┤
│ Flow (+1.5σ LightBlue)    │ Fair-Value (0.0σ Gray)    │ High-Conviction Long Trend Breakout.   │
│ Climax (+2.1σ DeepBlue)   │ Flow (+1.7σ LightBlue)    │ Strong Uptrend Active; Tighten Stops.  │
│ Climax (+2.3σ DeepBlue)   │ Climax (+2.2σ DeepBlue)   │ Multi-Timeframe Climax; Scale Out.     │
│ Flow (-1.6σ Coral)        │ Fair-Value (0.0σ Gray)    │ High-Conviction Short Trend Breakdown. │
│ Climax (-2.4σ OrangeRed)  │ Climax (-2.3σ OrangeRed)  │ Multi-Timeframe Capitulation Floor.    │
│ Extreme (-2.6σ DarkRed)   │ Climax (-2.2σ OrangeRed)  │ Extreme Exhaustion; Prepare Bounce.    │
└───────────────────────────┴───────────────────────────┴────────────────────────────────────────┘

```

---

## 3. Mathematical Foundations & 7-Zone Thermal Matrix

$$V\text{Score} = \frac{\text{Close} - \mu_{\text{VWAP}}}{\sigma_V}$$
*where $\mu_{\text{VWAP}}$ is the volume-weighted average price and $\sigma_V$ is the rolling standard deviation of price deviations from VWAP over period $P$.*

```text

                        +2.5σ (Extreme Bull Exhaustion)
       ───────────────────────────────────────────────── clrMidnightBlue
                        +2.0σ (Bullish Climax)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrDeepSkyBlue
                        +1.5σ (Bullish Flow)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrLightSkyBlue
                         0.0σ (VWAP Fair-Value Baseline)
       ───────────────────────────────────────────────── clrWhite (Neutral Range)
                        -1.5σ (Bearish Flow)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrCoral
                        -2.0σ (Bearish Climax)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrOrangeRed
                        -2.5σ (Extreme Bear Exhaustion)
       ───────────────────────────────────────────────── clrDarkRed

```

### Symmetrical 7-Zone Super-Thermal Matrix

| Zone State | Background Color | Text Color | Sigma Trigger | Institutional Market Action |
| :--- | :--- | :--- | :--- | :--- |
| **Bull Extreme** | `clrMidnightBlue` | `clrWhite` | $V\text{Score} \ge +2.5\sigma$ | **Extreme Parabolic Exhaustion:** Unsustainable premium; scale out long positions or prepare short fade. |
| **Bull Climax** | `clrDeepSkyBlue` | `clrWhite` | $+2.0\sigma \le V\text{Score} < +2.5\sigma$ | **Overbought Climax:** Heavy institutional volume expansion; tighten trailing stop-loss. |
| **Bull Flow** | `clrLightSkyBlue` | `clrBlack` | $+1.5\sigma \le V\text{Score} < +2.0\sigma$ | **Bullish Momentum Flow:** Institutional markup phase active; favor long continuation setups. |
| **Neutral Range** | `clrWhite` | `clrDarkGray` | $-1.5\sigma < V\text{Score} < +1.5\sigma$ | **Fair-Value Equilibrium:** Standard consolidation noise; market in balance around VWAP. |
| **Bear Flow** | `clrCoral` | `clrBlack` | $-2.0\sigma < V\text{Score} \le -1.5\sigma$ | **Bearish Momentum Flow:** Institutional markdown phase active; favor short continuation setups. |
| **Bear Climax** | `clrOrangeRed` | `clrWhite` | $-2.5\sigma < V\text{Score} \le -2.0\sigma$ | **Oversold Climax:** Heavy institutional selling push; prepare short-covering. |
| **Bear Extreme** | `clrDarkRed` | `clrWhite` | $V\text{Score} \le -2.5\sigma$ | **Panic Capitulation Floor:** Severe statistical discount; high-probability long bounce potential. |

---

## 4. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│            VScore_HUD_Widgets_Pro (Engine)             │
│    (Zero-Subwindow Telemetry & Graphical Layout Engine)│
├──────────────────────────┬─────────────────────────────┤
│   Heap-Free Execution    │   Centralized Framework     │
│   • Stack CVScoreCalc    │   • DataSync_Tools.mqh      │
│   • 200ms Rate Throttling│   • VScore_Calculator v3.00 │
│   • Dynamic Lookback     │   • 7-Zone Thermal Palette  │
└──────────────────────────┴─────────────────────────────┘

```

1. **Heap-Free Execution Model:** `GetVScoreValue()` instantiates `CVScoreCalculator calc;` on the local stack frame. All price and volume arrays are managed locally, eliminating thread bloat and memory fragmentation.
2. **Centralized Data Synchronization (`DataSync_Tools.mqh`):** Employs `CDataSync::EnsureHTFDataReady` for asynchronous, non-blocking history loading.
3. **Standardized HUD Geometry:**
   * Anchor Corner: `CORNER_LEFT_LOWER`.
   * Data Row Y-coordinate: `InpTableY` (e.g., 30 px).
   * Header Row Y-coordinate: `InpTableY + row_h + 2` (e.g., 54 px, growing upwards).
4. **Dynamic History Lookback Scaling:** Automatically determines required historical depth based on the selected anchor mode (Session: ~1 day, Week: ~7 days, Month: ~31 days) up to a 3000-bar safety ceiling.
5. **Tick Rate Throttling:** Built-in rate-limiter caps UI object redraws to a maximum of 5 updates per second (200 ms), preventing GUI thread saturation during high-frequency live tick floods.

---

## 5. Parameters Reference

### 5.1. `VScore_Widget_Pro.mq5` (Single-Slot)

| Parameter Group | Name | Default | Description |
| :--- | :--- | :--- | :--- |
| **HUD Settings** | `InpTimeframe` | `PERIOD_M15` | Target higher timeframe evaluated by widget telemetry. |
| | `InpRefreshSeconds` | `3` | Background timer interval for periodic refresh. |
| **V-Score Settings** | `InpVScorePeriod` | `20` | Volatility lookback period ($P$) for standard deviation. |
| | `InpVWAPReset` | `PERIOD_SESSION` | VWAP anchor mode (`SESSION`, `WEEK`, `MONTH`, `CUSTOM`). |
| | `InpTzShift` | `0` | Timezone offset in hours vs broker server time. |
| | `InpCustomSessionStart` | `"09:30"` | Custom session start time (`HH:MM`). |
| | `InpCustomSessionEnd` | `"16:00"` | Custom session end time (`HH:MM`). |
| **Calculation** | `InpVolumeType` | `VOLUME_TICK` | Volume source (`VOLUME_TICK` or `VOLUME_REAL`). |
| | `InpCandleSource` | `CANDLE_STANDARD` | Price source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`). |
| **Indicator Levels** | `InpLevelFlowHigh/Low` | `1.5 / -1.5` | Flow warning boundaries (`LightSkyBlue` / `Coral`). |
| | `InpLevelClimaxHigh/Low` | `2.0 / -2.0` | Climax thresholds (`DeepSkyBlue` / `OrangeRed`). |
| | `InpLevelExtremeHigh/Low` | `2.5 / -2.5` | Extreme exhaustion thresholds (`MidnightBlue` / `DarkRed`). |
| **Placement** | `InpTableX` | `20` | Horizontal pixel offset from left chart border. |
| | `InpTableY` | `30` | Vertical pixel offset from bottom chart border. |
| | `InpFontSize` | `9` | Font size of button cells. |

---

### 5.2. `VScore_Dual_Widget_Pro.mq5` (Dual-Slot)

| Parameter Group | Name | Default | Description |
| :--- | :--- | :--- | :--- |
| **HUD Settings** | `InpRefreshSeconds` | `3` | Background timer refresh interval. |
| **Slot 1 (Tactical)** | `InpSlot1Label` | `"Daily"` | Custom label text for Slot 1 header. |
| | `InpSlot1TF` | `PERIOD_M15` | Timeframe for Slot 1 calculation. |
| | `InpSlot1Reset` | `PERIOD_SESSION` | Anchor reset mode for Slot 1. |
| | `InpSlot1Period` | `20` | Volatility lookback period ($P$) for Slot 1. |
| **Slot 2 (Strategic)** | `InpSlot2Label` | `"Weekly"` | Custom label text for Slot 2 header. |
| | `InpSlot2TF` | `PERIOD_H1` | Timeframe for Slot 2 calculation. |
| | `InpSlot2Reset` | `PERIOD_WEEK` | Anchor reset mode for Slot 2. |
| | `InpSlot2Period` | `20` | Volatility lookback period ($P$) for Slot 2. |
| **Calculation** | `InpVolumeType` | `VOLUME_TICK` | Volume source (`VOLUME_TICK` or `VOLUME_REAL`). |
| | `InpCandleSource` | `CANDLE_STANDARD` | Price source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`). |
| | `InpTzShift` | `0` | Timezone offset in hours vs broker server time. |
| | `InpCustomSessionStart` | `"09:30"` | Custom session start time (`HH:MM`). |
| | `InpCustomSessionEnd` | `"16:00"` | Custom session end time (`HH:MM`). |
| **Indicator Levels** | `InpLevelFlowHigh/Low` | `1.5 / -1.5` | Flow warning boundaries. |
| | `InpLevelClimaxHigh/Low` | `2.0 / -2.0` | Climax thresholds. |
| | `InpLevelExtremeHigh/Low` | `2.5 / -2.5` | Extreme exhaustion thresholds. |
| **Placement** | `InpTableX` | `20` | Horizontal pixel offset from left chart border. |
| | `InpTableY` | `30` | Vertical pixel offset from bottom chart border. |
| | `InpFontSize` | `9` | Font size of button cells. |

---

## 6. Tactical Trading & Execution Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   TACTICAL HUD TELEMETRY PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Multi-Horizon Trend Alignment: Enter M1/M5 pullbacks only when both │
│                                   Slot 1 (M15) and Slot 2 (H1) agree.  │
│ 2. False Breakout Trap Filter:    When Slot 1 hits +2.0σ but Slot 2 is │
│                                   Neutral (0σ), expect range fade.     │
│ 3. Extreme Exhaustion Fade:       When either slot hits MidnightBlue   │
│                                   (+2.5σ) or DarkRed (-2.5σ), scale out│
└────────────────────────────────────────────────────────────────────────┘

```

### 6.1. Intraday Scalping Macro Filter

* **Setup:** Place `VScore_Dual_Widget_Pro` on an `M1` or `M5` execution chart with `Slot 1 = M15 (Daily)` and `Slot 2 = H1 (Weekly)`.
* **Execution Rules:**
  * **Long Bias:** If Slot 1 is **`LightSkyBlue (+1.5σ)`** and Slot 2 is **`Gray (0.0σ)`** or **`LightSkyBlue`** $\rightarrow$ High-conviction long trend markup.
  * **Short Bias:** If Slot 1 is **`Coral (-1.5σ)`** and Slot 2 is **`Gray (0.0σ)`** or **`Coral`** $\rightarrow$ High-conviction short trend markdown.
  * **Range Bound:** If both slots are **`White (Neutral)`** $\rightarrow$ Trade boundary mean-reversion setups.

### 6.2. The Dual-Horizon Climax Reversal ($\ge \pm 2.0\sigma \dots \pm 2.5\sigma$)

* **Trigger:** Slot 1 turns **`DeepSkyBlue`** ($+2.0\sigma$) or **`MidnightBlue`** ($+2.5\sigma$) while Slot 2 also shows **`DeepSkyBlue`** ($+2.0\sigma$).
* **Action:** This confirms a synchronous multi-timeframe volume exhaustion. Abort new trend-following entries and look for lower-timeframe structural reversal patterns to initiate counter-trend mean-reversion trades back toward the VWAP fair-value equilibrium.
