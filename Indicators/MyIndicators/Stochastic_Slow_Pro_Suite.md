# George Lane's Stochastic Slow Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **George Lane's Stochastic Slow Pro Suite** is an institutional-grade, highly optimized cyclical momentum and trend-reversal tracking system. It comprises two advanced quantitative indicators: `StochasticSlow_Pro` (Standard) and its Multi-Timeframe (MTF) counterpart.

Standard Fast Stochastic oscillators are highly sensitive to market noise, generating frequent false crossovers and premature reversal signals during high-frequency volatility spikes.

George Lane resolved this limitation by introducing a **Slowing Period (Triple-Smoothing)** to the Stochastic engine:

1. **Raw %K (Fast %K):** Calculates the direct mathematical ratio of the close price relative to its highest high and lowest low over the lookback window $K$.
2. **Slow %K (Main Line):** Smooths the raw $\%K$ over a slowing period to establish a stable, trend-following momentum baseline.
3. **Signal %D (Signal Line):** Applies a secondary smoothing layer over the Slow $\%K$ to generate high-probability trend crossover triggers.

By integrating our unified Standard/MTF engine, the suite guarantees non-repainting, flat staircase steps in real-time, fully supporting Heikin Ashi smoothed price sources and selectable moving average smoothing types (including volume-weighted VWMA).

---

## 2. Mathematical & Quant Foundations

The indicator utilizes a stateful, three-tier mathematical pipeline:

```text

[ Price Series ] ---> [ Raw %K (Fast %K) ] ---> [ Slowing %K ] ---> [ Signal %D ]

```

### A. Raw %K (Fast %K) Calculation

First, the extreme high and low boundaries are identified over the lookback window $K$ (`InpKPeriod`):

$$\text{HighestHigh}_t = \max_{j=0 \dots K-1} (H_{t-j})$$

$$\text{LowestLow}_t = \min_{j=0 \dots K-1} (L_{t-j})$$

$$\text{Raw } \%K_t = \begin{cases}
100.0 \times \frac{C_t - \text{LowestLow}_t}{\text{HighestHigh}_t - \text{LowestLow}_t} & \text{if } \text{HighestHigh}_t - \text{LowestLow}_t > 0.00001 \\
\text{Raw } \%K_{t-1} & \text{otherwise}
\end{cases}$$

Where $C_t$ is the close price (Standard or Heikin Ashi).

### B. Slow %K (Main Line) Smoothing
The raw $\%K_t$ is smoothed over the slowing period using the configured moving average:

$$\text{Slow } \%K_t = \text{Smoothing}_{\text{SlowingPeriod}}(\text{Raw } \%K_t)$$

### C. Signal %D (Signal Line) Smoothing
The final plotted Signal $\%D$ line is computed by smoothing the Slow $\%K_t$ over the signal period:

$$\text{Signal } \%D_t = \text{Smoothing}_{\text{SignalPeriod}}(\text{Slow } \%K_t)$$

---

## 3. Recommended Calibration Presets

| Asset Class | Timeframe | Stochastic Periods ($K, \text{Slow}, D$) | MA Selection | Quantitative Tactical Role |
| :--- | :--- | :---: | :---: | :--- |
| **Major FX Pairs** | M5 / M15 | `5, 3, 3` | `SMA` / `SMA` | **Intraday Mean Reversion.** Identifies rapid oversold/overbought cycles on intraday charts. |
| **Equity Indices** | M30 / H1 | `14, 3, 3` | `EMA` / `EMA` | **Momentum Reentry.** Catches early pullback reentries during index trend expansions. |
| **Commodities (Gold)**| H1 / H4 | `14, 5, 3` | `SMA` / `SMA` | **Volatility Cycle Filter.** Smoother slowing period filters out high-frequency retail noise. |

---

## 4. Visual & Technical Highlights

* **Three-Tier Chronological Lock (Safeguards):**
  To completely eliminate index-alignment corruption when switching timeframes or applying custom charting templates, the suite enforces strict chronological sorting (`ArraySetAsSeries(..., false)`) across all internal price caches and indicator buffers:
  `Calculator price buffers` $\to$ `Slowing/Signal state registers` $\to$ `Pro Indicator buffers`.
* **Pragmatic Visual Styling:**
  The main oscillator lines are plotted with distinct, professional weights: the Slow $\%K$ line is plotted in bold LightSeaGreen (`clrLightSeaGreen`, width 2) for immediate trend identification, while the Signal $\%D$ line is plotted as a thinner LightCoral line (`clrLightCoral`, width 1.5) for clean crossover visual comfort.
* **Heap-Free Execution:**
  Dynamic memory allocation is avoided inside `OnCalculate()`. The engine is instantiated once during `OnInit()` and managed on the stack, ensuring zero memory leaks and maximum execution speed.

---

## 5. Advanced MQL5 MTF Implementation Details

Operating recursive structures combined with lookback arrays across multiple timeframes requires precise architectural guards:

### A. Non-Warping Staircase Solution
To prevent the active, forming HTF candle from drawing a warped diagonal slope on lower timeframe charts, the indicator runs a backward-scanning block-force loop. It identifies the beginning of the active forming HTF block and rewrites the entire block flat on every tick:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Anchor start of current HTF period block

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

### B. High-Order IIR State Mocking

Since the Stochastic MA smoothing relies on deep historical averages, calling calculations continuously on the live forming bar on every tick can cause feedback decay. To solve this, the MTF engine uses **State Mocking** during live ticks by passing `prev_calculated = g_htf_count`, which updates only the active live register while keeping historical closed states completely locked.

---

## 6. Symmetrical Momentum Trading Strategies

### A. The Symmetrical Extremes Reversal Strategy (10/20 & 80/90 Crossover)

Because the Slow Stochastic is bounded between $0$ and $100$, crossovers occurring inside the extreme over-extended zones represent high-probability trend reversal points.

1. **Indicator Setup:**
   * **StochasticSlow Pro:** K Period = `5`, Slowing = `3`, D = `3` (SMA / SMA).
2. **Execution Rules:**
   * **BUY Trigger:** Enter Long when the **Slow $\%K$ line crosses above the Signal $\%D$ line** strictly while both lines are **below the $10.0$ or $20.0$ level**.
   * **SELL Trigger:** Enter Short when the **Slow $\%K$ line crosses below the Signal $\%D$ line** strictly while both lines are **above the $80.0$ or $90.0$ level**.
3. **Risk Management:** Place Stop Loss below the local swing low (for Long trades) or above the local swing high (for Short trades). Exit on an opposing crossover at the opposite extreme boundary.

### B. The Intraday Momentum Squeeze (VWMA Crossover)

By utilizing volume-weighted moving averages (VWMA) for both the Slowing $\%K$ and the Signal $\%D$ lines, we ensure that entries are backed by true institutional transaction volume.

1. **Indicator Setup:**
   * Load the indicator on an M5 or M15 chart.
   * Configure the Slowing MA and Signal MA to **`VWMA`**.
2. **Strategy Mechanics:**
   * During consolidation, volatility contracts, and the Stochastic $\%K$ and $\%D$ lines contract towards the $50.0$ level, forming a tight squeeze.
   * **BUY Entry:** Enter Long when the **Slow $\%K$ line crosses above the $\%D$ line** near the $50.0$ level, accompanied by a breakout of the $\%K$ line above $50.0$.
   * **SELL Entry:** Enter Short when the **Slow $\%K$ line crosses below the $\%D$ line** near the $50.0$ level, and breaks below $50.0$.
3. **Strategic Value:** Entering near the $50.0$ level allows you to catch the very beginning of a trend expansion immediately after a volatility contraction squeeze.
