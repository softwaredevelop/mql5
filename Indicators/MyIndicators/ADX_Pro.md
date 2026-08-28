# Average Directional Index (ADX) Pro (v3.00)

Quantitative Trend Strength & Directional Movement Index (DMI) Suite

---

## 1. Summary (Introduction)

**ADX Pro** is an institutional-grade implementation of J. Welles Wilder Jr.'s legendary **Directional Movement System**, comprising the **Average Directional Index (ADX)**, **Positive Directional Indicator (+DI)**, and **Negative Directional Indicator (-DI)**.

Unlike momentum oscillators that oscillate with price swings, **ADX measures the absolute strength and conviction of a market trend regardless of its direction**. By quantifying the balance of power between buyers (+DI) and sellers (-DI), ADX Pro serves as the ultimate regime filter:

* **Trend Absence / Consolidation Regime ($ADX < 20.0$):** Market is in a low-conviction range; trend-following breakout systems should be paused, and mean-reversion strategies favored.
* **Trend Confirmation Regime ($ADX \ge 25.0$):** Validates that an authentic, directional momentum trend is in progress.
* **Extreme Parabolic Climax ($ADX \ge 40.0$):** Indicates an over-extended, mature trend vulnerable to momentum exhaustion or violent pullbacks.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   THE DIRECTIONAL MOVEMENT SYSTEM                      │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Line Plot        │   Color Code           │   Core Role            │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ ADX Line             │ clrDodgerBlue (Width:2)│ Absolute Trend Strength│
│ +DI Line             │ clrOliveDrab (Width:1) │ Positive Buying Power  │
│ -DI Line             │ clrTomato (Width:1)    │ Negative Selling Power │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Definition-True Wilder Algorithm:** Implements Wilder's exact recursive smoothing (RMA) across True Range, Directional Movement, and the DX series.
* **Unified 2026 MTF Framework:** Synchronized with `DataSync_Tools.mqh` to project higher-timeframe ADX and DMI curves (e.g., H1 or H4) onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps.
* **Modular 3-Tier Architecture:** Powered by `DMI_Engine.mqh` and `ADX_Calculator.mqh` with leak-free pointer safety.
* **Synthetic Heikin Ashi Support:** Computes smoothed directional vectors from synthetic Heikin Ashi candles to filter out false directional whipsaws.
* **Dynamic Configurable Levels:** Customizable horizontal thresholds for trend strength ($25.0$) and exhaustion ($40.0$).

---

## 2. Mathematical Foundations & Directional Movement Mechanics

```text

                 HIGH(t) - HIGH(t - 1)  ───►  +DM (Positive Directional Movement)
                 LOW(t - 1) - LOW(t)    ───►  -DM (Negative Directional Movement)
                                              │
                      ┌───────────────────────┴───────────────────────┐
                      │    Wilder's RMA Smoothing over Period P       │
                      └───────────────────────┬───────────────────────┘
                                              ▼
                    +DI = Smoothed(+DM) / Smoothed(TR) × 100
                    -DI = Smoothed(-DM) / Smoothed(TR) × 100
                                              │
                                              ▼
                    DX = | (+DI) - (-DI) | / [ (+DI) + (-DI) ] × 100
                                              │
                                              ▼
                      ADX = Wilder's RMA Smoothing on DX (Period P)

```

### 2.1. True Range ($TR$) Formulation

$$TR_t = \max\left( H_t, C_{t-1} \right) - \min\left( L_t, C_{t-1} \right)$$

### 2.2. Directional Movement Vectors ($+DM, -DM$)

$$\Delta H_t = H_t - H_{t-1}, \quad\quad \Delta L_t = L_{t-1} - L_t$$

$$+DM_t = \begin{cases} \Delta H_t, & \text{if } \Delta H_t > \Delta L_t \text{ and } \Delta H_t > 0 \\ 0.0, & \text{otherwise} \end{cases}$$

$$-DM_t = \begin{cases} \Delta L_t, & \text{if } \Delta L_t > \Delta H_t \text{ and } \Delta L_t > 0 \\ 0.0, & \text{otherwise} \end{cases}$$

---

### 2.3. Wilder's Recursive Smoothing (RMA)

For any series $X \in \{+DM, -DM, TR\}$, the initial seed is the cumulative sum over lookback period $P$:
$$\text{Smoothed}(X)_P = \sum_{j=1}^{P} X_j$$

Subsequent bars update via Wilder's recursive smoothing equation:
$$\text{Smoothed}(X)_t = \text{Smoothed}(X)_{t-1} - \left( \frac{\text{Smoothed}(X)_{t-1}}{P} \right) + X_t = \frac{\text{Smoothed}(X)_{t-1} \cdot (P - 1) + X_t \cdot P}{P}$$

---

### 2.4. Directional Indicators ($+DI, -DI$)

$$+DI_t = \left( \frac{\text{Smoothed}(+DM)_t}{\text{Smoothed}(TR)_t} \right) \times 100$$
$$-DI_t = \left( \frac{\text{Smoothed}(-DM)_t}{\text{Smoothed}(TR)_t} \right) \times 100$$

### 2.5. Directional Index ($DX$) & Average Directional Index ($ADX$)

$$DX_t = \begin{cases} \left( \frac{|+DI_t - -DI_t|}{+DI_t + -DI_t} \right) \times 100, & \text{if } (+DI_t + -DI_t) > 0 \\ 0.0, & \text{otherwise} \end{cases}$$

The final ADX curve begins at bar index $t_{\text{seed}} = 2P - 1$ as the arithmetic mean of the preceding $P$ values of $DX$:
$$ADX_{2P-1} = \frac{1}{P} \sum_{j=0}^{P-1} DX_{2P-1-j}$$

Subsequent values update via Wilder's smoothing on $DX$:
$$ADX_t = \frac{ADX_{t-1} \cdot (P - 1) + DX_t}{P}$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                     DMI_Engine.mqh                     │
│    (Core Math: Computes Smoothed TR, +DM, -DM, ±DI)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Feeds +DI & -DI Series
                           ▼
┌────────────────────────────────────────────────────────┐
│                   ADX_Calculator.mqh                   │
│    (DX Calculation & Wilder's Recursive ADX Engine)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs ADX, +DI, -DI in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                       ADX_Pro.mq5                      │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 3 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular 3-Tier Engine Hierarchy:** Isolates low-level DMI physics (`DMI_Engine.mqh`) from high-level ADX smoothing (`ADX_Calculator.mqh`), allowing other oscillators in the suite to reuse DMI without recalculation overhead.
2. **Leak-Free Pointer Protection:** Factory methods (`CreateEngine`) explicitly verify pointer validity (`CheckPointer`) and safely free memory before re-allocation.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe data synchronization without GUI freezes.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it runs in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### ADX Core Settings

* `InpPeriodADX` (*default: `14`*): Wilder's lookback smoothing period ($P$) for DMI and ADX calculations.
* `InpCandleSource` (*default: `CANDLE_STANDARD`*): Candle price source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).

### Indicator Levels

* `InpLevelTrend` (*default: `25.0`*): Key institutional trend strength threshold.
* `InpLevelExtreme` (*default: `40.0`*): Strong trend / potential exhaustion boundary.
* `InpLevelColor` (*default: `clrSilver`*): Color of horizontal level lines.
* `InpLevelStyle` (*default: `STYLE_DOT`*): Line style of horizontal level lines.

### Visual Settings

* `InpColorADX` (*default: `clrDodgerBlue`*): ADX trend strength line color (Width: 2, Solid).
* `InpColorPDI` (*default: `clrOliveDrab`*): +DI positive directional line color (Width: 1, Solid).
* `InpColorNDI` (*default: `clrTomato`*): -DI negative directional line color (Width: 1, Solid).

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   ADX & DMI INSTITUTIONAL PLAYBOOKS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Regime Filter:        ADX < 20 = No Trend / Chop (Pause Breakouts) │
│                          ADX > 25 = Valid Directional Trend Active     │
│ 2. Directional Trigger:  +DI crosses above -DI while ADX > 25 = Buy    │
│                          -DI crosses above +DI while ADX > 25 = Sell   │
│ 3. Climax Exhaustion:    ADX > 40 turning downward = Scale Out Profits │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The ADX Regime Filter (Eliminating False Breakouts)

* **Chop Rule ($ADX < 20.0$):** When ADX is below 20.0, the market is range-bound. Disregard moving average crossovers and breakout signals. Favor mean-reversion boundary trades.
* **Trend Confirmation ($ADX \ge 25.0$):** A rising ADX crossing above 25.0 confirms that institutional trend expansion is active.

### 5.2. Directional Indicator Crossovers (+DI / -DI)

* **Bullish Momentum Trigger:** `+DI` crosses above `-DI` AND `ADX > 25.0` (with ADX sloping upward) $\rightarrow$ High-probability Long Trend Entry.
* **Bearish Momentum Trigger:** `-DI` crosses above `+DI` AND `ADX > 25.0` (with ADX sloping upward) $\rightarrow$ High-probability Short Trend Entry.

### 5.3. Multi-Timeframe Macro Trend Strength Filter

* Attach an **H1-calculated ADX** onto an **M5 execution chart**.
* Only take intraday long pullbacks on M5 when **H1 ADX is above 25.0 AND H1 +DI is above H1 -DI**. This ensures you are trading strictly aligned with higher-timeframe institutional trend momentum.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferADX` | `INDICATOR_DATA` | Average Directional Index (Main Trend Strength) |
| **1** | `BufferPDI` | `INDICATOR_DATA` | Positive Directional Indicator (+DI) |
| **2** | `BufferNDI` | `INDICATOR_DATA` | Negative Directional Indicator (-DI) |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
