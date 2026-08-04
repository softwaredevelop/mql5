# Institutional Session Analysis Single Pro (V1.21)

## Intraday Market Profiling & Volume-Weighted Value Suite

## 1. Summary (Introduction)

The **Session_Analysis_Single_Pro (V1.21)** is an institutional-grade, real-time intraday market profiling, volume-weighted value tracking, and structural boundary engine.

In professional trading, the 24-hour cycle is not a single homogeneous block of price action. Volatility, liquidity, and institutional participation shift dynamically across specific daylight segments. This indicator segmentizes the trading day into four custom-defined, daylight-aligned sub-sessions based on your broker's server time:

1. **Pre-Market Session:** Tracks early positioning, overnight order buildup, and overnight price gaps.
2. **Core Trading Session:** Tracks the primary high-liquidity open-to-close period of the local exchange (where institutional direction is established).
3. **Post-Market Session:** Tracks late-day settlement, late block-trades, and closing market-on-close (MOC) orders.
4. **Full Day Session:** Combines all three periods into a single, unified daily macro perspective.

For each active session, the indicator draws high-low structural Support/Resistance boundaries (Session Boxes), calculates the arithmetic Mean, projects least-squares **Linear Regression trendlines** ($a + bX$), and plots gapped, alternating **Volume Weighted Average Price (VWAP)** lines to prevent visual connection distortion.

---

## 2. Mathematical & Algorithmic Foundations

The underlying `Session_Analysis_Calculator.mqh` and `VWAP_Calculator.mqh` engines compute four distinct mathematical baselines for each active sub-session:

### A. Session Support & Resistance Boundaries (High/Low)

For each identified session starting at bar $S$ and ending at bar $E$, the indicator dynamically tracks the absolute highest high and lowest low of the chosen price source (Standard or Heikin Ashi):

$$\text{Session High} = \max_{j=S \dots E} (H_j), \quad \text{Session Low} = \min_{j=S \dots E} (L_j)$$

### B. Session Mean Price

Calculates the simple arithmetic average of the user-selected `Source Price` ($P_i$):

$$\text{Mean Price} = \frac{1}{W} \sum_{i=S}^{E} P_i$$

Where $W = E - S + 1$ represents the session width (bar count).

### C. Least-Squares Linear Regression Line

Calculates the "least squares fit" trendline across the active session to measure directional velocity and trend integrity:

$$\text{Slope } (b) = \frac{W \sum_{i=S}^{E} (X_i \cdot Y_i) - \sum_{i=S}^{E} X_i \sum_{i=S}^{E} Y_i}{W \sum_{i=S}^{E} X_i^2 - \left(\sum_{i=S}^{E} X_i\right)^2}$$

$$\text{Intercept } (a) = \frac{\sum_{i=S}^{E} Y_i - b \sum_{i=S}^{E} X_i}{W}$$

$$\text{Start Price} = a, \quad \text{End Price} = a + b \times (W - 1)$$

Where $X_i$ is mapped to chronological bar coordinates ($0 \dots W-1$) and $Y_i$ represents the corresponding price $P_i$.

### D. Gapped, Alternating Session VWAP

VWAP is calculated cumulatively starting from the first bar of each session ($S$) and resets to zero at the start of the next session:

$$\text{VWAP}_t = \frac{\sum_{i=S}^{t} (P_i \times V_i)}{\sum_{i=S}^{t} V_i}$$

To prevent MT5 from drawing a continuous diagonal connection line from the end of one session to the start of the next session (the "gapping" problem), the indicator calculates VWAP into two alternating buffers: **Odd** and **Even**. If the active session index is odd, the values are written to `Buffer_Odd[]` while `Buffer_Even[]` is filled with `EMPTY_VALUE`, preventing visual line connection.

---

## 3. The V1.21 Architectural Upgrades (Bug Resolutions)

Version 1.21 implements critical bug fixes to eliminate platform-specific drawing anomalies:

### A. The Weighted Price Index-Out-of-Bounds Resolution

In the legacy `PrepareSourceData` method, the calculation of the weighted price was translated with an index multiplication error:

```mql5
// CRITICAL BUG (Legacy):
m_src_price[i] = (high[i] + low[i] + close[i * 2.0]) * 0.25;
```

* **The Cause:** Multiplying the index `i` by `2.0` caused the array to access out-of-bounds memory. Since MT5 returns `0.0` or random uninitialized memory for out-of-bounds accesses in local arrays, `m_src_price[]` was calculated as `0.0` or close to it for many bars.
* **The Lancer-Reaction:** This corrupted `m_src_price[]` led to a `mean_price` and `end_price` that were close to `0.0`. Since `0.0` is far below standard asset prices, the trend lines (`Mean` and `LinReg`) were drawn shooting straight down to the bottom of the chart, creating an ugly **vertical grid/striation** on M5 and completely distorting the slope on M1.
* **The Resolution:** Corrected to proper price multiplication, completely curing both the vertical lines and the slope distortion:

```mql5
m_src_price[i] = (high[i] + low[i] + 2.0 * close[i]) * 0.25;
```

### B. Stateful Incremental Puffer-Wipe Resolution

In legacy code, `ArrayInitialize` wiped all VWAP buffers to `EMPTY_VALUE` at the start of every tick, while the state-persistent calculators only calculated from `prev_calculated - 1` forward.

* **The Cause:** This wiped out all previously calculated historical segments on every tick, leaving only the active forming bar plotted, creating disconnected **ghost lines (szellemképek)**.
* **The Resolution:** Wrapped the buffer initialization in a strict `prev_calculated == 0` block, preserving historical segments flawlessly during live tick updates:

```mql5
if(prev_calculated == 0)
  {
   ArrayInitialize(BufferPre_Odd, EMPTY_VALUE);
   // ... (Rest of the buffers)
  }
```

### C. Trendline Boundary Locking

To prevent session mean and regression lines from extending infinitely to the right of the chart, the engine explicitly disables infinite ray properties on the `OBJ_TREND` objects:

```mql5
ObjectSetInteger(0, mean_line_name, OBJPROP_RAY_RIGHT, false);
ObjectSetInteger(0, mean_line_name, OBJPROP_RAY_LEFT, false);
```

---

## 4. Parameters

### A. Global Settings

* **`InpMarketName`:** Unique string identifier for the market (e.g. `"NYSE"`, `"LSE"`). Used to generate unique graphical object prefixes, preventing collisions when running multiple instances on the same chart.
* **`InpFillBoxes`:** Toggles filled background rectangles vs. transparent outlines.
* **`InpMaxHistoryDays`:** Limits the historical depth of drawn objects (Default: `5` days). Prevents terminal bloat and keeps templates compact.
* **`InpVolumeType`:** Selects `Tick Volume` or `Real Volume` (Exchange) as the weighting variable for VWAP.
* **`InpCandleSource`:** Selects `Standard` or `Heikin Ashi` prices. If Heikin Ashi is enabled, all calculations (Boxes, Mean, LinReg, and VWAP) are routed through Heikin Ashi smoothed open/high/low/close data.
* **`InpSourcePrice`:** Applied price source for Mean and Linear Regression calculations.

### B. Sub-Session Configurations (Pre-Market, Core, Post, Full)

* **`Enable`:** Toggles the analysis of the specified session on/off.
* **`Start / End`:** Session boundaries in `HH:MM` format, based strictly on your **Broker Server Time**.
* **`Color`:** Custom color assigned to the session's boxes, means, and VWAP plots.
* **`Show VWAP / Mean / LinReg`:** Individual toggles for displaying specific analytical lines.

---

## 5. Trading Session Times Reference

This section provides a detailed reference for the trading hours of major global exchanges to help configure the indicator.

**IMPORTANT:** All times are listed in various time zones for comparison. You must use the times that correspond to your **broker's server time** in the indicator settings. Be aware that you may need to adjust these times twice a year due to Daylight Saving Time (DST) changes.

---

### **New York Stock Exchange (NYSE)**

* **Time Zone**: Eastern Time (ET)
* **DST (USA) in 2025/2026**: Starts March 9, Ends November 2.

#### Summer (EDT, UTC-4)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **New York (EDT)** | 06:30–09:30 | 09:30–16:00 | 16:00–20:00 |
| **UTC** | 10:30–13:30 | 13:30–20:00 | 20:00–00:00 |
| **Nicosia (EEST, UTC+3)** | 13:30–16:30 | 16:30–23:00 | 23:00–03:00 |
| **Budapest (CEST, UTC+2)** | 12:30–15:30 | 15:30–22:00 | 22:00–02:00 |

#### Winter (EST, UTC-5)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **New York (EST)** | 06:30–09:30 | 09:30–16:00 | 16:00–20:00 |
| **UTC** | 11:30–14:30 | 14:30–21:00 | 21:00–01:00 |
| **Nicosia (EET, UTC+2)** | 13:30–16:30 | 16:30–23:00 | 23:00–03:00 |
| **Budapest (CET, UTC+1)** | 12:30–15:30 | 15:30–22:00 | 22:00–02:00 |

---

### **London Stock Exchange (LSE)**

* **Time Zone**: GMT / BST
* **DST (Europe) in 2025/2026**: Starts March 30, Ends October 26.

#### Summer (BST, UTC+1)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **London (BST)** | 05:00–08:00 | 08:00–16:30 | 16:30–17:15 |
| **UTC** | 04:00–07:00 | 07:00–15:30 | 15:30–16:15 |
| **Nicosia (EEST, UTC+3)** | 07:00–10:00 | 10:00–18:30 | 18:30–19:15 |
| **Budapest (CEST, UTC+2)** | 06:00–09:00 | 09:00–17:30 | 17:30–18:15 |

#### Winter (GMT, UTC+0)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **London (GMT)** | 05:00–08:00 | 08:00–16:30 | 16:30–17:15 |
| **UTC** | 05:00–08:00 | 08:00–16:30 | 16:30–17:15 |
| **Nicosia (EET, UTC+2)** | 07:00–10:00 | 10:00–18:30 | 18:30–19:15 |
| **Budapest (CET, UTC+1)** | 06:00–09:00 | 09:00–17:30 | 17:30–18:15 |

---

### **Frankfurt Stock Exchange (Xetra)**

* **Time Zone**: CET / CEST
* **DST (Europe) in 2025/2026**: Starts March 30, Ends October 26.

#### Summer (CEST, UTC+2)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Frankfurt (CEST)** | 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |
| **UTC** | 06:00–07:00 | 07:00–15:30 | 15:30–18:00 |
| **Nicosia (EEST, UTC+3)** | 09:00–10:00 | 10:00–18:30 | 18:30–21:00 |
| **Budapest (CEST, UTC+2)** | 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |

#### Winter (CET, UTC+1)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Frankfurt (CET)** | 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |
| **UTC** | 07:00–08:00 | 08:00–16:30 | 16:30–19:00 |
| **Nicosia (EET, UTC+2)** | 09:00–10:00 | 10:00–18:30 | 18:30–21:00 |
| **Budapest (CET, UTC+1)** | 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |

---

### **Tokyo Stock Exchange (TSE)**

* **Time Zone**: Japan Standard Time (JST), UTC+9 all year.
* **No Daylight Saving Time.**

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Tokyo (JST)** | 08:00–09:00 | 09:00–11:30 | 12:30–15:30 |
| **UTC** | 23:00–00:00 | 00:00–02:30 | 03:30–06:30 |
| **Nicosia** | 01:00–02:00 (W) / 02:00–03:00 (S) | 02:00–04:30 (W) / 03:00–05:30 (S) | 05:30–08:30 (W) / 06:30–09:30 (S) |
| **Budapest** | 00:00–01:00 (W) / 01:00–02:00 (S) | 01:00–03:30 (W) / 02:00–04:30 (S) | 04:30–07:30 (W) / 05:30–08:30 (S) |

---

### **Sydney Stock Exchange (ASX)**

* **Time Zone**: AEST / AEDT
* **DST (Australia) in 2025/2026**: Starts October 5, Ends April 6.

#### Summer (AEDT, UTC+11) (Oct - Apr)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Sydney (AEDT)** | 07:00–10:00 | 10:00–16:00 | 16:00–19:00 |
| **UTC** | 20:00–23:00 | 23:00–05:00 | 05:00–08:00 |
| **Nicosia (EET, UTC+2)** | 22:00–01:00 | 01:00–07:00 | 07:00–10:00 |
| **Budapest (CET, UTC+1)** | 21:00–00:00 | 00:00–06:00 | 06:00–09:00 |

#### Winter (AEST, UTC+10) (Apr - Oct)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Sydney (AEST)** | 07:00–10:00 | 10:00–16:00 | 16:00–19:00 |
| **UTC** | 21:00–00:00 | 00:00–06:00 | 06:00–09:00 |
| **Nicosia (EEST, UTC+3)** | 00:00–03:00 | 03:00–09:00 | 09:00–12:00 |
| **Budapest (CEST, UTC+2)** | 23:00–02:00 | 02:00–08:00 | 08:00–11:00 |

---

## 6. Intraday Quantitative Trading Applications

### A. The Pre-Market Liquidity Sweep (Core Open Reversion)

The Pre-Market range represents the overnight retail positioning boundary. Institutional market makers often sweep these boundaries at the Core session open to capture deep liquidity pools before driving the true trend direction.

1. **Trade Setup:** Load the indicator on an M5 or M15 chart. Enable both Pre-Market and Core Trading sessions.
2. **The Execution:**
   * Mark the High and Low of the completed Pre-Market Range Box.
   * At the opening of the Core session (e.g., NYSE `16:30` Broker Time / `09:30` EST), look for a sudden, high-volume price spike that sweeps outside the Pre-Market High/Low.
   * **BUY Trigger:** Enter Long if the price sweeps below the Pre-Market Low and immediately closes back *inside* the Pre-Market range, showing strong bullish rejection.
   * **SELL Trigger:** Enter Short if the price sweeps above the Pre-Market High and closes back *inside* the Pre-Market range.
3. **Risk Management:** Place Stop Loss below the rejection swing low. Take Profit at the opposing Pre-Market boundary or at the Core VWAP line.

### B. Core Session VWAP Mean-Reversion Squeeze

During the Core session, price frequently deviates from its VWAP (institutional average) due to short-term retail momentum. When this momentum exhausts and the linear regression line flattens, price reverts back to the session's fair value.

1. **Trade Setup:** Load the indicator on an M15 chart. Enable Core Trading and Core VWAP.
2. **The Execution:**
   * Identify when the price has deviated significantly from the active Core VWAP line (trading near the upper or lower boundaries of the Session Box).
   * Confirm that the Linear Regression slope line has flattened (pointing sideways or starting to curve back), indicating a loss of trend velocity.
   * **Trigger:** Enter Short if price is at the top of the box and starts breaking down, or enter Long if price is at the bottom of the box and starts bouncing up.
3. **Risk Management:** Stop Loss is placed strictly outside the session high/low. Take Profit is targeted at the active **Core VWAP line** (the dynamic fair value of the session).
