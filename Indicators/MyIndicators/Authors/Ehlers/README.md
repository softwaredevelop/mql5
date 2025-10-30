# John Ehlers Indicator Collection

This folder contains a comprehensive collection of technical indicators developed or inspired by the work of John F. Ehlers. Ehlers, a pioneer in applying Digital Signal Processing (DSP) concepts to financial markets, created a suite of advanced, low-lag, and adaptive tools for modern traders.

Our implementations are designed to be **definition-true**, **robust**, and **modular**, following professional MQL5 coding standards. All indicators support both standard and Heikin Ashi data sources.

## Folder Structure

The indicators are organized into logical subfolders based on their primary function:

* `1_Smoothers`: Moving average-like indicators displayed on the main price chart.
* `2_Oscillators`: Indicators displayed in a separate window, typically used for momentum and cycle analysis.
* `3_Adaptive_MAs`: The most complex, self-adjusting moving averages.
* `4_Channels_and_Bands`: Volatility-based indicators that draw bands around the price.

## Indicator Quick Reference

The table below provides a quick summary of each indicator, its purpose, and its key features.

---

### 1. Smoothers (On-Chart Filters)

| Indicator | Primary Purpose | Key Feature / Why Use It? | Best For |
| :--- | :--- | :--- | :--- |
| **Butterworth Filter** | A high-fidelity moving average. | "Maximally flat" response provides superior smoothing. Excellent EMA/SMA replacement. | General Trend Analysis |
| **Ehlers Smoother** | A 2-in-1 advanced moving average. | Switch between **SuperSmoother** (max smoothing) and **UltimateSmoother** (zero-lag). | Versatile Trend Analysis |
| **Gaussian Filter** | A low-lag, 2-pole smoothing filter. | Excellent balance between responsiveness and smoothing. Similar to a DEMA. | Short to Mid-Term Trends |
| **Laguerre Filter** | A very low-lag, fast-reacting filter. | Uses Laguerre polynomials to closely track price with minimal delay. | Responsive Trend Following |
| **SMA Recursive** | A computationally efficient SMA. | Mathematically identical to a standard SMA, but faster to calculate. | Baseline Comparison |
| **Zero-Lag EMA** | A de-lagged Exponential Moving Average. | Reduces the inherent lag of a standard EMA, providing more timely signals. | Fast Trend Following |
| **Ehlers Filter Lab** | An experimental comparison tool. | Allows plotting two different smoothers in the same window for direct comparison. | Research & Strategy Dev |

### 2. Oscillators (Separate Window)

| Indicator | Primary Purpose | Key Feature / Why Use It? | Best For |
| :--- | :--- | :--- | :--- |
| **Band-Pass Filter** | Isolate a specific market cycle. | Removes trend and noise, showing only the "tradable" swings in a specific band. | Cycle Timing |
| **Band-Stop Filter** | Remove a specific market cycle. | Analytical tool to find the dominant cycle by "erasing" it from the price. | Cycle Analysis |
| **CG Oscillator** | A zero-lag timing oscillator. | Based on the "Center of Gravity" concept. Extremely fast crossover signals. | Precise Entry/Exit Timing |
| **Cyber Cycle** | Isolate the pure market cycle. | Advanced band-pass filter that shows the market's "rhythm." | Cycle Timing |
| **DMH** | A smoothed Directional Movement osc. | Ehlers' modern, single-line alternative to the classic ADX/DMI system. | Trend Direction & Momentum |
| **Fisher Transform** | Create sharp, predictive turning points. | Mathematically transforms price into a Gaussian distribution, creating sharp peaks. | Reversal Timing |
| **Inverse Fisher RSI** | A digital-like momentum "switch". | Compresses a smoothed RSI into a clear +1 (bull) or -1 (bear) state. | Regime/Momentum Filtering |
| **Laguerre RSI** | An extremely smooth RSI. | Uses a Laguerre filter to remove noise before the RSI calculation. | Clear Overbought/Oversold Signals |
| **Laguerre RSI Adaptive**| A self-adjusting Laguerre RSI. | Automatically adapts its smoothness based on the measured market cycle. | All-in-one Robust Oscillator |
| **MADH** | A "Thinking Man's MACD". | A MACD-like oscillator using superior Hann-windowed filters. | Momentum & Divergence Analysis |
| **Roofing Filter** | A pre-filter to "clean" price data. | Removes trend and noise. Designed to be used as a data source for other indicators. | Pre-processing for Oscillators |
| **RSIH** | A zero-mean, Hann-smoothed RSI. | Ehlers' improved RSI with a -1 to +1 scale and built-in smoothing. | Smoothed Momentum Analysis |
| **Stochastic Roofing** | A Stochastic on filtered data. | Calculates the Stochastic on the Roofing Filter's output, eliminating trend distortion. | Clearer Stochastic Signals |

### 3. Adaptive Moving Averages (On-Chart)

| Indicator | Primary Purpose | Key Feature / Why Use It? | Best For |
| :--- | :--- | :--- | :--- |
| **DSMA** | A volatility-adaptive moving average. | Speeds up in high volatility (trends) and slows down in low volatility (ranges). | All-in-one Trend/Range Filter |
| **FRAMA** | A fractal-adaptive moving average. | Adapts its speed based on the market's fractal dimension (roughness). | Identifying Trend vs. Range |
| **Laguerre Filter Adaptive**| A cycle-adaptive moving average. | Automatically adjusts its smoothing based on the measured dominant cycle period. | Advanced Trend Following |
| **MAMA / FAMA** | A phase-rate adaptive MA system. | The "Mother of Adaptive MAs." Extremely robust crossover system for major trends. | Major Trend Reversals |
| **MAMA MTF** | Multi-timeframe version of MAMA. | Projects the higher-timeframe MAMA/FAMA onto the current chart for a high-level view. | Top-Down Trend Analysis |

### 4. Channels and Bands (On-Chart)

| Indicator | Primary Purpose | Key Feature / Why Use It? | Best For |
| :--- | :--- | :--- | :--- |
| **Ehlers Bands** | A low-lag Bollinger Bands alternative. | Uses a SuperSmoother or UltimateSmoother as the centerline for faster, more responsive bands. | Volatility Analysis |
