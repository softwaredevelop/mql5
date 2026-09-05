# John Bollinger's Bollinger Bands Pro (v3.00)

Quantitative Multi-Algorithm Moving Average & Standard Deviation Volatility Envelope Suite

---

## 1. Summary (Introduction)

**Bollinger Bands Pro** is an institutional-grade volatility envelope indicator based on the classical formulation developed by technical analyst John Bollinger. It establishes a dynamic, self-adjusting price channel by projecting symmetrical **Standard Deviation ($\sigma$) bands** above and below a central **Moving Average baseline**.

Unlike rigid percentage bands, **Bollinger Bands automatically expand during volatile trend impulses and contract during low-volatility consolidations (The Squeeze)**. This creates an adaptive statistical framework for identifying volatility breakouts, trend-riding continuations, and mean-reverting exhaustion levels.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                     BOLLINGER BANDS ARCHITECTURE                       │
├────────────────────────────────────────────────────────────────────────┤
│  Upper Band:  Moving Average(t) + [Multiplier × StdDev(Price, P)]      │
│  Middle Band: Universal Centerline Basis (SMA/EMA/LWMA/VWMA)           │
│  Lower Band:  Moving Average(t) - [Multiplier × StdDev(Price, P)]      │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **8 Native Centerline Models:** Centerline basis can utilize any moving average algorithm (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, and Volume-Weighted VWMA).
* **Full Volume-Weighted Support (VWMA-BB):** Routes Real Volume (`VOLUME_REAL`) and Tick Volume (`VOLUME_TICK`) directly into the centerline moving average engine.
* **Unified 2026 MTF Framework:** Higher-timeframe Bollinger Bands (e.g., H1 or H4) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Fully compatible with filtered Heikin Ashi price series via `CBollingerBandsCalculator_HA` composition.
* **Foundation for Squeeze Systems:** Provides the primary statistical dispersion engine utilized by advanced volatility breakout systems (such as `Squeeze_Pro`).

---

## 2. Mathematical Foundations & Statistical Dispersion Mechanics

```text

                         Upper Band: Middle + (Deviation · σ)
       ══════════════════════════════════════════════════════════════════ clrOliveDrab (Dot)
                         ▲ Standard Deviation Corridor (2.0σ)
                         │
       ──────────────────┼─────────────────────────────────────────────── clrOliveDrab (Solid)
                         │ Middle Centerline Basis (SMA / EMA / VWMA)
                         ▼
       ══════════════════════════════════════════════════════════════════ clrOliveDrab (Dot)
                         Lower Band: Middle - (Deviation · σ)

```

### 2.1. Centerline Moving Average Basis ($\text{Middle}_t$)

Given input price series $P_t$:
$$\text{Middle}_t = \mathcal{MA}\left( P, \text{Period} = P_{\text{MA}}, \text{Type} = \text{InpMAType} \right)$$
*where standard parameters are $P_{\text{MA}} = 20$ and $\text{InpMAType} = \text{SMA}$.*

---

### 2.2. Rolling Standard Deviation ($\sigma_t$)

Standard deviation measures the Gaussian dispersion of price around the active centerline basis over lookback window $P = \text{InpPeriod}$:
$$\sigma_t = \sqrt{\frac{1}{P} \sum_{k=0}^{P-1} \left( P_{t-k} - \text{Middle}_t \right)^2}$$

---

### 2.3. Dynamic Volatility Band Projections

$$\text{Upper Band}_t = \text{Middle}_t + (D \cdot \sigma_t)$$
$$\text{Lower Band}_t = \text{Middle}_t - (D \cdot \sigma_t)$$
*where $D = \text{InpDeviation}$ (standard deviation multiplier, default: $2.0$).*

---

### 2.4. Volume-Weighted Bollinger Model (VWMA-BB)

When `InpMAType = VWMA`, the centerline weights prices directly by committed trade volume:
$$\text{Middle}_{\text{VWMA}, t} = \frac{\sum_{j=0}^{P-1} P_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{P-1} V_{t-j}}$$
$$\text{Upper Band}_t = \text{Middle}_{\text{VWMA}, t} + (D \cdot \sigma_t), \quad\quad \text{Lower Band}_t = \text{Middle}_{\text{VWMA}, t} - (D \cdot \sigma_t)$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                MovingAverage_Engine.mqh                │
│        (Core Universal Math: 8 MA Types & VWMA)        │
└──────────────────────────┬─────────────────────────────┘
                           │ Powers Centerline Basis
                           ▼
┌────────────────────────────────────────────────────────┐
│             Bollinger_Bands_Calculator.mqh             │
│    (Rolling Standard Deviation & Volatility Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Volume Routing Layer   │   Composition Engine        │
│   • Real Volume Support  │   • CBollingerBandsCalc_HA  │
│   • Tick Volume Fallback │   • Leak-Free Destructors   │
└──────────────────────────┴─────────────────────────────┘
                           │ Outputs Middle, Upper, Lower in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                Bollinger_Bands_Pro.mq5                 │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 3 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular Engine Hierarchy:** `CBollingerBandsCalculator` embeds `CMovingAverageCalculator` with zero heap memory leaks and safe pointer destruction (`CheckPointer`).
2. **Full VWMA Volume Routing:** Volume arrays (`h_vol[]` in MTF and `volume[]` in Native) are routed directly into the centerline calculation pipeline.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe data synchronization without UI lag.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### Bollinger Bands Core Settings

* `InpPeriod` (*default: `20`*): Lookback period ($P$) for the moving average basis and rolling standard deviation.
* `InpDeviation` (*default: `2.0`*): Standard deviation multiplier ($D$) defining channel width ($2.0 = 95.4\%$ Gaussian coverage).
* `InpMAType` (*default: `SMA`*): Centerline algorithm (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Visual Settings - Centerline

* `InpColorMiddle` (*default: `clrOliveDrab`*): Centerline color (Width: 2, Solid).
* `InpStyleMiddle` (*default: `STYLE_SOLID`*): Line style of the centerline.
* `InpWidthMiddle` (*default: `2`*): Line thickness.

### Visual Settings - Outer Bands

* `InpColorBands` (*default: `clrOliveDrab`*): Color applied to Upper and Lower volatility bands.
* `InpStyleBands` (*default: `STYLE_DOT`*): Line style for outer bands.
* `InpWidthBands` (*default: `1`*): Line thickness for outer bands.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   BOLLINGER BANDS TRADING PLAYBOOKS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. The Volatility Squeeze: Band contraction inside Keltner Channel     │
│                            identifies pre-breakout accumulation.       │
│ 2. Walking the Bands:      Candles closing outside bands with expanding│
│                            bandwidth confirm institutional markup.     │
│ 3. W-Bottom / M-Top Fades: Price retesting outer bands with momentum   │
│                            divergence signals high-reward reversals.   │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The Volatility Squeeze (Pre-Breakout Buildup)

* **Pre-Condition:** Bollinger Bands contract sharply, narrowing the distance between Upper and Lower bands.
* **Trigger:** An explosive candle close beyond the Upper Band (Long) or Lower Band (Short) accompanied by expanding bandwidth $\rightarrow$ Enter in the direction of the breakout.

### 5.2. "Walking the Bands" (Trend Riding)

* **Bullish Momentum:** In a powerful trend, price does not reverse upon touching the Upper Band; instead, it "walks" along the outer band as bandwidth expands.
* **Execution Rule:** Maintain long positions as long as candles continue closing above the `Centerline (20 SMA/EMA)`. Use the Centerline as a dynamic trailing stop.

### 5.3. Multi-Timeframe Macro Envelope Alignment

* Attach an **H1-calculated Bollinger Bands (20, 2.0σ)** onto an **M5 execution chart**.
* **Rule:** Only take M5 long pullback trades when price is trading in the upper half of the macro channel (between H1 Centerline and H1 Upper Band).

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferUpperBand` | `INDICATOR_DATA` | Upper Volatility Band ($\text{Middle} + D \cdot \sigma$) |
| **1** | `BufferLowerBand` | `INDICATOR_DATA` | Lower Volatility Band ($\text{Middle} - D \cdot \sigma$) |
| **2** | `BufferCenterLine` | `INDICATOR_DATA` | Centerline Moving Average Basis ($\text{Middle}$) |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
