# John Ehlers' Butterworth Channel Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Butterworth Channel Pro Suite** is an institutional-grade volatility corridor and trend-following trading suite comprising two advanced indicators:

* `Butterworth_Channel_Pro` (Standard)
* `Butterworth_Channel_MTF_Pro` (Multi-Timeframe)

The suite represents a modernized, low-latency adaptation of the classic **Keltner Channel**. Standard Keltner Channels employ a Simple Moving Average (SMA) or Exponential Moving Average (EMA) as their centerline. During explosive trend reversals, time-based centerlines suffer from significant phase delay, causing the corridors to warp or generating false breakout signals during sideways consolidations.

The Butterworth Channel Pro Suite resolves this bottleneck by employing **John F. Ehlers' Butterworth Filter** (supporting 2-pole and 3-pole transfer functions) as its dynamic centerline baseline ($\mu_B$).

By utilizing a fourier-aligned, maximally flat IIR filter centerline, the channel is immune to low-frequency market noise during choppy consolidations, yet reacts instantly to trend shifts and explosive breakouts. The centerline is then wrapped in a volatility envelope projected from a smoothed **Average True Range (ATR)**, establishing a highly adaptive price channel that encapsulates market volatility, provides clear breakout signals, and establishes precise dynamic support and resistance corridors.

The suite features dynamic Heikin Ashi price integration, three-decimal Gamma formatting to support precise **Fibonacci ratios**, and advanced multi-timeframe step-blocking algorithms to prevent real-time drawing warping.

---

## 2. Mathematical Foundations

The calculation pipeline consists of three cascading mathematical steps, calculated recursively on every bar:

### A. Dynamic Centerline (John Ehlers' Butterworth Filter $\mu_B$)

At each bar $t$, the price $P_t$ (Standard or Heikin Ashi) is mapped recursively into a stateful, high-order Butterworth Filter using the selected cutoff period $P$ (`InpPeriod`):

* **Two-Pole Butterworth Filter (POLES_TWO):**
  $$a = e^{-\sqrt{2}\pi / P}$$
  $$b = 2 \times a \times \cos\left(\frac{\sqrt{2}\pi}{P}\right)$$
  $$c_1 = \frac{1.0 - b + a^2}{4.0}$$
  $$\mu_{B, t} = b \times \mu_{B, t-1} - a^2 \times \mu_{B, t-2} + c_1 \times (P_t + 2 \times P_{t-1} + P_{t-2})$$

* **Three-Pole Butterworth Filter (POLES_THREE):**
  $$a = e^{-\pi / P}$$
  $$b = 2 \times a \times \cos\left(\frac{1.738\pi}{P}\right)$$
  $$c = a^2$$
  $$c_1 = \frac{(1.0 - b + c) \times (1.0 - c)}{8.0}$$
  $$\mu_{B, t} = (b + c) \mu_{B, t-1} - (c + b \times c) \mu_{B, t-2} + c^2 \mu_{B, t-3} + c_1 \times (P_t + 3 \times P_{t-1} + 3 \times P_{t-2} + P_{t-3})$$

### B. Average True Range (ATR) Volatility Smoothing

The Average True Range ($\text{ATR}$) measures absolute market volatility over a lookback period $M$ (`InpAtrPeriod`). First, the True Range ($\text{TR}$) of the current candle is calculated:

$$\text{TR}_t = \max \left( H_t - L_t, \, \left| H_t - C_{t-1} \right|, \, \left| L_t - C_{t-1} \right| \right)$$

The $\text{ATR}$ is then calculated by applying Welles Wilder's SMMA smoothing over the True Range series:

$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \times (M - 1) + \text{TR}_t}{M}$$

### C. Dynamic Volatility Band Boundaries

The upper and lower volatility boundaries are projected around the Butterworth Filter centerline $\mu_{B, t}$ by multiplying the computed $\text{ATR}_t$ by the user-defined multiplier $m$ (`InpMultiplier`):

$$\text{Upper Band}_t = \mu_{B, t} + (m \times \text{ATR}_t)$$

$$\text{Lower Band}_t = \mu_{B, t} - (m \times \text{ATR}_t)$$

---

## 3. High-Performance & Precision Enhancements

The suite is engineered to meet the highest execution and stability standards:

* **Szigorú Chronological Sorting Safeguards:**
  To prevent calculation corruption caused by reverse-chronological array states (often forced by custom templates or third-party indicators on the active chart), the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`. This is also applied inside the dynamic buffer resizes (`m_price[]`, `m_atr_buffer[]`, etc.) within the calculator engine classes.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations (such as access violation fatal crashes), a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 4. Advanced MQL5 MTF Implementation Details

`Butterworth_Channel_MTF_Pro` resolves standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

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

Since the Butterworth Filter and Welles Wilder's ATR smoothing are highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states ($F_{t-1}, F_{t-2}, F_{t-3}$). To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

### C. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

---

## 5. Parameters

### A. Butterworth Settings

* **Filter Period (`InpPeriod`):** The filter's cutoff period ($P$). Larger periods increase smoothing and decay; smaller periods increase responsiveness (Default: `20`, Range: $\ge 2$).
* **Number of Poles (`InpPoles`):** Selects between a 2-pole (`POLES_TWO = 2`) or 3-pole (`POLES_THREE = 3`) IIR transfer function. Default: `POLES_TWO`.
* **Price Source (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Channel Volatility Settings

* **ATR Period (`InpAtrPeriod`):** The Welles Wilder smoothing lookback period ($M$) used to calculate Average True Range (Default: `14`).
* **ATR Multiplier (`InpMultiplier`):** The volatility band width scaling factor ($m$) (Default: `2.0`).
* **ATR Source (`InpAtrSource`):** Selects the price array source used for the ATR calculation (`ATR_SOURCE_STANDARD` or `ATR_SOURCE_HEIKIN_ASHI`).

### C. MTF Specific Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate corridors on (Default: `PERIOD_H1`).

---

## 6. Quantitative Trading Strategies

### A. The Butterworth Volatility Breakout Trigger (The Squeeze breakout)

consolidation zones that breach the ATR bands represent high-probability trend momentum starts. Because the Butterworth centerline is maximally flat during choppy consolidations, the channel contracts tightly into a "Squeeze," generating exceptionally clean breakout triggers.

1. **Setup:** Apply `Butterworth_Channel_Pro` on an M15 chart:
   * `InpPeriod = 20`, `InpPoles = POLES_THREE` (3-pole achieves a sharper roll-off)
   * `InpAtrPeriod = 14`, `InpMultiplier = 1.8` (A tighter multiplier identifies breakouts earlier)
2. **Execution Trigger:**
   * **BUY Trigger:** Enter Long when a candle closes **completely above the Upper Band** after a period of channel compression.
   * **SELL Trigger:** Enter Short when a candle closes **completely below the Lower Band** after a period of channel compression.
3. **Stop-Loss:** Place the protective stop strictly below the local Butterworth centerline.
4. **Exit Strategy:** Close the trade once a candle closes on the opposite side of the Butterworth centerline, signifying that the cyclical trend momentum has terminated.

### B. Centerline Pullback Rejection (Dynamic Support/Resistance Pivots)

During strong trends, price fluctuates but tends to respect the centerline as a value anchor. Since the Butterworth filter centerline is highly responsive and smooth, it acts as an excellent dynamic pivot line.

1. **Setup:** Apply `Butterworth_Channel_Pro` configured to `POLES_TWO` with a period of **`20`** and a wider volatility buffer multiplier of **`2.5`** to identify the trend extremities.
2. **The Trend Definition:**
   * **Uptrend:** Price trades consistently between the Centerline and the Upper Band.
   * **Downtrend:** Price trades consistently between the Centerline and the Lower Band.
3. **Execution:**
   * In an uptrend, wait for price to pull back and **test the Butterworth Centerline**. On a bullish rejection candle (where the low touches the centerline but closes above), execute **BUY** limit or market orders.
   * In a downtrend, wait for price to rally to test the Butterworth Centerline. On a bearish rejection candle, execute **SELL** orders.
4. **Stop-Loss:** Place the protective stop strictly beyond the opposite ATR band (e.g., beyond the Lower Band for buy trades), using the channel's volatility range as an absolute safety barrier.
