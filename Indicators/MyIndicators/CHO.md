# Chaikin Oscillator (CHO)

## 1. Summary (Introduction)

The Chaikin Oscillator (CHO) is a momentum indicator developed by Marc Chaikin. It is an "indicator of an indicator," as it is derived from the Accumulation/Distribution Line (ADL). The CHO measures the momentum of the ADL by comparing a fast and a slow exponential moving average (EMA) of the ADL.

Its primary purpose is to anticipate changes in the direction of the ADL, and by extension, to signal shifts in buying and selling pressure. It does not measure overbought or oversold levels but rather the momentum of money flow, making it a valuable tool for confirming trends and spotting divergences.

## 2. Mathematical Foundations and Calculation Logic

The Chaikin Oscillator is calculated by subtracting a slow EMA of the Accumulation/Distribution Line from a fast EMA of the ADL.

### Required Components

- **Accumulation/Distribution Line (ADL):** The underlying cumulative money flow indicator.
- **Fast EMA Period:** The period for the shorter-term EMA of the ADL (standard is 3).
- **Slow EMA Period:** The period for the longer-term EMA of the ADL (standard is 10).

### Calculation Steps (Algorithm)

1. **Calculate the Accumulation/Distribution Line (ADL):** First, the full ADL data series is calculated.

   - $\text{Money Flow Multiplier (MFM)} = \frac{(\text{Close} - \text{Low}) - (\text{High} - \text{Close})}{\text{High} - \text{Low}}$
   - $\text{Money Flow Volume (MFV)} = \text{MFM} \times \text{Volume}$
   - $\text{ADL}_i = \text{ADL}_{i-1} + \text{MFV}_i$

2. **Calculate the Fast and Slow EMAs of the ADL:** Compute two separate EMAs on the ADL data series calculated in the first step.
   $\text{FastEMA}_{\text{ADL}} = \text{EMA}(\text{ADL}, \text{Fast Period})$
   $\text{SlowEMA}_{\text{ADL}} = \text{EMA}(\text{ADL}, \text{Slow Period})$

3. **Calculate the Chaikin Oscillator:** Subtract the Slow EMA from the Fast EMA.
   $\text{CHO}_i = \text{FastEMA}_{\text{ADL}, i} - \text{SlowEMA}_{\text{ADL}, i}$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a self-contained, robust, and flexible representation of the Chaikin Oscillator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This ensures that the multi-stage calculation (Price -> ADL -> EMAs -> CHO) remains stable and accurate.

- **Self-Contained Logic:** The indicator is completely self-contained and does not use any external handles (like `iAD`). All calculations, including the underlying ADL and the subsequent moving averages, are performed manually within the `OnCalculate` function.

- **Flexible MA Types:** While the classic CHO uses EMAs, our "Pro" version allows the user to select from four different moving average types (**SMA, EMA, SMMA, LWMA**) via the `InpMaMethod` input parameter, providing greater flexibility.

- **Robust MA Calculations:** All moving average calculations are performed manually to ensure 100% accuracy and consistency within our `non-timeseries` model. Recursive MA types (EMA, SMMA) are carefully initialized with a manual Simple Moving Average (SMA) to prevent floating-point overflows.

- **Heikin Ashi Variant (`CHO_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but the underlying ADL is calculated from the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values.
  - This results in a significantly smoother oscillator that filters out price noise and can provide clearer signals regarding the momentum of the underlying Heikin Ashi trend.

## 4. Parameters

- **Fast Period (`InpFastPeriod`):** The period for the shorter-term MA of the ADL. Default is `3`.
- **Slow Period (`InpSlowPeriod`):** The period for the longer-term MA of the ADL. Default is `10`.
- **MA Method (`InpMaMethod`):** The type of moving average to use for the Fast and Slow MAs. Default is `MODE_EMA`.
- **Volume Type (`InpVolumeType`):** Allows the user to select between Tick Volume and Real Volume.

## 5. Usage and Interpretation

- **Zero Line Crossovers:** This is the most direct signal from the CHO.
  - **Bullish Crossover:** When the oscillator crosses above the zero line, it indicates that buying pressure (accumulation) is strengthening. This can be used to confirm an uptrend or a bullish reversal.
  - **Bearish Crossover:** When the oscillator crosses below the zero line, it indicates that selling pressure (distribution) is strengthening. This can confirm a downtrend or a bearish reversal.
- **Divergence:** This is the CHO's most powerful signal.
  - **Bullish Divergence:** Price makes a lower low, but the CHO makes a higher low. This suggests that selling pressure is waning despite the lower price, often foreshadowing a bottom.
  - **Bearish Divergénce:** Price makes a higher high, but the CHO makes a lower high. This suggests that the rally is not supported by strong buying pressure and may be nearing exhaustion.
- **Caution:** The Chaikin Oscillator is a momentum indicator, not a trend indicator. It should be used in conjunction with price action analysis or trend-following tools to confirm signals and avoid trading against the primary trend.
