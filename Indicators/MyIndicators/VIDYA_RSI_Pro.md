# VIDYA RSI Professional

## 1. Summary (Introduction)

The `VIDYA_RSI_Pro` is an adaptive moving average that uses the Relative Strength Index (RSI) to dynamically adjust its speed. This version of the Variable Index Dynamic Average (VIDYA) is a popular alternative to Tushar Chande's original, which was based on the Chande Momentum Oscillator (CMO).

The core concept is to measure market volatility or trend strength by observing the RSI's distance from its central equilibrium point (50).

* When the RSI moves towards its extremes (0 or 100), it indicates strong momentum, causing the VIDYA to "speed up" and follow prices more closely.
* When the RSI hovers around the 50 level, it indicates a lack of momentum or a consolidating market, causing the VIDYA to "slow down" and flatten out.

Our `VIDYA_RSI_Pro` implementation is a professional version that supports calculations based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

VIDYA RSI is a modified Exponential Moving Average where the smoothing factor is multiplied by a volatility factor derived from the RSI.

### Required Components

* **RSI Period (N):** The lookback period for the RSI calculation.
* **EMA Period (M):** The base period for the EMA smoothing calculation.
* **Source Price (P):** The price series for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Relative Strength Index (RSI):** First, a standard Wilder's RSI is calculated over the period `N`, resulting in a value between 0 and 100.

2. **Create the RSI Volatility Factor:** The RSI's momentum strength is measured by its distance from the 50 centerline. This value is then normalized to a 0-1 range to be used as a multiplier.
    $\text{RSI Volatility Factor}_i = \frac{\text{Abs}(\text{RSI}_i - 50)}{50}$

3. **Calculate the VIDYA:** The VIDYA is calculated recursively using the standard EMA formula, but with the smoothing factor `alpha` dynamically adjusted by the `RSI Volatility Factor`.
    * $\alpha = \frac{2}{M + 1}$
    * $\text{VIDYA}_i = (P_i \times \alpha \times \text{RSI Volatility Factor}_i) + (\text{VIDYA}_{i-1} \times (1 - \alpha \times \text{RSI Volatility Factor}_i))$

## 3. MQL5 Implementation Details

* **Modular Calculation Engine (`VIDYA_RSI_Calculator.mqh`):** All mathematical logic is encapsulated in a dedicated include file. The engine first calculates the base RSI using the robust Wilder's smoothing method and then applies the adaptive VIDYA formula.

* **Object-Oriented Design (Inheritance):** A `CVIDYARSICalculator` base class and a `CVIDYARSICalculator_HA` derived class are used to cleanly separate the logic for standard and Heikin Ashi price sources without code duplication.

* **Simplified Main Indicator (`VIDYA_RSI_Pro.mq5`):** The main `.mq5` file acts as a clean "wrapper" responsible for handling user inputs, creating the correct calculator object, and delegating the calculation.

## 4. Parameters (`VIDYA_RSI_Pro.mq5`)

* **RSI Period (`InpPeriodRSI`):** The lookback period for the underlying RSI calculation. Default is `14`.
* **EMA Period (`InpPeriodEMA`):** The base period for the EMA smoothing. Default is `20`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation (Standard or Heikin Ashi).

## 5. Usage and Interpretation

* **Adaptive Trend Line:** Use it as a more intelligent, responsive trend line. It hugs the price during strong trends and flattens out during consolidation, helping to reduce whipsaws.
* **Trend Filter:** A flat or sideways VIDYA line is a strong indication of a ranging market, suggesting that trend-following strategies should be paused.
* **Dynamic Support/Resistance:** In a trending market, the VIDYA line can act as a dynamic level of support (in an uptrend) or resistance (in a downtrend).
