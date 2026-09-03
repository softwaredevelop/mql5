# Universal Session-Anchored Moving Average Pro (v3.00)

Quantitative Multi-Algorithm Periodic & Custom Session-Anchored Baseline Suite

---

## 1. Summary (Introduction)

**Moving Average Anchored Pro** is an institutional-grade trend and equilibrium overlay indicator that applies **periodic and custom session anchoring across eight classical, zero-lag, and volume-weighted moving average algorithms**.

Standard rolling moving averages carry historical price noise across session boundaries (such as low-volume overnight Asian drift polluting the London morning open). **Moving Average Anchored Pro eliminates cross-session pollution by re-seeding its calculation baseline at defined calendar and trading session boundaries**:

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   ANCHORED MOVING AVERAGE ARCHITECTURE                 │
├──────────────────────┬────────────────────────┬────────────────────────┤
│     Anchor Mode      │   Reset Frequency      │   Optimal Use-Case     │
├──────────────────────┼────────────────────────┼────────────────────────┤
│ ANCHOR_SESSION       │ Daily 00:00 / Server   │ Intraday Trend Anchor  │
│ ANCHOR_WEEK          │ Monday 00:00 Open      │ Weekly Fair-Value Base │
│ ANCHOR_MONTH         │ 1st Day of Month Open  │ Macro Trend Benchmark  │
│ ANCHOR_CUSTOM_SESSION│ User Hours (e.g. LSE)  │ London/NYSE Open Base  │
│ ANCHOR_NONE          │ Continuous Rolling     │ Classic Full Rolling MA│
└──────────────────────┴────────────────────────┴────────────────────────┘

```

### Key Capabilities

* **8 Supported Anchored Smoothing Models:** SMA, EMA, SMMA (Wilder RMA), LWMA, TMA, DEMA, TEMA, and Volume-Weighted VWMA.
* **Dynamic Lookback Expansion ($active\_p$):** At the anchor opening bar, lookback initializes at $active\_p = 1$ (matching opening price exactly), dynamically expanding as session candles accumulate up to the target period ($P = \text{InpPeriod}$).
* **Gapped Odd/Even Line Architecture:** Uses dual alternating buffers (`BufferMA_Odd`, `BufferMA_Even`) to guarantee seamless visual gaps between historical sessions without diagonal connecting lines.
* **Unified 2026 MTF Framework:** Higher-timeframe anchored moving averages (e.g., H1 or H4 Anchored EMA) map onto lower-timeframe execution charts (M1, M5, M15) with flat, non-warping steps via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Fully compatible with filtered Heikin Ashi price series via `CMovingAverageAnchoredCalculator_HA` composition.

---

## 2. Mathematical Foundations & Dynamic Lookback Mechanics

```text

          Anchor Bar (Session Open: t = 0)
          │
          ├───► Dynamic Period: active_p = min( P, elapsed_bars )
          │     (At t=0: active_p=1 -> MA = Opening Price)
          │     (At t=1: active_p=2 -> MA = 2-bar Average)
          │     (At t≥P: active_p=P -> MA = Full Target Smoothing)
          │
          └───► Recursive Dynamic Smoothing Engine (SMA / EMA / DEMA / VWMA)

```

### 2.1. Dynamic Lookback Window Scaling ($active\_p$)

For any bar $t$ within an anchored session starting at $t_{\text{anchor}}$:
$$\text{elapsed\_bars} = t - t_{\text{anchor}} + 1$$
$$active\_p = \begin{cases} P, & \text{if } \text{InpAnchor} = \text{ANCHOR\_NONE} \\ \min(P, \text{elapsed\_bars}), & \text{otherwise} \end{cases}$$
*where $P = \text{InpPeriod}$ (target lookback period).*

---

### 2.2. Anchored Moving Average Algorithms

#### 1. Anchored Simple Moving Average (SMA)

$$\text{SMA}_t = \frac{1}{active\_p} \sum_{j=0}^{active\_p - 1} P_{t-j}$$

#### 2. Anchored Exponential Moving Average (EMA)

$$\alpha_t = \frac{2}{active\_p + 1}$$
$$\text{EMA}_t = \begin{cases} P_t, & \text{if } t = t_{\text{anchor}} \\ \alpha_t P_t + (1 - \alpha_t) \text{EMA}_{t-1}, & \text{for } t > t_{\text{anchor}} \end{cases}$$

#### 3. Anchored Smoothed Moving Average (SMMA / Wilder's RMA)

$$\text{SMMA}_t = \begin{cases} P_t, & \text{if } t = t_{\text{anchor}} \\ \frac{\text{SMMA}_{t-1} \cdot (active\_p - 1) + P_t}{active\_p}, & \text{for } t > t_{\text{anchor}} \end{cases}$$

#### 4. Anchored Linear Weighted Moving Average (LWMA)

$$\text{LWMA}_t = \frac{\sum_{j=0}^{active\_p - 1} P_{t-j} \cdot (active\_p - j)}{\sum_{j=0}^{active\_p - 1} (active\_p - j)}$$

#### 5. Anchored Double Exponential Moving Average (DEMA)

$$\text{EMA1}_t = \text{DynamicEMA}(P, active\_p), \quad\quad \text{EMA2}_t = \text{DynamicEMA}(\text{EMA1}, active\_p)$$
$$\text{DEMA}_t = 2 \cdot \text{EMA1}_t - \text{EMA2}_t$$

#### 6. Anchored Volume-Weighted Moving Average (VWMA)

$$\text{VWMA}_t = \frac{\sum_{j=0}^{active\_p - 1} P_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{active\_p - 1} V_{t-j}}$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│           MovingAverage_Anchored_Engine.mqh            │
│   (Core Math Engine: 8 Anchored Algorithms in O(1))    │
├──────────────────────────┬─────────────────────────────┤
│   Volume Routing Layer   │   Composition Engine        │
│   • Real Volume Support  │   • CMovAvgAnchoredCalc_HA  │
│   • Tick Volume Fallback │   • Dynamic Lookback Memory │
└──────────────────────────┴─────────────────────────────┘
                           │ Outputs Odd/Even Gapped Buffers
                           ▼
┌────────────────────────────────────────────────────────┐
│             MovingAverage_Anchored_Pro.mq5             │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • DataSync_Tools Daemon   │
│   • 2 Output Plots       │   • Staircase Flat-Force    │
└──────────────────────────┴─────────────────────────────┘

```

1. **Defensive Index Bounds Protection:** All inner accumulation loops (`SMA`, `LWMA`, `TMA`, `VWMA`) enforce `if(idx < 0) break;`, guaranteeing that negative index memory violations (`array out of range`) are mathematically impossible.
2. **Stateless Custom Session In-Time Check:** `IsTimeInSession()` evaluates timestamps deterministically with timezone shift (`InpTzShift`), ensuring clean disconnection during non-session hours.
3. **2026 MTF Framework with Staircase Solution:** Higher-timeframe anchored curves map onto lower-timeframe execution charts with flat, synchronized steps via `first_bar_of_forming_htf` dynamic anchoring and `DataSync_Tools.mqh`.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### Moving Average Core Settings

* `InpPeriod` (*default: `20`*): Target smoothing period ($P$).
* `InpMAType` (*default: `SMA`*): Algorithm model (`SMA`, `EMA`, `SMMA`, `LWMA`, `TMA`, `DEMA`, `TEMA`, `VWMA`).
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price series source (Supports all 7 Standard and 7 Heikin Ashi modes).

### Anchor Settings

* `InpAnchor` (*default: `ANCHOR_SESSION`*): Anchor mode (`ANCHOR_NONE`, `ANCHOR_SESSION`, `ANCHOR_WEEK`, `ANCHOR_MONTH`, `ANCHOR_CUSTOM_SESSION`).
* `InpTzShift` (*default: `0`*): Timezone offset in hours vs broker server time.
* `InpCustomStart` (*default: `"09:00"`*): Session start time (`HH:MM`, e.g., European Open).
* `InpCustomEnd` (*default: `"18:00"`*): Session end time (`HH:MM`, e.g., European Close).

### Visual Settings

* `InpColorMA` (*default: `clrDodgerBlue`*): Line color (Width: 2, Solid).
* `InpStyleMA` (*default: `STYLE_SOLID`*): Line style.
* `InpWidthMA` (*default: `2`*): Line thickness.

---

## 5. Institutional Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│               ANCHORED MOVING AVERAGE TRADING PLAYBOOKS                │
├────────────────────────────────────────────────────────────────────────┤
│ 1. London Session Baseline:  Anchor 20 EMA to 08:00 London open to     │
│                              trade pure intraday European order flow.  │
│ 2. Weekly Fair-Value Anchor: Anchor 50 VWMA to Monday 00:00 to track   │
│                              macro weekly volume-weighted equilibrium. │
│ 3. S/R Dynamic Retest:       In strong trends, pullbacks to the rising │
│                              Anchored MA provide tight-stop entries.   │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The London Opening Session Baseline (LSE Open)

* **Configuration:** `InpAnchor = ANCHOR_CUSTOM_SESSION`, `InpCustomStart = "08:00"`, `InpCustomEnd = "16:30"`, `InpMAType = EMA`, `InpPeriod = 20`.
* **Execution:** At the 08:00 London bell, the moving average initializes at the opening price and expands its weighting:
  * **Bullish Momentum:** Price holds above the rising Anchored EMA $\rightarrow$ Focus exclusively on long intraday pullbacks.
  * **Bearish Momentum:** Price holds below the falling Anchored EMA $\rightarrow$ Focus exclusively on short intraday pullbacks.

### 5.2. Weekly Volume-Weighted Fair-Value Anchor (Monday Open)

* **Configuration:** `InpAnchor = ANCHOR_WEEK`, `InpMAType = VWMA`, `InpPeriod = 50`.
* **Strategic Context:** Serves as the institutional volume-weighted benchmark for the entire trading week.
* **Execution:** Pullbacks from extreme weekly extensions back to test the Weekly Anchored VWMA offer high-probability structural bounces or mean-reversion exit targets.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :--- | :--- |
| **0** | `BufferMA_Odd` | `INDICATOR_DATA` | Anchored Moving Average Values (Odd Session Periods) |
| **1** | `BufferMA_Even` | `INDICATOR_DATA` | Anchored Moving Average Values (Even Session Periods - Gapped) |

### MQL5 Reading Example (`iCustom` Helper)

```mql5
double GetAnchoredMAValue(const int handle, const int bar_shift)
{
   double odd[1], even[1];
   if(CopyBuffer(handle, 0, bar_shift, 1, odd) <= 0)  return EMPTY_VALUE;
   if(CopyBuffer(handle, 1, bar_shift, 1, even) <= 0) return EMPTY_VALUE;

   if(odd[0] != EMPTY_VALUE && odd[0] > 0.0)
      return odd[0];
   if(even[0] != EMPTY_VALUE && even[0] > 0.0)
      return even[0];

   return EMPTY_VALUE; // Outside session hours
}
```

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring instant compatibility with Expert Advisors and scanner dashboards via `iCustom()`.*
