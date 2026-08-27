# Historical VWAP Closing Levels (VWAP History Levels) Pro (v3.00)

Quantitative Institutional Settlement Benchmarks & Support/Resistance Ray Suite

---

## 1. Summary (Introduction)

**VWAP History Levels Pro** is an institutional market structure indicator that captures the **final closing settlement VWAP values** of completed historical trading periods and projects them forward as persistent, full-workspace horizontal Support & Resistance rays.

In algorithmic and institutional trading, the closing Volume-Weighted Average Price of a completed session represents the final consensus of value where the largest volume of liquidity was transacted. Unlike dynamic rolling lines that continuously shift with new price action, **historical closing VWAPs freeze at the exact moment a session terminates**, serving as static institutional benchmarks.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   HISTORICAL SETTLEMENT BENCHMARKS                     │
├──────────────────────┬────────────────────────┬────────────────────────┤
│  Benchmark Tag       │   Period Definition    │   Institutional Role   │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ PD-VWAP              │ Prior Daily Close      │ Intraday Value Anchor  │
│ PW-VWAP              │ Prior Weekly Close     │ Swing Equilibrium Level│
│ PM-VWAP              │ Prior Monthly Close    │ Macro Structure Filter │
│ PS-VWAP              │ Prior Custom Session   │ LSE / NY Fix Benchmark │
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **Multi-Period Settlement Tracking:** Simultaneously projects Prior Day (`PD-VWAP`), Prior Week (`PW-VWAP`), Prior Month (`PM-VWAP`), and Prior Custom Session (`PS-VWAP`) levels.
* **Custom Institutional Session Support:** Captures specific session closing benchmarks (such as the **London Stock Exchange 16:30 Fix** or **New York 16:00 Cash Close**).
* **Full-Workspace Ray Engine:** Employs vector rays (`OBJPROP_RAY_RIGHT = true` and `OBJPROP_BACK = true`) that extend seamlessly across the active forming candles and the forward Chart Shift margin up to the price scale.
* **High-Performance Memory Garbage Collection:** Features a pre-allocated array memory cleanup engine that purges older historical objects without heap fragmentation.
* **Synthetic Heikin Ashi & Real Volume Support:** Compatible with both Tick Volume and Real Volume (`VOLUME_REAL`), as well as filtered Heikin Ashi price series via `VWAP_Calculator.mqh` (v3.01).

---

## 2. Mathematical Foundations & Settlement Mechanics

```text

       Session t (Active Session)              Session t + 1 (Next Session)
  ───► Volume Accumulation: ∑(TP · V) / ∑V
                                        │
  ──────────────────────────────────────┼───► Settlement VWAP Frozen (PS-VWAP)
                                        │     Projected forward as Horizontal Ray:
                                        │     ═════════════════════════════════════

```

### 2.1. Cumulative Volume-Weighted Average Price

During any active period spanning from start bar $t_{\text{start}}$ to current bar $t$:
$$\text{VWAP}_t = \frac{\sum_{k=t_{\text{start}}}^{t} \text{TP}_k \cdot V_k}{\sum_{k=t_{\text{start}}}^{t} V_k}$$
*where $\text{TP}_k = \frac{H_k + L_k + C_k}{3}$ (Typical Price) and $V_k$ is the applied volume.*

### 2.2. Settlement Capture at Period Close ($t_{\text{close}}$)

At the exact timestamp where period $P_n$ terminates and period $P_{n+1}$ begins:
$$\text{Level}_{\text{Settlement}} = \text{VWAP}(t_{\text{close}})$$

### 2.3. Extended Ray Projection Function

A persistent geometric line object is constructed at $(t_{\text{close}}, \text{Level}_{\text{Settlement}})$ with infinite forward projection across the chart workspace:
$$y(t) = \text{Level}_{\text{Settlement}} \quad\quad \forall \; t \ge t_{\text{close}}$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                  VWAP_Calculator.mqh                   │
│   (Core Math Engine: Deterministic Session Evaluator)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs Discrete Historical VWAP Values
                           ▼
┌────────────────────────────────────────────────────────┐
│               VWAP_History_Levels.mq5                  │
│    (Settlement Detector & Extended Vector Ray Engine)  │
├──────────────────────────┬─────────────────────────────┤
│   Period Transition Scan │   Pre-Allocated Array GC    │
│   • Daily Transition     │   • O(1) Lexicographical    │
│   • Weekly Transition    │   • Clean Old Object Purge  │
│   • Monthly Transition   │   • Zero Heap Fragmentation │
│   • Custom Session Close │   • Chart Shift Labels      │
└──────────────────────────┴─────────────────────────────┘

```

1. **Deterministic Period Scanning:** Scans chronological bar transitions (`time[i]` vs `time[i-1]`). The settlement value is captured from index $i-1$, guaranteeing 100% mathematical fidelity to the true closing print.
2. **Pre-Allocated Garbage Collector:** Avoids dynamic array reallocations inside loops (`ArrayResize(..., count+1)`). Collects existing object handles into a pre-allocated stack buffer and deletes objects exceeding user limits (`InpDailyCount`, `InpWeeklyCount`, etc.).
3. **Workspace Shift Alignment:** Text labels (`OBJ_TEXT`) automatically float into the forward chart shift space (`InpLabelShift` bars ahead), preventing price candle occlusion.

---

## 4. Parameters Reference

### Calculation & Source Settings

* `InpVolumeType` (*default: `VOLUME_TICK`*): Applied volume data source (`VOLUME_TICK` or `VOLUME_REAL`).
* `InpCandleSource` (*default: `CANDLE_STANDARD`*): Price series source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`).
* `InpTzShift` (*default: `0`*): Timezone offset in hours to align midnight resets with broker server time.

### Daily Historical Levels (PD-VWAP)

* `InpShowDaily` (*default: `true`*): Toggle Prior Daily VWAP rays.
* `InpDailyCount` (*default: `3`*): Number of recent daily levels to retain on the chart.
* `InpDailyColor` (*default: `clrDeepPink`*): Color of daily level rays and labels.
* `InpDailyStyle` (*default: `STYLE_SOLID`*): Line style for daily rays.
* `InpDailyWidth` (*default: `1`*): Line thickness for daily rays.

### Weekly Historical Levels (PW-VWAP)

* `InpShowWeekly` (*default: `true`*): Toggle Prior Weekly VWAP rays.
* `InpWeeklyCount` (*default: `3`*): Number of recent weekly levels to retain on the chart.
* `InpWeeklyColor` (*default: `clrDodgerBlue`*): Color of weekly level rays and labels.
* `InpWeeklyStyle` (*default: `STYLE_SOLID`*): Line style for weekly rays.
* `InpWeeklyWidth` (*default: `1`*): Line thickness for weekly rays.

### Monthly Historical Levels (PM-VWAP)

* `InpShowMonthly` (*default: `true`*): Toggle Prior Monthly VWAP rays.
* `InpMonthlyCount` (*default: `2`*): Number of recent monthly levels to retain on the chart.
* `InpMonthlyColor` (*default: `clrMediumTurquoise`*): Color of monthly level rays and labels.
* `InpMonthlyStyle` (*default: `STYLE_SOLID`*): Line style for monthly rays.
* `InpMonthlyWidth` (*default: `1`*): Line thickness for monthly rays.

### Custom Session Levels (PS-VWAP)

* `InpShowCustom` (*default: `false`*): Toggle Custom Session closing VWAP rays.
* `InpCustomStart` (*default: `"08:00"`*): Custom session start time (`HH:MM`, e.g., London Open).
* `InpCustomEnd` (*default: `"16:30"`*): Custom session end time (`HH:MM`, e.g., London Fix / Close).
* `InpCustomCount` (*default: `2`*): Number of recent custom session levels to retain.
* `InpCustomColor` (*default: `clrGold`*): Color of custom session level rays.
* `InpCustomStyle` (*default: `STYLE_SOLID`*): Line style for custom rays.
* `InpCustomWidth` (*default: `1`*): Line thickness for custom rays.

### Visual & Label Settings

* `InpShowLabels` (*default: `true`*): Toggle text identifiers (e.g., `PD-VWAP 1.16820`) on the chart.
* `InpLabelShift` (*default: `8`*): Distance (in bars) extending into the forward chart shift space.
* `InpFontSize` (*default: `8`*): Font size of text identifiers.

---

## 5. Institutional Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   HISTORICAL VWAP TRADING PLAYBOOKS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. London Fix Retest:    Fade pullbacks to Prior London Close (PS-VWAP)│
│                          during the Asian or subsequent London open.   │
│ 2. Prior Day Acceptance: Price accepting above PD-VWAP confirms daily  │
│                          bullish value migration; target PW-VWAP.      │
│ 3. S/R Confluence Zone:  When PD-VWAP aligns with a Weekly Pivot or    │
│                          PW-VWAP, it forms a high-conviction reaction. │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The London 16:30 Fix Settlement Retest (PS-VWAP)

* **Context:** The 16:30 London session close represents the benchmark settlement for European institutional equity and FX portfolios.
* **Playbook:** When the Asian session or the next London morning session opens, watch for pullbacks into the prior day's `PS-VWAP (16:30)`:
  * A rejection candle at `PS-VWAP` acts as a high-probability bounce entry with tight invalidation just beyond the line.

### 5.2. Prior Day Value Migration (PD-VWAP Acceptance vs Rejection)

* **Bullish Value Migration:** If price opens above the `PD-VWAP` ray and retests it successfully as support $\rightarrow$ Look for long momentum expansions targeting the next upper level (`PW-VWAP` or Weekly Pivot).
* **Bearish Value Migration:** If price breaks below `PD-VWAP` and retests it as resistance $\rightarrow$ Institutional confirmation of lower value distribution; look for short entries.

### 5.3. Structural Confluence (The Cluster Matrix)

* When a **`PD-VWAP`** level aligns within a tight price cluster ($\pm 5 \dots 10$ pips) of a **`PW-VWAP`** or **Daily Pivot**, it creates an institutional confluence zone. Breakouts or bounces from these clusters offer asymmetrical risk-to-reward ratios.
