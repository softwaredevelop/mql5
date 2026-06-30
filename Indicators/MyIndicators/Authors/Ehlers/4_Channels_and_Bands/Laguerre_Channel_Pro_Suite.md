# Laguerre Channel Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Laguerre Channel Pro Suite** is an institutional-grade volatility corridor and trend-following trading suite comprising two advanced indicators:

* `Laguerre_Channel_Pro` (Standard Laguerre Channel)
* `Laguerre_Channel_MTF_Pro` (Multi-Timeframe Laguerre Channel)

The suite is a modernized, low-latency adaptation of the classic **Keltner Channel**. Standard Keltner Channels employ a Simple Moving Average (SMA) or Exponential Moving Average (EMA) as their centerline. During explosive trend reversals, time-based centerlines suffer from significant phase delay, often causing the bands to warp or leaving the price stuck outside the channel during sharp pivots.

The Laguerre Channel Pro Suite resolves this bottleneck by employing **John Ehlers' Laguerre Filter** as its dynamic center line ($\mu_L$). By utilizing a fourier-aligned, stateful centerline, the channel shifts instantly with trend reversals. It then projects dynamic volatility bands around this low-lag center based on a smoothed **Average True Range (ATR)**. The result is a highly adaptive price channel that encapsulates market volatility, provides clear breakout signals, and establishes precise dynamic support and resistance corridors.

The suite supports dynamic Heikin Ashi price integration, three-decimal Gamma formatting to support precise **Fibonacci ratios**, and advanced MTF step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The mathematical calculation combines recursive polynomial filtering with Welles Wilder's True Range volatility smoothing:

### A. Dynamic Centerline (John Ehlers' Laguerre Filter $\mu_L$)

On each bar $t$, the centerline is computed recursively using the stateful Laguerre polynomial states ($L_0$ to $L_3$), controlled by the dampening coefficient $\gamma$ (`InpGamma`):

$$L_{0, t} = (1 - \gamma) P_t + \gamma L_{0, t-1}$$

$$L_{1, t} = -\gamma L_{0, t} + L_{0, t-1} + \gamma L_{1, t-1}$$

$$L_{2, t} = -\gamma L_{1, t} + L_{1, t-1} + \gamma L_{2, t-1}$$

$$L_{3, t} = -\gamma L_{2, t} + L_{2, t-1} + \gamma L_{3, t-1}$$

$$\mu_{L, t} = \frac{L_{0, t} + 2 \times L_{1, t} + 2 \times L_{2, t} + L_{3, t}}{6}$$

### B. Average True Range (ATR) Volatility Smoothing

The Average True Range ($\text{ATR}$) measures market volatility over a lookback period $M$ (`InpAtrPeriod`). First, the True Range ($\text{TR}$) of the current candle is calculated:

$$\text{TR}_t = \max \left( \text{High}_t - \text{Low}_t, \, \left| \text{High}_t - \text{Close}_{t-1} \right|, \, \left| \text{Low}_t - \text{Close}_{t-1} \right| \right)$$

The $\text{ATR}$ is then calculated by applying Welles Wilder's SMMA smoothing over the True Range series:

$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \times (M - 1) + \text{TR}_t}{M}$$

### C. Dynamic Volatility Band Boundaries

The upper and lower volatility boundaries are projected around the Laguerre Filter centerline $\mu_{L, t}$ by multiplying the computed $\text{ATR}_t$ by the user-defined multiplier $m$ (`InpMultiplier`):

$$\text{Upper Band}_t = \mu_{L, t} + (m \times \text{ATR}_t)$$

$$\text{Lower Band}_t = \mu_{L, t} - (m \times \text{ATR}_t)$$

---

## 3. High-Performance & Precision Enhancements

The suite is built to conform with our strict quantitative design guidelines:

* **Three-Decimal Precision Formatting:**
  To natively support precise Fibonacci Gamma inputs (e.g., `0.236`, `0.382`, `0.618`) without visual rounding, the indicator short name formatting is expanded to three decimal places. The dynamic ShortName in `OnInit()` uses a `%.3f` formatting mask:

  ```mql5
  IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Laguerre Ch(%.3f, ATR %d)", InpGamma, InpAtrPeriod));
  ```

  This ensures that critical Fibonacci settings are clearly documented on the chart subwindow and inside the terminal legend.

* **Szigorú Chronological Sorting Safeguards:**
  To prevent calculation corruption caused by reverse-chronological array states (often forced by custom templates or third-party indicators on the active chart), the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations (such as access violation fatal crashes), a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 4. Advanced MQL5 MTF Implementation Details

`Laguerre_Channel_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

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

## 5. Parameters

### A. Laguerre Centerline Settings

* **Gamma Factor (`InpGamma`):** Controls the dampening speed of the polynomial states. Lower values (e.g., `0.382` or `0.500`) are faster; higher values (e.g., `0.700` or `0.850`) are smoother (Default: `0.700`, Fibonacci Recommendations: `0.236`, `0.382`, `0.618`).
* **Source Price (`InpSourcePrice`):** Selects the pricing input, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Channel Volatility Settings

* **ATR Period (`InpAtrPeriod`):** The Welles Wilder smoothing lookback period ($M$) used to calculate Average True Range (Default: `14`).
* **ATR Multiplier (`InpMultiplier`):** The volatility band width scaling factor ($m$) (Default: `2.0`).
* **ATR Source (`InpAtrSource`):** Selects the price array source used for the ATR calculation (`ATR_SOURCE_STANDARD` or `ATR_SOURCE_HEIKIN_ASHI`).

### C. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate Laguerre Channels on (Default: `PERIOD_H1`).

---

## 6. Quantitative Trading Strategies

### A. The Volatility Breakout Trigger (Laguerre Keltner Squeeze)

Breakouts from consolidation zones that breach the ATR bands represent high-probability trend momentum starts. Because the Laguerre centerline tracks price closely, the Keltner Squeeze contracts rapidly, generating incredibly clean breakout trigger zones.

1. **Setup:** Apply `Laguerre_Channel_Pro` on an M15 chart:
   * `InpGamma = 0.618` (The Golden Ratio anchor)
   * `InpAtrPeriod = 14`, `InpMultiplier = 1.5` (A tighter multiplier identifies breakouts earlier)
2. **Execution Trigger:**
   * **BUY Trigger:** Enter Long when a candle closes **completely above the Upper Band** after a period of channel compression.
   * **SELL Trigger:** Enter Short when a candle closes **completely below the Lower Band** after a period of channel compression.
3. **Stop-Loss:** Place the protective stop strictly below the local Laguerre centerline.
4. **Exit Strategy:** Close the trade once a candle closes on the opposite side of the Laguerre centerline, signifying that the cyclical expansion has terminated.

### B. Centerline Pullback Riding (Dynamic Support/Resistance Pivots)

During strong trends, price fluctuates but tends to respect the centerline as a value anchor. Since the Laguerre filter is highly responsive, it acts as an excellent dynamic pivot line.

1. **Setup:** Apply `Laguerre_Channel_Pro` configured with a light execution baseline Gamma of **`0.382`** and a wider volatility buffer multiplier of **`2.5`** to identify the trend extremities.
2. **The Trend Definition:**
   * **Uptrend:** Price trades consistently between the Centerline and the Upper Band.
   * **Downtrend:** Price trades consistently between the Centerline and the Lower Band.
3. **Execution:**
   * In an uptrend, wait for price to pull back and **test the Laguerre Centerline**. On a bullish rejection candle (where the low touches the centerline but closes above), execute **BUY** limit or market orders.
   * In a downtrend, wait for price to rally to test the Laguerre Centerline. On a bearish rejection candle, execute **SELL** orders.
4. **Stop-Loss:** Place the protective stop strictly beyond the opposite ATR band (e.g., beyond the Lower Band for buy trades), using the channel's volatility range as an absolute safety barrier.
