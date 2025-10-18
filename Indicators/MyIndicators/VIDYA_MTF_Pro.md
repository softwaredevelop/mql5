# Variable Index Dynamic Average (VIDYA) MTF Professional

## 1. Summary (Introduction)

The Variable Index Dynamic Average (VIDYA) MTF Pro is a multi-timeframe (MTF) version of the classic adaptive moving average developed by Tushar Chande. This indicator calculates the VIDYA on a **higher, user-selected timeframe** and projects it onto the current, lower-timeframe chart.

This allows traders to visualize the underlying trend from a broader perspective, using the higher-timeframe VIDYA as a dynamic benchmark for support, resistance, and overall market direction, all without leaving their primary trading chart.

The indicator is highly versatile: if the user selects the current chart's timeframe, it functions identically to the standard `VIDYA_Pro` indicator. It also fully supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard VIDYA. It is a modified Exponential Moving Average where the smoothing factor is multiplied by the absolute value of the Chande Momentum Oscillator (CMO).

### Required Components

* **EMA Period (N):** The base period for the EMA smoothing calculation.
* **CMO Period (M):** The lookback period for the Chande Momentum Oscillator.
* **Source Price (P):** The price series from the **higher timeframe** used for the calculation.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator first retrieves the OHLC price data for the user-selected higher timeframe.
2. **Calculate the Chande Momentum Oscillator (CMO):** The CMO is calculated on the higher timeframe's price data over a period `M`.
    $\text{CMO}_{htf} = \frac{\text{Sum Up}_{htf} - \text{Sum Down}_{htf}}{\text{Sum Up}_{htf} + \text{Sum Down}_{htf}}$
3. **Calculate the VIDYA on the Higher Timeframe:** The VIDYA is calculated recursively using the higher timeframe data.
    * $\alpha = \frac{2}{N + 1}$
    * $\text{VIDYA}_{htf_i} = (P_{htf_i} \times \alpha \times \text{Abs}(\text{CMO}_{htf_i})) + (\text{VIDYA}_{htf_{i-1}} \times (1 - \alpha \times \text{Abs}(\text{CMO}_{htf_i})))$
4. **Project to Current Chart:** The calculated higher-timeframe VIDYA values are then mapped to the current chart, creating a "step-like" line where each value from the higher timeframe is held constant for the duration of its corresponding bars on the lower timeframe.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data using built-in `Copy...` functions for maximum stability.

* **Modular Calculation Engine (`VIDYA_Calculator.mqh`):** The indicator reuses the exact same, proven calculation engine as the standard `VIDYA_Pro`. This ensures mathematical consistency and leverages our modular design principles.

* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the full MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `VIDYA_Pro`, calculating directly on the current chart's data for maximum efficiency.

* **Stability via Full Recalculation:** We employ a full recalculation for both modes, which is the most reliable method for a recursive indicator like VIDYA.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the VIDYA will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **CMO Period (`InpPeriodCMO`):** The lookback period for the Chande Momentum Oscillator. Default is `9`.
* **EMA Period (`InpPeriodEMA`):** The base period for the EMA smoothing. Default is `12`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The MTF version of VIDYA opens up new strategic possibilities beyond simple trend following.

* **Dynamic Support and Resistance:** The primary use of the MTF VIDYA is as a dynamic, high-level area of support and resistance. When the price on the lower timeframe pulls back to the higher-timeframe VIDYA line, it can present a high-probability entry point in the direction of the larger trend.
* **Major Trend Filter:** The slope and position of the MTF VIDYA line provide a clear, smoothed-out view of the dominant trend.
  * If the price is consistently above a rising MTF VIDYA, the market is in a strong uptrend. Traders should focus on buying opportunities.
  * If the price is consistently below a falling MTF VIDYA, the market is in a strong downtrend. Traders should focus on selling opportunities.
* **Confirmation of Breakouts:** A breakout on the lower timeframe that is also supported by the direction of the MTF VIDYA line is a much stronger signal.
* **Range Detection:** A flat MTF VIDYA line indicates that the higher timeframe is consolidating, signaling that range-bound strategies might be more appropriate on the lower timeframe.
