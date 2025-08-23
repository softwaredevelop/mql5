# Symbol Info String Checker Script

## 1. Summary (Introduction)

The Symbol Info String Checker is an MQL5 script designed as a **diagnostic and development tool**. When executed on a chart, it systematically queries and displays the status and value of every `ENUM_SYMBOL_INFO_STRING` property for the chart's current symbol.

Its primary purpose is to provide developers and advanced traders with a quick and comprehensive way to check the text-based metadata provided by their broker for a specific financial instrument. This includes crucial information like the symbol's description, the underlying base and profit currencies, the exchange it trades on, and its path in the Market Watch.

## 2. Features and Displayed Data

The script iterates through a comprehensive, hard-coded list of all `ENUM_SYMBOL_INFO_STRING` properties. For each property, it prints a formatted line to the "Experts" tab of the terminal, indicating:

- **Property Name:** The official `enum` name of the property (e.g., `SYMBOL_CURRENCY_BASE`).
- **Status:** Whether the request for the property was `SUPPORTED` or `FAILED`.
- **Value / Error:**
  - If **supported**, it displays the retrieved `string` value. For clarity, empty strings are explicitly marked as `<EMPTY>`, and non-empty strings are enclosed in single quotes (e.g., `'EUR'`).
  - If **failed**, it displays the error code returned by `GetLastError()`.

The output is neatly aligned in columns for easy readability.

## 3. MQL5 Implementation Details

The script was refactored to follow a clean, object-oriented, and modular design, ensuring consistency with our other diagnostic tools.

- **Object-Oriented Design:** The core logic is encapsulated within a `CSymbolStringPropertyChecker` class. This isolates the functionality from the script's entry point (`OnStart`).

  - The constructor takes the symbol name as an argument.
  - A single public method, `Run()`, executes the entire checking process.
  - Private helper methods (`PrintHeader`, `PrintFooter`, `PrintProperty`, `FormatValue`) break down the logic into smaller, manageable pieces.

- **Self-Contained Logic:** The script is completely self-contained. It uses the standard `<Trade\SymbolInfo.mqh>` library but does not require any custom include files. The formatting logic is integrated into the class as a private `FormatValue` method.

- **Static Property List:** The array of `ENUM_SYMBOL_INFO_STRING` properties is defined as a `static const` member of the `CSymbolStringPropertyChecker` class. This logically associates the data with the class that uses it, which is a cleaner approach than using a global variable.

- **Simplified `OnStart`:** The script's entry point, `OnStart()`, is now extremely simple. It is only responsible for creating an instance of the `CSymbolStringPropertyChecker` class and calling its `Run()` method.

## 4. Usage

1. **Installation:**
   - Place `SymbolInfoStringChecker.mq5` into your `MQL5\Scripts` folder.
2. **Execution:**
   - Open the chart of the symbol you wish to inspect.
   - Drag and drop the `SymbolInfoStringChecker` script from the Navigator window onto the chart.
3. **Review Output:**
   - Open the "Terminal" window (Ctrl+T).
   - Navigate to the "Experts" tab.
   - The script will print the full list of string properties and their status for the selected symbol. The script terminates automatically after printing the list.

## 5. Parameters

This script has no adjustable input parameters. It always runs on the symbol of the chart it is attached to.
