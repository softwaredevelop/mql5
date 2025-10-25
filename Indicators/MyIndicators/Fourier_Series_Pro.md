# Fourier Series Pro

## 1. Summary (Introduction)

The Fourier Series indicator, developed by John Ehlers, is an advanced analytical tool based on the principle that any complex market waveform can be represented as a sum of simple sine waves. This indicator attempts to model the market's price action by isolating and then recombining its most dominant cyclical components.

Instead of trying to analyze the noisy, raw price data, the indicator deconstructs it into three key harmonics using band-pass filters, measures their relative power, and then synthesizes them back into a single, smooth waveform.

The indicator plots two lines, forming a complete system for cycle analysis and timing:

* **Wave (red line):** The synthesized, smooth waveform that models the market's primary cyclical activity. Its amplitude reveals the market state (high amplitude = trending/cycling, low amplitude = consolidating).
* **ROC (blue line):** The Rate of Change of the `Wave` line. Its zero-crosses precisely identify the peaks and troughs of the synthesized `Wave`, providing clear timing signals.

## 2. Mathematical Foundations and Calculation Logic

The indicator's logic is a multi-stage process of decomposition, analysis, and synthesis based on Fourier theory.

### Required Components

* **Fundamental Period (N):** The primary, user-defined cycle period that the indicator will be tuned to.
* **Bandwidth (B):** A parameter that controls the selectivity of the internal filters.
* **Source Price (P):** The price series for the calculation (Ehlers' original work uses the Median Price `(H+L)/2`).

### Calculation Steps (Algorithm)

1. **Decomposition (Band-Pass Filtering):** The source price is passed through three separate, narrow band-pass filters to isolate three distinct cyclical components:
    * `BP1`: The fundamental cycle with period `N`.
    * `BP2`: The second harmonic (period `N/2`).
    * `BP3`: The third harmonic (period `N/3`).
2. **Quadrature Calculation:** For each of the three band-pass outputs, a "quadrature" component (`Q1, Q2, Q3`) is calculated. This is essentially the derivative of the filter's output, representing the 90-degree phase-shifted component of the cycle.
3. **Power Measurement:** The indicator calculates the "power" (`P1, P2, P3`) of each of the three harmonics by summing the squares of their in-phase (`BP`) and quadrature (`Q`) components over the `N` period lookback window.
4. **Synthesis (Wave Creation):** The final `Wave` is created by summing the three band-pass components, with the second and third harmonics being weighted by their power relative to the fundamental harmonic.
    $\text{Wave} = \text{BP1} + \sqrt{\frac{P2}{P1}} \times \text{BP2} + \sqrt{\frac{P3}{P1}} \times \text{BP3}$
5. **Rate of Change (ROC):** An optional ROC line is calculated on the `Wave` to pinpoint its turning points.

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`Fourier_Series_Calculator.mqh`):** The entire complex, multi-stage calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Computationally Intensive:** Due to the multiple recursive filters and the internal loop required for power calculation, this is a more CPU-intensive indicator than a simple moving average.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure the multiple state-dependent calculations remain perfectly synchronized and stable.

## 4. Parameters

* **Fundamental Period (`InpFundamentalPeriod`):** The primary cycle period (`N`) the indicator is tuned to. Finding the correct period for the instrument and timeframe is key to the indicator's effectiveness. Ehlers' default is **20** for daily data.
* **Bandwidth (`InpBandwidth`):** Controls the selectivity of the internal band-pass filters. Ehlers' default is **0.1**. Lower values create a smoother but slower-reacting output, while higher values are faster but allow more noise.
* **Show ROC (`InpShowROC`):** Toggles the visibility of the blue ROC timing line.
* **Source (`InpSource`):** Selects between `Standard` and `Heikin Ashi` candles.

## 5. Usage and Interpretation

The Fourier Series indicator is a complete system for identifying the market's state and timing entries based on its cyclical behavior.

**1. Identify the Market State with the `Wave` (Red Line)**

The amplitude and behavior of the red `Wave` line tell you what the market is doing.

* **Trending/Cycling Market:** The `Wave` line shows large, clear swings away from the zero line. This indicates that strong, measurable cycles are present, and trading signals are likely to be reliable.
* **Consolidating/Choppy Market:** The `Wave` line has a **low amplitude** and oscillates tightly around the zero line. This is a clear signal that no dominant cycle is present, and it is best to **avoid taking signals**.

**2. Time Entries with the `ROC` (Blue Line)**

The blue `ROC` line is the primary timing trigger. Its zero-crosses pinpoint the exact peaks and troughs of the `Wave`.

* **Buy Signal:** The **blue ROC line crosses above the zero line**. This marks the bottom of a `Wave` cycle and signals a potential upward move.
* **Sell Signal:** The **blue ROC line crosses below the zero line**. This marks the top of a `Wave` cycle and signals a potential downward move.

**Combined Strategy:**

1. **Filter:** Only consider taking trades when the red `Wave` line is showing clear, high-amplitude swings. Stay out of the market when it is flat.
2. **Direction:** Use a longer-term trend indicator (like a 200-period EMA or a long-period SuperSmoother) to determine the primary trend direction.
3. **Entry:** In an uptrend, only take the **Buy signals** from the ROC line (crosses above zero). In a downtrend, only take the **Sell signals** (crosses below zero). This uses the Fourier Series indicator to time pullbacks and entries in the direction of the main trend.
