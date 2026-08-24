# Kaufman's Adaptive Moving Average (KAMA) Channel Pro (v3.00)

Quantitative Volatility Envelope & Adaptive Keltner Channel Suite

---

## 1. Summary (Introduction)

**KAMA Channel Pro** is an institutional-grade adaptive volatility envelope based on the Keltner Channel concept. Unlike traditional Keltner Channels that rely on lagging Simple (SMA) or Exponential (EMA) Moving Averages, this indicator utilizes **Perry Kaufman's Adaptive Moving Average (KAMA)** as its dynamic equilibrium centerline, enveloped by **Average True Range (ATR)** volatility bands.

This mathematical synthesis produces an intelligent, regime-switching channel:

* **Trending Phase (High Efficiency):** KAMA accelerates dynamically to track price impulses closely, while expanding ATR bands encapsulate directional momentum without generating premature counter-trend exit signals.
* **Consolidation Phase (Low Efficiency / Chop):** KAMA aggressively flattens out, transforming the channel into a stationary horizontal trading range that precisely defines institutional supply (Upper Band) and demand (Lower Band) boundaries.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        KAMA CHANNEL ARCHITECTURE                       │
├────────────────────────────────────────────────────────────────────────┤
│  Upper Band:  KAMA(t) + [Multiplier × ATR(t)]                          │
│  Middle Band: Kaufman's Adaptive Moving Average (Centerline)           │
│  Lower Band:  KAMA(t) - [Multiplier × ATR(t)]                          │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **Adaptive Centerline Engine:** Low-lag trend tracking during expansions; horizontal baseline during sideways chop.
* **Wilder-Compliant Volatility Envelope:** Employs Wilder's classic RMA (Recursive Moving Average) smoothing for True Range calculations.
* **Hybrid Price Routing:** Allows independent price source selection (e.g., Heikin Ashi KAMA Centerline combined with Standard OHLC Volatility Bands).
* **2026 MTF Framework with DataSync Daemon:** High-performance multi-timeframe synchronization powered by `DataSync_Tools.mqh` with real-time flat-step staircase mapping.
* **Full Visual Customization:** Independent styling controls for the KAMA centerline and outer volatility boundaries.

---

## 2. Mathematical Foundations

```text

                            Upper Band: KAMA + (M · ATR)
          ═══════════════════════════════════════════════════════════════
                             ▲ Volatility Expansion (ATR)
                             │
          ───────────────────┼───────────────────────────────────────────
                             │ KAMA Centerline (Equilibrium)
                             ▼
          ═══════════════════════════════════════════════════════════════
                            Lower Band: KAMA - (M · ATR)

```

### 2.1. Centerline Calculation (KAMA)

The central equilibrium line is determined by the market's **Efficiency Ratio (ER)**:
$$\text{Direction}_t = | P_t - P_{t-N} |$$
$$\text{Volatility}_t = \sum_{i=0}^{N-1} | P_{t-i} - P_{t-i-1} |$$
$$\text{ER}_t = \frac{\text{Direction}_t}{\text{Volatility}_t}$$

The Scaled Smoothing Constant ($\text{SC}_t$) scales between the fastest ($F$) and slowest ($S$) exponential factors:
$$\alpha_{\text{fast}} = \frac{2}{F + 1}, \quad\quad \alpha_{\text{slow}} = \frac{2}{S + 1}$$
$$\text{SC}_t = \left[ \text{ER}_t \cdot (\alpha_{\text{fast}} - \alpha_{\text{slow}}) + \alpha_{\text{slow}} \right]^2$$
$$\text{Middle}_t = \text{KAMA}_t = \text{KAMA}_{t-1} + \text{SC}_t \cdot (P_t - \text{KAMA}_{t-1})$$

---

### 2.2. Volatility Bands Calculation (Wilder's ATR)

The channel width is governed by the Average True Range over period $P_{\text{ATR}}$:

#### 1. True Range ($TR$)

$$\text{TR}_t = \max \left( H_t - L_t, \; |H_t - C_{t-1}|, \; |L_t - C_{t-1}| \right)$$

#### 2. Wilder's RMA Smoothing

$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \cdot (P_{\text{ATR}} - 1) + \text{TR}_t}{P_{\text{ATR}}}$$

#### 3. Outer Band Projection

$$\text{Upper Band}_t = \text{Middle}_t + (M \cdot \text{ATR}_t)$$
$$\text{Lower Band}_t = \text{Middle}_t - (M \cdot \text{ATR}_t)$$
*where $M = \text{InpMultiplier}$ (Channel Width Multiplier).*

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│               KAMA_Channel_Calculator.mqh              │
│    (Core Math Engine - Composition of KAMA & ATR)      │
└──────────────────────────┬─────────────────────────────┘
                           │ Calculates Middle, Upper & Lower Bands (O(1))
                           ▼
┌────────────────────────────────────────────────────────┐
│                  KAMA_Channel_Pro.mq5                  │
│     (Unified Wrapper: Native Timeframe & MTF Engine)   │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • Zero-Overhead Bypass │   • Non-Repainting Step Map │
└──────────────────────────┴─────────────────────────────┘

```

1. **Modular Composition Pattern:** `CKamaChannelCalculator` embeds `CKamaCalculator` and `CATRCalculator` directly via composition, guaranteeing zero memory fragmentation and eliminating obsolete polymorphic class duplication.
2. **2026 High-Performance MTF Pipeline:**
   * **Asynchronous Data Guard:** Background 1-second timer daemon (`OnTimerUpdate`) manages history readiness without chart-blinking.
   * **Forming LTF Block Flat-Force (Staircase Solution):** The mapping start index snaps to `first_bar_of_forming_htf`, updating all lower-timeframe sub-bars of the live higher-timeframe candle simultaneously.
   * **State-Safe Live Bar Mocking:** Formulating HTF ticks are computed in real-time on index `g_htf_count - 1` without overwriting historical recursion registers.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Timeframe for calculation. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### KAMA Middle Settings

* `InpErPeriod` (*default: `10`*): Lookback period ($N$) for the KAMA Efficiency Ratio calculation.
* `InpFastEmaPeriod` (*default: `2`*): Fastest smoothing period ($F$) during high-efficiency trends.
* `InpSlowEmaPeriod` (*default: `30`*): Slowest smoothing period ($S$) during low-efficiency consolidations.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Applied price source for the KAMA centerline (Standard OHLC or Synthetic Heikin Ashi).

### Channel (ATR) Settings

* `InpAtrPeriod` (*default: `14`*): Lookback period ($P_{\text{ATR}}$) for volatility calculation.
* `InpMultiplier` (*default: `2.0`*): Volatility band multiplier ($M$).
* `InpAtrSource` (*default: `ATR_SOURCE_STANDARD`*): Selects whether True Range is derived from Standard candles or filtered Heikin Ashi candles.

### Visual Settings - Middle Line

* `InpColorMiddle` (*default: `clrCrimson`*): Color of the KAMA centerline.
* `InpStyleMiddle` (*default: `STYLE_SOLID`*): Line style of the KAMA centerline.
* `InpWidthMiddle` (*default: `2`*): Line thickness of the KAMA centerline.

### Visual Settings - Outer Bands

* `InpColorBands` (*default: `clrDarkOrange`*): Color applied to Upper and Lower volatility bands.
* `InpStyleBands` (*default: `STYLE_DOT`*): Line style for outer bands.
* `InpWidthBands` (*default: `1`*): Line thickness for outer bands.

---

## 5. Quantitative Trading Strategies & Signal Mechanics

```text

                  THE KAMA VOLATILITY SQUEEZE CYCLE

       Flat Centerline + Narrow Bands   ───►  Consolidation (Squeeze Build-up)
       Candle Close Outside Band        ───►  Explosive Volatility Expansion
       Price Riding Outer Band          ───►  Strong Trend In Progress
       Candle Close Inside Band         ───►  Exhaustion / Pullback to Centerline

```

### 5.1. The "Flatline" Volatility Squeeze (Breakout Setup)

* **Pre-Condition:** The KAMA centerline flattens out horizontally and the channel narrows significantly (contracting ATR). This identifies an institutional accumulation/distribution zone.
* **Trigger:** A decisive candle close beyond the Upper Band (Long) or Lower Band (Short) with an expanding KAMA Slope confirms an explosive volatility breakout.

### 5.2. Mean-Reversion Range Trading (The Fading Strategy)

* **Pre-Condition:** KAMA centerline is completely flat and horizontal.
* **Short Trigger:** Price spikes into the Upper Band and rejects $\rightarrow$ Target: KAMA Centerline.
* **Long Trigger:** Price drops into the Lower Band and rejects $\rightarrow$ Target: KAMA Centerline.

### 5.3. Multi-Timeframe Trend Envelopes (HTF Macro Filter)

By applying a Higher-Timeframe KAMA Channel (e.g., `PERIOD_H4` or `PERIOD_D1`) onto an intraday `M5` chart:

* Only take intraday long trades when price is trading in the upper half of the macro channel (between HTF Middle and HTF Upper Band).
* Only take intraday short trades when price is trading in the lower half of the macro channel (between HTF Middle and HTF Lower Band).

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufferUpper` | `INDICATOR_DATA` | Upper Volatility Band ($\text{Middle} + M \cdot \text{ATR}$) |
| **1** | `BufferLower` | `INDICATOR_DATA` | Lower Volatility Band ($\text{Middle} - M \cdot \text{ATR}$) |
| **2** | `BufferMiddle` | `INDICATOR_DATA` | KAMA Equilibrium Centerline ($\text{Middle}$) |

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and multi-indicator scanner dashboards via `iCustom()`.*
