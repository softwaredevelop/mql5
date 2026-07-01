# John Ehlers' Channel & Bands Pro Suites (Standard & MTF)

## 1. Summary (Introduction)

The **John Ehlers' Channel & Bands Pro Suites** are institutional-grade volatility corridor and cycle-bounding suites comprising four advanced indicators:

* `Ehlers_Channel_Pro` (Standard Keltner Concept)
* `Ehlers_Channel_MTF_Pro` (Multi-Timeframe Keltner Concept)
* `Ehlers_Bands_Pro` (Standard Bollinger Concept)
* `Ehlers_Bands_MTF_Pro` (Multi-Timeframe Bollinger Concept)

Traditional volatility envelopes (such as Bollinger Bands® or Keltner Channels) utilize lagging, time-based moving averages (SMA, EMA) as their centerline baselines. During sharp market expansions or structural trend reversals, these lagging centerlines cause the corridors to warp, creating false breakout signals.

This suite resolves this limitation by employing **John F. Ehlers' SuperSmoother** (2nd-order Low-Pass) or **UltimateSmoother** (3rd-order Low-Pass) Infinite Impulse Response (IIR) filters as their dynamic centerline baselines ($\mu_E$). These centerlines react recursively to price changes with near-zero phase lag.

The centerline is then wrapped in one of two volatility-envelope concepts:

1. **The Keltner Concept (Ehlers Channel):** Projects dynamic bands based on Welles Wilder's Average True Range (ATR) to measure absolute volatility.
2. **The Bollinger Concept (Ehlers Bands):** Projects dynamic bands based on Standard Deviation ($\sigma$) calculated directly relative to the smoother centerline to measure statistical dispersion.

Both suites support dynamic Heikin Ashi price integration, high-resolution decimal precision, and state-safe multi-timeframe step-blocking algorithms.

---

## 2. Mathematical Foundations

The calculations operate by first resolving the recursive Ihlers centerline and then projecting the volatility offsets:

### A. Dynamic Centerline Coefficient Calculations ($\mu_E$)

On each bar $t$, the decay rate ($a_1$) and trigonometric coefficients ($b_1, c_2, c_3$) are updated recursively based on the period $P$ (`InpPeriod`):

$$a_1 = e^{-\sqrt{2}\pi / P}$$

$$b_1 = 2 a_1 \cos\left(\frac{\sqrt{2}\pi}{P}\right)$$

$$c_2 = b_1, \quad c_3 = -a_1^2$$

The centerline ($\mu_{E, t}$) is then computed using the chosen filter type:

* **SuperSmoother Filter (2nd-Order Low-Pass):**
  $$c_1 = 1.0 - c_2 - c_3$$
  $$\mu_{E, t} = c_1 \frac{P_t + P_{t-1}}{2} + c_2 \mu_{E, t-1} + c_3 \mu_{E, t-2}$$

* **UltimateSmoother Filter (3rd-Order Low-Pass):**
  $$c_1 = \frac{1.0 + c_2 - c_3}{4.0}$$
  $$\mu_{E, t} = (1.0 - c_1) P_t + (2.0 c_1 - c_2) P_{t-1} - (c_1 + c_3) P_{t-2} + c_2 \mu_{E, t-1} + c_3 \mu_{E, t-2}$$

### B. Volatility Corridor Offsets

The centerline is offset by the selected volatility engine using the deviation multiplier $m$ (`InpMultiplier`):

* **Ehlers Channel (ATR - Keltner Concept):**
  Utilizes Average True Range ($\text{ATR}$) smoothed over $M$ (`InpAtrPeriod`):
  $$\text{Upper Band}_t = \mu_{E, t} + (m \times \text{ATR}_t)$$
  $$\text{Lower Band}_t = \mu_{E, t} - (m \times \text{ATR}_t)$$

* **Ehlers Bands (StdDev - Bollinger Concept):**
  Calculates Population Standard Deviation ($\sigma_E$) relative to the responsive IIR centerline ($\mu_{E}$) over $N$ (`InpPeriod`):
  $$\sigma_{E, t} = \sqrt{\frac{1}{N} \sum_{k=0}^{N-1} (P_{t-k} - \mu_{E, t})^2}$$
  $$\text{Upper Band}_t = \mu_{E, t} + (m \times \sigma_{E, t})$$
  $$\text{Lower Band}_t = \mu_{E, t} - (m \times \sigma_{E, t})$$

---

## 3. High-Performance & Precision Enhancements

The entire suite is optimized to conform with our strict quantitative design guidelines:

* **Strict Chronological Sorting Safeguards:**
  To prevent calculation corruption caused by reverse-chronological array states (often forced by custom templates or third-party indicators on the active chart), the suite enforces chronological sorting (`ArraySetAsSeries(..., false)`) on all price inputs inside `OnCalculate()`. This is also applied inside all internal resizes within the calculator classes.

* **Memory Safety Validation (Pointer Guards):**
  To shield the terminal from runtime memory violations, a robust pointer-safety layer validates all dynamic objects via `CheckPointer()` before any calculation sequence is allowed to execute.

---

## 4. Advanced MQL5 MTF Implementation Details

Both the Channel and Bands MTF versions resolve standard MTF calculation and display limitations by implementing a synchronized multi-timeframe pipeline:

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

Since the SuperSmoother and UltimateSmoother are highly recursive, calling calculations continuously on the live forming bar on every tick would corrupt the feedback states. To avoid this, we perform **State Mocking** by passing `prev_calculated = g_htf_count` during live ticks. This processes the forming index exactly once, protecting closed historical registers from accumulation errors.

---

## 5. Parameters

### A. Centerline Settings

* **Smoother Type (`InpSmootherType` / `InpCenterlineType`):** Selects between Ehlers' 2nd-order `SUPERSMOOTHER` or 3rd-order `ULTIMATESMOOTHER`. Default: `SUPERSMOOTHER`.
* **Smoothing Period (`InpPeriod`):** The dampening lookback period ($P$) for the centerline and standard deviation calculations (Default: `20`, Range: $\ge 2$).
* **Price Source (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. Volatility Settings

* **Multiplier (`InpMultiplier`):** The volatility band scaling multiplier ($m$) (Default: `2.0`).
* **ATR Period (`InpAtrPeriod` - Channel Only):** The Welles Wilder smoothing lookback period ($M$) used to calculate Average True Range (Default: `14`).
* **ATR Source (`InpAtrSource` - Channel Only):** Selects the price array source used for the ATR calculation (`ATR_SOURCE_STANDARD` or `ATR_SOURCE_HEIKIN_ASHI`).

### C. MTF Specific Settings (MTF Versions Only)

* **Target Timeframe (`InpUpperTimeframe` / `InpTimeframe`):** The target higher timeframe to calculate corridors on (Default: `PERIOD_H1`).

---

## 6. Quantitative Trading Strategies

### A. The Ehlers Volatility Squeeze (Channel vs. Bands)

The **Volatility Squeeze** is a premier institutional setup that combines both Bollinger and Keltner concepts to identify explosive breakout opportunities.

* **The Concept:** Bollinger Bands (`Ehlers_Bands_Pro`) measure statistical dispersion, while Keltner Channels (`Ehlers_Channel_Pro`) measure average price range. When volatility contracts severely, the Bollinger Bands squeeze **inside** the Keltner Channels. A subsequent expansion where the bands stretch outside the channel signifies an explosive trend breakout.

1. **Indicator Setup:**
   * Apply `Ehlers_Bands_Pro` (Default colors, represented in clrCornflowerBlue).
   * Apply `Ehlers_Channel_Pro` (Default colors, represented in clrMediumSlateBlue).
   * Ensure both indicators use identical centerline settings (e.g. `InpPeriod = 20`, `InpSmootherType = SUPERSMOOTHER`).
2. **The Squeeze Identification:**
   * Monitor the chart for periods where the **Upper Bollinger Band falls below the Upper Keltner Band**, and the **Lower Bollinger Band rises above the Lower Keltner Band**. This signifies that the Bollinger Bands are completely inside the Keltner Channel (The Squeeze).
3. **The Breakout Execution:**
   * **Bullish Breakout (BUY):** When the Bollinger Bands expand outside the Keltner Channel and a candle closes completely above the Upper Bollinger Band.
   * **Bearish Breakout (SELL):** When the Bollinger Bands expand outside the Keltner Channel and a candle closes completely below the Lower Bollinger Band.
4. **Stop-Loss:** Place the protective stop strictly below the low-lag Ehlers centerline.

### B. High-Timeframe Volatility Corridors (MTF Trend Riding)

By combining an MTF Volatility Corridor with a local entry strategy, traders can ride major institutional waves with minimal risk.

1. **Setup:** Apply `Ehlers_Channel_MTF_Pro` set to H1 or H4 on an M15 chart:
   * `InpSmootherType = ULTIMATESMOOTHER`
   * `InpPeriod = 20`, `InpAtrPeriod = 14`, `InpMultiplier = 2.0`
2. **Trend Definition:**
   * **Bullish Trend:** Price trades consistently above the H1 Middle MTF line, utilizing it as dynamic support.
   * **Bearish Trend:** Price trades consistently below the H1 Middle MTF line, utilizing it as dynamic resistance.
3. **LTF Execution:** On the local M15 chart:
   * In a Bullish Trend, wait for the price to pull back and touch the H1 Middle MTF line (dynamic support).
   * Enter **BUY** orders as soon as a bullish rejection candle forms. Place the stop-loss strictly below the Lower MTF Band, using the macro volatility corridor as an absolute stop barrier.
