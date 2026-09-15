# Rolling Volume-Weighted Z-Score (RV-Score) Widget Pro (v2.00)

Single-Asset Real-Time Heads-Up Display (HUD) Telemetry & Statistical Execution Filter

---

## 1. Summary (Introduction)

**RV-Score Widget Pro** is an ultra-lightweight, institutional-grade Heads-Up Display (HUD) engine designed to project real-time **Rolling Volume-Weighted Z-Score (RV-Score)** telemetry directly onto the main trading chart window.

Rather than consuming precious vertical chart real estate with separate oscillator subwindows, the widget renders a compact, two-tiered telemetry dashboard anchored permanently in the bottom-left corner (`CORNER_LEFT_LOWER`). It enables algorithmic and discretionary traders to instantly quantify whether the active asset is trading at institutional fair value, within a healthy trend expansion flow, or in an unsustainable statistical climax.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                     RV-SCORE HUD TELEMETRY LAYOUT                      │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   Y + 24px ──▶ ┌──────────────────────┬────────────────────┐           │
│   (Header)     │     Symbol (M15)     │      RV-Score      │           │
│                ├──────────────────────┼────────────────────┤           │
│   Y + 00px ──▶ │        BTCUSD        │      +2.14 σ       │           │
│   (Data Row)   └──────────────────────┴────────────────────┘           │
│                ▲                      ▲                                │
│                X = InpTableX          X + 102px                        │
│                                                                        │
│   Anchored at: CORNER_LEFT_LOWER (Coordinates Grow Upwards)            │
└────────────────────────────────────────────────────────────────────────┘

```

### Why Use an HUD Widget Over a Subwindow Oscillator?

- **Zero Chart Clutter:** Keeps price action, order flow footprints, and market structure levels completely unobstructed.
- **Higher-Timeframe Execution Overlay:** Allows lower-timeframe execution traders (e.g., M1 or M5) to monitor higher-timeframe momentum (e.g., M15 or H1 RV-Score) on every incoming tick.
- **Instant Thermal Context:** Translates continuous floating-point sigma deviations into discrete institutional states via the Symmetrical 7-Zone Super-Thermal Palette.

---

## 2. Mathematical Foundations & Telemetry Kernel

```text

     Sigma (σ)                   Thermal State                       Market State
    ════════════════════════════════════════════════════════════════════════════════════
     ≥ +2.5σ                     clrMidnightBlue                     Bullish Extreme Exhaustion
     +2.0σ ... +2.5σ             clrDeepSkyBlue                      Bullish Climax
     +1.5σ ... +2.0σ             clrLightSkyBlue                     Bullish Volume Flow
    ────────────────────────────────────────────────────────────────────────────────────
     -1.5σ ... +1.5σ             clrWhite / clrDarkGray              Equilibrium / Noise
    ────────────────────────────────────────────────────────────────────────────────────
     -2.0σ ... -1.5σ             clrCoral                            Bearish Volume Flow
     -2.5σ ... -2.0σ             clrOrangeRed                        Bearish Climax
     ≤ -2.5σ                     clrDarkRed                          Bearish Extreme Capitulation

```

### 2.1. Continuous Rolling Normalization Kernel

For the target higher timeframe $\text{TF}$, the widget executes the continuous dispersion formula on the latest completed and active bars:
$$\text{RV-Score}_t = \frac{\text{Close}_t - \mu_{\text{RVWAP}, t}}{\sigma_{\text{Rolling}, t}}$$
where $\mu_{\text{RVWAP}, t}$ is the prefix-sum integrated Rolling VWAP and $\sigma_{\text{Rolling}, t}$ is the rolling standard deviation of differences over lookback period $P = \text{InpSigmaPeriod}$.

### 2.2. Deterministic Lookback History Resolution

To eliminate the floating lookback estimation errors common in anchored VWAP widgets, RV-Score Widget Pro computes its exact historical data requirement deterministically:

#### Bar-Based Window (`ROLLING_BARS`)

$$\text{RequiredBars} = \min \Big( \text{InpRollingWindow} + \text{InpSigmaPeriod} + 10, \; 3000 \Big)$$

#### Time-Based Window (`ROLLING_TIME`)

$$\text{BarsInWindow} = \left\lfloor \frac{\text{InpRollingWindow} \times 60}{\text{PeriodSeconds}(\text{InpTimeframe})} \right\rfloor + 10$$
$$\text{RequiredBars} = \min \Big( \text{BarsInWindow} + \text{InpSigmaPeriod} + 10, \; 3000 \Big)$$

### 2.3. Symmetrical 7-Zone Super-Thermal Matrix

| Sigma Multiples ($\sigma$) | Background Color | Text Color | State Classification | Institutional Market Regime |
| :---: | :---: | :---: | :--- | :--- |
| **$\ge +2.50\sigma$** | `clrMidnightBlue` | `clrWhite` | **Bullish Extreme** | Severe liquidity exhaustion; high short-squeeze fade risk. |
| **$+2.00\sigma \dots +2.49\sigma$** | `clrDeepSkyBlue` | `clrWhite` | **Bullish Climax** | Overbought statistical expansion; profit-taking zone. |
| **$+1.50\sigma \dots +1.99\sigma$** | `clrLightSkyBlue` | `clrBlack` | **Bullish Flow** | Active institutional accumulation; markup expansion. |
| **$-1.49\sigma \dots +1.49\sigma$** | `clrWhite` | `clrDarkGray` | **Neutral / Equilibrium** | Fair-value mean oscillation; chop/consolidation noise. |
| **$-1.99\sigma \dots -1.50\sigma$** | `clrCoral` | `clrBlack` | **Bearish Flow** | Active institutional distribution; markdown expansion. |
| **$-2.49\sigma \dots -2.00\sigma$** | `clrOrangeRed` | `clrWhite` | **Bearish Climax** | Oversold statistical expansion; short covering expected. |
| **$\le -2.50\sigma$** | `clrDarkRed` | `clrWhite` | **Bearish Extreme** | Panic liquidation capitulation floor; mean-reversion setup. |

---

## 3. MQL5 Architecture & GUI Standards

```text

┌────────────────────────────────────────────────────────┐
│                 DataSync_Tools.mqh                     │
│    (Stateless Multi-Timeframe Data Integrity Daemon)   │
└──────────────────────────┬─────────────────────────────┘
                           │ Validates Target TF Bar Count
                           ▼
┌────────────────────────────────────────────────────────┐
│                 RVScore_Calculator.mqh                 │
│      (Stack-Only Execution: Zero Heap Allocation)      │
└──────────────────────────┬─────────────────────────────┘
                           │ Generates Live Sigma Reading
                           ▼
┌────────────────────────────────────────────────────────┐
│                RVScore_Widget_Pro.mq5                  │
│  (GUI Engine: 200ms Throttled HUD, CORNER_LEFT_LOWER)  │
└────────────────────────────────────────────────────────┘

```

### 3.1. The Heap-Free Stack Mandate

To guarantee sub-millisecond execution without memory leaks or garbage collection pauses, the telemetry calculation function `GetRVScoreValue()` instantiates the math engine strictly on the CPU stack:

```mql5
CRVScoreCalculator calc; // Local stack allocation - Zero new/delete overhead
```

The object is automatically allocated and destroyed within the function scope, entirely eliminating memory leaks and dangling pointer risks.

### 3.2. 2026 GUI Throttling Framework

Rapid tick updates during high-volatility events can saturate the MetaTrader UI thread, causing chart lag. The widget enforces a hard **200 ms rate limiter**:

```mql5
ulong current_ms = GetTickCount64();
if(current_ms - g_last_update_ms >= 200)
  {
   g_last_update_ms = current_ms;
   RenderDashboard();
  }
```

This caps chart redraws to a maximum of 5 FPS while preserving absolute numerical freshness.

### 3.3. Bottom-Left Coordinate Geometry

The widget is anchored strictly at `CORNER_LEFT_LOWER`. In this mode, the Y-coordinate increases **upward**:

- **Data Row:** Placed at `Y = InpTableY` (closest to bottom).
- **Header Row:** Placed at `Y = InpTableY + row_h + 2` (stacked directly above the data row).

---

## 4. Parameters Reference

### Heads-Up Display Settings

- `InpTimeframe` (*default: `PERIOD_M15`*): Target higher timeframe to sample for RV-Score telemetry. Allows higher-timeframe scoring on lower-timeframe execution charts.
- `InpRefreshSeconds` (*default: `3`*): Fallback timer interval in seconds. Triggers GUI updates during low-volume or off-market periods via `OnTimer()`.

### Rolling VWAP Engine

- `InpRollingType` (*default: `ROLLING_BARS`*):
  - `ROLLING_BARS`: Sliding window of fixed bar count.
  - `ROLLING_TIME`: Continuous physical time window in minutes.
- `InpRollingWindow` (*default: `144`*): Horizon length (bars or minutes depending on `InpRollingType`).
- `InpSigmaPeriod` (*default: `20`*): Volatility lookback ($P$) for standard deviation variance calculation.

### Calculation Settings

- `InpVolumeType` (*default: `VOLUME_TICK`*): Volume data source (`VOLUME_TICK` or `VOLUME_REAL`). Automatically falls back to tick volume if real volume is unavailable.
- `InpCandleSource` (*default: `CANDLE_STANDARD`*): Input price type (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).

### Indicator Levels (Sigma Multiples)

- `InpLevelFlowHigh` (*default: `1.5`*): Bullish Flow warning boundary.
- `InpLevelFlowLow` (*default: `-1.5`*): Bearish Flow warning boundary.
- `InpLevelClimaxHigh` (*default: `2.0`*): Bullish Climax threshold (`clrDeepSkyBlue`).
- `InpLevelClimaxLow` (*default: `-2.0`*): Bearish Climax threshold (`clrOrangeRed`).
- `InpLevelExtremeHigh` (*default: `2.5`*): Extreme Exhaustion ceiling (`clrMidnightBlue`).
- `InpLevelExtremeLow` (*default: `-2.5`*): Extreme Capitulation floor (`clrDarkRed`).

### Widget Placement (Pixels)

- `InpTableX` (*default: `20`*): Horizontal pixel offset from the left edge of the chart.
- `InpTableY` (*default: `30`*): Vertical pixel offset from the bottom edge of the chart.
- `InpFontSize` (*default: `9`*): Font size applied to HUD table buttons.

---

## 5. Quantitative Trading Playbooks & HUD Use-Cases

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   RV-SCORE HUD EXECUTION PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. HTF Trend-Flow Scalp Filter: Only take M1/M5 long pullbacks when    │
│                                 the HUD displays LightSkyBlue (+1.5σ). │
│ 2. Statistical Climax Fade:     Prepare mean-reversion counter-trades  │
│                                 when HUD turns DeepSkyBlue or Red.     │
│ 3. Neutral Equilibrium Squeeze: Anticipate breakouts when HUD rests in │
│                                 the White zone (|RV-Score| < 0.5σ).    │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Multi-Timeframe Trend-Flow Filter (M15 Telemetry on M1/M5 Chart)

- **Objective:** Prevent taking lower-timeframe trades against higher-timeframe institutional volume expansion.
- **Execution Rules:**
  - Attach `RVScore_Widget_Pro` with `InpTimeframe = PERIOD_M15` to an **M1 or M5 execution chart**.
  - **Bullish Regime:** If the HUD displays **`+1.50 σ ... +2.00 σ` (LightSkyBlue)**, M15 volume is in active markup $\rightarrow$ Take **Long pullback entries only**. Reject all short signals.
  - **Bearish Regime:** If the HUD displays **`-1.50 σ ... -2.00 σ` (Coral)**, M15 volume is in active markdown $\rightarrow$ Take **Short breakdown entries only**.

### 5.2. Statistical Climax & Liquidity Exhaustion Alert

- **Context:** Price makes an aggressive intraday surge, reaching critical resistance.
- **Execution Rules:**
  - Observe the RV-Score HUD value.
  - If the cell turns **`DeepSkyBlue` ($\ge +2.0\sigma$)** or **`MidnightBlue` ($\ge +2.5\sigma$)**, price is statistically overextended relative to the volume transacted over the rolling window.
  - **Action:** Tighten trailing stop-losses on long positions immediately; look for lower-timeframe bearish market structure breaks (CHoCH) to initiate high-R/R counter-trend short entries back toward $0.0\sigma$.

### 5.3. Equilibrium Squeeze & Compression Breakout

- **Context:** Market consolidates inside a tight trading range.
- **Execution Rules:**
  - When the HUD displays **`White`** with a low absolute value ($|\text{RV-Score}| \le 0.3\sigma$), price is tightly anchored to its volume-weighted mean (volatility compression).
  - Place bracket breakout orders or wait for the HUD to flash **`LightSkyBlue`** or **`Coral`** to confirm institutional commitment before entering.

---

## 6. Technical Specifications & Object Hierarchy

### Chart Object Naming Convention

All graphical elements are dynamically created using flat `OBJ_BUTTON` primitives and tagged with a chart-unique prefix to prevent multi-instance collisions:

$$\text{Object Prefix} = \text{"RVSW\_"} + \text{ChartID()} + \text{"\_"}$$

| Object Name Pattern | Type | Layer | Purpose |
| :--- | :---: | :---: | :--- |
| `RVSW_[ID]_H_Sym` | `OBJ_BUTTON` | Header | Displays target symbol name and selected timeframe (e.g., `Symbol (M15)`). |
| `RVSW_[ID]_H_RVS` | `OBJ_BUTTON` | Header | Static column header (`RV-Score`). |
| `RVSW_[ID]__SymLbl_[Symbol]` | `OBJ_BUTTON` | Data | Static asset identification cell (e.g., `BTCUSD`). |
| `RVSW_[ID]_[Symbol]_RVScore` | `OBJ_BUTTON` | Data | Dynamic telemetry cell displaying numeric $\sigma$ and 7-zone thermal color. |

### Lifecycle & Clean Exit Guarantee

Upon indicator removal or chart profile changes (`OnDeinit`), the widget invokes:

```mql5
ObjectsDeleteAll(0, g_prefix);
ChartRedraw(0);
```

This guarantees that **zero leftover graphical artifacts, text tags, or memory objects remain on the chart**.
