# Universal Moving Average (Moving Average) Pro (v3.00)

Quantitative Universal Smoothing Engine & Multi-Algorithm Moving Average Suite

---

## 1. Summary (Introduction)

**Moving Average Pro** is the universal baseline trend overlay of the Professional MQL5 Suite. Built upon the core `MovingAverage_Engine.mqh`, it synthesizes eight classical, low-lag, and volume-weighted moving average algorithms into a single unified high-performance indicator.

Moving averages serve as the foundation for trend identification, dynamic support and resistance, and signal line smoothing across quantitative trading systems. **Moving Average Pro provides instant algorithm interchangeability without altering indicator pipelines or charting architecture**:

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   THE 8 MOVING AVERAGE ALGORITHMS                      │
├───────┬────────────────────────┬───────┬───────────────────────────────┤
│ Type  │ Full Mathematical Name │ Type  │ Full Mathematical Name        │
├───────┼────────────────────────┼───────┼───────────────────────────────┤
│ SMA   │ Simple Moving Average  │ TMA   │ Triangular Moving Average     │
│ EMA   │ Exponential Moving Avg │ DEMA  │ Double Exponential Moving Avg │
│ SMMA  │ Smoothed MA (Wilder)   │ TEMA  │ Triple Exponential Moving Avg │
│ LWMA  │ Linear Weighted MA     │ VWMA  │ Volume-Weighted Moving Avg    │
└───────┴────────────────────────┴───────┴───────────────────────────────┘

```

### Key Capabilities

* **8 Native Smoothing Models:** Seamlessly switch between linear, exponential, multi-stage zero-lag, and volume-weighted smoothing.
* **Full Volume Routing (VWMA):** Automatically queries broker `SYMBOL_VOLUME_LIMIT` to utilize Real Volume (`VOLUME_REAL`) or Tick Volume (`VOLUME_TICK`).
* **Unified 2026 MTF Framework:** Higher-timeframe moving averages (e.g., H1 or Daily 50/200 MAs) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Computes smoothed curves from filtered Heikin Ashi price series via `CMovingAverageCalculator_HA` composition.
* **State-Safe $O(1)$ Recursive Execution:** Stateful recursive smoothing registers (EMA, SMMA, DEMA, TEMA) update in zero latency on live market ticks.

---

## 2. Mathematical Foundations & The 8 Smoothing Models

```text

                  RAW INPUT SERIES: Close, Median, Typical, HA Close
                                           │
       ┌───────────────┬───────────────────┼───────────────────┬───────────────┐
       ▼               ▼                   ▼                   ▼               ▼
   Linear        Exponential           Double/Triple       Triangular       Volume-Weighted
  (SMA/LWMA)     (EMA/SMMA)            (DEMA/TEMA)           (TMA)              (VWMA)

```

### 2.1. Simple Moving Average (SMA)

Arithmetic mean of the previous $P = \text{InpPeriod}$ bars:
$$\text{SMA}_t = \frac{1}{P} \sum_{j=0}^{P-1} P_{t-j}$$

---

### 2.2. Exponential Moving Average (EMA)

First-order recursive Infinite Impulse Response (IIR) filter:
$$\alpha = \frac{2}{P + 1}, \quad\quad \text{EMA}_t = \alpha P_t + (1 - \alpha) \text{EMA}_{t-1}$$
*The initial seed is computed as an SMA over the first $P$ bars.*

---

### 2.3. Smoothed Moving Average (SMMA / Wilder's RMA)

J. Welles Wilder Jr.'s recursive smoothing algorithm (equivalent to an EMA with $\alpha = 1/P$):
$$\text{SMMA}_t = \frac{\text{SMMA}_{t-1} \cdot (P - 1) + P_t}{P}$$

---

### 2.4. Linear Weighted Moving Average (LWMA)

Weights prices linearly proportional to their temporal recency:
$$W_j = P - j$$
$$\text{LWMA}_t = \frac{\sum_{j=0}^{P-1} P_{t-j} \cdot (P - j)}{\sum_{j=0}^{P-1} (P - j)} = \frac{\sum_{j=0}^{P-1} P_{t-j} \cdot (P - j)}{\frac{P(P + 1)}{2}}$$

---

### 2.5. Triangular Moving Average (TMA)

Double-smoothed simple moving average producing a triangular weighting kernel:
$$P_1 = \text{ceil}\left( \frac{P + 1}{2} \right), \quad\quad P_2 = P - P_1 + 1$$
$$\text{TMA}_t = \text{SMA}\left( \text{SMA}(P, P_1), P_2 \right)$$

---

### 2.6. Double Exponential Moving Average (DEMA - Patrick Mulloy)

Eliminates first-order exponential phase lag:
$$\text{EMA1}_t = \text{EMA}(P, P), \quad\quad \text{EMA2}_t = \text{EMA}(\text{EMA1}, P)$$
$$\text{DEMA}_t = 2 \cdot \text{EMA1}_t - \text{EMA2}_t$$

---

### 2.7. Triple Exponential Moving Average (TEMA - Patrick Mulloy)

Eliminates second-order exponential phase lag for ultra-fast trend tracking:
$$\text{EMA1}_t = \text{EMA}(P, P), \quad \text{EMA2}_t = \text{EMA}(\text{EMA1}, P), \quad \text{EMA3}_t = \text{EMA}(\text{EMA2}, P)$$
$$\text{TEMA}_t = 3 \cdot \text{EMA1}_t - 3 \cdot \text{EMA2}_t + \text{EMA3}_t$$

---

### 2.8. Volume-Weighted Moving Average (VWMA)

Weights price bars directly proportional to transacted trade volume ($V$):
$$\text{VWMA}_t = \frac{\sum_{j=0}^{P-1} P_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{P-1} V_{t-j}}$$

---

### 2.9. Algorithm Selection & Performance Matrix

| Algorithm | Smoothness | Phase Latency (Lag) | Noise Resistance | Optimal Market Context |
| :--- | :---: | :---: | :---: | :--- |
| **SMA** | Medium | High | High | Long-term macro benchmarks (e.g., 200 SMA). |
| **EMA** | High | Medium | Medium | General trend-following and MACD-style filtering. |
| **SMMA** | Very High | High | Very High | Wilder-style indicators (RSI, ADX, ATR). |
| **LWMA** | Medium | Low | Low | Short-term momentum tracking and signal lines. |
| **TMA** | Ultra-High | Very High | Ultra-High | Wave cycle analysis; filters all high frequencies. |
| **DEMA** | Medium | Very Low | Low | Fast trend trading; reduces 50% of EMA lag. |
| **TEMA** | Low | Near-Zero | Very Low | High-frequency scalping; eliminates almost all lag. |
| **VWMA** | High | Adaptive | High | Institutional liquidity analysis; volume-confirmed trends. |

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                MovingAverage_Engine.mqh                │
│    (Core Universal Math: 8 MA Algorithms in O(1))      │
├──────────────────────────┬─────────────────────────────┤
│   Volume Routing Layer   │   Composition Engine        │
│   • Real Volume Support  │   • CMovingAverageCalc_HA   │
│   • Tick Volume Fallback │   • Dynamic Price Routing   │
└──────────────────────────┴─────────────────────────────┘
                           │ Outputs MA Series in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                 MovingAverage_Pro.mq5                  │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 1 Output Plot        │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **State-Safe Recursive Lifecycles:** EMA, SMMA, DEMA, and TEMA calculators maintain persistent state registers without historical array corruption on live bar additions.
2. **Unified Volume Routing:** Automatically extracts real trade volume (`CopyRealVolume`) on supported exchange assets (Equities, Futures, Crypto) and seamlessly falls back to tick volume (`CopyTickVolume`) on Forex CFDs.
3. **2026 MTF Framework with Staircase Solution:** Higher-timeframe moving averages map onto lower-timeframe execution charts with flat, synchronized steps via `first_bar_of_forming_htf` dynamic anchoring and `DataSync_Tools.mqh`.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### Moving Average Core Settings

* `InpPeriod` (*default: `20`*): Lookback smoothing period ($P$).
* `InpMAType` (*default: `SMA`*): Mathematical algorithm selection (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Input price series (Supports all 7 Standard and 7 Heikin Ashi modes).

### Visual Settings

* `InpColorMA` (*default: `clrDodgerBlue`*): Line color.
* `InpStyleMA` (*default: `STYLE_SOLID`*): Line style (Solid, Dash, Dot).
* `InpWidthMA` (*default: `2`*): Line thickness.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   MOVING AVERAGE TRADING PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Trend Baseline Retest: Pullbacks to rising EMA/VWMA offer low-risk  │
│                           continuation entries in strong markups.      │
│ 2. Institutional Cross:   50 EMA crossing above 200 SMA confirms a     │
│                           macro Golden Cross regime shift.             │
│ 3. MTF Macro Step Filter: Only execute M5 long setups when price is    │
│                           trading above the H1 50 EMA flat step.       │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Dynamic Support & Resistance Pullbacks

* **Bullish Setup:** Price is trending upward above a rising **`20 EMA`** or **`20 VWMA`**. When price pulls back to test the moving average line and prints a rejection wick $\rightarrow$ High-conviction long continuation entry.
* **Bearish Setup:** Price is trending downward below a falling moving average line. Retests of the line from below offer short entry triggers.

### 5.2. Golden Cross & Death Cross Confirmation

* **Golden Cross (Macro Bullish):** Faster moving average (e.g., `50 EMA`) crosses **above** a slower baseline (e.g., `200 SMA`) $\rightarrow$ Institutional confirmation of a long-term bull market.
* **Death Cross (Macro Bearish):** Faster moving average crosses **below** the slower baseline $\rightarrow$ Institutional confirmation of a bear market.

### 5.3. Multi-Timeframe Macro Alignment Filter

* Attach an **H1-calculated 50 EMA** or **H4-calculated 200 SMA** onto an **M5 execution chart**.
* **Rule:** Only take intraday long trades when **price is above the higher-timeframe flat step**. This ensures zero counter-trend trading against macro institutional liquidity.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferMA` | `INDICATOR_DATA` | Universal Moving Average Plot Line |

*The buffer strictly maintains non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
