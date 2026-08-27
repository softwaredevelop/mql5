# Volume-Weighted Z-Score (V-Score) Multi-Asset Dashboards Pro Suite

*Quantitative Multi-Asset & Dual-Horizon Volatility Dispersion Scanner Suite*
*(Covering: VScore_Dashboard_Pro & VScore_Dual_Dashboard_Pro - Version 3.00)*

---

## 1. Summary (Introduction)

The **V-Score Multi-Asset Dashboard Suite** comprises two institutional-grade scanning and market-screening panels:

1. **`VScore_Dashboard_Pro` (Single-Column Scanner):** An ultra-compact, minimalist scanner designed to monitor single-timeframe Volume-Weighted Z-Score across an entire watch list of 15–20 assets with a minimal screen footprint.
2. **`VScore_Dual_Dashboard_Pro` (Dual-Column Scanner):** An institutional multi-horizon matrix scanner that evaluates **Tactical Intraday Flow** (e.g., Daily Session on M15) and **Strategic Macro Context** (e.g., Weekly Session on H1) side-by-side across the entire watch list.

Positioned in the upper-left corner (`CORNER_LEFT_UPPER`), both dashboards evaluate the exact statistical dispersion of assets relative to their **Volume-Weighted Average Price (VWAP)** in standardized Sigma units ($\sigma$) with strict **3-decimal precision** (`0.000 σ`), featuring **1-click interactive chart switching**.

```text

┌────────────────────────────────────────────────────────────────────────┐
│               DUAL-COLUMN SCANNER INTERFACE (TOP-LEFT)                 │
├───────────────┬────────────────────────┬───────────────────────────────┤
│ [Header]      │ Symbol                 │ Daily (M15)  │ Weekly (H1)    │
├───────────────┼────────────────────────┼──────────────┼────────────────┤
│ [Row 1]       │ EURUSD [Clickable]     │ -1.912 σ [CO]│ -2.345 σ [OR]  │
│ [Row 2]       │ GBPUSD [Clickable]     │ +1.650 σ [LB]│ +0.420 σ [GR]  │
│ [Row 3]       │ US500  [Clickable]     │ +2.155 σ [DB]│ +1.820 σ [LB]  │
│ [Row 4]       │ BTCUSD [Clickable]     │ +2.610 σ [MB]│ +2.230 σ [DB]  │
└───────────────┴────────────────────────┴──────────────┴────────────────┘
  *MB = MidnightBlue | DB = DeepSkyBlue | LB = LightSkyBlue | GR = Gray
  *CO = Coral | OR = OrangeRed | DR = DarkRed

```

---

## 2. Multi-Asset Scanning & Dual-Horizon Confluence

```text

┌───────────────────────────┬───────────────────────────┬────────────────────────────────────────┐
│ Slot 1: Tactical (M15)    │ Slot 2: Strategic (H1)    │ Systematic Market Action               │
├───────────────────────────┼───────────────────────────┼────────────────────────────────────────┤
│ Flow (+1.500σ LightBlue)  │ Fair-Value (0.000σ Gray)  │ High-Conviction Long Trend Breakout.   │
│ Climax (+2.100σ DeepBlue) │ Flow (+1.750σ LightBlue)  │ Strong Uptrend Active; Tighten Stops.  │
│ Climax (+2.350σ DeepBlue) │ Climax (+2.250σ DeepBlue) │ Multi-Timeframe Climax; Scale Out.     │
│ Extreme (+2.650σ MidBlue) │ Climax (+2.300σ DeepBlue) │ Parabolic Blow-Off; Prepare Reversal.  │
│ Flow (-1.650σ Coral)      │ Fair-Value (0.000σ Gray)  │ High-Conviction Short Trend Breakdown. │
│ Climax (-2.400σ OrangeRed)│ Climax (-2.300σ OrangeRed)│ Multi-Timeframe Capitulation Floor.    │
│ Extreme (-2.750σ DarkRed) │ Climax (-2.400σ OrangeRed)│ Panic Capitulation; Prepare Long Fade. │
└───────────────────────────┴───────────────────────────┴────────────────────────────────────────┘

```

---

## 3. Mathematical Foundations & 7-Zone Super-Thermal Matrix

$$V\text{Score} = \frac{\text{Close} - \mu_{\text{VWAP}}}{\sigma_V}$$
*where $\mu_{\text{VWAP}}$ is the volume-weighted mean price and $\sigma_V$ is the rolling standard deviation of price deviations from VWAP over period $P$.*

```text

                        +2.500σ (Extreme Bull Exhaustion)
       ───────────────────────────────────────────────── clrMidnightBlue
                        +2.000σ (Bullish Climax)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrDeepSkyBlue
                        +1.500σ (Bullish Flow)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrLightSkyBlue
                         0.000σ (VWAP Fair-Value Baseline)
       ───────────────────────────────────────────────── clrWhite (Neutral Range)
                        -1.500σ (Bearish Flow)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrCoral
                        -2.000σ (Bearish Climax)
       - - - - - - - - - - - - - - - - - - - - - - - - - clrOrangeRed
                        -2.500σ (Extreme Bear Exhaustion)
       ───────────────────────────────────────────────── clrDarkRed

```

### Symmetrical 7-Zone Super-Thermal Matrix

| Zone State | Background Color | Text Color | Sigma Trigger | Institutional Market Action |
| :--- | :--- | :--- | :--- | :--- |
| **Bull Extreme** | `clrMidnightBlue` | `clrWhite` | $V\text{Score} \ge +2.500\sigma$ | **Extreme Parabolic Exhaustion:** Unsustainable premium; scale out long positions or prepare short fade. |
| **Bull Climax** | `clrDeepSkyBlue` | `clrWhite` | $+2.000\sigma \le V\text{Score} < +2.500\sigma$ | **Overbought Climax:** Heavy institutional volume expansion; tighten trailing stop-loss. |
| **Bull Flow** | `clrLightSkyBlue` | `clrBlack` | $+1.500\sigma \le V\text{Score} < +2.000\sigma$ | **Bullish Momentum Flow:** Institutional markup phase active; favor long continuation setups. |
| **Neutral Range** | `clrWhite` | `clrDarkGray` | $-1.500\sigma < V\text{Score} < +1.500\sigma$ | **Fair-Value Equilibrium:** Standard consolidation noise; market in balance around VWAP. |
| **Bear Flow** | `clrCoral` | `clrBlack` | $-2.000\sigma < V\text{Score} \le -1.500\sigma$ | **Bearish Momentum Flow:** Institutional markdown phase active; favor short continuation setups. |
| **Bear Climax** | `clrOrangeRed` | `clrWhite` | $-2.500\sigma < V\text{Score} \le -2.000\sigma$ | **Oversold Climax:** Heavy institutional selling push; prepare short-covering. |
| **Bear Extreme** | `clrDarkRed` | `clrWhite` | $V\text{Score} \le -2.500\sigma$ | **Panic Capitulation Floor:** Severe statistical discount; high-probability long bounce potential. |

---

## 4. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│           VScore_Dashboards_Pro (Engine)               │
│    (Multi-Asset Scanner & Interactive Matrix Engine)   │
├──────────────────────────┬─────────────────────────────┤
│   Heap-Free Execution    │   Centralized Framework     │
│   • Stack CVScoreCalc    │   • DataSync_Tools.mqh      │
│   • 200ms Rate Throttling│   • VScore_Calculator v3.00 │
│   • 1-Click Chart Switch │   • 7-Zone Thermal Palette  │
└──────────────────────────┴─────────────────────────────┘

```

1. **Heap-Free Multi-Asset Scanning:** Inside the asset scanning loop, `GetVScoreValue()` instantiates `CVScoreCalculator calc;` directly on the local thread stack. Memory allocation is localized and destroyed immediately, preventing thread bloat across 20+ symbols.
2. **Centralized Data Synchronization (`DataSync_Tools.mqh`):** Employs `CDataSync::EnsureHTFDataReady` for asynchronous, non-blocking history loading across multi-symbol watch lists.
3. **Interactive 1-Click Chart Switcher:** Clicking on any symbol button (`_SymBtn_`) triggers `CHARTEVENT_OBJECT_CLICK`, instantly switching the chart to the selected asset via `ChartSetSymbolPeriod(0, symbol, _Period)`.
4. **Standardized Dashboard Geometry:**
   - Anchor Corner: `CORNER_LEFT_UPPER`.
   - Header Row: Fixed at `InpTableY` (e.g., 50 px from top).
   - Asset Rows: Sequentially generated downwards: `InpTableY + row_h + 2 + (r * (row_h + 2))`.
5. **Rate Throttling:** 200 ms rate-limiter prevents GUI thread saturation during high-frequency live tick floods.

---

## 5. Parameters Reference

### 5.1. `VScore_Dashboard_Pro.mq5` (Single-Column)

| Parameter Group | Name | Default | Description |
| :--- | :--- | :--- | :--- |
| **Asset Selection** | `InpCustomSymbols` | `""` | Custom comma-separated symbols (empty for Market Watch). |
| | `InpMaxSymbols` | `15` | Maximum number of assets to display in table. |
| | `InpRefreshSeconds` | `3` | Background timer fallback interval. |
| **V-Score Settings** | `InpTimeframe` | `PERIOD_M15` | Target calculation timeframe. |
| | `InpPeriod` | `20` | Volatility lookback period ($P$) for standard deviation. |
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
| | `InpTableY` | `50` | Vertical pixel offset from top chart border. |
| | `InpFontSize` | `9` | Font size of button cells. |

---

### 5.2. `VScore_Dual_Dashboard_Pro.mq5` (Dual-Column)

| Parameter Group | Name | Default | Description |
| :--- | :--- | :--- | :--- |
| **Asset Selection** | `InpCustomSymbols` | `""` | Custom comma-separated symbols (empty for Market Watch). |
| | `InpMaxSymbols` | `15` | Maximum number of assets to display in table. |
| | `InpRefreshSeconds` | `3` | Background timer fallback interval. |
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
| | `InpTableY` | `50` | Vertical pixel offset from top chart border. |
| | `InpFontSize` | `9` | Font size of button cells. |

---

## 6. Quantitative Portfolio Screening Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                 PORTFOLIO-WIDE SCREENING PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Market Flow Filter:   Identify the strongest institutional movers   │
│                          printing LightSkyBlue (+1.5σ) or Coral (-1.5σ)│
│                          across Market Watch.                          │
│ 2. Multi-Horizon Confl.: Click on assets where both Slot 1 and Slot 2  │
│                          print identical thermal colors.               │
│ 3. Market-Wide Climax:   Spot systemic market tops/bottoms when 80%+   │
│                          of watch list hits DeepSkyBlue / OrangeRed.   │
└────────────────────────────────────────────────────────────────────────┘

```

### 6.1. Portfolio Volume Flow Scanner

- **Setup:** Load `VScore_Dashboard_Pro` with `InpTimeframe = PERIOD_M15` on a monitoring chart.
- **Scan Rules:**
  - **Top Bullish Flow Assets:** Assets displaying **`LightSkyBlue`** ($+1.500\sigma \dots +2.000\sigma$) are experiencing active institutional volume expansion $\rightarrow$ Click the symbol to open its chart and execute trend-following long pullbacks.
  - **Top Bearish Flow Assets:** Assets displaying **`Coral`** ($-2.000\sigma \dots -1.500\sigma$) are in active volume markdown $\rightarrow$ Click symbol to trade short continuations.

### 6.2. Multi-Horizon Confluence Screening

- **Setup:** Load `VScore_Dual_Dashboard_Pro` with `Slot 1 = M15 (Daily)` and `Slot 2 = H1 (Weekly)`.
- **Execution:**
  - Scan for assets where **Slot 1 is `LightSkyBlue` (+1.500σ)** AND **Slot 2 is `LightSkyBlue` or `DeepSkyBlue` (+2.000σ)** $\rightarrow$ High-conviction institutional multi-horizon long trend.
  - Scan for assets where **Slot 1 is `Coral` (-1.500σ)** AND **Slot 2 is `Coral` or `OrangeRed` (-2.000σ)** $\rightarrow$ High-conviction institutional multi-horizon short trend.
