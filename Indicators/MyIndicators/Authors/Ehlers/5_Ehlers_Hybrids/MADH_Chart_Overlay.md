# MADH Chart Overlay

## 1. Summary

The **MADH Chart Overlay** is a visual companion tool for the `MADH_Pro` oscillator. While the oscillator shows the *difference* between two moving averages in a separate window, this indicator plots the actual **Hann-Windowed Moving Averages (HWMAs)** directly on the price chart.

It allows traders to visualize the "Thinking Man's" moving averages that drive the MADH signals, providing context on trend direction and the separation between the fast and slow trends.

## 2. Relation to MADH Oscillator

This indicator uses the **exact same calculation engine** (`Windowed_MA_Calculator.mqh`) and logic as the `MADH_Pro` oscillator.

* **Gold Line (Fast HWMA):** Corresponds to the `Filt1` component of the MADH.
* **Red Line (Slow HWMA):** Corresponds to the `Filt2` component of the MADH.

**Visual Correspondence:**

* When the **Gold line crosses above the Red line**, the MADH Oscillator crosses **above zero**.
* When the **Gold line crosses below the Red line**, the MADH Oscillator crosses **below zero**.
* The vertical distance between the two lines represents the magnitude of the MADH histogram.

## 3. Parameters

To ensure the overlay matches your oscillator, you must use identical settings:

* **Short Length (`InpShortLength`):** Period of the Gold line.
* **Dominant Cycle (`InpDominantCycle`):** Used to calculate the period of the Red line.
  * *Formula:* $\text{Slow Period} = \text{Short Length} + \text{round}(\frac{\text{Dominant Cycle}}{2})$

## 4. Usage

* **Trend Visualization:** The slope and separation of the two lines give an immediate visual cue about trend strength. Widening lines indicate accelerating momentum.
* **Dynamic Support/Resistance:** The Hann-Windowed MAs are extremely smooth and often act as dynamic support (in uptrends) or resistance (in downtrends).
* **Crossover Signals:** Use the crossover of the Gold and Red lines as a visual confirmation of the trend change signaled by the oscillator.
