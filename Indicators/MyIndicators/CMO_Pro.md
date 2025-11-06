# Chande Momentum Oscillator (CMO) Professional

## 1. Summary (Introduction)

The Chande Momentum Oscillator (CMO), developed by Tushar Chande, is a pure momentum indicator that measures the direction and strength of a trend. Unlike other oscillators like the RSI which can become "compressed" at their extremes, the CMO uses a distinct calculation that allows it to oscillate freely between -100 and +100.

It works by calculating the sum of all positive price changes and the sum of all negative price changes over a given period, and then expressing the difference as a percentage of the total movement.

* Values approaching **+100** indicate strong bullish momentum and potentially overbought conditions.
* Values approaching **-100** indicate strong bearish momentum and potentially oversold conditions.
* The **zero line** represents a point of equilibrium where bullish and bearish pressures are balanced.

Our `CMO_Pro` implementation is a professional, standalone version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The CMO's formula is direct and intuitive, focusing solely on the net momentum over a specified number of periods.

### Required Components

* **CMO Period (N):** The lookback period for the calculation (e.g., 14).
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Sum of Up and Down Moves:** For the last `N` periods, iterate through each bar and calculate the change from the previous bar.
    * $\text{Price Change}_i = P_i - P_{i-1}$
    * If $\text{Price Change}_i > 0$, add it to a running total, `Sum Up`.
    * If $\text{Price Change}_i < 0$, add its absolute value (`-Price Change_i`) to a running total, `Sum Down`.

2. **Calculate the CMO Value:** The final CMO value is calculated using the following formula, which normalizes the result to the -100 to +100 range.
    $\text{CMO}_i = 100 \times \frac{\text{Sum Up}_i - \text{Sum Down}_i}{\text{Sum Up}_i + \text{Sum Down}_i}$

## 3. MQL5 Implementation Details

Our MQL5 implementation is built on our standard, robust, and object-oriented framework.

* **Modular Calculator Engine (`CMO_Calculator.mqh`):**
    All core calculation logic is encapsulated within a dedicated and reusable include file. This engine was efficiently created by refactoring the validated CMO logic from our `VIDYA_Calculator`, ensuring consistency and code reusability across the indicator suite.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CCMOCalculator`, performs the full CMO calculation on a given source price.
  * A derived class, `CCMOCalculator_HA`, inherits all the logic and only overrides the `PreparePriceSeries` method to supply Heikin Ashi data as the input. This clean polymorphic approach eliminates code duplication.

* **Simplified Main Indicator (`CMO_Pro.mq5`):**
    The main `.mq5` file is a clean "wrapper" that handles user inputs, creates the appropriate calculator object (`standard` or `_HA`), and delegates the entire calculation with a single function call in `OnCalculate()`.

* **Stability via Full Recalculation:** The indicator performs a full recalculation on every tick. For a straightforward, non-recursive indicator like CMO, this ensures maximum stability and simplicity in the code.

## 4. Parameters (`CMO_Pro.mq5`)

* **CMO Period (`InpPeriodCMO`):** The lookback period for summing up and down price movements. A common value is `14`, but shorter periods (like `9`) will result in a more sensitive oscillator.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The CMO is a versatile tool for identifying momentum, overbought/oversold conditions, and potential trend reversals.

* **Overbought/Oversold Levels:**
  * **CMO > +50:** The market is considered overbought, and bullish momentum may be overextended. This can be an early warning of a potential bearish reversal or consolidation.
  * **CMO < -50:** The market is considered oversold, and bearish momentum may be exhausted. This can signal a potential bullish reversal or bounce.

* **Zero Line Crossover:**
  * A crossover **above the zero line** indicates that bullish momentum is now stronger than bearish momentum, confirming an uptrend.
  * A crossover **below the zero line** indicates that bearish momentum has taken control, confirming a downtrend.
  * The zero line can act as a filter; for example, only taking long trades when CMO is above 0.

* **Divergence:**
  * **Bearish Divergence:** Occurs when the price makes a new high, but the CMO fails to make a new high. This suggests that the momentum behind the uptrend is weakening and a reversal may be near.
  * **Bullish Divergence:** Occurs when the price makes a new low, but the CMO makes a higher low. This indicates that bearish momentum is fading and a bottom may be forming.
