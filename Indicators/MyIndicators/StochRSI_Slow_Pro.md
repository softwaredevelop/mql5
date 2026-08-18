# Stochastic RSI Slow Pro Suite (Standard & MTF)

## Technical Specification & Operational Manual

## 1. Summary (Introduction)

The **Stochastic RSI Slow Pro Suite** is an institutional-grade, highly smoothed cyclical momentum and overextension tracking system. It comprises two advanced quantitative indicators: `StochRSI_Slow_Pro` (Standard) and its Multi-Timeframe (MTF) counterpart, calculated cleanly within a unified codebase.

Standard Stochastic oscillators track absolute price extremes, often pegging prematurely during strong trends. Standard RSI oscillators track relative strength but can be choppy and noisy, consolidating in neutral zones for extended periods.

The **StochRSI Slow Suite** solves both limitations by applying the Stochastic formula directly to J. Welles Wilder’s standard Relative Strength Index (RSI), separating the calculation into a highly optimized, stateful three-tier pipeline:

1. **RSI Baseline:** Calculates a stable, fourier-aligned relative strength baseline.
2. **Stochastic Normalization:** Scales the RSI values relative to its high-low extremes over period $K$, converting it into a highly responsive cyclical oscillator bounded strictly between $0$ and $100$.
3. **Double-Smoothing (Slowing & Signal):** Filters high-frequency noise using selectable moving average types (including Volume-Weighted VWMA) on both the Slow $\%K$ and the Signal $\%D$ lines to generate high-probability trend crossover triggers.

By integrating our unified Standard/MTF engine, the suite guarantees non-repainting, flat staircase steps in real-time, fully supporting Heikin Ashi smoothed price sources and selectable moving average smoothing types.

---

## 2. Mathematical & Quant Foundations

The indicator represents a highly optimized, multi-tier mathematical pipeline:

```text

[ Price Series ] ---> [ Wilder's RSI ] ---> [ Stochastic Normalization ] ---> [ Slowing %K ] ---> [ Signal %D ]

```

### A. Wilder's RSI Baseline (RSI Engine)

First, price changes are separated into positive gains ($U$) and negative losses ($D$), smoothed recursively using Wilder's Smoothing (RMA) over the RSI period ($R$):

$$\text{Diff}_t = P_t - P_{t-1}$$

$$U_t = \max(0, \text{Diff}_t), \quad D_t = \max(0, -\text{Diff}_t)$$

$$\text{AvgGain}_t = \frac{\text{AvgGain}_{t-1} \times (R - 1) + U_t}{R}$$

$$\text{AvgLoss}_t = \frac{\text{AvgLoss}_{t-1} \times (R - 1) + D_t}{R}$$

$$\text{RSI}_t = 100.0 - \left( \frac{100.0}{1.0 + \frac{\text{AvgGain}_t}{\text{AvgLoss}_t}} \right)$$

Where $R$ is the RSI period (`InpRSIPeriod`).

### B. Stochastic Normalization of RSI (Raw %K)

The raw Stochastic $\%K$ measures the position of the current $\text{RSI}_t$ relative to its highest high and lowest low RSI values over the lookback period $K$ (`InpKPeriod`):

$$\text{MaxRSI}_t = \max_{j=0 \dots K-1} (\text{RSI}_{t-j})$$

$$\text{MinRSI}_t = \min_{j=0 \dots K-1} (\text{RSI}_{t-j})$$

$$\text{Raw } \%K_t = \begin{cases}
100.0 \times \frac{\text{RSI}_t - \text{MinRSI}_t}{\text{MaxRSI}_t - \text{MinRSI}_t} & \text{if } \text{MaxRSI}_t - \text{MinRSI}_t > 0.00001 \\
\text{Raw } \%K_{t-1} & \text{otherwise}
\end{cases}$$

### C. Slow %K and Signal %D Smoothing
The final plotted lines are smoothed using the configured moving averages (supporting double volume-weighting via VWMA if selected):

$$\text{Slow } \%K_t = \text{Smoothing}_{\text{SlowingPeriod}}(\text{Raw } \%K_t)$$

$$\text{Signal } \%D_t = \text{Smoothing}_{\text{SignalPeriod}}(\text{Slow } \%K_t)$$

---

## 3. Recommended Calibration Presets

| Asset Class | Timeframe | RSI / K Periods | Slow / D Smoothing | MA Selection | Quantitative Tactical Role |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Major FX Pairs** | M5 / M15 | `14` / `14` | `3` / `3` | `EMA` / `EMA` | **Intraday Mean Reversion.** Identifies tight overbought/oversold cycles on intraday charts. |
| **Equity Indices** | M30 / H1 | `10` / `10` | `3` / `3` | `EMA` / `EMA` | **Momentum Expansion.** Reacts extremely fast to trend breakout zones. |
| **Cryptocurrencies**| H1 / H4 | `14` / `14` | `5` / `3` | `EMA` / `EMA` | **Volatility Smoothing.** Smoother slowing period filters out high-frequency retail noise. |

---

## 4. Visual & Technical Highlights

* **Three-Tier Chronological Lock (Safeguards):**
  To completely eliminate index-alignment corruption when switching timeframes or applying custom charting templates, the suite enforces strict chronological sorting (`ArraySetAsSeries(..., false)`) across all three architecture layers:
  `RSI_Engine` (internal price & average buffers) $\to$ `Calculator` (state registers) $\to$ `Pro Indicator` (indicator buffers).
* **Polymorphic Caching Architecture:**
  The `CStochRSI_Slow_Calculator` dynamically instantiates either the standard close-price engine (`CRSIEngine`) or the Heikin Ashi smoothed price engine (`CRSIEngine_HA`) in `OnInit()`. This allows Heikin Ashi price routing to flow cleanly through all calculation levels (RSI, Stochastic, Slowing, and Signal) with zero code duplication.
* **Pragmatic Visual Styling:**
  The main oscillator lines are plotted with distinct, professional weights: the Slow $\%K$ line is plotted in bold DodgerBlue (`clrDodgerBlue`, width 2) for immediate trend identification, while the Signal $\%D$ line is plotted as a thinner Coral line (`clrCoral`, width 1.5) for clean crossover visual comfort.

---

## 5. Advanced MQL5 MTF Implementation Details

Operating high-order recursive structures (RSI averages) combined with lookback arrays (Stochastic highest/lowest) across multiple timeframes requires precise architectural guards:

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

Since the RSI calculation relies on deep historical smoothed averages ($\text{AvgGain}_{t-1}, \text{AvgLoss}_{t-1}$), calling calculations continuously on the live forming bar on every tick can cause feedback decay. To solve this, the MTF engine uses **State Mocking** during live ticks by passing `prev_calculated = g_htf_count`, which updates only the active live register while keeping historical closed states completely locked.

---

## 6. Symmetrical Momentum Trading Strategies

### A. The Extreme Symmetrical Reversal Strategy (10/20 & 80/90 Crossover)

Because StochRSI is extremely sensitive, crossovers occurring inside the standard $20/80$ zones can produce whipsaws. This strategy restricts execution strictly to extreme over-extensions:

1. **Indicator Setup:**
   * **StochRSI Slow Pro:** RSI Period = `14`, K Period = `14`, Slow = `3`, D = `3` (EMA / EMA).
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
   * During consolidation, the Stochastic $\%K$ and $\%D$ lines contract towards the $50.0$ level, forming a tight squeeze.
   * **BUY Entry:** Enter Long when the **Slow $\%K$ line crosses above the $\%D$ line** near the $50.0$ level, accompanied by a breakout of the $\%K$ line above $50.0$.
   * **SELL Entry:** Enter Short when the **Slow $\%K$ line crosses below the $\%D$ line** near the $50.0$ level, and breaks below $50.0$.
3. **Strategic Value:** Entering near the $50.0$ level allows you to catch the very beginning of a trend expansion immediately after a volatility contraction squeeze.
