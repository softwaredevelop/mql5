# Volatility Deviation HUD Cockpit Widget Suite (V1.20)

## Technical Specification & Operational Manual

## 1. Summary (Introduction)

The **Volatility Deviation HUD Cockpit Widget Suite (V1.20)** is an institutional-grade, real-time transaction-friction, regime-tracking, and volatility-adjusted market profiling suite. Operating directly on the price chart (`#property indicator_chart_window`), the suite comprises two specialized, highly optimized heads-up display (HUD) widgets:

1. **`VScore_Widget_Pro` (Single-Timeframe):** An ultra-compact, high-density cell overlay displaying the dynamic Z-Score relative to the Volume Weighted Average Price (VWAP) for a single user-defined timeframe.
2. **`VScore_Dual_Widget_Pro` (Dual-Timeframe):** A comprehensive multi-timeframe dashboard displaying Daily (Session-Reset) V-Score and Weekly (Week-Reset) V-Score side-by-side to track trend-and-pullback alignments.

Rather than cluttering the subwindow space, these widgets are anchored to the bottom-left corner of the price chart, operating as a **Heads-Up Display (HUD) Cockpit Warning System**.

The suite leverages an advanced **7-zone Symmetrical Thermal Color Palette** mapped to all three of the main indicator’s level-pairs (Flow, Climax, and Extreme warnings). When an asset reaches an absolute statistical limits ($\ge \pm2.5$ Sigma), the single-cell background deepens to Midnight Blue or Dark Red, immediately alerting the trader without causing visual fatigue.

---

## 2. Mathematical & Statistical Foundations

The indicators calculate price deviation relative to the Volume Weighted Average Price (VWAP) in units of volume-weighted standard deviation (Sigma):

### A. Volume Weighted Average Price (VWAP)

The baseline average price is calculated cumulatively, weighted by tick or real exchange volume, resetting at the start of each Daily Session ($S_D$) or Weekly Session ($S_W$):

$$\text{VWAP}_t = \frac{\sum_{i=S}^{t} (P_i \times V_i)}{\sum_{i=S}^{t} V_i}$$

### B. V-Score Volatility Deviation (Z-Score)

The price distance is divided by the volume-weighted standard deviation ($\sigma_{\text{VWAP}}$) calculated over the user-defined lookback window $N$ (`InpVScorePeriod`):

$$\text{Variance}_t = \frac{1}{N} \sum_{k=0}^{N-1} (P_{t-k} - \text{VWAP}_{t-k})^2 \implies \sigma_{\text{VWAP}, t} = \sqrt{\text{Variance}_t}$$

$$\text{V-Score}_t = \frac{P_t - \text{VWAP}_t}{\sigma_{\text{VWAP}, t}}$$

* **`VScore_Widget_Pro`:** Evaluates `V-Score` on a single target timeframe (`InpTimeframe`).
* **`VScore_Dual_Widget_Pro`:** Evaluates both `vs_day` (M15, Daily Session reset) and `vs_week` (H1, Weekly Session reset) side-by-side.

---

## 3. The Symmetrical 7-Zone Super-Thermal Color Palette

To represent market velocity and extreme over-extensions cleanly on a single text cell, the background and text colors of the widget buttons are dynamically updated using three adjustable input level-pairs:

```text

[ Extreme Low ] < [ Climax Low ] < [ Flow Low ] < [ Neutral ] < [ Flow High ] < [ Climax High ] < [ Extreme High ]
    ( -2.5 )          ( -2.0 )         ( -1.5 )        ( 0.0 )        ( +1.5 )          ( +2.0 )           ( +2.5 )

```

The background colors are mapped as follows:

| Zone Index | V-Score Range | Cell Background Color | Text Color | Quantitative Meaning |
| :---: | :--- | :--- | :--- | :--- |
| **`+3`** | $v \ge \text{InpLevelExtremeHigh}$ | **`clrMidnightBlue`** | `clrWhite` | **Extreme Bullish Exhaustion.** Absolute overbought ceiling. |
| **`+2`** | $\text{InpLevelClimaxHigh} \le v < \text{InpLevelExtremeHigh}$ | **`clrDeepSkyBlue`** | `clrWhite` | **Bullish Climax.** High-velocity upward expansion. |
| **`+1`** | $\text{InpLevelFlowHigh} \le v < \text{InpLevelClimaxHigh}$ | **`clrLightSkyBlue`** | `clrBlack` | **Bullish Flow.** Stable, healthy uptrend. |
| **`0`** | $\text{InpLevelFlowLow} < v < \text{InpLevelFlowHigh}$ | **`clrWhite`** | `clrDarkGray` | **Neutral / Value.** Trading close to the VWAP. |
| **`-1`** | $\text{InpLevelFlowLow} \ge v > \text{InpLevelClimaxLow}$ | **`clrCoral`** | `clrBlack` | **Bearish Flow.** Stable, healthy downtrend. |
| **`-2`** | $\text{InpLevelClimaxLow} \ge v > \text{InpLevelExtremeLow}$ | **`clrOrangeRed`** | `clrWhite` | **Bearish Climax.** High-velocity downward expansion. |
| **`-3`** | $v \le \text{InpLevelExtremeLow}$ | **`clrDarkRed`** | `clrWhite` | **Extreme Bearish Exhaustion.** Absolute oversold floor. |

---

## 4. Suite Configuration & Preset Matrix

Both indicators share identical input level configurations to maintain perfect fázis-helyes synchronization across your charts:

| Indicator Variant | Target Timeframe | Reset Period | Lookback Period ($N$) | Warning Levels ($\text{Flow}, \text{Climax}, \text{Extreme}$) | Quantitative Objective |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **`VScore_Widget_Pro`** | `InpTimeframe` | `InpVWAPReset` | `21` | $\pm 1.5, \pm 2.0, \pm 2.5$ | Focuses on a single key execution timeline (e.g., M5 or M15). |
| **`VScore_Dual_Widget_Pro`** | `InpDailyTF` (M15) <br> `InpWeeklyTF` (H1) | `PERIOD_SESSION` <br> `PERIOD_WEEK` | `20` <br> `20` | $\pm 1.5, \pm 2.0, \pm 2.5$ | Complete MTF Cockpit. Tracks trend alignments and intraday pullbacks. |

---

## 5. Visual & Technical Highlights

* **High-Frequency Tick Throttling (200 ms):**
  To prevent CPU bloat and chart lag during fast-moving market sessions, the widgets restrict their calculations using a high-precision timer:

  ```mql5
  ulong current_ms = GetTickCount64();
  if(current_ms - g_last_update_ms >= 200)
    {
     g_last_update_ms = current_ms;
     RenderDashboard();
    }
  ```

  This guarantees that even under a heavy tick-stream, the dashboard updates at most 5 times per second.

* **Flicker-Free Object Modification:**
  The engines use `CreateButton()` with a flat, borderless style (`BORDER_FLAT`). Rather than deleting and recreating buttons on every update (which would cause annoying flickering), the script uses `ObjectMove()` and `ObjectSetString()` to update coordinates and labels dynamically.
* **Unified Corner Anchoring:**
  All elements are anchored to `CORNER_LEFT_LOWER`. The Y-coordinates are calculated upwards ($header\_y > row\_y$), ensuring the widget stays perfectly aligned above the chart's timeline, regardless of terminal resizing.

---

## 6. HUD Cockpit Operational Playbook

Traders and automated Expert Advisors can use the widgets as master cockpit panels to make high-expectancy trend decisions:

### A. Intraday Volatility Pivot Detection (`VScore_Widget_Pro`)

When trading a single asset (e.g. BTCUSD or EURUSD) intraday, load `VScore_Widget_Pro` set to your trigger timeframe (M5 or M15):

* **Execution:**
  * If the widget is **White** (Neutral), wait.
  * If the widget transitions to **LightSkyBlue** or **Coral**, look for momentum continuation trades in that direction.
  * If the widget hits **DeepSkyBlue** or **OrangeRed** climax, prepare for trend exhaustion.
  * If the widget flashes **Midnight Blue** or **Dark Red**, execute mean-reversion counter-trend trades immediately, placing tight stops outside the swing high/low.

### B. Multi-Timeframe Trend Alignment (`VScore_Dual_Widget_Pro`)

* **The Setup:** Look for a state where both the Daily and Weekly V-Scores show the same color polarity.
* **FULL BULL (Double Blue):** If Daily is `clrDeepSkyBlue` (Climax) and Weekly is `clrLightSkyBlue` (Flow), it confirms a powerful institutional trend alignment. Only look for Long continuation setups on pullbacks.
* **FULL BEAR (Double Red):** If Daily is `clrOrangeRed` (Climax) and Weekly is `clrCoral` (Flow), a strong downward trend is in place. Only look for Short continuation setups.

### C. The Extreme Exhaustion Reversal (Midnight Blue / Dark Red Alerts)

When an asset hits the absolute boundaries, it represents a high-probability reversal zone due to institutional value-reversal.

* **Oversold Squeeze (Dark Red Alert):** If the Weekly V-Score (H1) is in the **Dark Red** exhaustion zone ($v \le -2.5$), but the Daily V-Score (M15) begins to rebound and turns **Gray** or **LightSkyBlue**:
  * *The Signal:* This represents an extremely high-probability Long mean-reversion opportunity. The weekly macro sellers have completely exhausted, and intraday buyers are stepping in at an institutional discount.
  * *Execution:* Enter Long, placing a tight Stop Loss below the local M15 swing low.
* **Overbought Squeeze (Midnight Blue Alert):** If the Weekly V-Score (H1) is in the **Midnight Blue** zone ($v \ge 2.5$), but the Daily V-Score (M15) turns **Gray** or **Coral**:
  * *The Signal:* High-probability Short mean-reversion opportunity as buying pressure exhausts at macro resistance.
