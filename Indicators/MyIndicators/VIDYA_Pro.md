# Variable Index Dynamic Average (VIDYA) Professional

## 1. Summary (Introduction)

The Variable Index Dynamic Average (VIDYA), developed by Tushar Chande, is an adaptive moving average that automatically adjusts its speed based on market momentum. It uses the Chande Momentum Oscillator (CMO) to dynamically alter its smoothing factor. When momentum is high, VIDYA speeds up; when momentum wanes, it slows down.

Our `VIDYA_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

VIDYA is a modified Exponential Moving Average where the smoothing factor is multiplied by the absolute value of the Chande Momentum Oscillator (CMO).

### Required Components

* **EMA Period (N):** The base period for the EMA smoothing calculation.
* **CMO Period (M):** The lookback period for the Chande Momentum Oscillator.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Chande Momentum Oscillator (CMO):** The CMO measures momentum over a period `M`.
    $\text{CMO}_i = \frac{\text{Sum Up}_i - \text{Sum Down}_i}{\text{Sum Up}_i + \text{Sum Down}_i}$
2. **Calculate the VIDYA:** The VIDYA is calculated recursively.
    * First, define the standard EMA smoothing factor, `alpha`:
        $\alpha = \frac{2}{N + 1}$
    * Then, calculate the VIDYA for each bar:
        $\text{VIDYA}_i = (P_i \times \alpha \times \text{Abs}(\text{CMO}_i)) + (\text{VIDYA}_{i-1} \times (1 - \alpha \times \text{Abs}(\text{CMO}_i)))$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`VIDYA_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CVIDYACalculator`**: The base class that performs the full VIDYA calculation on a given source price.
  * **`CVIDYACalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate`. For a recursive indicator like VIDYA, this is the most reliable method.

* **Robust Initialization:** The recursive VIDYA calculation is carefully initialized with a manual Simple Moving Average (SMA) to provide a stable starting point.

## 4. Parameters

* **CMO Period (`InpPeriodCMO`):** The lookback period for the Chande Momentum Oscillator. Default is `9`.
* **EMA Period (`InpPeriodEMA`):** The base period for the EMA smoothing. Default is `12`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

* **Trend Identification:** VIDYA is used as an adaptive trend line. When the price is above the VIDYA and the line is rising, the trend is bullish.
* **Crossover Signals:** Crossovers of the price and the VIDYA line can be used as trade signals.
* **Trend Filter:** The key advantage of VIDYA is its ability to flatten out during periods of low momentum. A flat VIDYA line is a clear signal to avoid trend-following strategies.
* **Caution:** While adaptive, VIDYA is still a lagging indicator. It is a tool for trend confirmation and filtering, not for precise market timing.
