# List Chart Indicators Script

## 1. Summary (Introduction)

The `List_Chart_Indicators` script is a lightweight diagnostic utility designed for traders and developers. It scans the current chart and generates a detailed list of all attached indicators, organized by chart window (Main Window and Subwindows).

This tool is invaluable for:

* **Template Verification:** Quickly checking which indicators are loaded in a complex template.
* **Debugging:** Identifying hidden or duplicate indicators that might be consuming resources.
* **Documentation:** Generating a list of tools used in a specific setup.

## 2. Features

* **Window-Aware:** It correctly identifies indicators in the Main Chart Window as well as all separate Indicator Subwindows.
* **Detailed Output:** Prints the exact "Short Name" of each indicator to the "Experts" tab in the Toolbox.
* **Simple Execution:** Runs instantly with no parameters required.

## 3. Usage

1. Open the chart you want to analyze.
2. Drag and drop the `List_Chart_Indicators` script from the Navigator onto the chart.
3. Open the **Toolbox** (Ctrl+T) and switch to the **Experts** tab.
4. You will see a formatted list of all indicators attached to that chart.

### Example Output

```text
--------------------------------------------------
Indicators on Chart 123456789 (EURUSD):
--- Main Window (2 indicators) ---
  [0] Moving Average(14)
  [1] Bollinger Bands(20, 2.00)
--- Subwindow 1 (1 indicators) ---
  [0] RSI(14)
--------------------------------------------------
```

## 4. Technical Details

* **File:** `List_Chart_Indicators.mq5`
* **Type:** Script
* **Dependencies:** None (Standard MQL5 libraries only).
