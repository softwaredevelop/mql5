# Institutional Absorption Pro Detector (Enterprise Ultra Edition v2.20)

## 1. Executive Summary & Market Microstructure Foundations

The **Institutional Absorption Pro Detector** is an institutional-grade quantitative market-microstructure indicator designed for MetaTrader 5 (Year 2026 Enterprise Edition). It detects, classifies, and tracks footprint anomalies where massive institutional volume is absorbed by passive liquidity providers (limit orders) without generating directional price progress.

In modern electronic markets, large tier-1 institutions, market makers, and liquidity consortia cannot execute massive directional block orders using aggressive market orders without triggering devastating price slippage. Instead, they position large passive limit order books (including Iceberg and algorithmic execution algorithms) to "absorb" incoming counter-trend market flow.

Based on the core principles of **Volume Spread Analysis (VSA)** originated by Richard D. Wyckoff, the system evaluates the divergence between **Effort** (injected volume) and **Result** (realized candle body spread):

* When extreme volume effort is matched with negligible price progression, an institutional absorption event is confirmed.
* The indicator projects these dynamic support/demand and resistance/supply zones directly onto the chart and automatically locks their lifecycle strictly to the exact candle where subsequent price action invalidates them.

---

## 2. Mathematical & Quantitative Engine Specifications

The indicator relies on two modular, stateful mathematical DSP engines (`CATRCalculator` and `CRelativeVolumeCalculator`) operating with chronological array safety (`ArraySetAsSeries(..., false)`).

### A. Volatility Normalization via Wilder's RMA ATR

To determine whether price spread is statistically compressed, candle bodies are normalized against market volatility using Wilder's Relative Moving Average (RMA) smoothed Average True Range (ATR):

$$\text{TR}_t = \max \big( (H_t - L_t), \, |H_t - C_{t-1}|, \, |L_t - C_{t-1}| \big)$$

$$\text{ATR}_t = \text{ATR}_{t-1} \cdot \left( \frac{N - 1}{N} \right) + \text{TR}_t \cdot \left( \frac{1}{N} \right)$$

* Where $N$ represents the lookback period (`InpATRPeriod`, default `14`).
* Computed via pipelined Fused Multiply-Add (FMA) multipliers ($m\_decay$ and $m\_inv\_period$) to eliminate runtime divisions.

### B. Institutional Effort Metric (Relative Volume - RVOL)

Relative Volume measures current trading volume against the rolling baseline of the preceding $M$ closed bars:

$$\text{RVOL}_t = \frac{V_t}{\frac{1}{M}\sum_{j=1}^{M} V_{t-j}}$$

* Where $V_t$ is exchange real volume (or tick volume on non-centralized feeds) and $M$ is the lookback period (`InpRVOLPeriod`, default `20`).
* An institutional footprint is flagged when $\text{RVOL}_t > 2.0$ (volume is over 200% of rolling expectation).

### C. Close Position ($CP$) & VSA Anomaly Classification

On each completed bar $t$, the algorithm evaluates the Effort-to-Spread relationship alongside the intra-bar settlement distribution ($CP_t$):

$$\text{Spread}_t = |C_t - O_t|, \quad \text{Range}_t = H_t - L_t$$

$$CP_t = \begin{cases} \frac{C_t - L_t}{\text{Range}_t} & \text{if } \text{Range}_t > 1.0 \times 10^{-9} \\ 0.5 & \text{otherwise} \end{cases}$$

#### 1. Bullish Demand Absorption (Institutional Accumulation)

Triggered when high selling effort is fully absorbed by passive buy limits, forcing the bar to close in its upper third:
$$\text{RVOL}_t > 2.0 \quad \land \quad \text{Spread}_t < (0.35 \cdot \text{ATR}_t) \quad \land \quad CP_t > 0.66$$

* **State Buffer Value:** `BufState[t] = 1.0`
* **Plot:** Wingdings 233 Arrow at $L_t - 0.3 \cdot \text{ATR}_t$ (`clrDodgerBlue`)
* **Zone Fill:** `clrLightSteelBlue`

#### 2. Bearish Supply Absorption (Institutional Distribution)

Triggered when high buying effort is fully absorbed by passive sell limits, forcing the bar to close in its lower third:
$$\text{RVOL}_t > 2.0 \quad \land \quad \text{Spread}_t < (0.35 \cdot \text{ATR}_t) \quad \land \quad CP_t < 0.33$$

* **State Buffer Value:** `BufState[t] = -1.0`
* **Plot:** Wingdings 234 Arrow at $H_t + 0.3 \cdot \text{ATR}_t$ (`clrCrimson`)
* **Zone Fill:** `clrMistyRose`

#### 3. Institutional Volume Climax (Exhaustion Peak)

Triggered during extreme bilateral block order turnover, representing local exhaustion or liquidity sweeps:
$$\text{RVOL}_t > 3.5 \quad \land \quad \text{Spread}_t < (0.60 \cdot \text{ATR}_t)$$

* **State Buffer Value:** `BufState[t] = 2.0`
* **Zone Fill:** `clrWheat`

---

## 3. High-Density MTF Fast-Path Architecture (2026 Protocol)

The indicator features a unified codebase capable of running on the chart's native timeframe or projecting higher timeframe (HTF) institutional absorption zones onto lower timeframe execution charts (`InpTimeframe > Period()`).

```text

+-------------------------------------------------------------------------+
|                  UNIFIED NATIVE & ZERO-LAG MTF PIPELINE                 |
+-------------------------------------------------------------------------+
  |
  +--> InpTimeframe == PERIOD_CURRENT
  |      +--> Direct O(1) Local Vector Calculation
  |
  +--> InpTimeframe > Period() [MTF Mode Triggered]
         +--> Step 1: CDataSync Background Daemon via OnTimer()
         +--> Step 2: Bulk Atomic CopyRates Query on HTF Bar Closure
         +--> Step 3: Fast RAM Mock-Up on Forming HTF Live Candle
         +--> Step 4: O(log N) Binary Search Snapping (ArrayBsearch)
         +--> Step 5: Vectorized Assignment to Chart Buffers (0 iBarShift calls)

```

1. **Atomic Bulk Synchronization:** On HTF candle close, historical data is retrieved in a single bulk query via `CopyRates()`, eliminating multiple redundant calls.
2. **Live-Tick Isolated Mocking:** On intra-bar live ticks, the forming HTF candle is mocked in memory (`live_idx = g_htf_count - 1`), updating calculation buffers without modifying closed historical registers.
3. **Binary Search Forming Block Snapping:** Replaces legacy, inefficient backwards `while` loops with an $O(\log N)$ binary search (`ArrayBsearch`), achieving nanosecond execution times across chart buffers.

---

## 4. Zone Lifecycle State Machine & Dirty-Flag Caching

Unlike conventional indicators that leave historical rectangles open or project them across future broken price regions, `Absorption_Pro` implements a deterministic, strictly non-repainting **Zone Lifecycle State Machine**.

```text

  Signal Detected at Bar [i]
              |
              v
  +-----------------------+
  | Forward Breach Scan   |------> Breach Bar [k] Found (Close < Low or Close > High)
  +-----------------------+                    |
              |                                v
              | No Breach      +-----------------------------------------+
              | Found          | Zone Status: BROKEN                     |
              v                | Rectangle End Time: Snapped to time[k]  |
  +-----------------------+    | Border Style: InpBrokenZoneStyle        |
  | Zone Status: ACTIVE   |    | Active Tracking Pool: EXCLUDED          |
  | End Time: Projected   |    +-----------------------------------------+
  | Added to Active Pool  |
  +-----------------------+

```

### A. Deterministic Forward Breach Verification

During initial calculation (`prev_calculated == 0`), any discovered absorption bar $i$ initiates an internal forward sweep:
$$\text{Breach Condition (Bullish):} \quad C_k < L_i \quad (k > i)$$
$$\text{Breach Condition (Bearish):} \quad C_k > H_i \quad (k > i)$$
$$\text{Breach Condition (Climax):} \quad (C_k > H_i) \lor (C_k < L_i) \quad (k > i)$$

* **Broken Historical Zones:** The rectangle's right coordinate (`OBJPROP_TIME, 1`) is locked directly to $\text{time}[k]$. The zone never extends past its point of invalidation.
* **Active Historical Zones:** If no bar $k$ has broken the boundary, the zone is flagged as active, extended into the future by `InpProjectionBars`, and registered in `g_active_zones[]`.

### B. The 2026 Dirty-Flag GUI Caching Mechanism

On live forming ticks (`prev_calculated > 0`), maintaining graphical objects (`OBJ_RECTANGLE`) can create severe GPU and UI thread bottlenecks if updated naively.

To achieve zero-lag operation in multi-chart setups:

1. **Intra-Bar Ticks:** The active pool performs purely scalar floating-point checks (`current_close < low`). If unbroken, **zero graphical API calls are made**.
2. **Breach Event:** If a tick causes a close breach, the rectangle's boundary is immediately locked to `live_time`, its style updated, and it is removed from the active pool via an $O(1)$ Swap-and-Pop operation.
3. **New Bar Open (`is_new_candle == true`):** The indicator executes a single, synchronized update across active zones to advance their projection timestamps forward. This eliminates up to 99.9% of redundant GDI/DirectX property mutations.

---

## 5. Parameter Reference & Configuration Matrix

### Input Settings

| Parameter | Type | Default | Description | Performance Impact |
| :--- | :---: | :---: | :--- | :--- |
| `InpTimeframe` | `ENUM_TIMEFRAMES` | `PERIOD_CURRENT` | Calculation timeframe (Current or HTF). | Minimal (Fast-path MTF cached). |
| `InpATRPeriod` | `int` | `14` | Rolling ATR volatility period. | Zero (Pipelined RMA). |
| `InpRVOLPeriod` | `int` | `20` | Rolling baseline RVOL volume period. | Zero ($O(1)$ sliding sum). |
| `InpHistoryBars` | `int` | `500` | Historical lookback limit for visual objects. | Governs initial startup allocation. |
| `InpShowObjects` | `bool` | `true` | Enables/disables absorption rectangles. | Toggles graphical object rendering. |
| `InpShowArrows` | `bool` | `true` | Enables/disables signal arrows on chart. | Zero (Native GPU buffer plot). |
| `InpTruncateOnBreak` | `bool` | `true` | Caps broken zones strictly at the breach bar. | Core lifecycle control feature. |
| `InpDeleteBrokenZones` | `bool` | `false` | Automatically deletes broken zones from chart. | Frees terminal object memory if `true`. |
| `InpBrokenZoneStyle` | `ENUM_LINE_STYLE` | `STYLE_DOT` | Border line style applied upon invalidation. | Visual distinction of broken levels. |
| `InpProjectionBars` | `int` | `3` | Forward bar projection for active zones. | Controls future visual extension. |

### Quantitative Calibration Matrix

| Market Regime | Asset Class | Target TF | ATR / RVOL | History Bars | Operational Objective |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Micro-Scalping** | Majors FX / Liquid Indices | M1 / M5 | `10` / `14` | `300` | Captures quick institutional absorption at key liquidity levels. |
| **Day Trading** | FX / Metals / Oil | M15 / H1 | `14` / `20` | `500` | Standard calibration for session open order absorption. |
| **Swing Trading** | FX / Indices / Equities | H4 / D1 | `14` / `24` | `1000` | Tracks multi-day institutional positioning and major reversals. |
| **Crypto Volatility** | BTCUSD / ETHUSD | H1 / H4 | `20` / `30` | `400` | Filters exchange-specific volume spikes and wash trading. |

---

## 6. Visual Interface & Institutional Color Standards

The visual design eliminates harsh retail colors, utilizing a calm, pastel super-thermal scheme optimized for institutional workstations:

* **Demand Absorption Zone (Accumulation):**
  * Fill: `clrLightSteelBlue` (Hex: `#B0C4DE`)
  * Arrow: `clrDodgerBlue` (Wingdings `233`, Plot Index `0`)
* **Supply Absorption Zone (Distribution):**
  * Fill: `clrMistyRose` (Hex: `#FFE4E1`)
  * Arrow: `clrCrimson` (Wingdings `234`, Plot Index `1`)
* **Volume Climax Zone (Bilateral Exhaustion):**
  * Fill: `clrWheat` (Hex: `#F5DEB3`)
* **Object Isolation Standard:**
  All rectangles are generated with an isolated prefix:

  ```mql5
  g_prefix = StringFormat("AbsZ_%I64d_", ChartID());
  ```

  This guarantees that multiple charts running identical symbols or indicators will never experience cross-chart namespace collisions or object-wiping conflicts.

---

## 7. Quantitative Trading Playbooks

### Playbook A: Institutional Demand Retest (Mitigation Long)

```text
Price
  |           [Impulse Rally Away]
  |                   /\
  |                  /  \     [Retest / Test of Demand]
  |                 /    \        |
  |                /      \       v (Low Volume / No Supply)
  +---------------+--------\-----[X] <--- BUY ENTRY
  | Demand Zone   |         \___/
  +---------------+
  | (Absorption)
  +-------------------------------------------------------- Time
```

1. **Setup:**
   * Locate an active, intact **Demand Zone** (`clrLightSteelBlue`) formed on H1 or M15.
   * Confirm that the initial absorption bar exhibited $\text{RVOL} > 2.0$ with price closing in the upper third ($CP > 0.66$).
2. **Execution Trigger:**
   * Wait for price to correct back towards the upper boundary of the intact Demand Zone.
   * Verify that the retest candle prints below-average volume ($\text{RVOL} < 1.0$), signaling a successful "Test for Supply" (sellers are exhausted).
   * **BUY:** Enter Long on a bullish rejection candle closing above the zone.
3. **Risk Management:**
   * **Stop Loss:** Set SL 2-5 ticks below the lower boundary of the Demand rectangle.
   * **Take Profit:** Target opposing intact Supply Zones or a minimum $1:2.5$ Risk-to-Reward ratio.

### Playbook B: Climax Zone Momentum Breakout (Trend Expansion)

```text
Price
  |
  |    Consolidation Range
  |      +------------------------+
  |======|  Climax Zone (Wheat)   |=====> [EXPLOSIVE BREAKOUT CLOSE] <--- BUY ENTRY
  |      +------------------------+
  |
  +-------------------------------------------------------- Time
```

1. **Setup:**
   * Identify an active **Volume Climax Zone** (`clrWheat`) where extreme turnover occurred ($\text{RVOL} > 3.5$).
   * Acknowledge that this zone represents an intense institutional liquidity transfer.
2. **Execution Trigger:**
   * Monitor price as it consolidates within or around the Climax boundaries.
   * **BULLISH BREAKOUT:** Enter Long when a full-bodied candle closes strictly above the upper boundary of the Climax rectangle.
   * **BEARISH BREAKOUT:** Enter Short when a full-bodied candle closes strictly below the lower boundary of the Climax rectangle.
3. **Risk Management:**
   * **Stop Loss:** Positioned at the 50% median line of the Climax rectangle.
   * **Take Profit:** Trailed behind trailing structure swing points.

### Playbook C: MTF Institutional Flow Alignment (H4 Filter -> M5 Execution)

1. Load `Absorption_Pro` on an **M5 chart** with `InpTimeframe = PERIOD_H4`.
2. Determine macro institutional positioning:
   * If price is trading above an intact **H4 Demand Zone**, only Long execution setups are permitted.
   * If price is trading below an intact **H4 Supply Zone**, only Short execution setups are permitted.
3. Execute micro-structure entries on M5 strictly in the direction of the dominant H4 institutional absorption bias.

---

## 8. Developer Integration & Backward Compatibility Guide

The indicator exposes its internal states through native MetaTrader 5 calculation buffers, making it directly accessible to automated Expert Advisors (EAs) and external scanners via `iCustom()`:

### Calculation Buffer Output Map

| Buffer Index | Buffer Name | Type | Value Definition |
| :---: | :---: | :---: | :--- |
| `0` | `BufBull` | `INDICATOR_DATA` | Price level of Bullish Arrow (or `EMPTY_VALUE`). |
| `1` | `BufBear` | `INDICATOR_DATA` | Price level of Bearish Arrow (or `EMPTY_VALUE`). |
| `2` | `BufATR` | `INDICATOR_CALCULATIONS` | Normalized Wilder's RMA ATR baseline value. |
| `3` | `BufRVOL` | `INDICATOR_CALCULATIONS` | Relative Volume ratio ($\text{RVOL}_t$). |
| `4` | `BufState` | `INDICATOR_CALCULATIONS` | Categorical State: `1.0` (Bull), `-1.0` (Bear), `2.0` (Climax), `0.0` (None). |

### Example MQL5 EA Integration Snippet

```mql5
//+------------------------------------------------------------------+
//| Reading Absorption Pro States from an Expert Advisor             |
//+------------------------------------------------------------------+
int h_absorption = INVALID_HANDLE;

int OnInit()
  {
   // Bind to Absorption Pro via iCustom
   h_absorption = iCustom(_Symbol, PERIOD_CURRENT, "Absorption_Pro",
                          PERIOD_CURRENT, // Calculation Timeframe
                          14,             // ATR Period
                          20,             // RVOL Period
                          500,            // History Bars
                          false,          // Show Objects (Disable GUI in EA for maximum speed!)
                          true,           // Show Arrows
                          true,           // Truncate On Break
                          false,          // Delete Broken Zones
                          STYLE_DOT,      // Broken Zone Style
                          3);             // Projection Bars

   if(h_absorption == INVALID_HANDLE)
     {
      Print("Failed to create handle for Absorption_Pro!");
      return INIT_FAILED;
     }
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   double state_buffer[1];
   // Copy bar index 1 (completed closed bar) to guarantee strictly non-repainting execution
   if(CopyBuffer(h_absorption, 4, 1, 1, state_buffer) <= 0)
      return;

   double signal_state = state_buffer[0];

   if(signal_state == 1.0)
     {
      // Institutional Demand Absorption Confirmed!
      ExecuteOrder(ORDER_TYPE_BUY);
     }
   else if(signal_state == -1.0)
     {
      // Institutional Supply Absorption Confirmed!
      ExecuteOrder(ORDER_TYPE_SELL);
     }
  }
```

---
 **Enterprise Quantitative Software Suite — 2026 Ultra Edition*
