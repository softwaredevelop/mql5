//+------------------------------------------------------------------+
//|                                     util_ExportCandlesToCSV.mq5  |
//|                       Copyright 2025, xxxxxxxx                   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property version   "2.00" // Refactored into a class-based structure
#property script_show_inputs
#property description "Exports historical candle data for the current chart to a CSV file."
#property description "The file is saved in the terminal's MQL5/Files/ folder."

//--- Input Parameters ---
input int    InpCandlesToExport = 1000;   // Number of most recent candles to export
input string InpFileName        = "";      // CSV file name. If empty, it will be auto-generated.
input string InpDelimiter       = ",";     // Delimiter for the CSV file (e.g., comma or semicolon)

//+------------------------------------------------------------------+
//| CCandleExporter Class                                            |
//| Encapsulates all logic for exporting candle data to a CSV file.  |
//+------------------------------------------------------------------+
class CCandleExporter
  {
private:
   //--- Export settings
   int               m_candles_to_export;
   string            m_file_name;
   char              m_delimiter;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_period;

   //--- Internal state
   int               m_file_handle;

public:
   //--- Constructor
                     CCandleExporter(int candles, string file_name, string delimiter);
   //--- Destructor
                    ~CCandleExporter(void);
   //--- Main execution method
   bool              Run(void);

private:
   //--- Helper methods
   bool              PrepareFileName(void);
   bool              OpenFile(void);
   int               CopyData(MqlRates &rates[]);
   bool              WriteData(const MqlRates &rates[], int count);
   void              CloseFile(void);
  };

//+------------------------------------------------------------------+
//| Constructor: Initializes the exporter with settings              |
//+------------------------------------------------------------------+
CCandleExporter::CCandleExporter(int candles, string file_name, string delimiter)
  {
   m_candles_to_export = (candles > 0) ? candles : 1;
   m_file_name         = file_name;
   m_delimiter         = (char)StringGetCharacter(delimiter, 0);
   m_symbol            = _Symbol;
   m_period            = _Period;
   m_file_handle       = INVALID_HANDLE;
  }

//+------------------------------------------------------------------+
//| Destructor: Ensures the file is always closed                    |
//+------------------------------------------------------------------+
CCandleExporter::~CCandleExporter(void)
  {
   CloseFile();
  }

//+------------------------------------------------------------------+
//| Main execution method                                            |
//+------------------------------------------------------------------+
bool CCandleExporter::Run(void)
  {
   if(!PrepareFileName())
      return false;

   if(!OpenFile())
      return false;

   MqlRates rates[];
   int copied_count = CopyData(rates);
   if(copied_count <= 0)
     {
      CloseFile();
      return false;
     }

   if(!WriteData(rates, copied_count))
     {
      CloseFile();
      return false;
     }

   CloseFile();
   PrintFormat("Successfully exported %d candles to '%s'.", copied_count, m_file_name);
   Print("You can find the file in the terminal's Data Folder under MQL5/Files/.");
   return true;
  }

//+------------------------------------------------------------------+
//| Prepares and validates the file name                             |
//+------------------------------------------------------------------+
bool CCandleExporter::PrepareFileName(void)
  {
   if(m_file_name == "")
     {
      m_file_name = StringFormat("%s_%s_Candles.csv", m_symbol, EnumToString(m_period));
     }

   if(StringFind(m_file_name, ".csv", StringLen(m_file_name) - 4) == -1)
     {
      m_file_name += ".csv";
     }

   PrintFormat("Starting export of %d candles for %s on %s...", m_candles_to_export, m_symbol, EnumToString(m_period));
   PrintFormat("Target file: MQL5\\Files\\%s", m_file_name);
   return true;
  }

//+------------------------------------------------------------------+
//| Opens the target file for writing                                |
//+------------------------------------------------------------------+
bool CCandleExporter::OpenFile(void)
  {
   ResetLastError();
   m_file_handle = FileOpen(m_file_name, FILE_WRITE | FILE_CSV | FILE_ANSI, m_delimiter);

   if(m_file_handle == INVALID_HANDLE)
     {
      PrintFormat("Error opening file '%s'. Error code: %d", m_file_name, GetLastError());
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Copies historical rate data from the terminal                    |
//+------------------------------------------------------------------+
int CCandleExporter::CopyData(MqlRates &rates[])
  {
   ArraySetAsSeries(rates, false);

   int copied_count = CopyRates(m_symbol, m_period, 0, m_candles_to_export, rates);
   if(copied_count <= 0)
     {
      PrintFormat("Error: Could not copy any candle data. Error code: %d", GetLastError());
      return 0;
     }

   if(copied_count < m_candles_to_export)
     {
      PrintFormat("Warning: Could only copy %d candles, less than the requested %d.", copied_count, m_candles_to_export);
     }
   return copied_count;
  }

//+------------------------------------------------------------------+
//| Writes the header and candle data to the opened CSV file         |
//+------------------------------------------------------------------+
bool CCandleExporter::WriteData(const MqlRates &rates[], int count)
  {
   FileWrite(m_file_handle, "time", "open", "high", "low", "close", "tick_volume", "real_volume", "spread");

   for(int i = 0; i < count; i++)
     {
      string time_str = TimeToString(rates[i].time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      FileWrite(m_file_handle, time_str, rates[i].open, rates[i].high, rates[i].low,
                rates[i].close, rates[i].tick_volume, rates[i].real_volume, rates[i].spread);
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Closes the file handle if it's open                              |
//+------------------------------------------------------------------+
void CCandleExporter::CloseFile(void)
  {
   if(m_file_handle != INVALID_HANDLE)
     {
      FileClose(m_file_handle);
      m_file_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   CCandleExporter exporter(InpCandlesToExport, InpFileName, InpDelimiter);
   exporter.Run();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
