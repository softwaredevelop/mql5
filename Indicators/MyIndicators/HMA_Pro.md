# Hull Moving Average (HMA) Pro

## 1. Summary (Introduction)

The Hull Moving Average (HMA), developed by Alan Hull, is designed to be both extremely responsive to current price activity and simultaneously smooth. It addresses the common trade-off between smoothness and lag in traditional moving averages.

The HMA uses a unique calculation involving multiple weighted moving averages (WMAs) to nearly eliminate lag.

Our `HMA_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The HMA's formula combines three separate Weighted Moving Averages (WMAs) to nearly eliminate lag and improve smoothness.

### Required Components

* **HMA Period (N):** The main lookback period for the indicator.
* **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

1. **Calculate a WMA with period (N/2):** First, calculate a WMA with a period of half the main HMA period, rounded to the nearest integer.
    $\text{WMA}_{\text{half}} = \text{WMA}(P, \text{integer}(\frac{N}{2}))$

2. **Calculate a WMA with period (N):** Second, calculate a WMA with the full HMA period.
    $\text{WMA}_{\text{full}} = \text{WMA}(P, N)$

3. **Calculate the Raw HMA:** Create a new, un-smoothed "raw" HMA series by taking two times the half-period WMA and subtracting the full-period WMA. This step significantly reduces lag.
    $\text{Raw HMA}_i = (2 \times \text{WMA}_{\text{half}, i}) - \text{WMA}_{\text{full}, i}$

4. **Calculate the Final HMA:** Smooth the `Raw HMA` series with another WMA, this time using a period equal to the square root of the main HMA period, rounded to the nearest integer. This final step reintroduces smoothness.
    $\text{Final HMA}_i = \text{WMA}(\text{Raw HMA}, \text{integer}(\sqrt{N}))_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability. The logic is separated into a main indicator file and a dedicated calculator engine.

* **Modular Calculator Engine (`HMA_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CHMACalculator`**: The base class that performs the full, multi-stage HMA calculation on a given source price.
  * **`CHMACalculator_HA`**: A child class that inherits from the base class and overrides only the data preparation step. Its sole responsibility is to use Heikin Ashi prices as the input for the base class's shared calculation algorithm. This object-oriented approach eliminates code duplication.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal buffers (like `m_price` and `m_raw_hma`) persist their state between ticks. This allows the multi-stage WMA calculation to continue seamlessly from the last known value without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Fully Manual WMA Calculation:** To guarantee 100% accuracy and consistency, the Weighted Moving Average calculation is implemented **manually** within a helper function inside the calculator engine. This provides full control over the calculation logic.

## 4. Parameters

* **HMA Period (`InpPeriodHMA`):** The main lookback period for the indicator. This single parameter controls all three internal WMA calculations. Default is `14`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard price types (e.g., `PRICE_CLOSE_STD`) and all Heikin Ashi price types (e.g., `PRICE_HA_CLOSE`). Default is `PRICE_CLOSE_STD`.

## 5. Usage and Interpretation

* **Trend Identification:** The HMA is primarily used as a fast and smooth trend line. When the price is above the HMA and the HMA is rising, the trend is considered bullish. When the price is below the HMA and the HMA is falling, the trend is considered bearish.
* **Crossover Signals:** Crossovers of the price and the HMA line can be used as trade signals. Due to its responsiveness, these signals occur with less lag than with traditional moving averages.
* **Trend Direction Filter:** The slope of the HMA itself can be used as a trend filter. A simple rule could be to only consider long trades when the HMA is rising and short trades when it is falling.
* **Caution:** While the HMA is very responsive, it is still a lagging indicator. Its primary strength is in trending markets. In sideways or choppy markets, it can still produce false signals.
