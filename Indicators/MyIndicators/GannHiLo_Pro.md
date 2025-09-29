# Gann HiLo Activator Professional

## 1. Summary (Introduction)

The Gann HiLo Activator is a simple yet effective trend-following indicator developed by Robert Krausz. It is not directly based on the complex methods of W.D. Gann, but rather follows the core principle of using moving averages of previous highs and lows to identify the trend direction.

The indicator is plotted on the price chart as a single line that changes color and position relative to the price, providing clear, visual signals for trend direction and trailing stop-loss levels.

Our `GannHiLo_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The Gann HiLo Activator is based on two separate moving averages: one calculated on the previous `N` bars' high prices, and the other on the previous `N` bars' low prices.

### Required Components

* **Period (N):** The lookback period for the high and low moving averages.
* **MA Method:** The type of moving average to use (Simple, Exponential, etc.).
* **Source Prices:** The `High[]`, `Low[]`, and `Close[]` price series.

### Calculation Steps (Algorithm)

1. **Calculate the Moving Average of Highs:** Compute the moving average of the high prices over the last `N` bars.
    $\text{HiAvg}_i = \text{MA}(\text{High}, N)_i$

2. **Calculate the Moving Average of Lows:** Compute the moving average of the low prices over the last `N` bars.
    $\text{LoAvg}_i = \text{MA}(\text{Low}, N)_i$

3. **Determine the Trend Direction:** The trend is determined by comparing the current closing price to the moving averages of the *previous* bar.
    * If the current `Close` is **above** the previous bar's `HiAvg`, the trend is **up**.
    * If the current `Close` is **below** the previous bar's `LoAvg`, the trend is **down**.
    * Otherwise, the trend **continues** from the previous bar.

4. **Plot the Gann HiLo Activator Line:**
    * If the trend is **up**, the indicator line is plotted at the level of the **LoAvg**.
    * If the trend is **down**, the indicator line is plotted at the level of the **HiAvg**.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`Gann_HiLo_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CGannHiLoCalculator`**: The base class that performs the full, state-dependent calculation on a given set of High, Low, and Close prices.
  * **`CGannHiLoCalculator_HA`**: A child class that inherits from the base class and overrides only the data preparation step. Its sole responsibility is to calculate Heikin Ashi candles and provide the `HA_High`, `HA_Low`, and `HA_Close` prices to the base class's shared calculation algorithm. This object-oriented approach eliminates code duplication.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate`. For a state-dependent indicator like the Gann HiLo, this is the most reliable method to prevent calculation errors.

* **Fully Manual MA Calculations:** To guarantee 100% accuracy and consistency, all moving average types (**SMA, EMA, SMMA, LWMA**) are implemented **manually** within the calculator engine.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the high and low moving averages. Default is `10`.
* **MA Method (`InpMAMethod`):** The type of moving average to use for the high and low calculations. Default is `MODE_SMA`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation.
  * `CANDLE_STANDARD`: Uses the standard chart's High, Low, and Close.
  * `CANDLE_HEIKIN_ASHI`: Uses the smoothed Heikin Ashi High, Low, and Close.

## 5. Usage and Interpretation

* **Trend Identification:** The primary use of the Gann HiLo is to identify the current market trend. A blue line below the price indicates an uptrend. A red line above the price indicates a downtrend.
* **Trailing Stop-Loss:** The indicator is exceptionally well-suited for use as a trailing stop-loss. In an uptrend, a trader might place their stop-loss just below the blue line. In a downtrend, the stop-loss could be placed just above the red line.
* **Trade Signals:** A change in the indicator's color can be interpreted as a trade signal. A flip from red to blue suggests a potential buy signal, while a flip from blue to red suggests a potential sell signal.
* **Caution:** Like all trend-following indicators, the Gann HiLo is most effective in trending markets. In sideways or ranging markets, it can produce frequent false signals ("whipsaws").
