# John Ehlers' Fisher Transform Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Fisher Transform Pro Suite** is an institutional-grade, high-performance cycle-isolation and market timing suite comprising two advanced indicators:

* `Fisher_Transform_Pro` (Standard)
* `Fisher_Transform_MTF_Pro` (Multi-Timeframe)

Developed by the legendary technical analyst John F. Ehlers, the Fisher Transform is a mathematical algorithm designed to convert financial price data into a nearly Gaussian (normal) probability distribution.

Standard momentum oscillators (such as RSI, CCI, or Stochastics) fluctuate within fixed boundary limits, causing them to stall and compress at the extremes during strong trends. The Fisher Transform is mathematically unbounded, expanding logarithmically as price stretches. This logarithmic expansion amplifies trend extremes, converting rounded market tops and bottoms into **extremely sharp, low-lag turning points**.

The suite features dynamic Heikin Ashi price integration, a highly flexible Signal Line engine supporting both a classic 1-bar delay and volume-weighted **Volume-Weighted Moving Average (VWMA)** smoothing, and advanced multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The calculation pipeline consists of three cascading mathematical steps calculated recursively on every bar:

### A. Price Normalization ($\text{Value1}_t$)

Price is first normalized to fluctuate strictly within the range $[-1.0, 1.0]$. The median price $P_t$ ($(H+L)/2$) is scaled relative to the highest high ($H_N$) and lowest low ($L_N$) over a rolling period $N$ (`InpPeriod`), and recursively smoothed using a dampening factor $\alpha$ (`InpAlpha`):

$$\text{Value1}_t = \alpha \times 2 \times \left( \frac{P_t - L_{N, t}}{H_{N, t} - L_{N, t}} - 0.5 \right) + (1.0 - \alpha) \times \text{Value1}_{t-1}$$

To prevent mathematical errors (division by zero or natural log of zero/negative coordinates) when price reaches absolute boundaries, the value is clamped strictly within the range $[-0.999, 0.999]$:

$$\text{Value1}_t = \max\left(-0.999, \, \min(0.999, \, \text{Value1}_t)\right)$$

### B. The Fisher Transform ($\text{Fish}_t$)

The clamped normalized value is converted into a Gaussian probability distribution by calculating the natural logarithm ($\ln$) of its ratio, and then smoothed recursively:

$$\text{Fish}_t = 0.5 \times \ln\left( \frac{1.0 + \text{Value1}_t}{1.0 - \text{Value1}_t} \right) + 0.5 \times \text{Fish}_{t-1}$$

### C. Signal Line Generation

To confirm cyclical turning points, the suite features a highly customizable secondary Signal Line. It can be configured in two distinct modes:

* **Classic Ehlers Delay (`SIGNAL_DELAY_1BAR`):**
  Introduces a pure 1-bar delay, acting as the fastest possible trigger line:
  $$\text{Signal}_t = \text{Fish}_{t-1}$$

* **Smoothing Average (`SIGNAL_MA`):**
  Applies any selected moving average type over the Fisher line. If **`VWMA`** is selected, the signal line is calculated dynamically using the corresponding volume array (Tick or Real Volume) to weight momentum:
  $$\text{Signal}_t = \frac{\sum_{k=0}^{P-1} \text{Fish}_{t-k} \times \text{Volume}_{t-k}}{\sum_{k=0}^{P-1} \text{Volume}_{t-k}}$$

---

## 3. High-Performance Architecture (Direct Close-Buffer Mapping)

Traditional indicator engines often create heavy performance bottlenecks by utilizing nested loops or allocating secondary price arrays to feed auxiliary indicators.

The Fisher Transform Pro Suite resolves this by utilizing the **Direct Close-Buffer Mapping Pattern**:

* The computed Fisher Transform values are maintained in a persistent internal class buffer `m_fish[]`.
* To calculate the moving average signal line, we call the standard `Calculate` method of the embedded `CMovingAverageCalculator`, passing the `m_fish[]` array for all price parameters (`open`, `high`, `low`, `close` parameters) and specifying `PRICE_CLOSE` as the applied price type:

  ```mql5
  m_signal_engine.Calculate(rates_total, prev_calculated, PRICE_CLOSE,
                            m_fish, m_fish, m_fish, m_fish,
                            volume,
                            signal_out);
  ```

This directs the MA engine to treat `m_fish` as the pricing close-source. This zero-copy approach natively supports all moving average types (including VWMA) on the Fisher line with maximum computational efficiency.

---

## 4. Visual & Architectural Highlights

The suite is engineered to maintain ultimate precision and runtime safety:

* **Locked Institutional Levels:**
  The separate subwindow separate levels are locked to Welles Wilder's standard significance boundaries: `1.5` (Extreme Bullish), `0.75` (Bullish Warning), `0.0` (Equilibrium Axis), `-0.75` (Bearish Warning), and `-1.5` (Extreme Bearish). The levels are rendered with clean silver dots (`STYLE_DOT`).

* **Szigorú Chronological Sorting Safeguards:**
  Because the normalization and Fisher Transform equations rely on a highly state-sensitive recursive history ($t-1$), any reverse-chronological array indexing will completely corrupt the calculations. To prevent this, the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`. This is also applied inside all internal resizes within the calculator classes.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations, a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 5. Advanced MQL5 MTF Implementation Details

`Fisher_Transform_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

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

Since the price normalization and Fisher equations are highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states. To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 6. Parameters

### A. Fisher Settings

* **Lookback Period (`InpPeriod`):** The rolling window size ($N$) for highest-high and lowest-low price normalization (Default: `10`, Range: $\ge 2$).
* **Smoothing Factor (`InpAlpha`):** The dampening coefficient ($\alpha$) for the normalized value. Smaller values increase smoothness; larger values increase speed (Default: `0.33`, Range: $0.01$ to $1.0$).
* **Price Source (`InpSource`):** Selects the price series source (`SOURCE_STANDARD` or `SOURCE_HEIKIN_ASHI`). Default: `SOURCE_STANDARD`.

### B. Signal Line Settings

* **Signal Type (`InpSignalType`):** Selects the trigger line calculation method (`SIGNAL_DELAY_1BAR`, `SIGNAL_MA`). Default: `SIGNAL_DELAY_1BAR`.
* **Signal Period (`InpSignalPeriod`):** The lookback period for the Signal Line MA (Default: `5`).
* **Signal Method (`InpSignalMethod`):** Select the MA type for the Signal Line (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, VWMA). Default: `SMA`.

### C. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate Fisher Transforms on (Default: `PERIOD_H1`).

---

## 7. Advanced Trading Strategies

### A. Low-Lag Reversal Crossovers (VWMA Signal Line)

Using a custom volume-weighted signal line on top of the Fisher Transform creates a highly precise mean-reversion filter. Crossovers are only triggered when structural market turns are backed by institutional trading volume.

1. Configure the Signal Line settings to:
   * `InpSignalType = SIGNAL_MA`
   * `InpSignalMethod = VWMA`
   * `InpSignalPeriod = 5`
2. **Bullish Reversal (BUY):** Wait for the Fisher line to drop below the Bearish Warning Level (**`-0.75`** or **`-1.5`**), indicating severe oversold conditions. Once the Fisher line crosses **above the VWMA Signal line** and rises, open Long.
3. **Bearish Reversal (SELL):** Wait for the Fisher line to rise above the Bullish Warning Level (**`0.75`** or **`1.5`**). Once the Fisher line crosses **below the VWMA Signal line** and falls, open Short.
4. **Stop-Loss:** Place the protective stop strictly beyond the extreme candle's high/low.

### B. Top-Down Volatility Alignment (MTF Core Strategy)

Trading lower timeframe crossovers in the direction of the higher timeframe cycle significantly reduces drawdown and increases win-rate.

1. **Macro Volatility Alignment (H1):** Apply `Fisher_Transform_MTF_Pro` set to H1 on an M5 execution chart. Configure the Signal Line to `VWMA` (Period 5).
2. **The Trend Filter:** Identify the direction of the macro cycle:
   * **Bullish Macro Regime:** The H1 Fisher line is above its Signal line and rising. Strictly seek buy setups on the M5 chart.
   * **Bearish Macro Regime:** The H1 Fisher line is below its Signal line and falling. Strictly seek sell setups.
3. **Execution:** On the local M5 chart, apply a fast local oscillator. When the H1 MTF indicator defines a Bullish Macro Regime, execute **BUY** orders strictly when the local oscillator crosses above its signal line, using the macro cycle alignment to filter out high-frequency false breakouts.
