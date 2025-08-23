# Candle Data Exporter Script

## 1. Summary (Introduction)

The Candle Data Exporter is an MQL5 script designed as a simple yet powerful **data utility tool**. When executed on a chart, it extracts a specified number of historical price bars (candlesticks) and saves them into a CSV (Comma-Separated Values) file.

Its primary purpose is to allow traders, analysts, and developers to easily export historical data from the MetaTrader 5 terminal for use in external applications such as Microsoft Excel, Python scripts, or other data analysis software. The generated file is saved in a standard, easy-to-parse format.

## 2. Features and Exported Data

The script is configurable through its input parameters and exports a comprehensive set of data for each candlestick. The resulting CSV file is saved in the terminal's `MQL5/Files/` directory.

For each candle, the following data points are exported into a separate column:

- **time:** The opening time of the candle, formatted as a human-readable string (e.g., `YYYY.MM.DD HH:MI:SS`).
- **open:** The opening price.
- **high:** The highest price.
- **low:** The lowest price.
- **close:** The closing price.
- **tick_volume:** The volume of ticks within the bar.
- **real_volume:** The real trade volume (if provided by the broker).
- **spread:** The spread in points at the time the bar was formed.

## 3. MQL5 Implementation Details

The script was refactored into a clean, fully object-oriented structure to ensure its logic is modular, reusable, and robust.

- **Object-Oriented Design:** The entire export logic is encapsulated within a `CCandleExporter` class. The script's entry point (`OnStart`) is minimal and is only responsible for creating an instance of this class with the user's input parameters and executing its `Run()` method.

- **Clear, Staged Execution:** The main `Run()` method orchestrates the export process in a series of clear, sequential steps, each handled by a dedicated private method:

  1. `PrepareFileName()`: Generates a descriptive file name if one is not provided by the user.
  2. `OpenFile()`: Opens the CSV file for writing.
  3. `CopyData()`: Retrieves the historical `MqlRates` data from the terminal.
  4. `WriteData()`: Writes the header row and then iterates through the retrieved data to write each candle to the file.
  5. `CloseFile()`: Closes the file handle.

- **Robust File Handling (RAII):** The script follows the **Resource Acquisition Is Initialization (RAII)** principle. The file handle is managed as a class member. The `CloseFile()` method is called automatically by the class's **destructor** (`~CCandleExporter`). This is a robust safety feature that guarantees the file handle is always properly closed, even if an error occurs during the export process, preventing file corruption or resource leaks.

- **Self-Contained Logic:** The script is completely self-contained and uses standard MQL5 functions (`CopyRates`, `FileOpen`, etc.) for its operations. It has no external dependencies on other indicators or libraries.

## 4. Usage

1. **Installation:**
   - Place `util_ExportCandlesToCSV.mq5` into your `MQL5\Scripts` folder.
2. **Execution:**
   - Open the chart of the symbol and timeframe you wish to export.
   - Drag and drop the `util_ExportCandlesToCSV` script from the Navigator window onto the chart.
   - The script input window will appear, allowing you to configure the export parameters.
3. **Retrieve File:**
   - After the script finishes, it will print a success message to the "Experts" tab.
   - To find the exported file, go to **File -> Open Data Folder** in the MetaTrader 5 terminal.
   - Navigate to the `MQL5\Files\` directory. Your CSV file will be located there.

## 5. Input Parameters

- **`InpCandlesToExport`**: The number of most recent candles you want to export from the current bar backwards. Default is `1000`.
- **`InpFileName`**: The name of the output CSV file. If left empty, a descriptive name will be automatically generated based on the symbol and timeframe (e.g., `EURUSD_PERIOD_M15_Candles.csv`).
- **`InpDelimiter`**: The character used to separate values in the CSV file. The default is a comma (`,`), but a semicolon (`;`) can be used for compatibility with some regional settings in Excel.
