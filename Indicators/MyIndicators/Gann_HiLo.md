# Gann HiLo Activator

## 1. Summary (Introduction)

The Gann HiLo Activator is a simple yet effective trend-following indicator developed by Robert Krausz. Despite its name, it is not directly based on the complex methods of W.D. Gann, but rather follows the core principle of using moving averages of previous highs and lows to identify the trend direction.

The indicator is plotted on the price chart as a single line that changes color and position relative to the price, providing clear, visual signals for trend direction, potential entry points, and trailing stop-loss levels.

## 2. Mathematical Foundations and Calculation Logic

The Gann HiLo Activator is based on two separate moving averages: one calculated on the previous `N` bars' high prices, and the other on the previous `N` bars' low prices. The indicator then uses the closing price to determine which of these two moving averages to follow.

### Required Components

- **Period (N):** The lookback period for the high and low moving averages.
- **MA Method:** The type of moving average to use (Simple, Exponential, etc.).
- **Source Prices:** The `High[]` and `Low[]` price series.

### Calculation Steps (Algorithm)

1. **Calculate the Moving Average of Highs:** Compute the moving average of the high prices over the last `N` bars.
   $\text{HiAvg}_i = \text{MA}(\text{High}, N)_i$

2. **Calculate the Moving Average of Lows:** Compute the moving average of the low prices over the last `N` bars.
   $\text{LoAvg}_i = \text{MA}(\text{Low}, N)_i$

3. **Determine the Trend Direction:** The trend is determined by comparing the current closing price to the moving averages of the _previous_ bar.

   - If the current `Close` is **above** the previous bar's `HiAvg`, the trend is **up**.
   - If the current `Close` is **below** the previous bar's `LoAvg`, the trend is **down**.
   - If the `Close` is between the two previous averages, the trend **continues** from the previous bar.

4. **Plot the Gann HiLo Activator Line:**
   - If the trend is **up**, the indicator line is plotted at the level of the **LoAvg**.
   - If the trend is **down**, the indicator line is plotted at the level of the **HiAvg**.

## 3. MQL5 Implementation Details

Our MQL5 implementation was refactored to be a completely self-contained, robust, and accurate indicator, consistent with our established coding principles.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. For a state-dependent indicator like the Gann HiLo, this is the most reliable method to prevent calculation errors and ensure stability.

- **Fully Manual MA Calculations:** To guarantee 100% accuracy and consistency within our `non-timeseries` calculation model, we have implemented all moving average types (**SMA, EMA, SMMA, LWMA**) **manually**. The indicator is completely independent of the `<MovingAverages.mqh>` standard library. This approach provides full control and ensures predictable behavior.

  - **Recursive MAs (EMA/SMMA)** are carefully initialized with a manual Simple Moving Average to prevent floating-point overflows.
  - **SMA** is calculated using an efficient sliding-window sum technique.

- **Integrated Calculation Loop:** The `OnCalculate` function uses a single, efficient `for` loop to perform all calculations. Within each iteration, it first computes the `HiAvg` and `LoAvg`, then immediately determines the trend direction and sets the final `GannHiLo` value. This integrated approach is clear and performant.

- **Visual Representation:** The implementation ensures that trend changes are represented by a clean, vertical line connecting the previous trend's endpoint to the new trend's starting point, providing continuous visual information.

- **Heikin Ashi Variant (`Gann_HiLo_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high` and `ha_low` values for the moving average calculations and the `ha_close` for determining the trend.
  - This results in a significantly smoother indicator, ideal for traders who want to focus on the primary trend and filter out market noise.

## 4. Parameters

- **Period (`InpPeriod`):** The lookback period for the high and low moving averages. A shorter period will result in a more responsive line that follows the price closely, while a longer period will create a smoother line that is less sensitive to minor fluctuations. Default is `10`.
- **MA Method (`InpMAMethod`):** The type of moving average to use for the high and low calculations (SMA, EMA, SMMA, LWMA). Default is `MODE_SMA`.

## 5. Usage and Interpretation

- **Trend Identification:** The primary use of the Gann HiLo is to identify the current market trend. A blue line below the price indicates an uptrend. A red line above the price indicates a downtrend.
- **Trailing Stop-Loss:** The indicator is exceptionally well-suited for use as a trailing stop-loss. In an uptrend, a trader might place their stop-loss just below the blue line. In a downtrend, the stop-loss could be placed just above the red line.
- **Trade Signals:** A change in the indicator's color can be interpreted as a trade signal. A flip from red to blue suggests a potential buy signal, while a flip from blue to red suggests a potential sell signal.
- **Caution:** Like all trend-following indicators, the Gann HiLo is most effective in trending markets. In sideways or ranging markets, it can produce frequent false signals ("whipsaws") as the price oscillates around the two moving averages.
