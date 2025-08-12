//+------------------------------------------------------------------+
//|                                     util_ExportCandlesToCSV.mq5  |
//|                       Copyright 2025, xxxxxxxx                   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "1.01" // Added comments and minor fixes
#property script_show_inputs
#property description "Exports historical candle data for the current chart to a CSV file."
#property description "The file is saved in the terminal's MQL5/Files/ folder."

//--- Input Parameters ---
input int    InpCandlesToExport = 1000;   // Number of most recent candles to export
input string InpFileName        = "";      // CSV file name. If empty, it will be auto-generated.
input string InpDelimiter       = ",";     // Delimiter for the CSV file (e.g., comma or semicolon)

//+------------------------------------------------------------------+
//| Script program start function.                                   |
//| This is the main entry point for the script.                     |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- 1. Validate Input Parameters ---
   if(InpCandlesToExport <= 0)
     {
      Print("Error: Number of candles to export must be greater than 0.");
      return;
     }

//--- 2. Prepare File Name ---
   string file_name = InpFileName;
// Auto-generate a descriptive file name if the user left it empty
   if(file_name == "")
     {
      file_name = StringFormat("%s_%s_Candles.csv", _Symbol, EnumToString(_Period));
     }

// Ensure the file name ends with .csv
   if(StringFind(file_name, ".csv", StringLen(file_name) - 4) == -1)
     {
      file_name = file_name + ".csv";
     }

   PrintFormat("Starting export of %d candles for %s on %s...", InpCandlesToExport, _Symbol, EnumToString(_Period));
   PrintFormat("Target file: MQL5\\Files\\%s", file_name);

//--- 3. Open File for Writing ---
   ResetLastError();
// FIX: Use StringGetCharacter for safety, as InpDelimiter is a string
   char separator = (char)StringGetCharacter(InpDelimiter, 0);
   int file_handle = FileOpen(file_name, FILE_WRITE | FILE_CSV | FILE_ANSI, separator);

   if(file_handle == INVALID_HANDLE)
     {
      PrintFormat("Error opening file '%s'. Error code: %d", file_name, GetLastError());
      return;
     }

//--- 4. Copy Historical Data ---
   MqlRates rates[]; // Array to store candle data

// Set array as non-timeseries to get data in chronological order (oldest first)
   ArraySetAsSeries(rates, false);

// Request rate data from the terminal
   int copied_count = CopyRates(_Symbol, _Period, 0, InpCandlesToExport, rates);
   if(copied_count <= 0)
     {
      PrintFormat("Error: Could not copy any candle data. Error code: %d", GetLastError());
      FileClose(file_handle);
      return;
     }

   if(copied_count < InpCandlesToExport)
     {
      PrintFormat("Warning: Could only copy %d candles, less than the requested %d.", copied_count, InpCandlesToExport);
     }

//--- 5. Write Data to CSV File ---
// Write the header row first
   FileWrite(file_handle, "time", "open", "high", "low", "close", "tick_volume", "real_volume", "spread");

// Loop through the copied rates and write each candle to a new line
   for(int i = 0; i < copied_count; i++)
     {
      // Convert Unix timestamp to a human-readable string for better readability in the CSV
      string time_str = TimeToString(rates[i].time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);

      // Write one line to the CSV file
      FileWrite(file_handle,
                time_str,
                rates[i].open,
                rates[i].high,
                rates[i].low,
                rates[i].close,
                rates[i].tick_volume,
                rates[i].real_volume,
                rates[i].spread);
     }

//--- 6. Finalize and Clean Up ---
   FileClose(file_handle);
   PrintFormat("Successfully exported %d candles to '%s'.", copied_count, file_name);
   Print("You can find the file in the terminal's Data Folder under MQL5/Files/.");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
