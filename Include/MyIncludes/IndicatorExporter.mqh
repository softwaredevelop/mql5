//+------------------------------------------------------------------+
//|                                           IndicatorExporter.mqh  |
//|         A toolkit for exporting indicator buffer data to CSV     |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""

#include <Object.mqh>

//+------------------------------------------------------------------+
//| Class CIndicatorExporter.                                        |
//| Purpose: Encapsulates all logic for exporting indicator data     |
//|          to a CSV file. It handles file opening, writing, and    |
//|          closing operations.                                     |
//+------------------------------------------------------------------+
class CIndicatorExporter : public CObject
  {
private:
   int               m_file_handle; // Stores the handle of the currently open file
   string            m_delimiter;   // Stores the delimiter character for the CSV

public:
   //--- Constructor and Destructor
                     CIndicatorExporter(void);
                    ~CIndicatorExporter(void);

   //--- Public Interface
   bool              OpenFile(const string file_name, const string delimiter=",");
   void              CloseFile(void);
   bool              WriteHeader(const string &header_fields[]);
   bool              WriteRow(const datetime time_val, const double &data_values[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIndicatorExporter::CIndicatorExporter(void) : m_file_handle(INVALID_HANDLE), m_delimiter(",")
  {
//--- Initializes member variables to default states
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CIndicatorExporter::~CIndicatorExporter(void)
  {
//--- Ensures the file is closed when the object is destroyed
   if(m_file_handle != INVALID_HANDLE)
      FileClose(m_file_handle);
  }

//+------------------------------------------------------------------+
//| Opens a file for writing in the MQL5/Files/ directory.           |
//| INPUT:  file_name - The name of the file to create.              |
//|         delimiter - The character to use for separating values.  |
//| RETURN: true if the file was opened successfully, false otherwise.|
//+------------------------------------------------------------------+
bool CIndicatorExporter::OpenFile(const string file_name, const string delimiter=",")
  {
   m_delimiter = delimiter;
   ResetLastError();

//--- Open the file with write, CSV, and ANSI flags
   char separator = (char)StringGetCharacter(m_delimiter, 0);
   m_file_handle = FileOpen(file_name, FILE_WRITE | FILE_CSV | FILE_ANSI, separator);

//--- Check for errors
   if(m_file_handle == INVALID_HANDLE)
     {
      PrintFormat("CIndicatorExporter: Error opening file '%s'. Error code: %d", file_name, GetLastError());
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Closes the currently open file.                                  |
//+------------------------------------------------------------------+
void CIndicatorExporter::CloseFile(void)
  {
   if(m_file_handle != INVALID_HANDLE)
     {
      FileClose(m_file_handle);
      m_file_handle = INVALID_HANDLE; // Reset handle to prevent accidental reuse
     }
  }

//+------------------------------------------------------------------+
//| Writes the header row to the CSV file.                           |
//| INPUT:  header_fields - A string array containing the column names.|
//| RETURN: true on success, false on failure.                       |
//| NOTE:   This version is hardcoded for 4 header fields.           |
//+------------------------------------------------------------------+
bool CIndicatorExporter::WriteHeader(const string &header_fields[])
  {
   if(m_file_handle == INVALID_HANDLE)
      return false;

//--- Check array size before writing
   if(ArraySize(header_fields) == 4)
     {
      FileWrite(m_file_handle, header_fields[0], header_fields[1], header_fields[2], header_fields[3]);
     }
   else
     {
      Print("CIndicatorExporter: WriteHeader currently supports exactly 4 header fields.");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Writes a single row of data to the file.                         |
//| INPUT:  time_val    - The datetime for the current row.          |
//|         data_values - A double array with the indicator values.  |
//| RETURN: true on success, false on failure.                       |
//| NOTE:   This version is hardcoded for 3 data values.             |
//+------------------------------------------------------------------+
bool CIndicatorExporter::WriteRow(const datetime time_val, const double &data_values[])
  {
   if(m_file_handle == INVALID_HANDLE)
      return false;

//--- Convert datetime to a standard string format
   string time_str = TimeToString(time_val, TIME_DATE | TIME_MINUTES | TIME_SECONDS);

//--- Check array size before writing
   if(ArraySize(data_values) == 3)
     {
      FileWrite(m_file_handle, time_str, data_values[0], data_values[1], data_values[2]);
     }
   else
     {
      Print("CIndicatorExporter: WriteRow currently supports exactly 3 data values.");
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
