//+------------------------------------------------------------------+
//|                                                   StrategyDB.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_STRATEGIES_STRATEGYDB_MQH
#define LEGSTECH_STRATEGIES_STRATEGYDB_MQH

#include "..\Core\Defs.mqh"
#include "..\Core\Logger.mqh"
#include "..\Core\StateMachine.mqh"
#include "..\Core\BaseStrategy.mqh"
#include "..\Engine\SymbolHelper.mqh"
#include "..\Engine\RiskEngine.mqh"
#include "..\Engine\ExecutionEngine.mqh"
#include "..\Engine\PositionManager.mqh"
#include "..\Indicators\FractalDetector.mqh"
#include "..\Indicators\SessionFilter.mqh"

//+------------------------------------------------------------------+
//| Struct for DB Strategy Setup State                               |
//+------------------------------------------------------------------+
struct SDBSetup
{
   bool              isValid;                // True if valid setup identified
   bool              isBuy;                  // True = BUY setup, False = SELL setup
   ENUM_DAILY_BIAS   dailyBias;              // Evaluated D1 bias
   datetime          biasTime;               // Time of evaluated D1 bar
   bool              isSessionActive;        // True if inside active window
   bool              isMorningSession;       // True if morning window
   bool              isEveningSession;       // True if evening window
   datetime          sessionTime;            // Server timestamp during window
   SFractalPoint     refSwingFractal;        // Reference M30 swing fractal
   double            swingPivotPrice;        // M30 swing pivot price
   double            bufferPips;             // Stop buffer in pips
   double            calculatedSL;           // Calculated Stop Loss
   double            calculatedTP;           // Calculated Take Profit
   double            triggerClosePrice;      // M30 candle close price
   datetime          triggerTime;            // M30 candle timestamp
   bool              isContinuationLocked;   // True if lock is currently engaged
   int               pullbackCandleCount;    // M15 counter-trend candle count
   bool              pullbackResetAchieved;  // True if pullback unlocked system

   void Reset()
   {
      isValid               = false;
      isBuy                 = false;
      dailyBias             = DAILY_BIAS_NONE;
      biasTime              = 0;
      isSessionActive       = false;
      isMorningSession      = false;
      isEveningSession      = false;
      sessionTime           = 0;
      refSwingFractal.Reset();
      swingPivotPrice       = 0.0;
      bufferPips            = 15.0;
      calculatedSL          = 0.0;
      calculatedTP          = 0.0;
      triggerClosePrice     = 0.0;
      triggerTime           = 0;
      isContinuationLocked  = false;
      pullbackCandleCount   = 0;
      pullbackResetAchieved = false;
   }
};

//+------------------------------------------------------------------+
//| Class CStrategyDB                                                |
//| DB: Daily Bias & M30 Session-Gated Continuation Architecture     |
//+------------------------------------------------------------------+
class CStrategyDB : public CBaseStrategy
{
private:
   // Collaborator Subsystems
   CSymbolHelper        *m_symbolHelper;
   CRiskEngine          *m_riskEngine;
   CExecutionEngine     *m_execEngine;
   CPositionManager     *m_posManager;
   CFractalDetector     *m_fractalDetector;
   CSessionFilter       *m_sessionFilter;

   bool                  m_ownsEngines;
   bool                  m_ownsIndicators;

   // Strategy Configuration
   SStrategyConfig       m_config;

   // Active Setup State
   SDBSetup              m_setup;
   bool                  m_continuationLocked;
   datetime              m_continuationLockTime;
   datetime              m_lastConfirmedM30BarTime;

   // Offline / Deterministic Testing Support
   bool                  m_mockMode;
   datetime              m_mockServerTime;
   MqlRates              m_syntheticD1Rates[];
   int                   m_syntheticD1Count;
   MqlRates              m_syntheticM30Rates[];
   int                   m_syntheticM30Count;
   MqlRates              m_syntheticM15Rates[];
   int                   m_syntheticM15Count;

   // Internal processing helpers
   bool                  BuildSignal(const SDBSetup &setup, STradeSignal &outSignal, double currentPrice = 0.0);

public:
                         CStrategyDB();
   virtual              ~CStrategyDB();

   // IStrategy Contract Implementation
   virtual bool          Init(const string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_M30);
   virtual void          Deinit();
   virtual void          OnTickHandler();
   virtual void          OnBarHandler(ENUM_TIMEFRAMES tf);
   virtual void          EvaluateSetup();
   virtual bool          GetTradeSignals(STradeSignal &outSignal);
   virtual void          ManageOpenPositions();
   virtual void          Reset();
   virtual string        GetStatusString();

   // Advanced Dependency Injection Initializer
   bool                  InitWithEngines(const string symbol,
                                         ENUM_TIMEFRAMES timeframe,
                                         const SStrategyConfig &config,
                                         CSymbolHelper *symHelper,
                                         CRiskEngine *riskEngine,
                                         CExecutionEngine *execEngine,
                                         CPositionManager *posMgr,
                                         CLogger *logger,
                                         CFractalDetector *fractalDet = NULL,
                                         CSessionFilter *sessionFilter = NULL,
                                         int brokerUtcOffset = 2);

   // Offline / Deterministic Testing Support
   void                  SetMockMode(bool enabled);
   bool                  IsMockMode() const { return m_mockMode; }
   void                  SetSyntheticD1Rates(const MqlRates &rates[], int count);
   void                  SetSyntheticM30Rates(const MqlRates &rates[], int count);
   void                  SetSyntheticM15Rates(const MqlRates &rates[], int count);
   void                  SetMockServerTime(datetime serverTime);
   bool                  EvaluateSetupFromRates(const MqlRates &d1Rates[], int d1Total,
                                                const MqlRates &m30Rates[], int m30Total,
                                                const MqlRates &m15Rates[], int m15Total,
                                                datetime currentServerTime = 0,
                                                double currentPrice = 0.0);
   void                  ManageOpenPositionsFromRates(const MqlRates &rates[], int totalRates);

   // Execution Dispatcher
   bool                  ExecuteCurrentSignal();

   // Continuation Lock & Pullback Engine Accessors
   void                  SetContinuationLock(bool locked)
   {
      m_continuationLocked = locked;
      if(m_sessionFilter != NULL) m_sessionFilter.SetContinuationLock(locked);
      m_setup.isContinuationLocked = locked;
   }
   bool                  IsContinuationLocked() const { return m_continuationLocked; }

   // Setters & Configuration Accessors
   void                  SetConfig(const SStrategyConfig &cfg)          { m_config = cfg; }
   void                  GetConfig(SStrategyConfig &outCfg) const       { outCfg = m_config; }
   bool                  GetActiveSetup(SDBSetup &outSetup) const       { outSetup = m_setup; return m_setup.isValid; }

   // Subsystem Accessors
   CSessionFilter*       GetSessionFilter()                             { return m_sessionFilter; }
   CFractalDetector*     GetFractalDetector()                           { return m_fractalDetector; }
   CPositionManager*     GetPositionManager()                           { return m_posManager; }
   CRiskEngine*          GetRiskEngine()                                { return m_riskEngine; }
   CExecutionEngine*     GetExecutionEngine()                           { return m_execEngine; }
   CSymbolHelper*        GetSymbolHelper()                              { return m_symbolHelper; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStrategyDB::CStrategyDB()
{
   m_symbol              = "";
   m_timeframe           = PERIOD_M30;
   m_magicNumber         = DEFAULT_MAGIC_DB;
   m_strategyType        = STRATEGY_DB;
   m_strategyName        = "DB";
   m_isInitialized       = false;
   m_ownsEngines         = false;
   m_ownsIndicators      = false;
   m_mockMode            = false;
   m_continuationLocked  = false;
   m_continuationLockTime = 0;
   m_lastConfirmedM30BarTime = 0;
   m_mockServerTime      = 0;
   m_syntheticD1Count    = 0;
   m_syntheticM30Count   = 0;
   m_syntheticM15Count   = 0;

   m_symbolHelper        = NULL;
   m_riskEngine          = NULL;
   m_execEngine          = NULL;
   m_posManager          = NULL;
   m_fractalDetector     = NULL;
   m_sessionFilter       = NULL;

   m_config.SetDefaults();
   m_config.strategyType = STRATEGY_DB;
   m_config.magicNumber  = DEFAULT_MAGIC_DB;
   m_setup.Reset();

   ArrayResize(m_syntheticD1Rates, 0);
   ArrayResize(m_syntheticM30Rates, 0);
   ArrayResize(m_syntheticM15Rates, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStrategyDB::~CStrategyDB()
{
   Deinit();
   if(m_ownsEngines)
   {
      if(CheckPointer(m_symbolHelper) == POINTER_DYNAMIC) { delete m_symbolHelper; m_symbolHelper = NULL; }
      if(CheckPointer(m_riskEngine) == POINTER_DYNAMIC)   { delete m_riskEngine;   m_riskEngine = NULL; }
      if(CheckPointer(m_execEngine) == POINTER_DYNAMIC)   { delete m_execEngine;   m_execEngine = NULL; }
      if(CheckPointer(m_posManager) == POINTER_DYNAMIC)   { delete m_posManager;   m_posManager = NULL; }
   }
   if(m_ownsIndicators)
   {
      if(CheckPointer(m_fractalDetector) == POINTER_DYNAMIC) { delete m_fractalDetector; m_fractalDetector = NULL; }
      if(CheckPointer(m_sessionFilter) == POINTER_DYNAMIC)   { delete m_sessionFilter;   m_sessionFilter = NULL; }
   }
   ArrayFree(m_syntheticD1Rates);
   ArrayFree(m_syntheticM30Rates);
   ArrayFree(m_syntheticM15Rates);
}

//+------------------------------------------------------------------+
//| Standard Initialization                                          |
//+------------------------------------------------------------------+
inline bool CStrategyDB::Init(const string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol    = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe = timeframe;
   m_lastConfirmedM30BarTime = 0;

   if(!CBaseStrategy::Init(m_symbol, m_timeframe))
      return false;

   if(m_symbolHelper == NULL)
   {
      m_symbolHelper = new CSymbolHelper();
      m_symbolHelper.Init(m_symbol);
      m_ownsEngines = true;
   }

   if(m_execEngine == NULL)
   {
      m_execEngine = new CExecutionEngine();
      m_execEngine.Init(m_symbol, m_magicNumber, m_config.slippagePoints, m_symbolHelper);
   }

   if(m_riskEngine == NULL)
   {
      m_riskEngine = new CRiskEngine();
      m_riskEngine.Init(m_symbol, m_config.riskPercent, m_config.riskMode,
                        m_config.maxDailyLossPercent, (double)m_config.maxSpreadPips,
                        m_config.maxDailyTrades, m_symbolHelper);
   }

   if(m_posManager == NULL)
   {
      m_posManager = new CPositionManager();
      m_posManager.Init(m_symbol, m_magicNumber, m_execEngine, m_symbolHelper);
   }

   if(m_fractalDetector == NULL)
   {
      m_fractalDetector = new CFractalDetector();
      m_fractalDetector.Init(m_symbol, m_timeframe, 100);
      m_ownsIndicators = true;
   }

   if(m_sessionFilter == NULL)
   {
      m_sessionFilter = new CSessionFilter();
      m_sessionFilter.Init(m_symbol, 2, m_config.dbStartHour1, m_config.dbStartHour2, 90, m_config.dbPullbackCandles);
      m_ownsIndicators = true;
   }
   else
   {
      m_sessionFilter.SetRequiredPullbackBars(m_config.dbPullbackCandles);
   }

   m_isInitialized = true;
   LogState(StringFormat("DB Strategy initialized on %s TF: %s (Magic: %I64u)",
            m_symbol, EnumToString(m_timeframe), m_magicNumber));
   return true;
}

//+------------------------------------------------------------------+
//| Advanced Dependency Injection Initializer                        |
//+------------------------------------------------------------------+
inline bool CStrategyDB::InitWithEngines(const string symbol,
                                        ENUM_TIMEFRAMES timeframe,
                                        const SStrategyConfig &config,
                                        CSymbolHelper *symHelper,
                                        CRiskEngine *riskEngine,
                                        CExecutionEngine *execEngine,
                                        CPositionManager *posMgr,
                                        CLogger *logger,
                                        CFractalDetector *fractalDet,
                                        CSessionFilter *sessionFilter,
                                        int brokerUtcOffset)
{
   m_symbol        = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe     = timeframe;
   m_config        = config;
   m_config.strategyType = STRATEGY_DB;
   m_magicNumber   = config.magicNumber;
   m_symbolHelper  = symHelper;
   m_riskEngine    = riskEngine;
   m_execEngine    = execEngine;
   m_posManager    = posMgr;
   m_logger        = logger;
   m_ownsEngines   = false;

   if(fractalDet != NULL) { m_fractalDetector = fractalDet; }
   else
   {
      m_fractalDetector = new CFractalDetector();
      m_fractalDetector.Init(m_symbol, m_timeframe, 100);
      m_ownsIndicators = true;
   }

   if(sessionFilter != NULL)
   {
      m_sessionFilter = sessionFilter;
      m_sessionFilter.SetRequiredPullbackBars(m_config.dbPullbackCandles);
   }
   else
   {
      m_sessionFilter = new CSessionFilter();
      m_sessionFilter.Init(m_symbol, brokerUtcOffset, m_config.dbStartHour1, m_config.dbStartHour2, 90, m_config.dbPullbackCandles);
      m_ownsIndicators = true;
   }

   if(m_stateMachine != NULL)
   {
      m_stateMachine.Init(m_logger, m_strategyName, EA_STATE_IDLE);
   }

   m_isInitialized = true;
   m_lastConfirmedM30BarTime = 0;
   LogState(StringFormat("DB Strategy initialized via DI on %s TF: %s (Magic: %I64u)",
            m_symbol, EnumToString(m_timeframe), m_magicNumber));
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
inline void CStrategyDB::Deinit()
{
   CBaseStrategy::Deinit();
   m_setup.Reset();
   m_lastSignal.Clear();
}

//+------------------------------------------------------------------+
//| Set Mock Mode for Offline Deterministic Testing                  |
//+------------------------------------------------------------------+
inline void CStrategyDB::SetMockMode(bool enabled)
{
   m_mockMode = enabled;
   if(m_execEngine != NULL) m_execEngine.SetMockExecutionMode(enabled);
   if(m_posManager != NULL) m_posManager.SetMockMode(enabled);
}

inline void CStrategyDB::SetSyntheticD1Rates(const MqlRates &rates[], int count)
{
   m_syntheticD1Count = count;
   ArrayResize(m_syntheticD1Rates, count);
   for(int i = 0; i < count; i++) m_syntheticD1Rates[i] = rates[i];
}

inline void CStrategyDB::SetSyntheticM30Rates(const MqlRates &rates[], int count)
{
   m_syntheticM30Count = count;
   ArrayResize(m_syntheticM30Rates, count);
   for(int i = 0; i < count; i++) m_syntheticM30Rates[i] = rates[i];
}

inline void CStrategyDB::SetSyntheticM15Rates(const MqlRates &rates[], int count)
{
   m_syntheticM15Count = count;
   ArrayResize(m_syntheticM15Rates, count);
   for(int i = 0; i < count; i++) m_syntheticM15Rates[i] = rates[i];
}

inline void CStrategyDB::SetMockServerTime(datetime serverTime)
{
   m_mockServerTime = serverTime;
}

//+------------------------------------------------------------------+
//| OnTick Event Handler                                             |
//+------------------------------------------------------------------+
inline void CStrategyDB::OnTickHandler()
{
   if(!m_isInitialized)
      return;

   if(IsNewBar(m_timeframe))
      OnBarHandler(m_timeframe);

   if(IsNewBar(PERIOD_M15))
      OnBarHandler(PERIOD_M15);

   ENUM_EA_STATE state = GetState();
   if(state == EA_STATE_MANAGING)
      ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| OnBar Event Handler (PERIOD_M30 / PERIOD_M15 Guard)              |
//+------------------------------------------------------------------+
inline void CStrategyDB::OnBarHandler(ENUM_TIMEFRAMES tf)
{
   if(!m_isInitialized)
      return;

   ENUM_EA_STATE state = GetState();

   if(tf == m_timeframe)
   {
      if(state == EA_STATE_IDLE || state == EA_STATE_ANALYSING ||
         state == EA_STATE_SETUP_FOUND || state == EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP)
      {
         EvaluateSetup();

         if(GetState() == EA_STATE_ENTRY_READY)
            ExecuteCurrentSignal();
      }
      else if(state == EA_STATE_MANAGING)
      {
         ManageOpenPositions();
      }
   }
}

//+------------------------------------------------------------------+
//| Evaluate Market Setup from Live Chart Data                       |
//+------------------------------------------------------------------+
inline void CStrategyDB::EvaluateSetup()
{
   if(!m_isInitialized || m_sessionFilter == NULL || m_fractalDetector == NULL)
      return;

   if(m_mockMode && m_syntheticD1Count >= 2 && m_syntheticM30Count >= 5 && m_syntheticM15Count >= 3)
   {
      datetime sTime = (m_mockServerTime > 0) ? m_mockServerTime : m_syntheticM30Rates[0].time;
      double cPrice = (m_symbolHelper != NULL && m_symbolHelper.GetBid() > 0.0) ? m_symbolHelper.GetBid() : m_syntheticM30Rates[0].close;
      EvaluateSetupFromRates(m_syntheticD1Rates, m_syntheticD1Count,
                             m_syntheticM30Rates, m_syntheticM30Count,
                             m_syntheticM15Rates, m_syntheticM15Count,
                             sTime, cPrice);
      return;
   }

   MqlRates d1Rates[], m30Rates[], m15Rates[];
   ArraySetAsSeries(d1Rates, true);
   ArraySetAsSeries(m30Rates, true);
   ArraySetAsSeries(m15Rates, true);

   int copiedD1  = CopyRates(m_symbol, PERIOD_D1, 0, 5, d1Rates);
   int copiedM30 = CopyRates(m_symbol, m_timeframe, 0, 100, m30Rates);
   int copiedM15 = CopyRates(m_symbol, PERIOD_M15, 0, 50, m15Rates);
   if(copiedD1 < 2 || copiedM30 < 5 || copiedM15 < 3)
      return;

   datetime serverTime = (m_symbolHelper != NULL) ? m_symbolHelper.GetTickTime() : TimeCurrent();
   double currentPrice = (m_symbolHelper != NULL) ? m_symbolHelper.GetBid() : m30Rates[0].close;

   EvaluateSetupFromRates(d1Rates, copiedD1, m30Rates, copiedM30, m15Rates, copiedM15, serverTime, currentPrice);
}

//+------------------------------------------------------------------+
//| Evaluate Setup from Rates Arrays (Public Baseline Placeholder)   |
//+------------------------------------------------------------------+
inline bool CStrategyDB::EvaluateSetupFromRates(const MqlRates &d1Rates[], int d1Total,
                                               const MqlRates &m30Rates[], int m30Total,
                                               const MqlRates &m15Rates[], int m15Total,
                                               datetime currentServerTime,
                                               double currentPrice)
{
   if(d1Total < 2 || m30Total < 5 || m15Total < 3 || m_sessionFilter == NULL || m_fractalDetector == NULL)
      return false;

   ENUM_EA_STATE currentState = GetState();
   if(currentState == EA_STATE_EXECUTED || currentState == EA_STATE_MANAGING)
      return false;

   if(currentState == EA_STATE_IDLE && m_stateMachine != NULL)
      m_stateMachine.TransitionTo(EA_STATE_ANALYSING, "Evaluating D1 Bias & M30 Window (Baseline)");

   if(m_config.dbUseSessionFilter)
   {
      if(!CSessionFilter::IsInsideGmtTradingWindow(m_config.dbSessionStartGmt, m_config.dbSessionEndGmt))
         return false;
   }

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   // Public baseline placeholder: validates timeframe inputs without emitting live proprietary signals.
   if(currentServerTime <= 0 && currentPrice <= 0.0)
      return false;

   m_setup.Reset();
   m_lastSignal.Clear();
   return false;
}

//+------------------------------------------------------------------+
//| Build Valid STradeSignal (Public Baseline Placeholder)           |
//+------------------------------------------------------------------+
inline bool CStrategyDB::BuildSignal(const SDBSetup &setup, STradeSignal &outSignal, double currentPrice)
{
   outSignal.Clear();
   if(!setup.isValid || m_symbolHelper == NULL)
      return false;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   double slDist = m_symbolHelper.PipToPrice(m_config.dbSlPips);
   double tpDist = m_symbolHelper.PipToPrice(m_config.dbTpPips);
   bool isBuy = setup.isBuy;
   outSignal.type             = isBuy ? SIGNAL_BUY : SIGNAL_SELL;
   outSignal.strategy         = STRATEGY_DB;
   outSignal.symbol           = m_symbol;
   outSignal.timestamp        = TimeCurrent();
   outSignal.entryPrice       = (currentPrice > 0.0) ? currentPrice : (isBuy ? m_symbolHelper.GetAsk() : m_symbolHelper.GetBid());
   outSignal.stopLossPrice    = isBuy ? (outSignal.entryPrice - slDist) : (outSignal.entryPrice + slDist);
   outSignal.takeProfit1Price = isBuy ? (outSignal.entryPrice + tpDist) : (outSignal.entryPrice - tpDist);
   outSignal.takeProfit2Price = 0.0;
   outSignal.isDualPosition   = (m_config.enableDoublePosition && m_config.dbRunnerEnabled);
   outSignal.riskAmountOrPct  = (m_config.riskMode == RISK_MODE_FIXED_LOT) ? m_config.fixedLotSize : m_config.riskPercent;
   outSignal.magicNumber      = m_magicNumber;
   outSignal.setupDescription = "DB Public Baseline Placeholder";

   return ValidateSignal(outSignal);
}

//+------------------------------------------------------------------+
//| Execute Validated Signal through Execution Engine                |
//+------------------------------------------------------------------+
inline bool CStrategyDB::ExecuteCurrentSignal()
{
   if(GetState() != EA_STATE_ENTRY_READY || !m_lastSignal.IsValid())
   {
      LogState("ExecuteCurrentSignal: State is not ENTRY_READY or signal invalid.");
      return false;
   }

   if(m_riskEngine == NULL || m_execEngine == NULL || m_posManager == NULL || m_symbolHelper == NULL)
   {
      LogState("ExecuteCurrentSignal: Required engine collaborators are NULL.");
      return false;
   }

   string denyReason;
   if(!m_riskEngine.IsTradingAllowed(denyReason))
   {
      LogState(StringFormat("Execution BLOCKED by RiskEngine: %s", denyReason));
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "RiskEngine Guard Trip");
      m_lastSignal.Clear();
      return false;
   }

   double lot1 = 0.0, lot2 = 0.0;
   if(!m_riskEngine.CalculateLotSize(m_lastSignal.entryPrice, m_lastSignal.stopLossPrice, lot1, lot2, m_lastSignal.isDualPosition, m_lastSignal.riskAmountOrPct))
   {
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Lot Size Calc Failure");
      m_lastSignal.Clear();
      return false;
   }

   ENUM_ORDER_TYPE orderType = (m_lastSignal.type == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(!m_riskEngine.CheckMargin(orderType, lot1 + lot2, denyReason))
   {
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Insufficient Margin");
      m_lastSignal.Clear();
      return false;
   }

   // Cross-chart execution mutex lock
   if(!m_riskEngine.AcquireExecutionLock(3))
   {
      LogState("Execution BLOCKED: Another chart instance is executing orders on this symbol. Waiting for lock release...");
      return false;
   }

   m_execEngine.SetMagicNumber(m_magicNumber);
   ulong ticket1 = 0, ticket2 = 0;
   bool executed = false;
   if(m_lastSignal.isDualPosition && lot2 > 0.0)
   {
      executed = m_execEngine.ExecuteDualPositionOrder(orderType, lot1, lot2,
                                                       m_lastSignal.stopLossPrice,
                                                       m_lastSignal.takeProfit1Price,
                                                       m_lastSignal.takeProfit2Price,
                                                       "DB", ticket1, ticket2);
   }
   else
   {
      executed = m_execEngine.ExecuteMarketOrder(orderType, lot1,
                                                 m_lastSignal.stopLossPrice,
                                                 m_lastSignal.takeProfit1Price,
                                                 "DB", ticket1);
   }

   m_riskEngine.ReleaseExecutionLock();

   if(!executed || ticket1 == 0)
   {
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Execution Engine Failure");
      m_lastSignal.Clear();
      return false;
   }

   m_posManager.RegisterPositions(ticket1, ticket2, STRATEGY_DB, orderType,
                                  m_lastSignal.entryPrice, m_lastSignal.stopLossPrice,
                                  m_lastSignal.takeProfit1Price);

   m_positionInfo.ticket1            = ticket1;
   m_positionInfo.ticket2            = ticket2;
   m_positionInfo.strategy           = STRATEGY_DB;
   m_positionInfo.symbol             = m_symbol;
   m_positionInfo.positionType       = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   m_positionInfo.openPrice1         = m_lastSignal.entryPrice;
   m_positionInfo.openPrice2         = m_lastSignal.entryPrice;
   m_positionInfo.initialLot1        = lot1;
   m_positionInfo.initialLot2        = lot2;
   m_positionInfo.currentSL1         = m_lastSignal.stopLossPrice;
   m_positionInfo.currentSL2         = m_lastSignal.stopLossPrice;
   m_positionInfo.currentTP1         = m_lastSignal.takeProfit1Price;
   m_positionInfo.currentTP2         = 0.0;
   m_positionInfo.openTime           = TimeCurrent();
   m_positionInfo.isPosition1Closed  = false;
   m_positionInfo.isPosition2Closed  = (ticket2 == 0);
   m_positionInfo.isBreakEvenApplied = false;
   m_positionInfo.comment            = "DB";

   m_stateMachine.TransitionTo(EA_STATE_EXECUTED, "Orders Filled");
   m_stateMachine.TransitionTo(EA_STATE_MANAGING, "Managing Active Positions");
   return true;
}

//+------------------------------------------------------------------+
//| Manage Open Positions (Live Tick Mode)                           |
//+------------------------------------------------------------------+
inline void CStrategyDB::ManageOpenPositions()
{
   if(!m_isInitialized || m_posManager == NULL)
      return;

   m_posManager.ApplyActiveTrailing(m_config);
   m_posManager.UpdatePositionState(m_config.beLockPips, m_config.beTriggerPips);

   if(m_posManager.GetActiveTicketCount() == 0)
   {
      m_positionInfo.isPosition1Closed = true;
      m_positionInfo.isPosition2Closed = true;

      if(GetState() == EA_STATE_MANAGING)
      {
         m_stateMachine.TransitionTo(EA_STATE_CLOSED, "All Positions Terminated");
         m_stateMachine.TransitionTo(EA_STATE_IDLE, "Ready for Next Cycle");
      }
      m_setup.Reset();
      m_lastSignal.Clear();
   }
}

//+------------------------------------------------------------------+
//| Manage Open Positions from Synthetic Rates (Offline Mode)        |
//+------------------------------------------------------------------+
inline void CStrategyDB::ManageOpenPositionsFromRates(const MqlRates &rates[], int totalRates)
{
   if(!m_isInitialized || m_posManager == NULL || totalRates < 5)
      return;

   m_posManager.UpdatePositionState(m_config.beLockPips, m_config.beTriggerPips);

   if(m_posManager.GetActiveTicketCount() == 0)
   {
      m_positionInfo.isPosition1Closed = true;
      m_positionInfo.isPosition2Closed = true;

      if(GetState() == EA_STATE_MANAGING)
      {
         m_stateMachine.TransitionTo(EA_STATE_CLOSED, "All Positions Terminated");
         m_stateMachine.TransitionTo(EA_STATE_IDLE, "Ready for Next Cycle");
      }
      m_setup.Reset();
      m_lastSignal.Clear();
   }
}

//+------------------------------------------------------------------+
//| Retrieve Active Trade Signals                                    |
//+------------------------------------------------------------------+
inline bool CStrategyDB::GetTradeSignals(STradeSignal &outSignal)
{
   return CBaseStrategy::GetTradeSignals(outSignal);
}

//+------------------------------------------------------------------+
//| Reset Strategy Internal State                                    |
//+------------------------------------------------------------------+
inline void CStrategyDB::Reset()
{
   CBaseStrategy::Reset();
   m_setup.Reset();
   m_continuationLocked = false;
   m_continuationLockTime = 0;
   m_syntheticD1Count = 0;
   m_syntheticM30Count = 0;
   m_syntheticM15Count = 0;
   ArrayResize(m_syntheticD1Rates, 0);
   ArrayResize(m_syntheticM30Rates, 0);
   ArrayResize(m_syntheticM15Rates, 0);
}

//+------------------------------------------------------------------+
//| Generate Strategy Telemetry Status String                        |
//+------------------------------------------------------------------+
inline string CStrategyDB::GetStatusString()
{
   return StringFormat("DB | State: %s | TF: M30 | ActiveTickets: %d",
                       (m_stateMachine != NULL) ? m_stateMachine.GetCurrentStateName() : "N/A",
                       (m_posManager != NULL) ? m_posManager.GetActiveTicketCount() : 0);
}

#endif // LEGSTECH_STRATEGIES_STRATEGYDB_MQH
