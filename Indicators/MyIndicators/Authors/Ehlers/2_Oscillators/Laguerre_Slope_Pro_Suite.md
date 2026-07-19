# John Ehlers' Laguerre Slope Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Laguerre Slope Pro Suite** is an institutional-grade, low-latency quantitative momentum and trend-reversal tracking suite. It consists of two highly optimized indicators: `Laguerre_Slope_Pro` (Standard) and `Laguerre_Slope_MTF_Pro` (Multi-Timeframe).

While Ehlers' original Laguerre Filter acts as a low-lag moving average, the **Laguerre Slope Suite** focuses on the *first derivative (rate of change)* of this filter. In quantitative trading, detecting when trend strength begins to decelerate is far more valuable than waiting for an actual price crossover. By calculating the slope of Ehlers' Laguerre Filter, this suite identifies early momentum shifts, trend exhaustion points, and highly accurate pivot zones before they manifest in standard moving average lags.

To eliminate flat-market whipsaws, the suite implements an adjustable noise threshold. To gauge volume-backed participation, it features an optional signal line that fully supports **Volume-Weighted Moving Averages (VWMA)**. Combined with a symmetrical 5-zone thermal coloring matrix, the suite provides an incredibly intuitive representation of market velocity.

---

## 2. Mathematical Foundations

The suite calculates the Laguerre Slope recursively. It is built upon the four polynomial state registers of Ehlers' low-pass IIR filter:

### A. The Underlying Laguerre States

On each bar $t$, the price $P_t$ (Standard or Heikin Ashi) is mapped into a four-dimensional space governed by the Gamma ($\gamma$) feedback coefficient:

$$L_{0, t} = (1 - \gamma) P_t + \gamma L_{0, t-1}$$

$$L_{1, t} = -\gamma L_{0, t} + L_{0, t-1} + \gamma L_{1, t-1}$$

$$L_{2, t} = -\gamma L_{1, t} + L_{1, t-1} + \gamma L_{2, t-1}$$

$$L_{3, t} = -\gamma L_{2, t} + L_{2, t-1} + \gamma L_{3, t-1}$$

The baseline low-pass filter is computed as:

$$\text{Filter}_t = \frac{L_{0, t} + 2 \times L_{1, t} + 2 \times L_{2, t} + L_{3, t}}{6}$$

### B. The Laguerre Slope Formula

The Slope representing the velocity of the Laguerre Filter is calculated as the first difference:

$$\text{Slope}_t = \text{Filter}_t - \text{Filter}_{t-1}$$

### C. 5-Zone Symmetrical Thermal Slope Classification

To distinguish between trend expansions, decelerations, and quiet market regimes, the indicator classifies each bar into one of five states based on a user-defined threshold ($\epsilon$):

| Color Index | Market State | Mathematical Condition | Visual Indication |
| :---: | :--- | :--- | :--- |
| **`0.0`** | **Neutral / Noise** | $\text{Slope}_t \le \epsilon$ | **`clrGray`** (No directional momentum) |
| **`1.0`** | **Strong Bullish** | $\text{Slope}_t > \epsilon \quad \text{AND} \quad \text{Slope}_t > \text{Slope}_{t-1}$ | **`clrMediumSeaGreen`** (Accelerating upward momentum) |
| **`2.0`** | **Weak Bullish** | $\text{Slope}_t > \epsilon \quad \text{AND} \quad \text{Slope}_t \le \text{Slope}_{t-1}$ | **`clrPaleGreen`** (Decelerating upward momentum) |
| **`3.0`** | **Strong Bearish** | $\text{Slope}_t < -\epsilon \quad \text{AND} \quad \text{Slope}_t < \text{Slope}_{t-1}$ | **`clrCrimson`** (Accelerating downward momentum) |
| **`4.0`** | **Weak Bearish** | $\text{Slope}_t < -\epsilon \quad \text{AND} \quad \text{Slope}_t \ge \text{Slope}_{t-1}$ | **`clrLightCoral`** (Decelerating downward momentum) |

### D. The Volume-Weighted Signal Line (VWMA)

When the Signal Line is enabled and set to VWMA, the indicator overlays a volume-weighted moving average calculated on top of the calculated slope array:

$$\text{VWMA(Slope)}_t = \frac{\sum_{j=0}^{N-1} (\text{Slope}_{i-j} \times V_{i-j})}{\sum_{j=0}^{N-1} V_{i-j}}$$

Where $V$ represents the underlying volume array (Real Volume if supported, otherwise falling back to Tick Volume) and $N$ represents the signal period.

---

## 3. Recommended Fibonacci Gamma & Threshold Levels

Because the slope values are highly dependent on the chosen timeframe and asset volatility, configuring appropriate Gamma ($\gamma$) and Threshold ($\epsilon$) parameters is key to clean execution signals:

### A. Gamma Settings by Trading Style

* **`0.236` (Ultra-Light):** Best for scalping. Detects micro-acceleration in milliseconds.
* **`0.382` (Light):** Day trading baseline. Fast reaction with moderate noise filtering.
* **`0.500` (Balanced):** Swing trading standard. Perfect balance between lag and smoothness.
* **`0.618` (The Golden Anchor):** Outstanding core filter for H1/H4 charts. Minimizes fourier noise.

### B. Suggested Threshold ($\epsilon$) Matrices

The following threshold baselines help isolate consolidations:

| Asset Class | Timeframe | Recommended Threshold ($\epsilon$) | Quant Rationale |
| :--- | :--- | :--- | :--- |
| **Major FX (EURUSD, etc.)** | M5 / M15 | `0.00003` to `0.00005` | Filters micro-point spreads during low-volume sessions. |
| **Major FX (EURUSD, etc.)** | H1 / H4 | `0.00010` to `0.00015` | Captures structural directional expansions. |
| **Cryptocurrencies (BTCUSD)** | M15 / H1 | `1.50000` to `5.00000` | Tuned to handle high-volatility dollar-value swings. |
| **Equity Indices (SPX, GER40)** | H1 / Daily | `0.10000` to `0.50000` | Filters out market-open volatility spikes. |

---

## 4. Visual & Architectural Highlights

* **Precision-Matched Typography:**
  To support precise Fibonacci inputs without truncation, the indicator dynamically updates its short name format to three decimal places for Gamma (`%.3f`) and five decimal places for Thresholds (`%.5f`):

  ```mql5
  string short_name = StringFormat("Laguerre Slope(%.3f, %.5f) | EMA(5)", InpGamma, InpThreshold);
  ```

* **Chronological Array Safeguards:**
  The engine enforces chronological sorting (`ArraySetAsSeries(..., false)`) across all internal processing states. This ensures that historical recursive states ($L_0$ to $L_3$) are mapped forward, eliminating index corruption caused by reverse-sorted charting templates.
* **Heap-Free Performance:**
  Dynamic memory allocation is avoided inside `OnCalculate()`. The engine is instantiated once during `OnInit()` and managed on the stack, ensuring zero memory leaks and maximum execution speed.

---

## 5. Advanced MQL5 MTF Implementation Details

`Laguerre_Slope_MTF_Pro` utilizes a highly sophisticated multi-timeframe pipeline that guarantees non-repainting historical blocks and live-bar stability.

### A. Forming LTF Block Flat-Force (The Staircase Solution)

On lower timeframe charts, the higher timeframe values must be displayed as flat, clean steps (resembling a staircase). To prevent the live-forming step from warping diagonally as prices tick, the indicator isolates the starting anchor bar of the forming HTF block and recalculates the entire block flat on every tick:

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

### B. High-Performance Volume Caching ($O(1)$)

To support VWMA on higher timeframes, the MTF engine must retrieve higher-timeframe volume data. Because volumes are returned as `long`, the indicator converts them to a `double` cache array incrementally:

```mql5
int start_sync = (prev_calculated > 0) ? prev_calculated - 1 : 0;
if(vol_limit > 0)
  {
   for(int i = start_sync; i < rates_total; i++)
      g_double_volume[i] = (double)volume[i];
  }
```

This incremental conversion keeps calculation complexity at $O(1)$ per tick.

---

## 6. Quantitative Trading Strategies

### A. The 5-Zone Momentum Climax Strategy

This strategy is based on the transition of the Slope from accelerating momentum to deceleration (climax), indicating an imminent pullback or reversal.

1. **Indicator Setup:**
   * **Laguerre Slope Pro:** Gamma = **`0.500`**, Threshold = `0.00005`.
   * **Signal Line:** Disabled.
2. **Execution Rules:**
   * **BUY Trigger (Bullish Recovery):** Enter Long when the histogram transitions from **Strong Bearish** (`clrCrimson`) or **Weak Bearish** (`clrLightCoral`) directly into a **Strong Bullish** (`clrMediumSeaGreen`) bar. This indicates that downward pressure has collapsed and buyers are rapidly accelerating.
   * **SELL Trigger (Bearish Exhaustion):** Enter Short when the histogram transitions from **Strong Bullish** (`clrMediumSeaGreen`) or **Weak Bullish** (`clrPaleGreen`) directly into a **Strong Bearish** (`clrCrimson`) bar.
3. **Alternative Momentum Climax Exit:**
   * If in a Long trade, exit immediately when the histogram turns from **Strong Bullish** (`clrMediumSeaGreen`) to **Weak Bullish** (`clrPaleGreen`). This represents an early warning that the buying momentum is decelerating, allowing you to lock in profits before the price actually pivots.

```text
       [ Strong Bullish (Green) ]  -->  [ Weak Bullish (Pale Green) ]  ==> EXIT LONG
       (Momentum Accelerating)          (Momentum Decelerating)
```

### B. The Volume-Weighted Golden Ratio Crossover

This strategy utilizes a volume-weighted signal line to confirm trend reversals, ensuring that trades are only executed when institutional volume backs the momentum shift.

1. **Indicator Setup:**
   * **Laguerre Slope Pro:** Gamma = **`0.618`** (The Golden Anchor).
   * **Signal MA:** Enabled, Period = **`5`**, Type = **`VWMA`**.
2. **Execution Rules:**
   * **BUY Entry:** Enter Long when the **Laguerre Slope histogram crosses above the Maroon Signal MA Line**. This cross must occur while the histogram is colored either `clrMediumSeaGreen` (Strong Bullish) or `clrPaleGreen` (Weak Bullish), confirming a volume-supported upward expansion.
   * **SELL Entry:** Enter Short when the **Laguerre Slope histogram crosses below the Maroon Signal MA Line**. The histogram must be colored `clrCrimson` (Strong Bearish) or `clrLightCoral` (Weak Bearish).
3. **Stop Loss and Risk Management:**
   * Place the Stop Loss strictly below the low of the signal candle (for Long trades) or above the high of the signal candle (for Short trades).
   * Exit the trade when the Slope crosses back over the VWMA Signal Line in the opposite direction.
