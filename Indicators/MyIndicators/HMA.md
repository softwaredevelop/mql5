# Hull Moving Average (HMA)

## 1. Summary (Introduction)

The Hull Moving Average (HMA) was developed by Alan Hull in 2005. Its primary goal is to create a moving average that is both extremely responsive to current price activity and simultaneously smooths out price data effectively. Traditional moving averages often present a trade-off between smoothness and lag; a smoother average lags more, while a faster average is more prone to "whipsaws" or noise.

The HMA aims to solve this problem by using a unique calculation involving multiple weighted moving averages (WMAs), resulting in a line that closely follows the price while maintaining a high degree of smoothness.

## 2. Mathematical Foundations and Calculation Logic

The HMA's formula cleverly combines three separate Weighted Moving Averages (WMAs) to nearly eliminate lag and improve smoothness.

### Required Components

- **HMA Period (N):** The main lookback period for the indicator.
- **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

1. **Calculate a WMA with period (N/2):** First, calculate a WMA with a period of half the main HMA period, rounded to the nearest integer.
   $\text{WMA}_{\text{half}} = \text{WMA}(P, \text{integer}(\frac{N}{2}))$

2. **Calculate a WMA with period (N):** Second, calculate a WMA with the full HMA period.
   $\text{WMA}_{\text{full}} = \text{WMA}(P, N)$

3. **Calculate the Raw HMA:** Create a new, un-smoothed "raw" HMA series by taking two times the half-period WMA and subtracting the full-period WMA. This step significantly reduces lag.
   $\text{Raw HMA}_i = (2 \times \text{WMA}_{\text{half}, i}) - \text{WMA}_{\text{full}, i}$

4. **Calculate the Final HMA:** Smooth the `Raw HMA` series with another WMA, this time using a period equal to the square root of the main HMA period, rounded to the nearest integer. This final step reintroduces smoothness to the fast-moving raw line.
   $\text{Final HMA}_i = \text{WMA}(\text{Raw HMA}, \text{integer}(\sqrt{N}))_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation was refactored to be a completely self-contained, robust, and accurate indicator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This is our standard practice to ensure maximum stability and prevent calculation errors during timeframe changes or history loading.

- **Fully Manual WMA Calculation:** To guarantee 100% accuracy and consistency within our `non-timeseries` calculation model, we have implemented the Weighted Moving Average calculation **manually**. The indicator does **not** use the `<MovingAverages.mqh>` standard library. This approach avoids any potential inconsistencies that might arise from using library functions on `non-timeseries` arrays and gives us full control over the calculation logic.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps:

  1. **Step 1 (Price Preparation):** A single source price array (`price_source[]`) is prepared based on the user's `InpAppliedPrice` selection, including all standard and calculated price types (e.g., `PRICE_TYPICAL`).
  2. **Step 2 (Base WMAs & Raw HMA):** The first `for` loop calculates the two base WMAs (half-period and full-period) and the resulting `Raw HMA`, storing them in their respective calculation buffers.
  3. **Step 3 (Final HMA):** A second `for` loop performs the final smoothing step, calculating a WMA on the `Raw HMA` buffer to produce the final, plotted HMA line.

- **Heikin Ashi Variant (`HMA_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi price data (e.g., `ha_close`) as its input.
  - This results in an exceptionally smooth trend line, combining the advanced smoothing of the HMA formula with the noise-filtering properties of Heikin Ashi candles.

## 4. Parameters

- **HMA Period (`InpPeriodHMA`):** The main lookback period for the indicator. This single parameter controls all three internal WMA calculations. Default is `14`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation (e.g., `PRICE_CLOSE`).

## 5. Usage and Interpretation

- **Trend Identification:** The HMA is primarily used as a fast and smooth trend line. When the price is above the HMA and the HMA is rising, the trend is considered bullish. When the price is below the HMA and the HMA is falling, the trend is considered bearish.
- **Crossover Signals:** Crossovers of the price and the HMA line can be used as trade signals. Due to its responsiveness, these signals occur with less lag than with traditional moving averages.
- **Trend Direction Filter:** The slope of the HMA itself can be used as a trend filter. A simple rule could be to only consider long trades when the HMA is rising and short trades when it is falling.
- **Caution:** While the HMA is very responsive, it is still a lagging indicator. Its primary strength is in trending markets. In sideways or choppy markets, it can still produce false signals.
