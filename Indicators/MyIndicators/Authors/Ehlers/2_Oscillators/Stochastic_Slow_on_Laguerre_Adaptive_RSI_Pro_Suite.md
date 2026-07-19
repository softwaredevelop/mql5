# Stochastic Slow on Laguerre Adaptive RSI Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Stochastic Slow on Laguerre Adaptive RSI Pro Suite** represents the absolute pinnacle of stateful, volatility-adjusted cyclical oscillators. It comprises two highly optimized indicators: `StochasticSlow_on_Laguerre_Adaptive_RSI_Pro` (Standard) and its Multi-Timeframe (MTF) counterpart.

Standard Stochastic oscillators are highly sensitive to market noise, generating frequent false crossovers during flat consolidations. Conversely, when a strong trend develops, standard stochastics "peg" prematurely at extreme boundaries ($0$ or $100$), rendering them useless during the most profitable phases of a trend.

This suite resolves both limitations by nesting a **Slow Stochastic filter** directly on top of John Ehlers' **Adaptive Laguerre RSI**.

By dynamically adjusting the underlying Laguerre baseline's Gamma ($\gamma$) using Kaufman's Efficiency Ratio (ER), ATR, or Standard Deviation, the oscillator self-regulates its sensitivity:

- **During high efficiency/volatility:** Gamma contracts, causing the underlying Laguerre RSI to react instantly, allowing the Stochastic lines ($\%K$ and $\%D$) to cling tightly to the extreme boundaries ($10/90$) to ride the trend.
- **During low efficiency/consolidation:** Gamma dilates, heavily smoothing the underlying states. The Stochastic lines smoothly contract towards the center ($50$), completely neutralizing false whipsaws.

Presented as a dual-line oscillator inside a separate subwindow, the suite is engineered to deliver pristine, institutional-grade cyclical reversal signals with near-zero lag.

---

## 2. Mathematical & Quant Foundations

The indicator represents a nested three-tier mathematical pipeline:

[ Volatility/Efficiency Metric ] ---> [ Dynamic Gamma Scaling ] ---> [ Stateful
Laguerre RSI ] ---> [ Stochastic %K & %D Smoothing ]

### A. Dynamic Gamma & Stateful Laguerre RSI

On each bar $t$, the selected adaptive metric $M_t \in [0.0, 1.0]$ is mapped to the Gamma boundaries to calculate the dynamic feedback factor $\gamma_t$:

$$\gamma_t = \gamma_{\max} - M_t \times (\gamma_{\max} - \gamma_{\min})$$

Using $\gamma_t$, the price is smoothed into the four polynomial state registers ($L_{0,t}$ to $L_{3,t}$), and the Adaptive Laguerre RSI ($\text{LRSI}_t$) is computed:

$$\text{cu}_t = \max(0, L_{0,t} - L_{1,t}) + \max(0, L_{1,t} - L_{2,t}) + \max(0, L_{2,t} - L_{3,t})$$

$$\text{cd}_t = \max(0, L_{1,t} - L_{0,t}) + \max(0, L_{2,t} - L_{1,t}) + \max(0, L_{3,t} - L_{2,t})$$

$$\text{LRSI}_t = \begin{cases}
100.0 \times \frac{\text{cu}_t}{\text{cu}_t + \text{cd}_t} & \text{if } \text{cu}_t + \text{cd}_t > 0.0 \\
\text{LRSI}_{t-1} & \text{otherwise}
\end{cases}$$

### B. Stochastic on Laguerre RSI (Raw %K)
The raw Stochastic $\%K$ is calculated by normalizing the active $\text{LRSI}_t$ value against its highest and lowest boundaries over the lookback window $K$ (Stochastic Period):

$$\text{MaxRSI}_t = \max_{j=0 \dots K-1} (\text{LRSI}_{t-j})$$

$$\text{MinRSI}_t = \min_{j=0 \dots K-1} (\text{LRSI}_{t-j})$$

$$\text{Raw } \%K_t = \begin{cases}
100.0 \times \frac{\text{LRSI}_t - \text{MinRSI}_t}{\text{MaxRSI}_t - \text{MinRSI}_t} & \text{if } \text{MaxRSI}_t - \text{MinRSI}_t > 0.00001 \\
\text{Raw } \%K_{t-1} & \text{otherwise}
\end{cases}$$

### C. Slow %K and Signal %D Smoothing
The final plotted lines are smoothed using the configured moving averages (supporting double volume-weighting via VWMA):

$$\text{Slow } \%K_t = \text{Smoothing}_{\text{SlowingPeriod}}(\text{Raw } \%K_t)$$

$$\text{Signal } \%D_t = \text{Smoothing}_{\text{SignalPeriod}}(\text{Slow } \%K_t)$$

---

## 3. Recommended Calibration Presets

| Asset Class | Timeframe | Adaptive Method | Stochastic Settings ($K, \text{Slow}, D$) | Gamma Boundaries ($\gamma_{\min} - \gamma_{\max}$) | Quant Tactical Role |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **Major FX Pairs** | M5 / M15 | `METHOD_ATR` | `14, 3, 3` (EMA / EMA) | `0.136` to `0.882` | **Intraday Mean Reversion.** Captures micro-oversold bottoms during European/US sessions. |
| **Equity Indices** | M30 / H1 | `METHOD_EFFICIENCY_RATIO` | `10, 3, 3` (SMA / SMA) | `0.236` to `0.800` | **Trend Pullback Reentry.** Identifies shallow pullbacks during index expansions. |
| **Commodities (Gold)**| H1 / H4 | `METHOD_STAND_DEV` | `14, 5, 3` (EMA / EMA) | `0.200` to `0.850` | **Volatility Squeeze Exhaustion.** Catches major commodity cycle peaks. |

---

## 4. Visual & Technical Highlights

* **Nested Composite OOP Design:**
  To guarantee $100\%$ DRY (*Don't Repeat Yourself*) code and flawless memory safety, the `CStochasticSlowOnLaguerreAdaptiveRSICalculator` class directly encapsulates the `CLaguerreAdaptiveRSICalculator` engine. Instead of replicating complex adaptive Laguerre equations, the Stochastic engine calls the nested class to populate the internal RSI buffer, keeping calculations completely modular.
* **Double-Smoothed Volume Weighting (VWMA):**
  When configured to VWMA, the indicator converts the platform volume arrays to a `double` cache array. The engine applies volume weighting to *both* the Slowing $\%K$ and the Signal $\%D$ calculations, ensuring that moving average crossovers are backed by institutional transaction volume.
* **Enforced Chronological Safety:**
  The engine enforces chronological array indexing (`ArraySetAsSeries(..., false)`) across all internal persistent buffers, preventing index corruption during timeframe switches or custom template applications.

---

## 5. Advanced MQL5 MTF Implementation Details

Operating recursive structures (Laguerre states) combined with lookback arrays (Stochastic highest/lowest) across multiple timeframes requires precise architectural guards:

### A. Double State Mocking during Live Ticks
Since both the underlying Laguerre states and the Stochastic lookback arrays are state-sensitive, tick updates on the forming bar (index `rates_total - 1`) must not corrupt historical states. The engine performs **Double State Mocking** by passing `prev_calculated = g_htf_count` to the calculators. This recalculates only the active live index, preserving closed historical registers from cumulative rounding errors.

### B. Non-Warping Staircase Solution
To prevent diagonal warping of the steps on lower timeframe charts, the indicator implements a backward-scanning block-force loop. It identifies the beginning of the active forming HTF block and rewrites the entire block flat on every tick:

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

6. Fibonacci & Cyclical Trading Strategies

A. The Institutional Extremes Crossover Strategy (10/90 Reversal)

Because the adaptive baseline contracts the Gamma during trends, Stochastic
lines will stay pegged above 90 or below 10 for the entire duration of a strong
trend, and will only cross when a true cyclical reversal occurs.

1.  Strategy Setup:
      - Run the indicator with: Gamma = 0.136 to 0.882, Method =
        METHOD_EFFICIENCY_RATIO, Stochastic = 14, 3, 3 (EMA / EMA).
2.  Execution Rules:
      - BUY Trigger: Enter Long when the Slow \%K line crosses above the Signal
        \%D line strictly while both lines are below the 10.0 Oversold level.
      - SELL Trigger: Enter Short when the Slow \%K line crosses below the
        Signal \%D line strictly while both lines are above the 90.0 Overbought
        level.
3.  Risk Management:
      - Stop Loss: Place Stop Loss below the local swing low (for Long trades)
        or above the local swing high (for Short trades).
      - Exit: Close the position on an opposing crossover at the opposite
        extreme boundary.

B. The Volume-Weighted Momentum Continuation Squeeze (VWMA Alignment)

This trend-following continuation strategy utilizes volume-weighted smoothing to
trade explosive trend expansions.

1.  Strategy Setup:
      - Configure the indicator with: Method = METHOD_ATR, Stochastic = 14, 5, 3
        (Slowing = VWMA, Signal = VWMA).
2.  Strategy Mechanics:
      - During flat consolidations, the ATR is low, Gamma expands to 0.882, and
        the Stochastic \%K and \%D lines contract towards the 50.0 level,
        forming a tight squeeze.
      - BUY Entry: Enter Long when the Slow \%K line crosses above the \%D line
        near the 50.0 level, accompanied by a breakout of the \%K line above
        50.0. The VWMA smoothing ensures this cross is backed by true
        transaction volume.
      - SELL Entry: Enter Short when the Slow \%K line crosses below the \%D
        line near the 50.0 level, and breaks below 50.0.
3.  Strategic Value: By entering near the 50.0 level, you catch the very
    beginning of a trend expansion immediately after a volatility contraction
    squeeze, ensuring high-probability trend alignment.
