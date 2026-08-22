# Pivot Points Pro (v3.30) *Professional Quantitative Multi-Timeframe Support & Resistance Suite*

---

## 1. Summary (Introduction)

**Pivot Points Pro** is a high-performance, institutional-grade support and resistance indicator developed for MetaTrader 5 (2026 Edition). Designed specifically for active technical analysts and systematic traders, it eliminates the visual noise of historical lines by rendering levels **strictly for the active period** while extending them continuously across the entire chart workspace.

### Key Innovations in Version 3.30

* **Native Full-Workspace & Chart Shift Support:** Utilizes a zero-latency vector rendering engine (`OBJPROP_RAY_RIGHT`) that anchors lines to the exact period open (e.g., 00:00) and extends them seamlessly across current price action to the far-right price scale.
* **Dual-Layer Architecture:** Combines hardware-accelerated chart objects for flawless visuals with synchronized indicator buffers (`DRAW_NONE`) to ensure 100% compatibility with MetaTrader 5 **Data Window (`Ctrl+D`)** and automated Expert Advisors (`iCustom`).
* **Multi-Timeframe (MTF) Engine:** Real-time synchronization allowing Daily, Weekly, or Monthly pivots to be displayed on intraday timeframes (M1, M5, M15, H1).
* **5 Institutional Formula Modes:** Classic Floor, Fibonacci, Woodie, Camarilla, and Tom DeMark.
* **Heikin Ashi Filtered Source:** Dynamic transformation of OHLC prices into synthetic Heikin Ashi data to eliminate high-frequency false breakouts.

---

## 2. Mathematical Foundations

Pivot Points are computed using the High ($H$), Low ($L$), and Close ($C$) prices from the **previous completed** higher-timeframe bar. The Range is defined as:
$$\text{Range} = H - L$$

### 2.1. Calculation Modes

#### 1. Classic (Floor Trader)

The quintessential standard for intraday equilibrium and reaction bands:
$$PP = \frac{H + L + C}{3}$$
$$R1 = 2 \cdot PP - L \quad\quad S1 = 2 \cdot PP - H$$
$$R2 = PP + \text{Range} \quad\quad S2 = PP - \text{Range}$$
$$R3 = H + 2 \cdot (PP - L) \quad\quad S3 = L - 2 \cdot (H - PP)$$

#### 2. Fibonacci

Projects golden ratio intervals around the central equilibrium:
$$PP = \frac{H + L + C}{3}$$
$$R1 = PP + 0.382 \cdot \text{Range} \quad\quad S1 = PP - 0.382 \cdot \text{Range}$$
$$R2 = PP + 0.618 \cdot \text{Range} \quad\quad S2 = PP - 0.618 \cdot \text{Range}$$
$$R3 = PP + 1.000 \cdot \text{Range} \quad\quad S3 = PP - 1.000 \cdot \text{Range}$$

#### 3. Woodie

Weights the settlement price more heavily to account for late-session momentum:
$$PP = \frac{H + L + 2 \cdot C}{4}$$
$$R1 = 2 \cdot PP - L \quad\quad S1 = 2 \cdot PP - H$$
$$R2 = PP + \text{Range} \quad\quad S2 = PP - \text{Range}$$
$$R3 = H + 2 \cdot (PP - L) \quad\quad S3 = L - 2 \cdot (H - PP)$$

#### 4. Camarilla

Specifically calibrated for mean-reverting range scalping and explosive breakout triggers:
$$PP = \frac{H + L + C}{3}$$
$$R1 = C + \text{Range} \cdot \frac{1.1}{12} \quad\quad S1 = C - \text{Range} \cdot \frac{1.1}{12}$$
$$R2 = C + \text{Range} \cdot \frac{1.1}{6} \quad\quad S2 = C - \text{Range} \cdot \frac{1.1}{6}$$
$$R3 = C + \text{Range} \cdot \frac{1.1}{4} \quad\quad S3 = C - \text{Range} \cdot \frac{1.1}{4}$$

#### 5. Tom DeMark

A conditional predictive model based on open-close directional pressure:
$$\text{If } C < O \implies X = H + 2 \cdot L + C$$
$$\text{If } C > O \implies X = 2 \cdot H + L + C$$
$$\text{If } C = O \implies X = H + L + 2 \cdot C$$

$$PP = \frac{X}{4}$$
$$R1 = \frac{X}{2} - L \quad\quad S1 = \frac{X}{2} - H$$

---

### 2.2. Median Equilibrium Levels (Mid-Points)

When enabled, arithmetic midpoints are calculated to provide intermediate micro-structure targets:
$$M_1 = \frac{S1 + S2}{2}, \quad M_2 = \frac{S1 + PP}{2}, \quad M_3 = \frac{PP + R1}{2}$$
$$M_4 = \frac{R1 + R2}{2}, \quad M_5 = \frac{R2 + R3}{2}, \quad M_6 = \frac{S2 + S3}{2}$$

---

### 2.3. Heikin Ashi Synthetic Price Model

When `InpSourceType = PIVOT_SRC_HEIKIN_ASHI`, prices are filtered prior to level calculations:
$$C_{\text{ha}} = \frac{O + H + L + C}{4}$$
$$O_{\text{ha}} = \frac{O_{\text{prev}} + C_{\text{prev}}}{2}$$
$$H_{\text{ha}} = \max(H, \max(O_{\text{ha}}, C_{\text{ha}}))$$
$$L_{\text{ha}} = \min(L, \min(O_{\text{ha}}, C_{\text{ha}}))$$

---

## 3. MQL5 Architecture & Technical Implementation

```text

┌────────────────────────────────────────────────────────┐
│               PivotPoint_Calculator.mqh                │
│    (Core Math Engine - Stateful O(1) Cache Memory)     │
└──────────────────────────┬─────────────────────────────┘
                           │ Computes Levels & Period Start
                           ▼
┌────────────────────────────────────────────────────────┐
│                  PivotPoints_Pro.mq5                   │
│   (Thin Wrapper - Vector Ray Engine & Data Buffers)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (13)      │   Extended Object Engine    │
│   • Data Window (Ctrl+D) │   • Ray Right Vector Lines  │
│   • iCustom EA Ready     │   • Future Shift Labels     │
└──────────────────────────┴─────────────────────────────┘

```

1. **Stateful HTF Caching ($O(1)$ Efficiency):** Calculations run only once when a new HTF session bar opens. Subsequent ticks retrieve levels from cached memory.
2. **Extended Ray Objects:** Utilizes `OBJ_TREND` with `OBJPROP_RAY_RIGHT = true` and `OBJPROP_BACK = true`. This prevents line clipping at the live bar index and fills the Chart Shift workspace cleanly.
3. **Smart Label Engine:** Text labels (`OBJ_TEXT`) automatically float into the forward workspace margin (`InpLabelShift` bars ahead) to avoid obscuring the current price action.
4. **Resource Management:** Safe pointer deletion (`CheckPointer`) and prefix-based object purging (`ObjectsDeleteAll`) prevent ghost objects during symbol, timeframe, or parameter updates.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_D1`*): The Higher Timeframe used for calculation. Must be greater than or equal to the current chart timeframe.

### Calculation Settings

* `InpPivotType` (*default: `PIVOT_CLASSIC`*): Formula selection (`PIVOT_CLASSIC`, `PIVOT_FIBONACCI`, `PIVOT_WOODIE`, `PIVOT_CAMARILLA`, `PIVOT_DEMARK`).
* `InpSourceType` (*default: `PIVOT_SRC_STANDARD`*): Price series source (`PIVOT_SRC_STANDARD` or `PIVOT_SRC_HEIKIN_ASHI`).

### Visual Settings - Pivot Point

* `InpColorPP` (*default: `clrGold`*): Color of the central equilibrium level (PP).
* `InpStylePP` (*default: `STYLE_SOLID`*): Line style of the central PP.
* `InpWidthPP` (*default: `2`*): Line thickness of the central PP.

### Visual Settings - Resistance Levels

* `InpColorRes` (*default: `clrDodgerBlue`*): Color applied to R1, R2, and R3.
* `InpStyleRes` (*default: `STYLE_SOLID`*): Line style for resistance lines.
* `InpWidthRes` (*default: `1`*): Line thickness for resistance lines.

### Visual Settings - Support Levels

* `InpColorSup` (*default: `clrFireBrick`*): Color applied to S1, S2, and S3.
* `InpStyleSup` (*default: `STYLE_SOLID`*): Line style for support lines.
* `InpWidthSup` (*default: `1`*): Line thickness for support lines.

### Visual Settings - Medians

* `InpShowMedians` (*default: `true`*): Toggle arithmetic midpoint levels between main pivots.
* `InpColorMed` (*default: `clrSilver`*): Color for median lines.
* `InpStyleMed` (*default: `STYLE_DOT`*): Line style for median lines.
* `InpWidthMed` (*default: `1`*): Line thickness for median lines.

### Labels

* `InpShowLabels` (*default: `true`*): Toggle text identifiers (PP, R1, S1, etc.) on the chart.
* `InpLabelShift` (*default: `8`*): Offset distance (in bars) extending into the forward chart shift space.
* `InpFontSize` (*default: `8`*): Font size of the text identifiers.

---

## 5. Usage & Trading Interpretation

### 5.1. Directional Bias (The Central Pivot)

* **Bullish Bias:** Price established above $PP$. Look for pullbacks toward $PP$ or momentum continuations toward $R1$, $R2$, and $R3$.
* **Bearish Bias:** Price established below $PP$. Look for pullbacks toward $PP$ or momentum continuations toward $S1$, $S2$, and $S3$.

### 5.2. Mean Reversion vs. Momentum Breakout

* **Ranging Markets (Consolidation):** Support levels ($S1, S2$) act as demand pools; resistance levels ($R1, R2$) act as supply caps. Fades from $S1$ toward $PP$ and $R1$ toward $PP$ offer favorable risk-to-reward ratios.
* **Trending Markets (Breakout Expansion):** A decisive candle close beyond $R1$ or $S1$ confirms momentum, shifting the next targets to $R2/R3$ or $S2/S3$.

### 5.3. Role of Median Lines ($M_1 \dots M_6$)

* Medians serve as early take-profit targets or entry-confirmation zones before committing to full structural target levels.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Formula / Level | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufferPP` | $PP$ | Central Pivot Point |
| **1** | `BufferR1` | $R1$ | First Resistance Level |
| **2** | `BufferS1` | $S1$ | First Support Level |
| **3** | `BufferR2` | $R2$ | Second Resistance Level |
| **4** | `BufferS2` | $S2$ | Second Support Level |
| **5** | `BufferR3` | $R3$ | Third Resistance Level |
| **6** | `BufferS3` | $S3$ | Third Support Level |
| **7** | `BufferM1` | $(S1 + S2)/2$ | Median Between S1 and S2 |
| **8** | `BufferM2` | $(S1 + PP)/2$ | Median Between S1 and PP |
| **9** | `BufferM3` | $(PP + R1)/2$ | Median Between PP and R1 |
| **10** | `BufferM4` | $(R1 + R2)/2$ | Median Between R1 and R2 |
| **11** | `BufferM5` | $(R2 + R3)/2$ | Median Between R2 and R3 |
| **12** | `BufferM6` | $(S2 + S3)/2$ | Median Between S2 and S3 |

*All buffers return `EMPTY_VALUE` for historical periods outside the active session, maintaining a pristine and deterministic environment for backtesting and automated execution.*
