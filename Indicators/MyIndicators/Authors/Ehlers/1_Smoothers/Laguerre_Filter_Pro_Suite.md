# John Ehlers' Laguerre Filter Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Laguerre Filter Pro Suite** is an institutional-grade, low-latency trend-following and smoothing suite comprising two advanced indicators: `Laguerre_Filter_Pro` (Standard) and `Laguerre_Filter_MTF_Pro` (Multi-Timeframe).

Developed by John F. Ehlers, the pioneer of maximum entropy spectrum analysis in trading, the Laguerre Filter is a stateful low-pass filter designed to solve the classic trend-following trade-off: **reducing noise while maintaining near-zero lag**.

Traditional moving averages (such as SMA, EMA, or SMMA) accumulate price history over a rigid, linear time window, making them slow to react to trend shifts. The Laguerre Filter maps price into a stateful, four-dimensional polynomial Laguerre space. This mathematical transformation allows the filter to smooth out volatile consolidations while reacting instantly to explosive breakouts.

The suite features dynamic Heikin Ashi price integration, an optional 4-bar Finite Impulse Response (FIR) comparative filter, and three-decimal Gamma formatting to natively support precise **Fibonacci ratios** (such as `0.236`, `0.382`, and `0.618`) for micro-tuned trend tracking.

---

## 2. Mathematical Foundations

The Laguerre Filter is calculated recursively. Unlike time-based moving averages, its smoothing and dampening characteristics are entirely governed by the **Gamma** ($\gamma$) dampening coefficient:

### A. Stateful Laguerre Polynomial States

On each bar $t$, the price $P_t$ (Standard or Heikin Ashi) is transformed into four independent polynomial state registers ($L_0$ to $L_3$), using the feedback coordinates from the prior bar ($t-1$):

$$L_{0, t} = (1 - \gamma) P_t + \gamma L_{0, t-1}$$

$$L_{1, t} = -\gamma L_{0, t} + L_{0, t-1} + \gamma L_{1, t-1}$$

$$L_{2, t} = -\gamma L_{1, t} + L_{1, t-1} + \gamma L_{2, t-1}$$

$$L_{3, t} = -\gamma L_{2, t} + L_{2, t-1} + \gamma L_{3, t-1}$$

### B. Filter Output Formula

The final Laguerre Filter value represents a weighted combination of the four polynomial states, achieving a clean low-pass filter response with minimal phase delay:

$$\text{Laguerre Filter}_t = \frac{L_{0, t} + 2 \times L_{1, t} + 2 \times L_{2, t} + L_{3, t}}{6}$$

### C. Optional Symmetrical FIR Filter

For traders seeking a baseline comparative measure, the indicator features an optional 4-bar weighted Finite Impulse Response (FIR) filter. The FIR filter is calculated using the zero-copy price arrays:

$$\text{FIR Filter}_t = \frac{P_t + 2 \times P_{t-1} + 2 \times P_{t-2} + P_{t-3}}{6}$$

---

## 3. Recommended Fibonacci Gamma Levels

Because the Laguerre Filter reacts recursively in polynomial space, the dampening factor $\gamma$ behaves similarly to a lookback window but on a non-linear scale.

Utilizing **Fibonacci ratios** as Gamma parameters aligns the filter's dampening curve with the golden proportions of natural expansions:

| Fibonacci Gamma | Smoothing Depth | Latency (Lag) | Target Market Regime | Quantitative Concept |
| :--- | :--- | :--- | :--- | :--- |
| **`0.236`** | Ultra-Light | Near-Zero | High-Frequency Scalping / Momentum | **Extreme Sensitivity.** Tracks price closely. Identifies immediate trend acceleration and micro-reversals. |
| **`0.382`** | Light | Very Low | Day Trading / Intraday Execution | **Optimal Execution Baseline.** Excellent alternative to 9 EMA. Filters out noise while keeping crossovers fast. |
| **`0.500`** | Balanced | Medium-Low | Swing Trading / Volatility Pivots | **Balanced Corridor Center.** Standard baseline for medium swing setups on M15/H1 charts. |
| **`0.618`** | Medium-Strong | Medium | Medium-Term Trend Following | **The Golden Ratio Anchor.** Outstanding core filter. Replaces 20-period standard moving averages with 50% less fourier lag. |
| **`0.764`** | Strong | Medium-High | Macro Trend Identification | **Structural Support.** Identifies institutional trend direction on H4/D1 charts. Bypasses whipsaws. |
| **`0.882`** | Ultra-Strong | High | Secular Trend Smoothing | **Absolute Noise Elimination.** Ideal for long-term investing and tracking macro market cycles on weekly/monthly charts. |

---

## 4. Visual & Architectural Highlights

The Laguerre Filter Pro Suite is engineered to operate efficiently under volatile market conditions:

* **Three-Decimal Precision Formatting:**
  To natively support precise Fibonacci Gamma inputs (e.g., `0.236` or `0.382`) without visual rounding, the indicator short name formatting is expanded to three decimal places. The dynamic ShortName in `OnInit()` uses a `%.3f` formatting mask:

  ```mql5
  IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre Filter(%.3f)", InpGamma));
  ```

  This ensures that critical Fibonacci settings are clearly documented on the chart subwindow and inside the terminal legend.

* **Strict Chronological Sorting Safeguards:**
  To prevent calculation corruption caused by reverse-chronological array states (often forced by custom templates or third-party indicators on the active chart), the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations (such as access violation fatal crashes), a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 5. Advanced MQL5 MTF Implementation Details

`Laguerre_Filter_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

### A. Forming LTF Block Flat-Force (The Warping Solution)

To prevent real-time step warping and slope distortion on lower timeframe charts, the indicator implements a step-blocking algorithm. On every tick, the indicator isolates the beginning of the active forming HTF block and forces the calculations to rewrite that block completely, keeping the visual lines perfectly flat and historically stable:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Dynamic anchor start

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

### B. State Mocking for IIR State Stability

Since the Laguerre Filter is highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states ($L_0$ to $L_3$). To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 6. Fibonacci Quantitative Trading Strategies

### A. The Fibonacci Gravity Pivot (Dual Laguerre Crossover)

By combining an ultra-fast Fibonacci Gamma and a medium-strong Fibonacci anchor, we create a highly responsive trend crossover system that filters out choppy, sideways market actions:

1. **Indicator Setup:**
   * **Fast Laguerre Filter:** Gamma set to **`0.236`** (represented in clrDodgerBlue).
   * **Slow Laguerre Filter:** Gamma set to **`0.618`** (represented in clrCrimson).
2. **The Trend Alignment:**
   * When the Fast Filter (`0.236`) is above the Slow Filter (`0.618`), the market is in a bullish expansion.
   * When the Fast Filter (`0.236`) is below the Slow Filter (`0.618`), the market is in a bearish expansion.
3. **Execution Trigger:**
   * **BUY Entry:** Enter Long when the Fast Filter crosses above the Slow Filter. Place stop-loss strictly below the local swing low.
   * **SELL Entry:** Enter Short when the Fast Filter crosses below the Slow Filter. Place stop-loss strictly above the local swing high.
4. **Exit Strategy:** Close positions immediately when the fast filter contracts and crosses back over the slow filter, locking in low-lag trend profits.

### B. Laguerre vs. FIR Low-Lag Crossover (Ehlers' Classic Crossover)

The 4-bar FIR filter serves as an ultra-fast proxy for current price action, while a medium Laguerre filter represents structural value. Crossing them creates an incredibly fast momentum trigger.

1. **Indicator Setup:**
   * On the same chart, enable the comparative FIR filter (`InpShowFIR = true`).
   * Configure the Laguerre Gamma to **`0.382`** (the light execution baseline).
2. **Execution Trigger:**
   * **BUY Entry:** Enter Long when the smooth, low-lag **FIR Filter line crosses above the Laguerre Filter line**.
   * **SELL Entry:** Enter Short when the smooth, low-lag **FIR Filter line crosses below the Laguerre Filter line**.
3. **Strategic Advantage:** Because both filters utilize Ehlers' fourier-aligned smoothing logic, crossovers are extremely clean, producing fewer whipsaws than standard SMA/EMA crossovers during flat, consolidated market regimes.
