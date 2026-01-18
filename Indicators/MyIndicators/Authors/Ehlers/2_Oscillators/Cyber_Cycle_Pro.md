# Cyber Cycle Pro

## 1. Summary (Introduction)

The **Cyber Cycle Pro**, developed by John Ehlers, is a unique indicator designed to isolate and display the short-term cyclical components of price action. Unlike momentum oscillators like the RSI, which measure the strength of price moves, the Cyber Cycle acts as a **band-pass filter** to remove trend and high-frequency noise, revealing the underlying "heartbeat" or rhythm of the market.

The output is a smooth, sine-wave-like oscillator whose amplitude varies with the strength of the cycles. Its primary purpose is not to measure overbought/oversold levels, but to **time the turning points** of these short-term cycles.

The indicator plots two lines:

* **Cycle Line:** The main filtered value.
* **Signal Line:** A trigger line used for generating crossover signals. This version offers flexible signal line calculation methods.

## 2. Mathematical Foundations

The indicator uses a two-pole Butterworth band-pass filter to isolate the cyclical component of the price.

### Calculation Steps

1. **Pre-Smoothing:** The source price is first lightly smoothed using a 4-bar weighted FIR filter.
2. **Cycle Calculation:** The core is a recursive Butterworth filter applied to the smoothed price.
3. **Signal Line Generation:** The Signal Line can be calculated in two ways:
    * **Delay (Classic):** The Cycle line's value from the previous bar (`Cycle[i-1]`).
    * **Moving Average:** A smoothing (SMA, EMA, etc.) applied to the Cycle line.

## 3. MQL5 Implementation Details

* **O(1) Incremental Calculation:** Optimized for high performance. The indicator processes only new bars (`prev_calculated`), ensuring zero lag and minimal CPU usage.
* **Stateful Engine (`Cyber_Cycle_Calculator.mqh`):** The calculation logic is encapsulated in a stateful class that persists intermediate values (`m_smooth`, `m_cycle`) between ticks.
* **Heikin Ashi Integration:** Built-in support for all Heikin Ashi price types.

## 4. Parameters

### Cyber Cycle Settings

* **Alpha (`InpAlpha`):** The smoothing factor for the Butterworth filter. Ehlers' recommendation is **0.07**.
* **Source Price (`InpSourcePrice`):** Selects the input data. Default is `PRICE_MEDIAN_STD`.

### Signal Line Settings

* **Signal Type (`InpSignalType`):**
  * `SIGNAL_DELAY_1BAR`: The classic Ehlers method (fastest trigger).
  * `SIGNAL_MA`: Allows using a moving average as the signal line.
* **Signal Period (`InpSignalPeriod`):** The period for the MA signal line (if `SIGNAL_MA` is selected).
* **Signal Method (`InpSignalMethod`):** The averaging method (SMA, EMA, etc.).

## 5. Usage and Interpretation

The Cyber Cycle is a **timing tool for cycle reversals**.

### Signal Line Crossover

* **Buy Signal:** The **Cycle line crosses above the Signal line**.
* **Sell Signal:** The **Cycle line crosses below the Signal line**.
* *Tip:* Using an SMA Signal Line (e.g., Period 3) can provide smoother crossovers than the classic 1-bar delay, reducing false signals in choppy markets.

### Trend Filter Rule (Critical)

The Cyber Cycle removes the trend component. Therefore, trading its signals against a strong trend is risky. Always trade in the direction of the higher timeframe trend.
