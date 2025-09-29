# Accumulation/Distribution (A/D) Professional

## 1. Summary (Introduction)

The Accumulation/Distribution Line (A/D Line or ADL) is a volume-based indicator developed by Marc Chaikin. It was designed to measure the cumulative flow of money into and out of a security. The ADL attempts to identify whether traders are primarily "accumulating" (buying) or "distributing" (selling) an asset by analyzing the relationship between the closing price and its trading range, weighted by volume.

It is a cumulative, running total. A rising ADL suggests that buying pressure is dominant, while a falling ADL suggests that selling pressure is dominant. Our `AD_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** candles.

## 2. Mathematical Foundations and Calculation Logic

The ADL is calculated by first determining the "Money Flow Multiplier" for each period and then using it to weight the volume.

### Required Components

* **Price Data:** The `High`, `Low`, and `Close` of each bar.
* **Volume Data:** The volume for each bar.

### Calculation Steps (Algorithm)

1. **Calculate the Money Flow Multiplier (MFM):** This value determines the proportion of the volume that was bullish or bearish. It ranges from +1 (if Close = High) to -1 (if Close = Low).
    $\text{MFM} = \frac{(\text{Close} - \text{Low}) - (\text{High} - \text{Close})}{\text{High} - \text{Low}}$
    *(Note: If High equals Low, the MFM is 0).*

2. **Calculate the Money Flow Volume (MFV):** Multiply the MFM by the volume for the period.
    $\text{MFV}_i = \text{MFM}_i \times \text{Volume}_i$

3. **Calculate the Accumulation/Distribution Line (ADL):** The ADL is the cumulative sum of the Money Flow Volume.
    $\text{ADL}_i = \text{ADL}_{i-1} + \text{MFV}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design pattern to ensure stability, reusability, and maintainability. The logic is separated into a main indicator file and a dedicated calculator engine.

* **Modular Calculator Engine (`AD_Calculator.mqh`):**
    All core calculation logic is encapsulated within a reusable include file. This separates the mathematical complexity from the indicator's user interface and buffer management.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CADCalculator`, handles the core A/D algorithm. It is designed to work with any set of High, Low, and Close data it receives.
  * A derived class, `CADCalculator_HA`, inherits from the base class and **overrides** only one specific function: the candle data preparation. Its sole responsibility is to calculate Heikin Ashi candles and provide the resulting HA High, Low, and Close values to the base class's A/D algorithm. This is a clean and efficient use of polymorphism.

* **Simplified Main Indicator (`AD_Pro.mq5`):**
    The main indicator file is now extremely clean. Its primary roles are:
    1. Handling user inputs (`input` variables).
    2. Instantiating the correct calculator object (`CADCalculator` or `CADCalculator_HA`) in `OnInit()` based on the user's choice.
    3. Delegating the entire calculation process to the calculator object with a single call in `OnCalculate()`.

* **Stability via Full Recalculation:** We use a full recalculation on every tick. For a cumulative, recursive indicator like the ADL, this "brute-force" approach is the most robust method, eliminating potential errors from `prev_calculated` logic during history loading or timeframe changes.

## 4. Parameters (`AD_Pro.mq5`)

* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation.
  * `CANDLE_STANDARD`: Uses the standard chart's OHLC data.
  * `CANDLE_HEIKIN_ASHI`: Uses smoothed Heikin Ashi data for the calculation.
* **Volume Type (`InpVolumeType`):** Allows the user to select between Tick Volume (`VOLUME_TICK`) and Real Volume (`VOLUME_REAL`) for the calculation.

## 5. Usage and Interpretation

The absolute value of the ADL is not important; its **slope and direction** are what matter.

* **Trend Confirmation:**
  * If both the price and the ADL are making higher highs and higher lows, the uptrend is considered strong and likely to continue.
  * If both the price and the ADL are making lower highs and lower lows, the downtrend is considered strong.
* **Divergence:** This is the most powerful signal from the ADL.
  * **Bullish Divergence:** The price continues to fall and makes a new low, but the ADL fails to make a new low and starts to rise. This suggests that accumulation (buying) is taking place despite the lower prices, which can foreshadow a bullish reversal.
  * **Bearish Divergence:** The price continues to rise and makes a new high, but the ADL fails to make a new high and starts to fall. This suggests that distribution (selling) is occurring on the rally, which can be an early warning of a bearish reversal.
* **Caution:** The ADL does not account for price gaps between periods. A significant gap down will not be reflected in the ADL's calculation, which can sometimes lead to a discrepancy between price and the indicator. It is best used for confirmation alongside other price-based indicators.
