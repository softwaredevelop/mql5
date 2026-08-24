# Session-Anchored Kaufman's Adaptive Moving Average (AKAMA) Pro (v1.00)

Quantitative Session-Anchored Adaptive Equilibrium Baseline Suite

---

## 1. Summary (Introduction)

**KAMA Anchored Pro (AKAMA Pro)** is a professional-grade trend and equilibrium overlay indicator that calculates **Perry Kaufman's Adaptive Moving Average anchored to specific periodic market boundaries**.

Standard rolling moving averages carry historical baggage from low-liquidity overnight trading sessions (such as the Asian drift), leading to distorted baseline readings during high-volume regular trading hours (RTH). **AKAMA Pro eliminates cross-session pollution** by re-seeding its calculation exactly at key institutional liquidity events—such as the **London Stock Exchange (LSE) Open**, **Frankfurt Open**, **New York Cash Open**, or Weekly/Monthly open boundaries.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                        AKAMA BASELINE CONCEPTION                       │
├────────────────────────────────────────────────────────────────────────┤
│  • Resets calculation at defined session opening bar (Anchor Bar)      │
│  • Adapts exclusively using price action within the active session     │
│  • Employs dual Odd/Even buffers to prevent diagonal connecting lines  │
│  • Provides an uncluttered dynamic support/resistance overlay          │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Capabilities

* **Periodic & Custom Session Anchoring:** Supports Daily Session, Weekly Open, Monthly Open, and Custom Institutional Windows (e.g., LSE `08:00 - 16:30`, London/NY Overlap `13:30 - 17:00`).
* **Intra-Session Efficiency Adaptation:** Dynamic lookback window ($N_{\text{eff}}$) adapts immediately from the opening bar, expanding as session candles accumulate.
* **Gapped Odd/Even Line Architecture:** Uses dual alternating buffers (`BufKAMA_Odd`, `BufKAMA_Even`) to guarantee seamless visual gaps between historical sessions without chart-crossing line artifacts.
* **Unified 2026 MTF Framework:** Higher-timeframe session averages (e.g., H1 or H4 AKAMA) map into flat, non-warping steps on intraday execution charts (M1, M5, M15) via `DataSync_Tools.mqh`.
* **Synthetic Heikin Ashi Support:** Fully compatible with filtered Heikin Ashi price series for noise-free institutional trend tracking.

---

## 2. Mathematical Foundations

```text

          Anchor Reset (Session Open: t = 0)
          │
          ├───► Local Lookback: N_eff = min(t - Anchor, ER_Period)
          │
          ├───► Direction:      | Price(t) - Price(t - N_eff) |
          ├───► Volatility:     ∑ | Price(t - j) - Price(t - j - 1) |
          │
          └───► Local AKAMA:    AKAMA(t - 1) + SC(t) · [ Price(t) - AKAMA(t - 1) ]

```

### 2.1. Anchor Boundary Synchronization

At each session boundary bar ($t = \text{Anchor Bar}$), the calculation re-seeds from the opening price:
$$\text{AKAMA}_{\text{anchor}} = P_{\text{anchor}}$$

### 2.2. Intra-Session Lookback Expansion ($N_{\text{eff}}$)

To prevent calculation errors on the opening bars of a new session, the lookback window expands dynamically:
$$k_t = t - \text{Anchor Bar}$$
$$N_{\text{eff}} = \min(k_t, N_{\text{ER}})$$
*where $N_{\text{ER}} = \text{InpErPeriod}$ (default: $10$).*

### 2.3. Intra-Session Efficiency Ratio ($ER$)

Directional net change and total path volatility are computed strictly within the session boundaries:
$$\text{Direction}_t = | P_t - P_{t - N_{\text{eff}}} |$$
$$\text{Volatility}_t = \sum_{j=0}^{N_{\text{eff}}-1} | P_{t-j} - P_{t-j-1} |$$
$$\text{ER}_t = \begin{cases} \frac{\text{Direction}_t}{\text{Volatility}_t}, & \text{if } \text{Volatility}_t > 10^{-9} \\ 0.0, & \text{otherwise} \end{cases}$$

### 2.4. Local Scaled Smoothing Constant ($\text{SC}_t$)

The smoothing constant scales between the fastest ($F$) and slowest ($S$) exponential factors:
$$\alpha_{\text{fast}} = \frac{2}{F + 1}, \quad\quad \alpha_{\text{slow}} = \frac{2}{S + 1}$$
$$\text{SC}_t = \left[ \text{ER}_t \cdot (\alpha_{\text{fast}} - \alpha_{\text{slow}}) + \alpha_{\text{slow}} \right]^2$$

### 2.5. Recursive AKAMA Update

$$\text{AKAMA}_t = \text{AKAMA}_{t-1} + \text{SC}_t \cdot (P_t - \text{AKAMA}_{t-1})$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│               KAMA_Anchored_Calculator.mqh             │
│   (Core Engine: Stateless Anchor & Local KAMA Engine)  │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs AKAMA Odd/Even Buffers in O(1)
                           ▼
┌────────────────────────────────────────────────────────┐
│                   KAMA_Anchored_Pro.mq5                │
│    (Unified Wrapper: Native Timeframe & MTF Engine)    │
├──────────────────────────┬─────────────────────────────┤
│   Buffer Layer (2)       │   MTF & Session Management  │
│   • BufKAMA_Odd (DATA)   │   • DataSync_Tools.mqh      │
│   • BufKAMA_Even (DATA)  │   • Staircase Flat-Force    │
│   • Gapped Line Engine   │   • Odd/Even Period Toggle  │
└──────────────────────────┴─────────────────────────────┘

```

1. **Stateless Deterministic Engine:** `CKamaAnchoredCalculator` processes all session transitions deterministically by comparing timestamps directly, eliminating static memory corruption during real-time tick recalculations.
2. **Gapped Odd/Even Dual Buffering:**
   * Odd session periods populate `BufKAMA_Odd` while `BufKAMA_Even = EMPTY_VALUE`.
   * Even session periods populate `BufKAMA_Even` while `BufKAMA_Odd = EMPTY_VALUE`.
   * This ensures MetaTrader 5 renders crisp, disconnected segments without diagonal lines connecting session ends to session starts.
3. **2026 MTF Framework with Staircase Solution:** Higher-timeframe session averages map into flat, synchronized steps on lower-timeframe charts via `first_bar_of_forming_htf` dynamic anchoring and `DataSync_Tools.mqh`.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Calculation timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (e.g., `PERIOD_M15`, `PERIOD_H1`), it activates the synchronized MTF engine.

### Anchor Settings

* `InpResetPeriod` (*default: `ANCHOR_PERIOD_SESSION`*): Periodic anchor reset mode (`ANCHOR_PERIOD_SESSION`, `ANCHOR_PERIOD_WEEK`, `ANCHOR_PERIOD_MONTH`, `ANCHOR_PERIOD_CUSTOM_SESSION`).
* `InpTzShift` (*default: `0`*): Timezone offset in hours to align midnight resets with broker server time.
* `InpCustomStart` (*default: `"08:00"`*): Session start time (`HH:MM`) when using `ANCHOR_PERIOD_CUSTOM_SESSION` (e.g., LSE Open).
* `InpCustomEnd` (*default: `"17:00"`*): Session end time (`HH:MM`) when using `ANCHOR_PERIOD_CUSTOM_SESSION` (e.g., LSE Close).

### KAMA Core Settings

* `InpErPeriod` (*default: `10`*): Lookback period ($N$) for the KAMA Efficiency Ratio.
* `InpFastEmaPeriod` (*default: `2`*): Fastest smoothing period ($F$) during high directional efficiency.
* `InpSlowEmaPeriod` (*default: `30`*): Slowest smoothing period ($S$) during consolidation.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Input price series (Standard OHLC or Synthetic Heikin Ashi).

### Visual Settings

* `InpColorKAMA` (*default: `clrOrange`*): Color of the AKAMA line.
* `InpStyleKAMA` (*default: `STYLE_SOLID`*): Line style (Solid, Dash, Dot).
* `InpWidthKAMA` (*default: `2`*): Line thickness.

---

## 5. Institutional Trading Playbooks (The Anchor Baseline Advantage)

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   HOW INSTITUTIONS USE ANCHORED KAMA                   │
├────────────────────────────────────────────────────────────────────────┤
│ 1. LSE Open Baseline: Anchored at 08:00 London to capture pure European│
│                       institutional order flow and breakout direction. │
│ 2. Weekly Fair Value: Anchored to Monday 00:00 to serve as the macro   │
│                       institutional benchmark for the trading week.    │
│ 3. Dynamic S/R Flips: Retests of a rising/falling AKAMA provide high-  │
│                       conviction pullback entry triggers.              │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. The London Open Institutional Baseline (LSE Open)

* **Setup:** Configure `InpResetPeriod = ANCHOR_PERIOD_CUSTOM_SESSION`, `InpCustomStart = "08:00"`, `InpCustomEnd = "16:30"`.
* **Execution:** At the 08:00 London bell, the AKAMA baseline seeds from the opening print. If initial order flow is strongly bullish, AKAMA accelerates upward with low lag:
  * **Bullish Bias:** Price holds above rising AKAMA $\rightarrow$ Focus exclusively on long intraday continuations.
  * **Bearish Bias:** Price holds below falling AKAMA $\rightarrow$ Focus exclusively on short intraday continuations.

### 5.2. Weekly Fair Value Equilibrium (Monday Anchor)

* **Setup:** Set `InpResetPeriod = ANCHOR_PERIOD_WEEK`.
* **Strategic Context:** Weekly AKAMA represents the volume-independent, efficiency-weighted mean for the entire trading week.
* **Execution:** Pullbacks from extreme weekly deviations back into the Weekly AKAMA offer high-probability mean-reversion retests or structural continuation bounces.

### 5.3. Multi-Timeframe Macro Anchor Alignment

* Attach an **H1-calculated AKAMA** onto an **M5 execution chart**.
* The flat, synchronized steps clearly show whether intraday pullbacks are respecting the macro institutional baseline, allowing traders to enter with tight risk and macro trend confluence.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufKAMA_Odd` | `INDICATOR_DATA` | Anchored KAMA Values (Odd Session Periods) |
| **1** | `BufKAMA_Even` | `INDICATOR_DATA` | Anchored KAMA Values (Even Session Periods - Gapped) |

### MQL5 Reading Example (`iCustom` Helper)

```mql5
// Helper to extract the single valid AKAMA value from Odd/Even buffers
double GetAKAMAValue(const int handle, const int bar_shift)
{
   double odd[1], even[1];
   if(CopyBuffer(handle, 0, bar_shift, 1, odd) <= 0)  return EMPTY_VALUE;
   if(CopyBuffer(handle, 1, bar_shift, 1, even) <= 0) return EMPTY_VALUE;

   if(odd[0] != EMPTY_VALUE && odd[0] > 0.0)
      return odd[0];
   if(even[0] != EMPTY_VALUE && even[0] > 0.0)
      return even[0];

   return EMPTY_VALUE; // Outside active session hours
}
```

*All buffers strictly maintain non-series chronological order (`ArraySetAsSeries = false`), ensuring seamless, high-speed integration with MetaTrader 5 Expert Advisors.*
