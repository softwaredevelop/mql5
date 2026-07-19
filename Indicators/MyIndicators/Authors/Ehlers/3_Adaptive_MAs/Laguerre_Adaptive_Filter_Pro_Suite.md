# John Ehlers' Laguerre Adaptive Filter Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Laguerre Adaptive Filter Pro Suite** is an institutional-grade, low-latency trend-following smoothing suite designed to solve the classic trade-off of technical indicators: **minimizing lag in trending markets while maximizing noise-dampening in consolidations**.

Standard low-pass filters (such as SMA, EMA, or static Laguerre Filters) apply a constant smoothing parameter across all market conditions. This static approach inevitably leads to whipsaws during quiet consolidations or significant entry lag when explosive trends develop.

The **Adaptive Filter Suite** resolves this by dynamically accelerating and decelerating the **Gamma** ($\gamma$) dampening coefficient of the Laguerre space in real-time. Governed by a selected volatility or efficiency metric, the filter continuously recalibrates its internal polynomial registers ($L_0$ to $L_3$).

To provide complete analytical flexibility, the suite implements three distinct adaptive pathways:

1. **Kaufman's Efficiency Ratio (ER):** Analyzes the efficiency of price movement (net directional change vs. absolute path traveled). Ideal for identifying structural momentum and flat market regimes.
2. **Normalized Average True Range (ATR):** Measures price ranges to detect volatility-backed breakouts. Excellent for catching explosive expansion cycles.
3. **Normalized Standard Deviation (StDev):** Analyzes price dispersion around a moving average to identify volatility-contraction squeeze zones.

Calculated as a clean, single-colored chart line (`DRAW_LINE`), the suite is optimized for high visual clarity, keeping the trader focused on structural price levels without visual clutter.

---

## 2. Mathematical Foundations

The core Laguerre Filter is calculated recursively. However, instead of utilizing a static Gamma input, the dampening factor $\gamma_t$ is updated dynamically on every bar $t$.

### A. Dynamic Gamma Scaling Formula

On each bar, the selected adaptive metric $M_t$ is computed and clamped strictly to a normalized closed range $M_t \in [0.0, 1.0]$. This metric is then mapped onto the user-defined Gamma boundaries ($\gamma_{\min}$ and $\gamma_{\max}$):

$$\gamma_t = \gamma_{\max} - M_t \times (\gamma_{\max} - \gamma_{\min})$$

* **High Volatility / Directional Efficiency ($M_t \to 1.0$):** Gamma accelerates towards its minimum ($\gamma_t \to \gamma_{\min}$), making the filter highly reactive and eliminating lag.
* **Low Volatility / Sideways Consolidation ($M_t \to 0.0$):** Gamma decelerates towards its maximum ($\gamma_t \to \gamma_{\max}$), heavily smoothing the line to bypass consolidation noise.

### B. Stateful Polynomial Calculations

Using the dynamic dampening factor $\gamma_t$, the price $P_t$ (Standard or Heikin Ashi) is transformed recursively into the four state registers:

$$L_{0, t} = (1 - \gamma_t) P_t + \gamma_t L_{0, t-1}$$

$$L_{1, t} = -\gamma_t L_{0, t} + L_{0, t-1} + \gamma_t L_{1, t-1}$$

$$L_{2, t} = -\gamma_t L_{1, t} + L_{1, t-1} + \gamma_t L_{2, t-1}$$

$$L_{3, t} = -\gamma_t L_{2, t} + L_{2, t-1} + \gamma_t L_{3, t-1}$$

The final adaptive filter output is a weighted combination of the registers:

$$\text{Adaptive Filter}_t = \frac{L_{0, t} + 2 \times L_{1, t} + 2 \times L_{2, t} + L_{3, t}}{6}$$

---

## 3. The Three Adaptive Metrics & Normalization

Because volatility metrics (such as ATR and Standard Deviation) are unbounded and depend heavily on the asset price and timeframe, the suite implements a sliding window Min-Max normalization to bring them into a pure $[0.0, 1.0]$ multiplier.

### 1. Kaufman's Efficiency Ratio (ER)

The ER is naturally bounded between `0.0` and `1.0`. It calculates the net change over period $N$ divided by the sum of absolute bar-to-bar changes:

$$M_{ER, t} = \frac{|P_t - P_{t-N}|}{\sum_{j=0}^{N-1} |P_{t-j} - P_{t-j-1}|}$$

### 2. Normalized Average True Range (ATR)

First, raw ATR is calculated over period $N$ using Wilder's smoothing. To normalize it, a sliding window of length $N$ identifies the absolute maximum and minimum ATR values:

$$M_{ATR, t} = \frac{\text{ATR}_t - \text{ATR}_{\min, N}}{\text{ATR}_{\max, N} - \text{ATR}_{\min, N}}$$

### 3. Normalized Standard Deviation (StDev)

First, raw Standard Deviation ($\sigma_t$) is calculated over period $N$ against the Simple Moving Average (SMA). It is normalized over a rolling window of length $N$:

$$M_{StDev, t} = \frac{\sigma_t - \sigma_{\min, N}}{\sigma_{\max, N} - \sigma_{\min, N}}$$

---

## 4. Recommended Calibration Presets

| Trading Goal | Timeframe | Adaptive Method | Period ($N$) | Gamma Range ($\gamma_{\min} - \gamma_{\max}$) | Quant Strategy Rationale |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Micro-Scalping** | M1 / M5 | `METHOD_EFFICIENCY_RATIO` | `8` | `0.15` to `0.85` | Extremely sensitive. Filters out micro-flat noise while sticking to active order flows. |
| **Day Trading** | M15 / H1 | `METHOD_ATR` | `10` | `0.10` to `0.90` | Calibrated to volatility breakout cycles. Sticks tightly to high-volume intraday trend moves. |
| **Swing Trading** | H1 / H4 | `METHOD_STAND_DEV` | `14` | `0.20` to `0.85` | Tracks institutional asset dispersion. Smooths out whipsaws during consolidation squeezes. |
| **Trend Following** | Daily / Weekly | `METHOD_EFFICIENCY_RATIO` | `20` | `0.236` to `0.882` | Uses golden ratios for macro tracking. Acts as a low-lag alternative to the classic 50 SMA. |

---

## 5. Advanced MQL5 MTF Implementation Details

`Laguerre_Adaptive_Filter_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

### A. Dynamic Price Routing (Standard vs Heikin Ashi)

To maintain the highest level of fourier-aligned smoothing, the calculator dynamically intercepts Heikin Ashi candles if selected. The entire adaptive metric (such as ER or ATR) is calculated on Heikin Ashi Close or Median prices transparently inside the engine, keeping calculations clean:

```mql5
CHeikinAshi_Calculator ha_calc;
ha_calc.Calculate(rates_total, start_index, open, high, low, close, ha_open, ha_high, ha_low, ha_close);
```

### B. Non-Warping Staircase Solution

To prevent real-time step warping on lower timeframe charts, the indicator implements a step-blocking algorithm. On every tick, the indicator isolates the beginning of the active forming HTF block and forces the calculations to rewrite that block completely, keeping the visual lines perfectly flat and historically stable:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Dynamic anchor start of current HTF block

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

---

## 6. Fibonacci & Adaptive Trading Strategies

### A. The Volatility-Contraction Breakout Strategy (StDev / ATR Crossover)

During flat, quiet markets, volatility contracts, causing StDev and ATR to reach historical minimums. This strategy triggers entries on explosive volatility expansions.

1. **Indicator Setup:**
   * **Laguerre Adaptive Filter:** Method = `METHOD_STAND_DEV`, Period = `14`, Gamma range = `0.15` to `0.85`.
2. **Strategy Mechanics:**
   * During consolidation, the normalized metric $M_{StDev}$ drops close to `0.0`. The filter's Gamma decelerates towards `0.85`, drawing a perfectly flat, smoothed line.
   * **BUY Trigger:** Enter Long when price closes above the flat Adaptive Filter line, and the line abruptly starts bending upwards (indicating $M_{StDev} \to 1.0$ and Gamma accelerating).
   * **SELL Trigger:** Enter Short when price closes below the flat Adaptive Filter line, and the line bends downwards.
3. **Strategic Edge:** By waiting for the Gamma to contract to `0.85` (flat), you bypass the random chops. The entry occurs exactly when volatility expands, ensuring you catch the initial thrust of a new trend.

### B. The Efficiency pullback Reentry Strategy (ER Alignment)

This swing strategy is designed to enter ongoing trends during brief corrective pullbacks by monitoring price efficiency.

1. **Indicator Setup:**
   * **Laguerre Adaptive Filter:** Method = `METHOD_EFFICIENCY_RATIO`, Period = `10`, Gamma range = `0.10` to `0.90`.
2. **The Trend Alignment:**
   * Identify a strong macro trend (e.g., price is consistently above the Adaptive Filter line).
3. **Execution Rules:**
   * **BUY Entry (Pullback Reentry):** When a temporary pullback occurs, price action becomes inefficient, causing the Efficiency Ratio to drop ($M_{ER} \to 0.0$). This decelerates the Gamma towards `0.90`, making the filter line flat and acting as dynamic support. Enter Long when price touches the flat Adaptive Filter line and bounces upward.
   * **Stop Loss:** Place Stop Loss below the flat filter line (dynamic support zone).
   * **Take Profit:** Exit when price over-extends and the filter line accelerates up, locking in momentum-based profits.
