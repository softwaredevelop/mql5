# Donchian Channel Pro (v2.20)

## Institutional Multi-Timeframe Asymmetric Breakout Channel & Dynamic Volatility Envelope Suite

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**Donchian Channel Pro (v2.20)** is the institutional trend-following and breakout volatility overlay of the Professional MQL5 Suite. Built upon the decoupled **Engine-Wrapper Component Architecture**, it synthesizes Richard Donchian’s classical highest-high/lowest-low channel framework with modern quantitative enhancements: asymmetric lookback windows, non-repainting breakout offsets, synthetic Heikin Ashi price routing, and the zero-lag 2026 MTF Fast-Path engine.

While standard Donchian Channel implementations are historically restricted to symmetric lookbacks, lack MTF capabilities, and inadvertently repaint on live breakout bars by including the unclosed candle, **Donchian Channel Pro provides full quantitative flexibility for mechanical trading systems**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│               DONCHIAN CHANNEL PRO ARCHITECTURAL OVERVIEW              │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Asymmetric Lookback Engine • Fully independent Upper and Lower      │
│                                 lookback periods (e.g. 20/10 or 55/20) │
│                               • Turtle Trading System 1 & 2 ready      │
├────────────────────────────────────────────────────────────────────────┤
│ 2. The Lookback Offset Matrix • Offset = 1: Non-repainting breakout    │
│                               • Offset = 0: Dynamic envelope expansion │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Extreme-Price DSP Routing  • Direct High/Low extreme scanning       │
│                               • Standard vs. Synthetic Heikin Ashi     │
├────────────────────────────────────────────────────────────────────────┤
│ 4. 2026 MTF Fast-Path Engine  • Atomic single-query CopyRates() sync   │
│                               • Two-Pointer Chronological Sweep (O(N)) │
│                               • Binary search snapping (ArrayBsearch)  │
├────────────────────────────────────────────────────────────────────────┤
│ 5. Decoupled Memory Core      • CDonchianCalculator headless math core │
│                               • 2048-element capacity reservations     │
│                               • Zero heap allocations on live ticks    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & Extreme-Price Routing

```text
                  RAW PRICE INPUT: High/Low vs. Synthetic Heikin Ashi
                                           │
       ┌───────────────────────────────────┴───────────────────────────────────┐
       ▼                                                                       ▼
Upper Band Scanning Engine                             Lower Band Scanning Engine
  (Upper Period + Offset)                                (Lower Period + Offset)
       │                                                                       │
       ▼                                                                       ▼
Upper Channel Line (t)                                 Lower Channel Line (t)
Highest High over P_upper                              Lowest Low over P_lower
       │                                                                       │
       └───────────────────────────────────┬───────────────────────────────────┘
                                           │ Arithmetic Mean
                                           ▼
                                 Middle Channel Line (t)
                              (UpperBand + LowerBand) / 2
```

### 2.1. Dedicated Extreme-Price Routing

Unlike moving averages or oscillators that smooth a single scalar price point (Close, Open, Median), the Donchian Channel evaluates **absolute market extremes**. The engine routes price streams through a dedicated two-state architecture (`ENUM_DONCHIAN_PRICE_TYPE`):

$$\text{HighSeries}_t = \begin{cases}
\text{High}_t & \text{if } \text{InpPriceType} = \text{PRICE\_DONCHIAN\_STANDARD} \\
\text{HA\_High}_t & \text{if } \text{InpPriceType} = \text{PRICE\_DONCHIAN\_HEIKIN\_ASHI}
\end{cases}$$

$$\text{LowSeries}_t = \begin{cases}
\text{Low}_t & \text{if } \text{InpPriceType} = \text{PRICE\_DONCHIAN\_STANDARD} \\
\text{HA\_Low}_t & \text{if } \text{InpPriceType} = \text{PRICE\_DONCHIAN\_HEIKIN\_ASHI}
\end{cases}$$

*Heikin Ashi Advantage:* Selecting `PRICE_DONCHIAN_HEIKIN_ASHI` filters out volatile microstructure spikes and stop-hunts, creating smoothed breakout boundaries based on auction momentum rather than illiquid wicks.

### 2.2. Upper Channel Band (Highest High)
Computes the maximum extreme over the designated upper lookback window $P_{upper}$ starting from the configured offset $\Delta$:
$$\text{UpperBand}_t = \max_{j = \Delta}^{\Delta + P_{upper} - 1} (\text{HighSeries}_{t-j})$$

### 2.3. Lower Channel Band (Lowest Low)
Computes the minimum extreme over the designated lower lookback window $P_{lower}$ starting from the configured offset $\Delta$:
$$\text{LowerBand}_t = \min_{j = \Delta}^{\Delta + P_{lower} - 1} (\text{LowSeries}_{t-j})$$

### 2.4. Middle Channel Band (Median Pivot Line)
The arithmetic center of the channel represents the internal equilibrium or fair value of the range:
$$\text{MiddleBand}_t = \frac{\text{UpperBand}_t + \text{LowerBand}_t}{2} = (\text{UpperBand}_t + \text{LowerBand}_t) \times 0.5$$

---

## 3. The Asymmetric Lookback & Offset Paradigm

### 3.1. Asymmetric Lookbacks ($P_{upper} \ne P_{lower}$)
Classical indicators enforce symmetric periods ($P_{upper} = P_{lower} = 20$). In institutional quantitative trading, entry and exit requirements are fundamentally asymmetric:
* **Trend-Following Systems:** Require a wide lookback to enter on high-conviction breakouts, but a tighter lookback to lock in profits on pullbacks.
* **Turtle System 1 Example:** Configured with $P_{upper} = 20$ (20-day breakout entry) and $P_{lower} = 10$ (10-day trailing stop exit).
* **Directional Regime Bias:** During strong macro bull markets, traders can set $P_{upper} = 20$ (aggressive long entries) and $P_{lower} = 50$ (wide trailing stop allowing deep pullbacks).

### 3.2. The Lookback Offset ($\Delta$)
The `InpBarOffset` parameter dictates the relationship between the forming live candle and historical boundaries:

```text
  Offset Mode    Scanning Window                          Operational Character
  ───────────    ───────────────────────────────────────  ──────────────────────────────────────────
  Offset = 1     Bars [t-1 ... t-P] (Excludes Bar 0)      STRICTLY NON-REPAINTING BREAKOUT BOUNDARY
                 The band remains static on the current   Price can cross and close outside the band
                 candle, representing true resistance.    without dragging the line.

  Offset = 0     Bars [t ... t-P+1] (Includes Bar 0)      DYNAMIC ENVELOPE EXPANSION
                 The band expands with the current live   Price cannot trade outside the band;
                 tick, hugging the absolute high/low.     bands dynamically stretch with new ticks.
```

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Donchian Channels onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

```text
  HTF Domain (e.g. H4)
  [ HTF Bar 0 ]────────────────────────>[ HTF Bar 1 ]────────────────────────>[ HTF Forming ]
        │                                     │                                     │
        ▼ (Chronological 2-Pointer Projection)▼                                     ▼
  LTF Domain (e.g. M15)
  [m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15][m15]
  └───────────────────┘ └───────────────────┘ └───────────────────┘ └───────────────────────┘
     Flat Step 0           Flat Step 1           Flat Step 2           Forming Block (Live)
```

### 4.1. Atomic Single-Query Rates Synchronization
Legacy indicators call multiple `Copy*` functions in chained sequences. This causes non-atomic race conditions during volatile live ticks.

`Donchian_Channel_Pro` executes a single atomic `CopyRates()` query:
```mql5
MqlRates htf_bulk_rates[];
if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
   return 0;
```
All OHLCV arrays are updated in cache simultaneously in nanoseconds.

### 4.2. Two-Pointer Chronological Sweep ($O(N)$ Projection)
Instead of executing an $O(N \cdot M)$ loop calling `iBarShift()` on every chart candle, the engine sweeps chronologically forward using two moving pointers:
```mql5
int htf_ptr = 0;
datetime oldest_htf = h_time[0];

for(int i = 0; i < rates_total; i++)
  {
   datetime t = time[i];
   if(t < oldest_htf)
     {
      BufferUpper[i]  = EMPTY_VALUE;
      BufferMiddle[i] = EMPTY_VALUE;
      BufferLower[i]  = EMPTY_VALUE;
      continue;
     }

   while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
      htf_ptr++;

   BufferUpper[i]  = h_res_upper[htf_ptr];
   BufferMiddle[i] = h_res_middle[htf_ptr];
   BufferLower[i]  = h_res_lower[htf_ptr];
  }
```

### 4.3. Live-Tick RAM Mocking & Binary Snapping
During live market ticks where the HTF bar has not closed:
1. Only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is updated.
2. The engine recalculates bar `live_idx` locally.
3. An $O(\log N)$ binary search (`ArrayBsearch`) locates the first LTF bar of the forming HTF block:
   ```mql5
   int first_bar = ArrayBsearch(time, htf_time_current);
   ```
4. Values are direct-vector assigned across the forming block. **Zero `iBarShift()` API calls occur on live ticks.**

---

## 5. Parameters Reference

### === Timeframe Settings ===
* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Timeframe of calculation. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Donchian Core Settings ===
* **`InpUpperPeriod`** (*default: `20`*): Lookback smoothing window for the Upper Channel Band (Breakout Entry Lookback).
* **`InpLowerPeriod`** (*default: `20`*): Lookback smoothing window for the Lower Channel Band (Asymmetric Exit / Support Lookback).
* **`InpBarOffset`** (*default: `1`*): Lookback offset. Set to `1` for strictly non-repainting breakout trading (excludes current bar). Set to `0` for dynamic envelope expansion (includes current bar).
* **`InpPriceType`** (*default: `PRICE_DONCHIAN_STANDARD`*):
  - `PRICE_DONCHIAN_STANDARD`: Calculates channels using raw market High and Low prices.
  - `PRICE_DONCHIAN_HEIKIN_ASHI`: Calculates channels using synthetic Heikin Ashi High and Low prices (eliminates wick noise).

### === Visual Settings - Upper Band ===
* **`InpColorUpper`** (*default: `clrDodgerBlue`*): Line color for the Upper Channel Band.
* **`InpStyleUpper`** (*default: `STYLE_SOLID`*): Line style for the Upper Channel Band.
* **`InpWidthUpper`** (*default: `2`*): Line thickness for the Upper Channel Band.

### === Visual Settings - Middle Band ===
* **`InpColorMiddle`** (*default: `clrDarkGray`*): Line color for the Middle Median Line.
* **`InpStyleMiddle`** (*default: `STYLE_DOT`*): Line style for the Middle Median Line.
* **`InpWidthMiddle`** (*default: `1`*): Line thickness for the Middle Median Line.

### === Visual Settings - Lower Band ===
* **`InpColorLower`** (*default: `clrDodgerBlue`*): Line color for the Lower Channel Band.
* **`InpStyleLower`** (*default: `STYLE_SOLID`*): Line style for the Lower Channel Band.
* **`InpWidthLower`** (*default: `2`*): Line thickness for the Lower Channel Band.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   DONCHIAN CHANNEL TRADING PLAYBOOKS                   │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Turtle System 1 Breakout:   Enter Long on 20-bar High breach;       │
│                                Exit Long on 10-bar Low breach.         │
│ 2. Turtle System 2 Breakout:   Enter Long on 55-bar High breach;       │
│                                Exit Long on 20-bar Low breach.         │
│ 3. Volatility Squeeze (TTM):   Bollinger Bands pinching inside the     │
│                                Donchian Channel -> Pre-breakout coil.  │
│ 4. MTF Macro Step Filter:      Only take M5 long pullbacks when price  │
│                                is holding above the H4 Donchian Mid.   │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: The Classical Turtle Breakout (System 1)
* **Configuration:** `InpUpperPeriod = 20`, `InpLowerPeriod = 10`, `InpBarOffset = 1`.
* **Long Entry Trigger:** An M15/H1 bar closes strictly **above** the Upper Band (`Close[1] > UpperBand[1]`).
* **Long Exit / Stop Trigger:** Once in a position, trail stop loss dynamically along the Lower Band (`InpLowerPeriod = 10`). Close position immediately when price breaches below the 10-period Low.
* **Mathematical Edge:** Asymmetric lookbacks guarantee that profits are captured before a full 20-bar cycle reversal occurs.

### 6.2. Playbook 2: Asymmetric Channel Trailing Stop
* **Mechanism:** When riding macro trend impulses, volatility expands dramatically.
* **Execution:** Keep an active position open as long as price holds on the favorable side of the **Middle Channel Band (Median Pivot)**.
* **Trailing Stop Adjustment:** Tighten stop loss to the Middle Band when momentum stalls, and full exit on an opposite band breach.

### 6.3. Playbook 3: Donchian-Bollinger Volatility Squeeze (TTM Squeeze)
* **Setup:** Overlay a 20-period Bollinger Band (2.0 Dev) with a 20-period Donchian Channel (`Offset = 0`).
* **The Squeeze Condition:**
  $$\text{UpperBollinger} < \text{UpperDonchian} \quad \land \quad \text{LowerBollinger} > \text{LowerDonchian}$$
* **Market State:** Volatility has compressed to historical extremes (the market is coiling inside the Donchian channel).
* **The Firing Trigger:** The first bar where Bollinger Bands expand outside the Donchian Channel confirms that the squeeze has "fired". Enter in the direction of the expansion.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment
* Attach an **H4-calculated Donchian Channel Pro** onto an **M5 execution chart**.
* **Quantitative Execution Rule:**
  $$\text{If } \text{Bid} > \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{Bid} < \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
* Prevents intraday scalpers from taking counter-trend positions against macro institutional liquidity.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 3 native `INDICATOR_DATA` buffers, maintaining sub-millisecond data query performance for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferUpper` | `DRAW_LINE` | `clrDodgerBlue` | Upper Channel Band (Highest High over $P_{upper}$) |
| **1** | `BufferMiddle` | `DRAW_LINE` | `clrDarkGray` | Middle Channel Band (Median Pivot Line) |
| **2** | `BufferLower` | `DRAW_LINE` | `clrDodgerBlue` | Lower Channel Band (Lowest Low over $P_{lower}$) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the currently forming live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Donchian Channel Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Donchian Channel Pro
int handle = iCustom(_Symbol, _Period, "Donchian_Channel_Pro",
                     PERIOD_CURRENT,             // InpTimeframe
                     20,                         // InpUpperPeriod (Breakout Entry)
                     10,                         // InpLowerPeriod (Asymmetric Exit)
                     1,                          // InpBarOffset (1 = Non-repainting Breakout)
                     PRICE_DONCHIAN_STANDARD     // InpPriceType (Standard High/Low)
                     // ... remaining visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Donchian_Channel_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double upper_val[], middle_val[], lower_val[];
ArraySetAsSeries(upper_val,  true);
ArraySetAsSeries(middle_val, true);
ArraySetAsSeries(lower_val,  true);

if(CopyBuffer(handle, 0, 1, 2, upper_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, middle_val) == 2 &&
   CopyBuffer(handle, 2, 1, 2, lower_val) == 2)
  {
   double upper_curr = upper_val[0];    // Closed bar (Bar 1)
   double lower_curr = lower_val[0];
   double mid_curr   = middle_val[0];

   double close_curr = iClose(_Symbol, _Period, 1);
   double close_prev = iClose(_Symbol, _Period, 2);

   // Example Strategy: Classical Turtle Breakout above 20-bar High
   bool is_breakout_long = (close_prev <= upper_val[1] && close_curr > upper_curr);

   if(is_breakout_long)
     {
      // Execute Buy Order (Breakout Entry)
     }
  }
```
