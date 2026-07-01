# Welles Wilder's ADX Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Welles Wilder's ADX Pro Suite** is an institutional-grade trend-strength and directional movement isolation suite comprising two advanced indicators:

* `ADX_Pro` (Standard)
* `ADX_MTF_Pro` (Multi-Timeframe)

Developed by the legendary mechanical engineer and technical analyst J. Welles Wilder Jr., the Average Directional Index (ADX) and Directional Movement Index (DMI) constitute one of the most robust trend-trading frameworks in financial mathematics. Unlike single-line momentum oscillators, the ADX system strictly separates trend **direction** from trend **strength**:

* **+DI and -DI Lines:** Isolate positive and negative directional price pressure (Trend Direction).
* **ADX Line:** Measures the absolute momentum and velocity of the active trend, completely independent of its direction (Trend Strength).

Wilder constructed this system using a specialized, stateful recursive smoothing algorithm (Wilder's Smoothing, mathematically equivalent to an SMMA), making it exceptionally sensitive to chronological sequence alignment.

The suite features dynamic Heikin Ashi price integration, customizable **Dynamic Horizontal Levels** to identify trend thresholds, and advanced multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The calculation pipeline consists of five cascading mathematical steps, calculated sequentially on every bar:

### A. True Range (TR) and Directional Movement (+DM, -DM)

At each bar $t$, the absolute price volatility and direction are isolated using the current and previous High ($H$), Low ($L$), and Close ($C$) coordinates:

$$\text{TR}_t = \max \left( H_t - L_t, \, \left| H_t - C_{t-1} \right|, \, \left| L_t - C_{t-1} \right| \right)$$

$$\text{+DM}_t = \begin{cases}
  H_t - H_{t-1} & \text{if } H_t - H_{t-1} > L_{t-1} - L_t \text{ and } H_t - H_{t-1} > 0 \\
  0 & \text{otherwise}
\end{cases}$$

$$\text{-DM}_t = \begin{cases}
  L_{t-1} - L_t & \text{if } L_{t-1} - L_t > H_t - H_{t-1} \text{ and } L_{t-1} - L_t > 0 \\
  0 & \text{otherwise}
\end{cases}$$

### B. Welles Wilder's Stateful Smoothing

The raw daily values are smoothed recursively over the lookback period $N$ (`InpPeriodADX`) using Wilder's smoothing. The initial value at $t = N$ is computed as a simple sum, and subsequent states are smoothed recursively:

$$\text{Smoothed TR}_t = \text{Smoothed TR}_{t-1} - \frac{\text{Smoothed TR}_{t-1}}{N} + \text{TR}_t$$

$$\text{Smoothed +DM}_t = \text{Smoothed +DM}_{t-1} - \frac{\text{Smoothed +DM}_{t-1}}{N} + \text{+DM}_t$$

$$\text{Smoothed -DM}_t = \text{Smoothed -DM}_{t-1} - \frac{\text{Smoothed -DM}_{t-1}}{N} + \text{-DM}_t$$

### C. Directional Indicators (+DI, -DI)

The directional movement lines are normalized by dividing them by the Smoothed True Range, mapping them to a standardized percentage range:

$$\text{+DI}_t = \frac{\text{Smoothed +DM}_t}{\text{Smoothed TR}_t} \times 100$$

$$\text{-DI}_t = \frac{\text{Smoothed -DM}_t}{\text{Smoothed TR}_t} \times 100$$

### D. Directional Movement Index (DX)

The absolute ratio of directional divergence is calculated:

$$\text{DX}_t = \frac{\left| \text{+DI}_t - \text{-DI}_t \right|}{\text{+DI}_t + \text{-DI}_t} \times 100$$

### E. Average Directional Index (ADX)

The final ADX line is calculated. On the first warm-up bar ($t = 2N - 1$), the ADX is initialized as a simple moving average of the `DX[]` buffer. On all subsequent bars, it is smoothed recursively using Wilder's smoothing constant:

$$\text{ADX}_t = \frac{\text{ADX}_{t-1} \times (N - 1) + \text{DX}_t}{N}$$

---

## 3. Dynamic Levels Configuration

Welles Wilder identified specific statistical thresholds for trend identification:
* **ADX < 25.0:** SIDELAY/sideways market. Trend momentum is weak. Trade range-bound reversion strategies.
* **ADX > 25.0:** Trending market. Momentum is expanding. Trade breakout or trend-following models.
* **ADX > 40.0:** Strong trend. Whipsaws are minimized. Protect trailing stops.

Because these boundaries can change depending on asset volatility (e.g. crypto vs. fiat), the suite implements a **Dynamic Levels Engine**:
* During `OnInit()`, the engine programmatically registers the horizontal grids on the separate subwindow:
  ```mql5
  IndicatorSetInteger(INDICATOR_LEVELS, 2);
  IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevel1); // Default 25.0
  IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevel2); // Default 40.0
  ```

This ensures that the dynamic centerline grid is rendered at the exact mathematical thresholds chosen by the user.

---

## 4. High-Performance & Precision Enhancements

The entire suite is optimized to conform with our strict quantitative design guidelines:

* **Szigorú Chronological Sorting Safeguards:**
  Because Welles Wilder's smoothing relies on a highly state-sensitive recursive history ($t-1$), any reverse-chronological array indexing will completely corrupt the calculations. To prevent this, the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations (such as access violation fatal crashes), a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 5. Advanced MQL5 MTF Implementation Details

`ADX_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

### A. Forming LTF Block Flat-Force (The Warping Solution)

To prevent real-time step warping and slope distortion on lower timeframe charts, the indicator implements a step-blocking algorithm. On every tick, the indicator isolates the beginning of the active forming HTF block and forces the calculations to rewrite that block completely, keeping the visual lines perfectly flat and historically stable:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Dynamic anchor start of current forming block

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

### B. State Mocking for IIR State Stability

Since Wilder's smoothing is highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states. To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 6. Parameters

### A. ADX Settings

* **Smoothing Period (`InpPeriodADX`):** Welles Wilder's lookback window size ($N$) for the directional movement and ADX calculations (Default: `14`, Range: $\ge 1$).
* **Candle Source (`InpCandleSource`):** Selects the price series source (`CANDLE_STANDARD` or `CANDLE_HEIKIN_ASHI`). Default: `CANDLE_STANDARD`.

### B. Indicator Levels Settings

* **Trend Threshold Level (`InpLevel1`):** Horizontal grid value representing the beginning of trend expansion (Default: `25.0`).
* **Strong Trend Level (`InpLevel2`):** Horizontal grid value representing a highly established trend (Default: `40.0`).
* **Levels Color (`InpLevelColor`):** Customize the color of the horizontal line layout (Default: `clrSilver`).
* **Levels Style (`InpLevelStyle`):** Customize the line style of the horizontal line layout (Default: `STYLE_DOT`).

### C. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate ADX on (Default: `PERIOD_H1`).

---

## 7. Advanced Trading Strategies

### A. The Wilder Intraday Trend strength Filter (Standard Crossover)

The most robust way to trade ADX is to use the directional indicators (+DI and -DI) for entry signals, but strictly filter execution based on the trend-strength line (ADX).

1. **Setup:** Apply `ADX_Pro` set to a standard period of `14` on an M15 chart.
2. **BUY Entry (Long):**
   * Wait for the **+DI line (green) to cross above the -DI line (red)**.
   * Verify that the **ADX line (blue) is above 25.0 and rising**, confirming that the bullish breakout is backed by expanding momentum.
   * **Execution:** Open Long. Place stop-loss strictly below the breakout candle's low.
3. **SELL Entry (Short):**
   * Wait for the **-DI line to cross above the +DI line**.
   * Verify that the **ADX line is above 25.0 and rising**, confirming expanding bearish trend strength.
   * **Execution:** Open Short.

### B. Top-Down Macro Directional Alignment (MTF Trend Riding)

By combining an MTF ADX trend filter with local execution setups, traders align their trades with institutional, higher-timeframe flow.

1. **Setup:** Apply `ADX_MTF_Pro` set to H1 or H4 on an M5 chart.
2. **Macro Trend Definition:**
   * **Bullish Macro Trend:** The H1 ADX is above 25.0, and the H1 +DI line is above the -DI line. Strictly seek buy setups on the lower M5 chart.
   * **Bearish Macro Trend:** The H1 ADX is above 25.0, and the H1 -DI line is above the +DI line. Strictly seek sell setups.
3. **Execution:** On the local M5 chart, apply a local entry trigger (e.g. moving average pullback crossover). When the macro H1 indicator establishes a Bullish Macro Trend, execute long entry setups strictly when the local trigger crosses up, ignoring all counter-trend short setups.
