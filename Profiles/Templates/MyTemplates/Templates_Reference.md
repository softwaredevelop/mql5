# Chart Templates Reference

This document provides a detailed breakdown of the available chart templates in the `MyTemplates` folder.

## 1. Scalping Strategies (`scalp.*`)

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
