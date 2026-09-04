# Classic Keltner Channel (Keltner Channel) Pro (v4.00)

Quantitative Multi-Algorithm Moving Average & ATR Volatility Envelope Suite

---

## 1. Summary (Introduction)

**Keltner Channel Pro** is an institutional-grade volatility envelope indicator based on the classic formula originated by Chester Keltner and refined by Linda Bradford Raschke. It constructs a dynamic, volatility-adjusted price corridor by projecting **Average True Range (ATR)** bands above and below a central **Moving Average baseline**.

Unlike standard Bollinger Bands which rely on standard deviation and are prone to sudden, erratic spikes, **Keltner Channels expand and contract smoothly in direct proportion to true market range**. This creates a reliable envelope for identifying institutional breakout expansion, trend riding, and over-extended mean-reversion exhaustion.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                      KELTNER CHANNEL ARCHITECTURE                      │
├────────────────────────────────────────────────────────────────────────┤
│  Upper Band:  Moving Average(t) + [Multiplier × ATR(t)]                │
│  Middle Band: Universal Centerline Basis (SMA/EMA/LWMA/VWMA)           │
│  Lower Band:  Moving Average(t) - [Multiplier × ATR(t)]                │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **8 Native Centerline Models:** Centerline basis can utilize any moving average algorithm (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, and Volume-Weighted VWMA).
* **Independent Hybrid Routing:** Allows independent price sourcing (e.g., Typical Price EMA Centerline combined with Standard True Range ATR Bands).
* **Full Volume-Weighted Support (VWMA-KC):** Routes Real Volume (`VOLUME_REAL`) and Tick Volume (`VOLUME_TICK`) into the centerline moving average engine.
* **Unified 2026 MTF Framework:** Higher-timeframe Keltner Channels (e.g., H1 or H4) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Fully compatible with filtered Heikin Ashi price series via `CKeltnerChannelCalculator_HA` composition.

---

## 2. Mathematical Foundations & Volatility Envelope Mechanics

```text

                         Upper Band: Middle + (Multiplier · ATR)
       ══════════════════════════════════════════════════════════════════ clrOliveDrab (Dot)
                         ▲ ATR Volatility Corridor
                         │
       ──────────────────┼─────────────────────────────────────────────── clrOliveDrab (Solid)
                         │ Middle Centerline Basis (MA / VWMA)
                         ▼
       ══════════════════════════════════════════════════════════════════ clrOliveDrab (Dot)
                         Lower Band: Middle - (Multiplier · ATR)

```

### 2.1. Centerline Moving Average Basis ($\text{Middle}_t$)

Given input price series $P_t$ (e.g., Typical Price $\frac{H + L + C}{3}$):
$$\text{Middle}_t = \mathcal{MA}\left( P, \text{Period} = P_{\text{MA}}, \text{Type} = \text{InpMaMethod} \right)$$
*where standard parameters are $P_{\text{MA}} = 20$ and $\text{InpMaMethod} = \text{EMA}$.*

---

### 2.2. Wilder's Average True Range ($\text{ATR}_t$)

The True Range ($TR$) captures gap volatility across adjacent bars:
$$TR_t = \max\left( H_t - L_t, \; |H_t - C_{t-1}|, \; |L_t - C_{t-1}| \right)$$
$$\text{ATR}_t = \text{Wilder's RMA}(TR_t, P_{\text{ATR}})$$
*where $P_{\text{ATR}} = \text{InpAtrPeriod}$ (default: $10$).*

---

### 2.3. Dynamic Volatility Band Projections

$$\text{Upper Band}_t = \text{Middle}_t + (M \cdot \text{ATR}_t)$$
$$\text{Lower Band}_t = \text{Middle}_t - (M \cdot \text{ATR}_t)$$
*where $M = \text{InpMultiplier}$ (default: $2.0$).*

---

### 2.4. Volume-Weighted Keltner Model (VWMA-KC)

When `InpMaMethod = VWMA`, the centerline weights prices directly by committed volume:
$$\text{Middle}_{\text{VWMA}, t} = \frac{\sum_{j=0}^{P_{\text{MA}}-1} P_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{P_{\text{MA}}-1} V_{t-j}}$$
$$\text{Upper Band}_t = \text{Middle}_{\text{VWMA}, t} + (M \cdot \text{ATR}_t), \quad\quad \text{Lower Band}_t = \text{Middle}_{\text{VWMA}, t} - (M \cdot \text{ATR}_t)$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│               KeltnerChannel_Calculator.mqh            │
│    (Core Engine: MovingAverage_Engine + ATR_Calculator)│
├──────────────────────────┬─────────────────────────────┤
│   Volume Routing Layer   │   Composition Engine        │
│   • Real Volume Support  │   • CKeltnerChannelCalc_HA  │
│   • Tick Volume Fallback │   • Leak-Free Destructors   │
└──────────────────────────┴─────────────────────────────┘
                           │ Outputs Middle, Upper, Lower in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                 KeltnerChannel_Pro.mq5                 │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 3 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Dual-Engine Composition Architecture:** `CKeltnerChannelCalculator` coordinates `CMovingAverageCalculator` and `CATRCalculator` with zero heap memory leaks and safe pointer destruction (`CheckPointer`).
2. **Full VWMA Volume Routing:** Volume arrays (`h_vol[]` in MTF and `volume[]` in Native) are routed directly into the centerline calculation pipeline.
3. **2026 MTF Framework with Staircase Solution:**
   * Asynchronous 1-second timer daemon (`OnTimerUpdate`) ensures higher-timeframe data synchronization without UI lag.
   * Dynamic staircase anchor (`first_bar_of_forming_htf`) synchronizes all lower-timeframe sub-bars belonging to the active higher-timeframe candle.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### Middle Line (MA) Settings

* `InpMaPeriod` (*default: `20`*): Smoothing period ($P_{\text{MA}}$) for the centerline basis.
* `InpMaMethod` (*default: `EMA`*): Smoothing algorithm for centerline (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpSourcePrice` (*default: `PRICE_TYPICAL_STD`*): Applied price source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Channel (ATR) Settings

* `InpAtrPeriod` (*default: `10`*): Lookback period ($P_{\text{ATR}}$) for volatility calculation.
* `InpMultiplier` (*default: `2.0`*): Volatility band multiplier ($M$).
* `InpAtrSource` (*default: `ATR_SOURCE_STANDARD`*): Selects whether True Range is derived from Standard candles or filtered Heikin Ashi candles.

### Visual Settings - Centerline (Basis)

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
│                   KELTNER CHANNEL TRADING PLAYBOOKS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Volatility Squeeze:   Bollinger Bands contract inside Keltner       │
│                          Channel; breakout outside Keltner = Surge.    │
│ 2. Band Riding Trend:    Candles closing outside Upper/Lower band with │
│                          expanding ATR confirm institutional markup.   │
│ 3. Mean Reversion Fade:  Candles rejecting outer bands in consolidation │
│                          target mean reversion back to Centerline.     │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The Bollinger-Keltner Volatility Squeeze (John Carter Model)

* **Pre-Condition (Squeeze):** Standard Bollinger Bands ($2.0\sigma$) contract **entirely inside** the Keltner Channel ($20\text{ EMA}, 1.5\text{ ATR}$). This indicates that market volatility has compressed to statistical extremes.
* **Trigger (The "Firing" Breakout):** Bollinger Bands expand and break **outside** the Keltner Channel while price decisively closes above the `Upper Band` (Long) or below the `Lower Band` (Short) $\rightarrow$ Enter in the direction of the breakout.

### 5.2. Trend Riding & Trailing Stop Management

* **Bullish Momentum:** During strong trend expansion, price "rides" the `Upper Band`.
* **Execution Rule:** Hold long positions as long as candles continue closing above the `Centerline (Basis)`. Use the Centerline as a dynamic trailing stop.

### 5.3. Multi-Timeframe Macro Envelope Alignment

* Attach an **H1-calculated Keltner Channel** onto an **M5 execution chart**.
* **Rule:** Only take M5 long pullback trades when price is trading in the upper half of the macro channel (between H1 Centerline and H1 Upper Band).

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferUpper` | `INDICATOR_DATA` | Upper Volatility Band ($\text{Middle} + M \cdot \text{ATR}$) |
| **1** | `BufferLower` | `INDICATOR_DATA` | Lower Volatility Band ($\text{Middle} - M \cdot \text{ATR}$) |
| **2** | `BufferMiddle` | `INDICATOR_DATA` | Centerline Moving Average Basis ($\text{Middle}$) |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
