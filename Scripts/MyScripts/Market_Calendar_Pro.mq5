//+------------------------------------------------------------------+
//|                                          Market_Calendar_Pro.mq5 |
//|                   Fundamental Risk Mapper for QuantScan          |
//|                   Copyright 2026, xxxxxxxx                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "2.10" // Added Country Code + Fixed Filename
#property description "Exports Daily Economic Events to CSV."
#property script_show_inputs

//--- Input Parameters
input group "Calendar Settings"
input datetime InpDateFrom = 0; // Start Date (0 = Today)
input bool     InpFilterHighOnly = false; // Show only High Impact?
input bool     InpIncludeMedium  = true;  // Include Medium Impact?

//--- Selected Currencies
string g_currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD"};

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart()
  {
// 1. Define Time Range
   datetime time_start = (InpDateFrom == 0) ? iTime(NULL, PERIOD_D1, 0) : InpDateFrom;
   datetime time_end   = time_start + 86400;

// 2. Output File (Fixed Logic)
   string date_str = TimeToString(time_start, TIME_DATE); // "2026.02.17"
   StringReplace(date_str, ".", ""); // "20260217"
   string filename = "MarketCalendar_" + date_str + ".csv";

   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
   if(file_handle == INVALID_HANDLE)
     {
      Print("Error opening CSV.");
      return;
     }

// Header Updated
   FileWrite(file_handle, "TIME", "COUNTRY", "CURRENCY", "IMPORTANCE", "EVENT", "PREVIOUS", "FORECAST", "ACTUAL");

// 3. Fetch Events
   MqlCalendarValue values[];

   if(CalendarValueHistory(values, time_start, time_end))
     {
      int total = ArraySize(values);
      PrintFormat("Found %d events. Processing...", total);

      for(int i=0; i<total; i++)
        {
         ulong event_id = values[i].event_id;
         MqlCalendarEvent event;
         MqlCalendarCountry country;

         if(!CalendarEventById(event_id, event))
            continue;
         if(!CalendarCountryById(event.country_id, country))
            continue;

         // Checker
         bool currency_match = false;
         for(int c=0; c<ArraySize(g_currencies); c++)
           {
            if(country.currency == g_currencies[c])
              {
               currency_match = true;
               break;
              }
           }
         if(!currency_match)
            continue;

         bool is_high = (event.importance == CALENDAR_IMPORTANCE_HIGH);
         bool is_med  = (event.importance == CALENDAR_IMPORTANCE_MODERATE);

         if(InpFilterHighOnly && !is_high)
            continue;
         if(!InpFilterHighOnly && !InpIncludeMedium && !is_high)
            continue;
         if(!is_high && !is_med)
            continue;

         string time_str = TimeToString(values[i].time, TIME_MINUTES);
         string impact = (is_high) ? "HIGH" : "MEDIUM";

         string s_prev = values[i].HasPreviousValue() ? DoubleToString(values[i].GetPreviousValue(), 2) : "-";
         string s_fore = values[i].HasForecastValue() ? DoubleToString(values[i].GetForecastValue(), 2) : "-";
         string s_act  = values[i].HasActualValue()   ? DoubleToString(values[i].GetActualValue(), 2)   : "-";

         string ev_name = event.name;
         StringReplace(ev_name, ";", " ");

         // Write Row with Country Code
         FileWrite(file_handle,
                   time_str,
                   country.code,     // e.g. "DE", "EU", "US"
                   country.currency, // e.g. "EUR", "USD"
                   impact,
                   ev_name,
                   s_prev, s_fore, s_act
                  );
        }
     }

   FileClose(file_handle);
   Print("Done. File: ", filename);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
