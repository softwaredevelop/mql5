# TDI CMO Professional

## 1. Summary (Introduction)

The `TDI_CMO_Pro` is an innovative adaptation of the classic Trader's Dynamic Index (TDI). While the original TDI is built upon the Relative Strength Index (RSI), this version replaces the RSI with the **Chande Momentum Oscillator (CMO)** as its core engine.

This modification creates a unique trading system that analyzes market dynamics through the lens of "pure momentum" (as measured by CMO) rather than normalized price speed (as measured by RSI). The indicator retains the full visual framework of the TDI, including:

* **Price Line (Green):** The fastest, most sensitive momentum line.
* **Signal Line (Red):** A short-term moving average of the Price Line, used for crossover signals.
* **Base Line (Orange):** A medium-term moving average representing the overall market sentiment or momentum bias.
* **Volatility Bands (Blue):** Bollinger Bands that measure the volatility of the underlying momentum, providing a sense of market expansion and contraction.

This implementation also supports calculations based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The calculation is a multi-stage process that begins with the CMO and then builds the entire TDI structure on top of a rescaled version of it.

### Required Components

* **CMO Period (N):** The lookback period for the base oscillator.
* **TDI Periods:** Periods for the Price Line, Signal Line, and Base Line.
* **Bands Deviation:** The standard deviation multiplier for the volatility bands.

### Calculation Steps (Algorithm)

1. **Calculate the Chande Momentum Oscillator (CMO):** First, the standard CMO is calculated over period `N`, resulting in a value between -100 and +100.
    $\text{CMO}_i = 100 \times \frac{\text{Sum Up}_i - \text{Sum Down}_i}{\text{Sum Up}_i + \text{Sum Down}_i}$

2. **Rescale the CMO:** This is the critical step. The TDI system is designed for an oscillator in the 0-100 range. Therefore, the CMO's output is rescaled from [-100, +100] to [0, 100].
    $\text{Rescaled CMO}_i = \frac{\text{CMO}_i + 100}{2}$

3. **Calculate the Price Line:** The Price Line is a short-period Moving Average of the `Rescaled CMO`.
    * *Classic TDI uses SMA.*

4. **Calculate the Signal and Base Lines:** Both are Moving Averages calculated on the `Price Line`.
    * *Classic TDI uses SMA.*

5. **Calculate the Volatility Bands:** These are Bollinger Bands, but with a unique twist. The standard deviation is calculated on the `Rescaled CMO` over the `Base Line Period`. The resulting bands are then plotted around the `Base Line`.
    $\text{StdDev} = \text{StandardDeviation}(\text{Rescaled CMO}, \text{Base Line Period})$
    $\text{Upper Band}_i = \text{Base Line}_i + (\text{Deviation Multiplier} \times \text{StdDev})$
    $\text{Lower Band}_i = \text{Base Line}_i - (\text{Deviation Multiplier} \times \text{StdDev})$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Full Engine Integration:**
    The calculator (`TDI_CMO_Calculator.mqh`) orchestrates **four** powerful engines:
    1. **CMO Engine:** Computes the base Chande Momentum Oscillator.
    2. **Price Line Engine:** Smooths the rescaled CMO (using `MovingAverage_Engine.mqh`).
    3. **Signal Line Engine:** Smooths the Price Line (using `MovingAverage_Engine.mqh`).
    4. **Base Line Engine:** Smooths the Price Line (using `MovingAverage_Engine.mqh`).
    This architecture allows for extreme flexibility (e.g., using DEMA for all lines) while maintaining code consistency.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations.

* **Object-Oriented Design:**
  * The Heikin Ashi version (`CTDICMOCalculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the CMO module.

## 4. Parameters

* **CMO Period (`InpCmoPeriod`):** The lookback period for the base Chande Momentum Oscillator.
* **Price Line Period (`InpPriceLinePeriod`):** The smoothing period for the fast (green) line. (Default: `2`).
* **Signal Line Period (`InpSignalLinePeriod`):** The smoothing period for the short-term signal (red) line. (Default: `7`).
* **Base Line Period (`InpBaseLinePeriod`):** The smoothing period for the medium-term market sentiment (orange) line. (Default: `34`).
* **Bands Deviation (`InpBandsDeviation`):** The multiplier for the volatility bands. (Default: `1.618`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. (Standard or Heikin Ashi).
* **MA Method (`InpMAMethod`):** The type of moving average to use for all lines. Set to **SMA** for classic TDI behavior. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).

## 5. Suggested Settings for the CMO Indicator Family

To use the `CMO_Pro`, `VIDYA_Pro`, and `TDI_CMO_Pro` as a coherent system, their parameters should be synchronized. The core of the system is the base CMO Period. Here are two suggested configurations:

| Indicator         | Parameter             | **Standard Setting (13)** | **Fast Setting (8)** |
| ----------------- | --------------------- | :-----------------------: | :------------------: |
| **CMO_Pro**       | `InpPeriodCMO`        |            **13**         |         **8**        |
|                   |                       |                           |                      |
| **VIDYA_Pro**     | `InpPeriodCMO`        |            **13**         |         **8**        |
|                   | `InpPeriodEMA`        |            `12`           |         `8`          |
|                   |                       |                           |                      |
| **TDI_CMO_Pro**   | `InpCmoPeriod`        |            **13**         |         **8**        |
|                   | `InpPriceLinePeriod`  |             `2`           |         `2`          |
|                   | `InpSignalLinePeriod` |             `7`           |         `5`          |
|                   | `InpBaseLinePeriod`   |            `34`           |         `34`         |
|                   | `InpBandsDeviation`   |           `1.618`         |       `1.618`        |

### Rationale for Settings

* **Standard Setting (13):** This is a balanced, medium-term configuration suitable for most timeframes (e.g., H1, H4). It provides a good compromise between responsiveness and signal smoothness.
* **Fast Setting (8):** This is a more sensitive configuration, ideal for lower timeframes (e.g., M5, M15) or scalping strategies. It will react faster to momentum changes but may also produce more false signals. The `TDI Signal Line Period` is reduced to `5` to better track the faster Price Line, while the `TDI Base Line Period` is kept at `34` to maintain a stable long-term context.

## 6. Usage and Interpretation

The interpretation of TDI CMO is similar to the classic TDI, but with the understanding that it reflects pure momentum rather than price speed.

* **Price Line (Green):** Represents the most immediate market sentiment. A steep angle indicates strong momentum.
* **Signal Line (Red):** Acts as the trigger line. A crossover of the Green Line above the Red Line is a bullish signal; a crossover below is a bearish signal.
* **Base Line (Orange):** Represents the overall momentum bias. When the Green/Red lines are above the Orange line, the market has a bullish bias. When they are below, the bias is bearish. Trades are often filtered based on the location relative to this line.
* **Volatility Bands (Blue):** Indicate momentum volatility.
  * **Expanding Bands ("Shark Mouth"):** Signal a strong, high-momentum move is underway.
  * **Contracting Bands ("Squeeze"):** Signal a period of low momentum and consolidation, often preceding a breakout.
