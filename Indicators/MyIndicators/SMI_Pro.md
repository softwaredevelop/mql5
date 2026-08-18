# William Blau's Stochastic Momentum Index (SMI) Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **William Blau's Stochastic Momentum Index (SMI) Pro Suite** is an institutional-grade, low-latency cyclical momentum and trend-reversal tracking system. It consists of two highly synchronized indicators: `SMI_Pro` (Standard) and its Multi-Timeframe (MTF) counterpart.

Standard Stochastic oscillators calculate price location relative to the absolute low of the high-low range, which makes them highly sensitive to micro-noise and causes them to peg prematurely at extremes during strong trends.

Developed by William Blau, the **Stochastic Momentum Index (SMI)** resolves this limitation by measuring the relative position of the close price relative to the **median (center) of the high-low range** instead:

$$\text{Median}_t = \frac{\text{HighestHigh}_t + \text{LowestLow}_t}{2}$$

$$\text{RelativePrice}_t = C_t - \text{Median}_t$$

By double-smoothing both this relative price and the total high-low range over a double smoothing period ($D$), the SMI generates exceptionally smooth, fourier-stable, and organic momentum waves.

To deliver maximum quantitative flexibility, this suite elevates Blau's original concept by replacing the hardcoded EMAs with a **5-motor moving average composition**. This allows traders to select *any* moving average type (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA) for both the double-smoothing stages and the final signal line, introducing volume-weighting (VWMA) capabilities to the entire SMI pipeline for the first time.

---

## 2. Mathematical & Quant Foundations

The indicator calculates a double-smoothed ratio using five independent, state-safe moving average engines:

### A. Core Price and Range Calculations

Over the lookback period $K$ (`InpLengthK`), the highest high and lowest low are calculated to determine the high-low range and the relative price distance from the median:

$$\text{Range}_t = \max_{j=0 \dots K-1} (H_{t-j}) - \min_{j=0 \dots K-1} (L_{t-j})$$

$$\text{Relative}_t = C_t - \frac{\max_{j=0 \dots K-1} (H_{t-j}) + \min_{j=0 \dots K-1} (L_{t-j})}{2}$$

### B. Double Smoothing Pipeline

Both the relative price ($\text{Relative}_t$) and the absolute range ($\text{Range}_t$) are processed through two consecutive, state-safe smoothing engines using the slowing period $D$ (`InpLengthD`) and the selected slowing MA type (`InpSlowingType`):

$$\text{Sm1\_Rel}_t = \text{Smoothing1}_{D}(\text{Relative}_t)$$

$$\text{Sm2\_Rel}_t = \text{Smoothing2}_{D}(\text{Sm1\_Rel}_t)$$

$$\text{Sm1\_Ran}_t = \text{Smoothing1}_{D}(\text{Range}_t)$$

$$\text{Sm2\_Ran}_t = \text{Smoothing2}_{D}(\text{Sm1\_Ran}_t)$$

### C. Final SMI & Signal Line Equations

The final SMI represents the ratio of the double-smoothed relative price over half of the double-smoothed absolute range, bounded strictly between $-100$ and $100$:

$$\text{SMI}_t = \begin{cases}
100.0 \times \frac{\text{Sm2\_Rel}_t}{\frac{\text{Sm2\_Ran}_t}{2.0}} & \text{if } \text{Sm2\_Ran}_t > 1.0e-9 \\
0.0 & \text{otherwise}
\end{cases}$$

The final plotted Signal Line is computed by smoothing the active $\text{SMI}_t$ over the signal period (`InpLengthEMA`) using the selected signal MA type (`InpSignalType`):

$$\text{Signal}_t = \text{Smoothing}_{\text{SignalPeriod}}(\text{SMI}_t)$$

---

## 3. Recommended Calibration Presets

| Trading Style | Timeframe | SMI Settings ($K, D, \text{Slowing MA}$) | Signal Settings ($\text{EMA}, \text{Signal MA}$) | Quantitative Tactical Role |
| :--- | :--- | :---: | :---: | :--- |
| **Intraday Scalping** | M5 / M15 | `10, 3` (EMA) | `3` (EMA) | **Fast Mean Reversion.** Highly responsive crossover triggers on intraday charts. |
| **Trend Following** | M30 / H1 | `14, 5` (SMA) | `5` (SMA) | **Stable Swing Tracking.** Filters out noise on H1 charts, tracking clean cyclical waves. |
| **Institutional Flow** | H1 / H4 | `14, 3` (VWMA) | `3` (EMA) | **Volume-Backed Momentum.** Integrates exchange volume weighting to track true institutional pivots. |

---

## 4. Visual & Technical Highlights

* **5-Motor Composite OOP Design:**
  To handle double-smoothing across multiple variables cleanly without visual or computational lag, the `CSMICalculator` class instantiates five independent `CMovingAverageCalculator` engines. This modular structure completely isolates the MA calculations, enabling fázis-helyes (phase-correct) and state-safe execution for any combination of MA types.
* **Pragmatic Visual Styling:**
  The main oscillator lines are plotted with distinct, professional weights: the SMI line is plotted in bold Steel Blue (`clrSteelBlue`, width 2) for immediate trend identification, while the Signal line is plotted as a thinner Dark Orange line (`clrDarkOrange`, width 1.5) for clean crossover visual comfort.
* **Chronological Safety Guards:**
  The engine enforces chronological array indexing (`ArraySetAsSeries(..., false)`) across all internal persistent buffers, price caches, and indicator buffers, completely eliminating phase shift errors during template changes.

---

## 5. Advanced MQL5 MTF Implementation Details

Operating high-order recursive double-smoothings combined with lookback arrays across multiple timeframes requires precise architectural guards:

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

Since the SMI MA double-smoothing relies on deep historical smoothed averages, calling calculations continuously on the live forming bar on every tick can cause feedback decay. To solve this, the MTF engine uses **State Mocking** during live ticks by passing `prev_calculated = g_htf_count`, which updates only the active live register while keeping historical closed states completely locked.

---

## 6. Symmetrical Momentum Trading Strategies

### A. The Symmetrical Extremes Crossover Strategy (40/60 & 80/90 Reversal)

Because the SMI is bounded between $-100$ and $100$, crossovers occurring inside the extreme over-extended zones represent high-probability trend reversal points.

1. **Indicator Setup:**
   * **SMI Pro:** K Period = `10`, D Period = `3` (EMA), Signal = `3` (EMA).
2. **Execution Rules:**
   * **BUY Trigger:** Enter Long when the **SMI line crosses above the Signal line** strictly while both lines are **below the $-40.0$ or $-60.0$ levels** (Oversold).
   * **SELL Trigger:** Enter Short when the **SMI line crosses below the Signal line** strictly while both lines are **above the $+40.0$ or $+60.0$ levels** (Overbought).
3. **Risk Management:** Place Stop Loss below the local swing low (for Long trades) or above the local swing high (for Short trades). Exit on an opposing crossover at the opposite extreme boundary.

### B. The Volume-Weighted Momentum Continuation Squeeze

By utilizing volume-weighted moving averages (VWMA) for the double-smoothing slowing stage, we ensure that trend accelerations are backed by true institutional transaction volume.

1. **Indicator Setup:**
   * Load the indicator on an M5 or M15 chart.
   * Configure the Slowing MA to **`VWMA`** and the Signal MA to **`EMA`**.
2. **Strategy Mechanics:**
   * During consolidation, the SMI and Signal lines contract towards the $0.0$ level, forming a tight squeeze.
   * **BUY Entry:** Enter Long when the **SMI line crosses above the Signal line** near the $0.0$ level, accompanied by a breakout of the SMI line above $0.0$. The VWMA double-smoothing ensures this cross is backed by true transaction volume.
   * **SELL Entry:** Enter Short when the **SMI line crosses below the Signal line** near the $0.0$ level, and breaks below $0.0$.
3. **Strategic Value:** Entering near the $0.0$ level allows you to catch the very beginning of a trend expansion immediately after a volatility contraction squeeze.
