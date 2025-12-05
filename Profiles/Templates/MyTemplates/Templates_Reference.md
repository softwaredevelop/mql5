# Chart Templates Reference

This document provides a detailed breakdown of the available chart templates in the `MyTemplates` folder. Use this reference to select the right workspace for your trading session and strategy.

## 1. Scalping Strategies (`scalp.*`)

Designed for short-term, intraday trading (M1, M5, M15). Focus on session timing, VWAP, and momentum oscillators.

### VWAP & Momentum System (`scalp.std.vwap.*` & `scalp.ha.vwap.*`)

This system is available in both **Standard (`std`)** and **Heikin Ashi (`ha`)** variants. The indicators are identical, but the base chart visualization differs.

#### `scalp.*.vwap.tlx_win.full.tpl`

* **Session:** TLX Winter (Tokyo, London, Xetra)
* **Description:** Lightweight setup focusing purely on session structure and momentum oscillators.
* **Indicators:**
  * `Session_Analysis_Pro`
  * `StochRSI_Slow_Pro` (13,13)
  * `SMI_Pro` (13,3,3)

#### `scalp.*.vwap.lxn.full.tpl`

* **Session:** LXN (London, Xetra, NY)
* **Description:** Same as above, configured for Western sessions.
* **Indicators:**
  * `Session_Analysis_Pro`
  * `StochRSI_Slow_Pro` (13,13)
  * `SMI_Pro` (13,3,3)

#### `scalp.*.vwap.tlx_win.full_v1.tpl`

* **Session:** TLX Winter
* **Description:** Enhanced suite adding institutional levels (VWAP) and structural pivots (Murrey Math) for precision entries.
* **Indicators:**
  * `Session_Analysis_Pro`
  * `VWAP_Pro`
  * `Murrey_Math_Line_X`
  * `StochRSI_Slow_Pro`
  * `SMI_Pro`

#### `scalp.*.vwap.lxn.full_v1.tpl`

* **Session:** LXN
* **Description:** Enhanced suite for Western sessions.
* **Indicators:**
  * `Session_Analysis_Pro`
  * `VWAP_Pro`
  * `Murrey_Math_Line_X`
  * `StochRSI_Slow_Pro`
  * `SMI_Pro`

#### `scalp.*.vwap.tlx_win.full_v2.tpl`

* **Session:** TLX Winter
* **Description:** **Maximum Suite.** Adds `ADX Pro` to filter out weak trends and confirm momentum strength. Ideal for filtering false breakouts.
* **Indicators:**
  * `Session_Analysis_Pro`
  * `VWAP_Pro`
  * `Murrey_Math_Line_X`
  * `StochRSI_Slow_Pro`
  * `SMI_Pro`
  * `ADX_Pro` (13)

#### `scalp.*.vwap.lxn.full_v2.tpl`

* **Session:** LXN
* **Description:** Maximum suite for Western sessions.
* **Indicators:**
  * `Session_Analysis_Pro`
  * `VWAP_Pro`
  * `Murrey_Math_Line_X`
  * `StochRSI_Slow_Pro`
  * `SMI_Pro`
  * `ADX_Pro` (13)

## 2. Trend Following Strategies (`trend.*`)

Designed for swing trading and capturing larger moves (H1, H4). These templates focus on trend identification, pullback entries, and momentum confirmation.

### Laguerre Trend Suite (`trend.std.laguerre.*` & `trend.ha.laguerre.*`)

This suite leverages the low-lag properties of John Ehlers' Laguerre filters to identify trends earlier than traditional moving averages. Available in both **Standard (`std`)** and **Heikin Ashi (`ha`)** variants.

#### `trend.*.laguerre.suite.tpl`

* **Session:** Generic (No Session Analysis)
* **Description:** **Core Trend System.** Uses three Laguerre filters (Fast, Medium, Slow) to define the trend structure, supported by Laguerre-based momentum oscillators.
* **Indicators:**
  * `Laguerre_Filter_Pro` (0.20 - Fast)
  * `Laguerre_Filter_Pro` (0.50 - Medium)
  * `Laguerre_Filter_Pro` (0.80 - Slow)
  * `MACD_Laguerre_Pro`
  * `Laguerre_RSI_Pro` (0.50)

#### `trend.*.laguerre.lxn.suite_v1.tpl`

* **Session:** LXN (London, Xetra, NY)
* **Description:** **Enhanced Suite.** Adds structural context with Murrey Math lines and Session Analysis boxes to identify key support/resistance levels and session breakouts.
* **Indicators:**
  * `Laguerre_Filter_Pro` (x3: 0.2, 0.5, 0.8)
  * `MACD_Laguerre_Pro`
  * `Laguerre_RSI_Pro`
  * `Murrey_Math_Line_X`
  * `Session_Analysis_Pro` (LXN)

#### `trend.*.laguerre.tlx_win.suite_v1.tpl`

* **Session:** TLX Winter (Tokyo, London, Xetra)
* **Description:** Same as above, configured for Asian/European sessions.
* **Indicators:**
  * (Same as LXN suite_v1)

#### `trend.*.laguerre.lxn.suite_v2.tpl`

* **Session:** LXN
* **Description:** **Maximum Suite.** Adds `ADX Pro` to filter out ranging markets and confirm trend strength before entering.
* **Indicators:**
  * `Laguerre_Filter_Pro` (x3)
  * `MACD_Laguerre_Pro`
  * `Laguerre_RSI_Pro`
  * `Murrey_Math_Line_X`
  * `Session_Analysis_Pro`
  * `ADX_Pro` (13)

#### `trend.*.laguerre.tlx_win.suite_v2.tpl`

* **Session:** TLX Winter
* **Description:** Maximum suite for Asian/European sessions.
* **Indicators:**
  * (Same as LXN suite_v2)

### SuperSmoother MACD System (`trend.*.supersmoother.*`)

This system uses John Ehlers' SuperSmoother filter to create a highly responsive trend-following setup. It is designed to filter out noise better than standard EMAs while maintaining low lag.

#### `trend.*.supersmoother.macd.tpl`

* **Session:** Generic
* **Description:** **Core System.** Uses a fast (13) and slow (34) SuperSmoother to define the trend, confirmed by the specialized `MACD_SuperSmoother_Pro`.
* **Indicators:**
  * `Ehlers_Smoother_Pro` (13)
  * `Ehlers_Smoother_Pro` (34)
  * `MACD_SuperSmoother_Pro` (13,34,3)

#### `trend.*.supersmoother.macd_v1.tpl`

* **Session:** Generic
* **Description:** **Enhanced System.** Adds `Murrey_Math_Line_X` to identify key pivot points and support/resistance levels within the trend.
* **Indicators:**
  * `Ehlers_Smoother_Pro` (13 & 34)
  * `MACD_SuperSmoother_Pro`
  * `Murrey_Math_Line_X`

#### `trend.*.supersmoother.lxn.macd_v1.tpl`

* **Session:** LXN (London, Xetra, NY)
* **Description:** Same as above, but includes `Session_Analysis_Pro` for intraday context.
* **Indicators:**
  * `Ehlers_Smoother_Pro` (13 & 34)
  * `MACD_SuperSmoother_Pro`
  * `Murrey_Math_Line_X`
  * `Session_Analysis_Pro` (LXN)

#### `trend.*.supersmoother.tlx_win.macd_v1.tpl`

* **Session:** TLX Winter
* **Description:** Same as above, configured for Asian/European sessions.
* **Indicators:**
  * (Same as LXN macd_v1)

#### `trend.*.supersmoother.lxn.macd_v2.tpl`

* **Session:** LXN
* **Description:** **Maximum Suite.** Adds `ADX Pro` to confirm trend strength.
* **Indicators:**
  * `Ehlers_Smoother_Pro` (13 & 34)
  * `MACD_SuperSmoother_Pro`
  * `Murrey_Math_Line_X`
  * `Session_Analysis_Pro`
  * `ADX_Pro` (13)

#### `trend.*.supersmoother.tlx_win.macd_v2.tpl`

* **Session:** TLX Winter
* **Description:** Maximum suite for Asian/European sessions.
* **Indicators:**
  * (Same as LXN macd_v2)

## Legend

* **TLX:** Tokyo, London, Xetra
* **LXN:** London, Xetra, New York
* **Win/Sum:** Winter/Summer time adjustments for session boxes.
* **v1:** Enhanced version with additional structural indicators (VWAP, Murrey).
* **v2:** Maximum version with ADX for trend strength confirmation.
