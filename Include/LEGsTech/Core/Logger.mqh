//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_CORE_LOGGER_MQH
#define LEGSTECH_CORE_LOGGER_MQH

#include <Object.mqh>
#include "Defs.mqh"

#define LOGGER_RING_BUFFER_SIZE 32

//+------------------------------------------------------------------+
//| Class CLogger: Institutional-Grade Multi-Channel Telemetry Logger|
//+------------------------------------------------------------------+
class CLogger : public CObject
{
private:
   string            m_prefix;
   ENUM_LOG_LEVEL    m_minLevel;
   int               m_targetMask;
   int               m_fileHandle;
   string            m_currentLogFileName;
   
   // Ring Buffer for Dashboard Overlay
   string            m_recentLogs[LOGGER_RING_BUFFER_SIZE];
   int               m_ringHead;
   int               m_ringCount;

   // Internal File Management
   void              EnsureDailyFileOpened();
   string            GenerateTimestamp();
   void              PushToRingBuffer(const string &formattedMsg);

public:
                     CLogger();
   virtual          ~CLogger();

   bool              Init(string prefix = "LEGsTECH", ENUM_LOG_LEVEL minLevel = LOG_LEVEL_INFO, int targetMask = LOG_TARGET_ALL);
   void              Deinit();

   // Core Log Methods
   void              Log(ENUM_LOG_LEVEL level, string msg, string context = "");
   void              Debug(string msg, string context = "");
   void              Info(string msg, string context = "");
   void              Warning(string msg, string context = "");
   void              Error(string msg, string context = "");
   void              Critical(string msg, string context = "");

   // Structured Telemetry Streamer
   void              Telemetry(string jsonOrKv);

   // Configuration & Buffer Access
   void              SetMinLevel(ENUM_LOG_LEVEL level) { m_minLevel = level; }
   void              SetTargetMask(int mask)           { m_targetMask = mask; }
   void              GetRecentLogs(string &outLogs[], int maxCount = 5);
   void              ClearBuffer();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger()
{
   m_prefix             = "LEGsTECH";
   m_minLevel           = LOG_LEVEL_INFO;
   m_targetMask         = LOG_TARGET_ALL;
   m_fileHandle         = INVALID_HANDLE;
   m_currentLogFileName = "";
   m_ringHead           = 0;
   m_ringCount          = 0;
   for(int i = 0; i < LOGGER_RING_BUFFER_SIZE; i++)
      m_recentLogs[i] = "";
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLogger::~CLogger()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialize Logger Subsystem                                      |
//+------------------------------------------------------------------+
inline bool CLogger::Init(string prefix, ENUM_LOG_LEVEL minLevel, int targetMask)
{
   m_prefix     = (prefix == "" || prefix == NULL) ? "LEGsTECH" : prefix;
   m_minLevel   = minLevel;
   m_targetMask = targetMask;
   m_ringHead   = 0;
   m_ringCount  = 0;
   
   if((m_targetMask & LOG_TARGET_FILE) != 0)
   {
      EnsureDailyFileOpened();
   }
   
   Info(StringFormat("Logger initialized. Prefix: %s, MinLevel: %s, TargetMask: %d", 
        m_prefix, LogLevelToString(m_minLevel), m_targetMask), "CORE");
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize & Close Resources                                   |
//+------------------------------------------------------------------+
inline void CLogger::Deinit()
{
   if(m_fileHandle != INVALID_HANDLE)
   {
      FileClose(m_fileHandle);
      m_fileHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Generate High-Resolution Formatted Timestamp                     |
//+------------------------------------------------------------------+
inline string CLogger::GenerateTimestamp()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   ulong msc = GetTickCount64() % 1000;
   return StringFormat("%04d.%02d.%02d %02d:%02d:%02d.%03llu", 
                       dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec, msc);
}

//+------------------------------------------------------------------+
//| Ensure Daily Rotating Log File is Open                           |
//+------------------------------------------------------------------+
inline void CLogger::EnsureDailyFileOpened()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   string expectedFileName = StringFormat("LEGsTech_Logs\\%s_%04d%02d%02d.log", 
                                          m_prefix, dt.year, dt.mon, dt.day);
   
   if(m_currentLogFileName != expectedFileName || m_fileHandle == INVALID_HANDLE)
   {
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileClose(m_fileHandle);
         m_fileHandle = INVALID_HANDLE;
      }
      
      m_currentLogFileName = expectedFileName;
      m_fileHandle = FileOpen(m_currentLogFileName, FILE_WRITE | FILE_READ | FILE_TXT | FILE_SHARE_READ);
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileSeek(m_fileHandle, 0, SEEK_END);
      }
   }
}

//+------------------------------------------------------------------+
//| Push message into in-memory ring buffer                          |
//+------------------------------------------------------------------+
inline void CLogger::PushToRingBuffer(const string &formattedMsg)
{
   m_recentLogs[m_ringHead] = formattedMsg;
   m_ringHead = (m_ringHead + 1) % LOGGER_RING_BUFFER_SIZE;
   if(m_ringCount < LOGGER_RING_BUFFER_SIZE)
      m_ringCount++;
}

//+------------------------------------------------------------------+
//| Core Multi-Channel Log Dispatcher                                |
//+------------------------------------------------------------------+
inline void CLogger::Log(ENUM_LOG_LEVEL level, string msg, string context)
{
   if(level < m_minLevel)
      return;

   string ts = GenerateTimestamp();
   string lvlStr = LogLevelToString(level);
   string ctxStr = (context != "") ? StringFormat("[%s]", context) : "";
   string formatted = StringFormat("[%s] [%-5s] [%s]%s %s", ts, lvlStr, m_prefix, ctxStr, msg);

   // Channel 1: Console
   if((m_targetMask & LOG_TARGET_CONSOLE) != 0)
   {
      Print(formatted);
   }

   // Channel 2: Daily File
   if((m_targetMask & LOG_TARGET_FILE) != 0)
   {
      EnsureDailyFileOpened();
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileWriteString(m_fileHandle, formatted + "\r\n");
         FileFlush(m_fileHandle);
      }
   }

   // Channel 3: UI Dashboard Ring Buffer
   if((m_targetMask & LOG_TARGET_DASHBOARD) != 0)
   {
      PushToRingBuffer(formatted);
   }
}

inline void CLogger::Debug(string msg, string context)    { Log(LOG_LEVEL_DEBUG, msg, context); }
inline void CLogger::Info(string msg, string context)     { Log(LOG_LEVEL_INFO, msg, context); }
inline void CLogger::Warning(string msg, string context)  { Log(LOG_LEVEL_WARNING, msg, context); }
inline void CLogger::Error(string msg, string context)    { Log(LOG_LEVEL_ERROR, msg, context); }
inline void CLogger::Critical(string msg, string context) { Log(LOG_LEVEL_CRITICAL, msg, context); }

//+------------------------------------------------------------------+
//| Telemetry Output (Machine Readable JSON / KV)                    |
//+------------------------------------------------------------------+
inline void CLogger::Telemetry(string jsonOrKv)
{
   string ts = GenerateTimestamp();
   string formatted = StringFormat("[%s] [TELEMETRY] %s", ts, jsonOrKv);

   if((m_targetMask & LOG_TARGET_CONSOLE) != 0)
      Print(formatted);

   if((m_targetMask & LOG_TARGET_FILE) != 0)
   {
      EnsureDailyFileOpened();
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileWriteString(m_fileHandle, formatted + "\r\n");
         FileFlush(m_fileHandle);
      }
   }
}

//+------------------------------------------------------------------+
//| Retrieve recent N log lines for UI Dashboard                     |
//+------------------------------------------------------------------+
inline void CLogger::GetRecentLogs(string &outLogs[], int maxCount)
{
   int count = MathMin(maxCount, m_ringCount);
   ArrayResize(outLogs, count);
   
   for(int i = 0; i < count; i++)
   {
      int index = (m_ringHead - 1 - i + LOGGER_RING_BUFFER_SIZE) % LOGGER_RING_BUFFER_SIZE;
      outLogs[i] = m_recentLogs[index];
   }
}

//+------------------------------------------------------------------+
//| Clear Buffer                                                     |
//+------------------------------------------------------------------+
inline void CLogger::ClearBuffer()
{
   for(int i = 0; i < LOGGER_RING_BUFFER_SIZE; i++)
      m_recentLogs[i] = "";
   m_ringHead  = 0;
   m_ringCount = 0;
}

#endif // LEGSTECH_CORE_LOGGER_MQH
