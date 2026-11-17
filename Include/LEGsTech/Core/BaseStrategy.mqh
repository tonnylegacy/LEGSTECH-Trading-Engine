//+------------------------------------------------------------------+
//|                                                 BaseStrategy.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_CORE_BASESTRATEGY_MQH
#define LEGSTECH_CORE_BASESTRATEGY_MQH

#include <Object.mqh>
#include "Defs.mqh"
#include "Logger.mqh"
#include "StateMachine.mqh"
#include "..\Strategies\IStrategy.mqh"

//+------------------------------------------------------------------+
//| Class CBaseStrategy: Abstract Base Class for LEGsTECH Strategies |
//+------------------------------------------------------------------+
class CBaseStrategy : public IStrategy
{
protected:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   ulong                m_magicNumber;
   ENUM_STRATEGY_TYPE   m_strategyType;
   string               m_strategyName;
   bool                 m_isInitialized;
   
   // Shared Subsystems
   CStateMachine       *m_stateMachine;
   CLogger             *m_logger;
   
   // Signal & Position State
   STradeSignal         m_lastSignal;
   SPositionInfo        m_positionInfo;
   datetime             m_lastBarTime;

   // Timeframe-decoupled bar time tracker to prevent cross-TF collision
   struct STimeframeBar
   {
      ENUM_TIMEFRAMES tf;
      datetime        lastTime;
   };
   STimeframeBar        m_tfBars[10];
   int                  m_tfBarCount;

   // Protected Helper Methods
   bool                 IsNewBar(ENUM_TIMEFRAMES tf);
   bool                 ValidateSignal(const STradeSignal &signal);
   void                 LogState(string message);

public:
                        CBaseStrategy();
   virtual             ~CBaseStrategy();

   // IStrategy Interface Implementation
   virtual bool         Init(const string symbol, ENUM_TIMEFRAMES timeframe);
   virtual void         Deinit();
   virtual void         OnTickHandler();
   virtual void         OnBarHandler(ENUM_TIMEFRAMES tf);
   virtual void         EvaluateSetup() = 0;
   virtual bool         GetTradeSignals(STradeSignal &outSignal);
   virtual void         ManageOpenPositions() = 0;
   virtual ENUM_EA_STATE GetState();
   virtual void         SetState(ENUM_EA_STATE newState);
   virtual void         Reset();
   virtual string       GetStrategyName()       { return m_strategyName; }
   virtual string       GetStatusString();

   // Setters / Getters
   void                 SetLogger(CLogger *logger)        { m_logger = logger; }
   void                 SetMagicNumber(ulong magic)       { m_magicNumber = magic; }
   ulong                GetMagicNumber() const            { return m_magicNumber; }
   ENUM_STRATEGY_TYPE   GetStrategyType() const           { return m_strategyType; }
   CStateMachine*       GetStateMachine()                 { return m_stateMachine; }
   void                 GetPositionInfo(SPositionInfo &outInfo) const { outInfo = m_positionInfo; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBaseStrategy::CBaseStrategy()
{
   m_symbol        = "";
   m_timeframe     = PERIOD_M15;
   m_magicNumber   = 0;
   m_strategyType  = STRATEGY_REMMY;
   m_strategyName  = "BaseStrategy";
   m_isInitialized = false;
   m_stateMachine  = NULL;
   m_logger        = NULL;
   m_lastBarTime   = 0;
   m_tfBarCount    = 0;
   m_lastSignal.Clear();
   m_positionInfo.Clear();
   m_stateMachine  = new CStateMachine();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBaseStrategy::~CBaseStrategy()
{
   Deinit();
   if(CheckPointer(m_stateMachine) == POINTER_DYNAMIC)
   {
      delete m_stateMachine;
      m_stateMachine = NULL;
   }
}

//+------------------------------------------------------------------+
//| Base Initialization                                              |
//+------------------------------------------------------------------+
inline bool CBaseStrategy::Init(const string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol        = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe     = timeframe;
   m_isInitialized = true;
   m_lastBarTime   = 0;
   m_tfBarCount    = 0;

   // Pre-arm primary timeframe tracker with current in-flight candle
   datetime initialTime = iTime(m_symbol, m_timeframe, 0);
   if(initialTime > 0)
   {
      m_tfBars[0].tf       = m_timeframe;
      m_tfBars[0].lastTime = initialTime;
      m_tfBarCount         = 1;
      m_lastBarTime        = initialTime;
   }

   if(m_stateMachine != NULL)
   {
      m_stateMachine.Init(m_logger, m_strategyName, EA_STATE_IDLE);
   }

   if(m_logger != NULL)
   {
      m_logger.Info(StringFormat("%s initialized on %s, TF: %s", 
                     m_strategyName, m_symbol, EnumToString(m_timeframe)), m_strategyName);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Base Deinitialization                                            |
//+------------------------------------------------------------------+
inline void CBaseStrategy::Deinit()
{
   if(m_stateMachine != NULL)
   {
      m_stateMachine.ForceState(EA_STATE_IDLE, "STRATEGY_DEINIT");
   }
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Base Tick Handler                                                |
//+------------------------------------------------------------------+
inline void CBaseStrategy::OnTickHandler()
{
   if(!m_isInitialized)
      return;

   // Check for new bar event on strategy primary timeframe
   if(IsNewBar(m_timeframe))
   {
      OnBarHandler(m_timeframe);
   }

   // Manage active positions on tick
   if(m_stateMachine != NULL && m_stateMachine.GetCurrentState() == EA_STATE_MANAGING)
   {
      ManageOpenPositions();
   }
}

//+------------------------------------------------------------------+
//| Base Bar Handler                                                 |
//+------------------------------------------------------------------+
inline void CBaseStrategy::OnBarHandler(ENUM_TIMEFRAMES tf)
{
   if(!m_isInitialized)
      return;

   // If not in trade execution/management, evaluate new setups
   if(m_stateMachine != NULL)
   {
      ENUM_EA_STATE state = m_stateMachine.GetCurrentState();
      if(state == EA_STATE_IDLE || state == EA_STATE_ANALYSING || state == EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP)
      {
         EvaluateSetup();
      }
   }
}

//+------------------------------------------------------------------+
//| Signal Retrieval                                                 |
//+------------------------------------------------------------------+
inline bool CBaseStrategy::GetTradeSignals(STradeSignal &outSignal)
{
   if(m_stateMachine != NULL && m_stateMachine.GetCurrentState() == EA_STATE_ENTRY_READY && m_lastSignal.IsValid())
   {
      outSignal = m_lastSignal;
      return true;
   }
   outSignal.Clear();
   return false;
}

//+------------------------------------------------------------------+
//| State Getter & Setter                                            |
//+------------------------------------------------------------------+
inline ENUM_EA_STATE CBaseStrategy::GetState()
{
   return (m_stateMachine != NULL) ? m_stateMachine.GetCurrentState() : EA_STATE_IDLE;
}

inline void CBaseStrategy::SetState(ENUM_EA_STATE newState)
{
   if(m_stateMachine != NULL)
   {
      m_stateMachine.TransitionTo(newState, "STRATEGY_STATE_SET");
   }
}

//+------------------------------------------------------------------+
//| Reset Strategy State                                             |
//+------------------------------------------------------------------+
inline void CBaseStrategy::Reset()
{
   m_lastSignal.Clear();
   m_positionInfo.Clear();
   m_tfBarCount = 0;
   m_lastBarTime = 0;
   if(m_stateMachine != NULL)
   {
      m_stateMachine.Reset("STRATEGY_RESET");
   }
}

//+------------------------------------------------------------------+
//| Status String Generation for GUI / Telemetry                     |
//+------------------------------------------------------------------+
inline string CBaseStrategy::GetStatusString()
{
   return StringFormat("Strategy: %s | State: %s | ActivePos: %s | LastSignal: %s",
                       m_strategyName,
                       (m_stateMachine != NULL) ? m_stateMachine.GetCurrentStateName() : "N/A",
                       m_positionInfo.HasActivePositions() ? "YES" : "NO",
                       SignalTypeToString(m_lastSignal.type));
}

//+------------------------------------------------------------------+
//| New Bar Detection Helper (Decoupled per Timeframe)               |
//+------------------------------------------------------------------+
inline bool CBaseStrategy::IsNewBar(ENUM_TIMEFRAMES tf)
{
   datetime currentBarTime = iTime(m_symbol, tf, 0);
   if(currentBarTime <= 0)
      return false;

   // Search for existing timeframe tracker slot
   for(int i = 0; i < m_tfBarCount; i++)
   {
      if(m_tfBars[i].tf == tf)
      {
         if(currentBarTime != m_tfBars[i].lastTime)
         {
            m_tfBars[i].lastTime = currentBarTime;
            m_lastBarTime        = currentBarTime;
            return true;
         }
         return false;
      }
   }

   // Register new timeframe tracker slot (up to 10 distinct timeframes)
   // CRITICAL FIX: Return false on initial slot discovery to prevent hot-start false triggers!
   if(m_tfBarCount < 10)
   {
      m_tfBars[m_tfBarCount].tf       = tf;
      m_tfBars[m_tfBarCount].lastTime = currentBarTime;
      m_tfBarCount++;
      m_lastBarTime = currentBarTime;
      return false; // Armed on current in-flight candle; will trigger true on the next actual candle close
   }

   // Fallback for safety
   if(m_lastBarTime == 0)
   {
      m_lastBarTime = currentBarTime;
      return false;
   }
   if(currentBarTime != m_lastBarTime)
   {
      m_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Signal Validation Helper                                         |
//+------------------------------------------------------------------+
inline bool CBaseStrategy::ValidateSignal(const STradeSignal &signal)
{
   if(!signal.IsValid())
      return false;

   if(signal.type == SIGNAL_BUY && (signal.stopLossPrice >= signal.entryPrice || signal.takeProfit1Price <= signal.entryPrice))
      return false;

   if(signal.type == SIGNAL_SELL && (signal.stopLossPrice <= signal.entryPrice || signal.takeProfit1Price >= signal.entryPrice))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Log State Helper                                                 |
//+------------------------------------------------------------------+
inline void CBaseStrategy::LogState(string message)
{
   if(m_logger != NULL)
   {
      m_logger.Info(message, m_strategyName);
   }
}

#endif // LEGSTECH_CORE_BASESTRATEGY_MQH
