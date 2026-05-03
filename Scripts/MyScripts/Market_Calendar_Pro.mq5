//+------------------------------------------------------------------+
//|                                          Market_Calendar_Pro.mq5 |
//|                   Fundamental Risk Mapper for QuantScan          |
//|                   Copyright 2026, xxxxxxxx                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "3.00" // Advanced Sector Filtering & Holiday Bypass
#property description "Exports Daily Economic Events to CSV."
#property script_show_inputs

//--- Input Parameters
input group "Calendar Settings"
input datetime InpDateFrom       = 0;     // Start Date (0 = Today)
input bool     InpFilterHighOnly = false; // Show only High Impact?
input bool     InpIncludeMedium  = true;  // Include Medium Impact?

//--- Selected Currencies (Core Portfolio Exposure)
string g_currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD"};

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart()
  {
// 1. Define Time Range
   datetime time_start = (InpDateFrom == 0) ? iTime(NULL, PERIOD_D1, 0) : InpDateFrom;
   datetime time_end   = time_start + 86400; // 24 hours later

// 2. Output File Setup
   string date_str = TimeToString(time_start, TIME_DATE); // "2026.02.17"
   StringReplace(date_str, ".", "");                      // "20260217"
   string filename = "MarketCalendar_" + date_str + ".csv";

   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
   if(file_handle == INVALID_HANDLE)
     {
      Print("Error opening CSV for writing.");
      return;
     }

// Write Header (Explicit DATE column included)
   FileWrite(file_handle, "DATE", "TIME", "COUNTRY", "CURRENCY", "IMPORTANCE", "EVENT", "PREVIOUS", "FORECAST", "ACTUAL");

// 3. Fetch Events
   MqlCalendarValue values[];

   if(CalendarValueHistory(values, time_start, time_end))
     {
      int total = ArraySize(values);
      PrintFormat("Found %d total events. Applying Portfolio Filters...", total);
      int written_rows = 0;

      for(int i = 0; i < total; i++)
        {
         ulong event_id = values[i].event_id;
         MqlCalendarEvent event;
         MqlCalendarCountry country;

         if(!CalendarEventById(event_id, event))
            continue;
         if(!CalendarCountryById(event.country_id, country))
            continue;

         // --- FILTER 1: Target Currencies ---
         bool currency_match = false;
         for(int c = 0; c < ArraySize(g_currencies); c++)
           {
            if(country.currency == g_currencies[c])
              {
               currency_match = true;
               break;
              }
           }
         if(!currency_match)
            continue;

         // --- FILTER 2: Target Macro Sectors ---
         bool is_core_macro = false;
         switch(event.sector)
           {
            case CALENDAR_SECTOR_BUSINESS:
            case CALENDAR_SECTOR_CONSUMER:
            case CALENDAR_SECTOR_GDP:
            case CALENDAR_SECTOR_HOLIDAYS:
            case CALENDAR_SECTOR_JOBS:
            case CALENDAR_SECTOR_MARKET:
            case CALENDAR_SECTOR_MONEY:
            case CALENDAR_SECTOR_PRICES:
               is_core_macro = true;
               break;
           }

         // Drop irrelevant noise (e.g. Housing, Retail specific, Taxes, etc.)
         if(!is_core_macro)
            continue;

         // --- FILTER 3: Importance (with Holiday Bypass) ---
         string impact = "LOW/NONE";

         // Holidays are often marked as LOW/NONE importance in MT5,
         // but we MUST pass them to the LLM.
         if(event.sector == CALENDAR_SECTOR_HOLIDAYS)
           {
            impact = "HOLIDAY";
           }
         else
           {
            bool is_high = (event.importance == CALENDAR_IMPORTANCE_HIGH);
            bool is_med  = (event.importance == CALENDAR_IMPORTANCE_MODERATE);

            if(InpFilterHighOnly && !is_high)
               continue;
            if(!InpFilterHighOnly && !InpIncludeMedium && !is_high)
               continue;
            if(!is_high && !is_med)
               continue; // Drop standard Low/None events

            impact = (is_high) ? "HIGH" : "MEDIUM";
           }

         // Format Date and Time
         string date_val_str = TimeToString(values[i].time, TIME_DATE);    // "2026.04.26"
         string time_val_str = TimeToString(values[i].time, TIME_MINUTES); // "14:30"

         // Format Statistical Values
         string s_prev = values[i].HasPreviousValue() ? DoubleToString(values[i].GetPreviousValue(), 2) : "-";
         string s_fore = values[i].HasForecastValue() ? DoubleToString(values[i].GetForecastValue(), 2) : "-";
         string s_act  = values[i].HasActualValue()   ? DoubleToString(values[i].GetActualValue(), 2)   : "-";

         // Clean Event Name (Prevent CSV delimiter breakage)
         string ev_name = event.name;
         StringReplace(ev_name, ";", " ");

         // Write Row
         FileWrite(file_handle,
                   date_val_str,
                   time_val_str,
                   country.code,
                   country.currency,
                   impact,
                   ev_name,
                   s_prev,
                   s_fore,
                   s_act
                  );

         written_rows++;
        }

      PrintFormat("Processing complete. Exported %d high-relevance portfolio events.", written_rows);
     }
   else
     {
      Print("No events found or failed to retrieve history.");
     }

   FileClose(file_handle);
   Print("Done. File saved: ", filename);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
