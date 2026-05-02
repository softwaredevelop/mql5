//+------------------------------------------------------------------+
//|                                  Market_Calendar_Discovery.mq5   |
//|               Event Dictionary Exporter for QuantScan            |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property description "Exports the entire MT5 Economic Calendar Dictionary to CSV."
#property script_show_inputs

// Target countries based on our portfolio
string g_target_countries[] = {"US", "EU", "DE", "GB", "JP", "CH", "AU"};

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart()
  {
   string filename = "Calendar_Discovery.csv";
   int file_handle = FileOpen(filename, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");

   if(file_handle == INVALID_HANDLE)
     {
      Print("Error opening CSV for writing.");
      return;
     }

// Write CSV Header
   FileWrite(file_handle, "COUNTRY", "SECTOR", "IMPORTANCE", "EVENT_NAME", "EVENT_ID");

   int total_events_found = 0;

// Iterate through our target countries
   for(int c = 0; c < ArraySize(g_target_countries); c++)
     {
      string current_country = g_target_countries[c];
      MqlCalendarEvent events[];

      // Fetch all event definitions for the specific country
      if(CalendarEventByCountry(current_country, events))
        {
         int events_count = ArraySize(events);
         total_events_found += events_count;

         for(int i = 0; i < events_count; i++)
           {
            // Convert Enums to readable strings
            string sector_str     = EnumToString(events[i].sector);
            string importance_str = EnumToString(events[i].importance);

            // Clean the event name to prevent CSV structure breaking
            string event_name = events[i].name;
            StringReplace(event_name, ";", " ");

            // Write data row
            FileWrite(file_handle,
                      current_country,
                      sector_str,
                      importance_str,
                      event_name,
                      IntegerToString(events[i].id)
                     );
           }
         PrintFormat("Exported %d events for %s", events_count, current_country);
        }
      else
        {
         PrintFormat("Failed to retrieve events for %s or no events available.", current_country);
        }
     }

   FileClose(file_handle);
   PrintFormat("Discovery complete. Total events mapped: %d. File saved as: %s", total_events_found, filename);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
