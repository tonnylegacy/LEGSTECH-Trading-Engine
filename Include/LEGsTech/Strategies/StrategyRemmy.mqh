//+------------------------------------------------------------------+
//|                                                StrategyRemmy.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_STRATEGIES_STRATEGYREMMY_MQH
#define LEGSTECH_STRATEGIES_STRATEGYREMMY_MQH

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
//| Class CStrategyRemmy                                             |
//| REMMY: M15 Momentum & Multi-Timeframe Continuation Architecture  |
//| Dual Position Setup: Pos 1 (Banker TP1) + Pos 2 (Runner Auto-BE) |
//+------------------------------------------------------------------+
class CStrategyRemmy : public CBaseStrategy
{
private:
   // Collaborator Subsystems
   CSymbolHelper        *m_symbolHelper;
   CRiskEngine          *m_riskEngine;
   CExecutionEngine     *m_execEngine;
   CPositionManager     *m_posManager;
   CFractalDetector     *m_fractalDetector;
   bool                  m_ownsEngines;
   bool                  m_ownsFractalDetector;

   // Strategy Configuration
   SStrategyConfig       m_config;

   // Swing & Breakout Setup Structures
   SRemmyStructure       m_setupBuy;
   SRemmyStructure       m_setupSell;

   // Offline / Deterministic Testing Support
   bool                  m_mockMode;
   MqlRates              m_syntheticRates[];
   int                   m_syntheticRatesCount;

   // Indicator Handles (Lifecycle Managed in InitWithEngines / Deinit)
   int                   m_emaHandle;
   int                   m_atrHandle;

   // Multi-Timeframe Cascade Helpers
   ENUM_DAILY_BIAS       GetDailyBias();
   bool                  CheckH4Confirmation(ENUM_DAILY_BIAS bias);
   bool                  CheckH1Momentum(ENUM_DAILY_BIAS bias);
   bool                  CheckM15FractalTrigger(ENUM_DAILY_BIAS bias, const MqlRates &rates[], int totalRates, SFractalPoint &outFractal);

   // Internal processing helpers
   bool                  ProcessRates(const MqlRates &rates[], int totalRates);
   bool                  BuildSignal(bool isBuy, const SRemmyStructure &setup, STradeSignal &outSignal);
   bool                  CheckOverextensionAndTrend(bool isBuy, const MqlRates &rates[], int totalRates);
   void                  HandleManagingState(const MqlRates &rates[], int totalRates);

public:
                         CStrategyRemmy();
   virtual              ~CStrategyRemmy();

   // IStrategy Contract Implementation
   virtual bool          Init(const string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_M15);
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
                                         CLogger *logger);

   // Offline / Deterministic Testing
   void                  SetMockMode(bool enabled);
   bool                  IsMockMode() const { return m_mockMode; }
   void                  SetSyntheticRates(const MqlRates &rates[], int count);
   bool                  EvaluateSetupFromRates(const MqlRates &rates[], int totalRates);
   void                  ManageOpenPositionsFromRates(const MqlRates &rates[], int totalRates);

   // Execution Dispatcher
   bool                  ExecuteCurrentSignal();

   // Getters & Accessors
   void                  SetConfig(const SStrategyConfig &cfg)          { m_config = cfg; }
   void                  GetConfig(SStrategyConfig &outCfg) const       { outCfg = m_config; }
   bool                  GetBuySetup(SRemmyStructure &outSetup) const   { outSetup = m_setupBuy; return m_setupBuy.isValid; }
   bool                  GetSellSetup(SRemmyStructure &outSetup) const  { outSetup = m_setupSell; return m_setupSell.isValid; }
   CFractalDetector*     GetFractalDetector()                           { return m_fractalDetector; }
   CPositionManager*     GetPositionManager()                           { return m_posManager; }
   CRiskEngine*          GetRiskEngine()                                { return m_riskEngine; }
   CExecutionEngine*     GetExecutionEngine()                           { return m_execEngine; }
   CSymbolHelper*        GetSymbolHelper()                              { return m_symbolHelper; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStrategyRemmy::CStrategyRemmy()
{
   m_symbol              = "";
   m_timeframe           = PERIOD_M15;
   m_magicNumber         = DEFAULT_MAGIC_RM;
   m_strategyType        = STRATEGY_REMMY;
   m_strategyName        = "RM";
   m_isInitialized       = false;
   m_ownsEngines         = false;
   m_ownsFractalDetector = false;
   m_mockMode            = false;
   m_syntheticRatesCount = 0;
   m_emaHandle           = INVALID_HANDLE;
   m_atrHandle           = INVALID_HANDLE;

   m_symbolHelper        = NULL;
   m_riskEngine          = NULL;
   m_execEngine          = NULL;
   m_posManager          = NULL;
   m_fractalDetector     = NULL;

   m_config.SetDefaults();
   m_setupBuy.Reset();
   m_setupSell.Reset();
   ArrayResize(m_syntheticRates, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStrategyRemmy::~CStrategyRemmy()
{
   Deinit();
   if(m_ownsEngines)
   {
      if(CheckPointer(m_symbolHelper) == POINTER_DYNAMIC)    { delete m_symbolHelper;    m_symbolHelper = NULL; }
      if(CheckPointer(m_riskEngine) == POINTER_DYNAMIC)      { delete m_riskEngine;      m_riskEngine = NULL; }
      if(CheckPointer(m_execEngine) == POINTER_DYNAMIC)      { delete m_execEngine;      m_execEngine = NULL; }
      if(CheckPointer(m_posManager) == POINTER_DYNAMIC)      { delete m_posManager;      m_posManager = NULL; }
   }
   if((m_ownsEngines || m_ownsFractalDetector) && CheckPointer(m_fractalDetector) == POINTER_DYNAMIC)
   {
      delete m_fractalDetector;
      m_fractalDetector = NULL;
   }
   ArrayFree(m_syntheticRates);
}

//+------------------------------------------------------------------+
//| Standard Initialization                                          |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::Init(const string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol    = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe = timeframe;

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
      m_ownsFractalDetector = true;
   }

   int emaPeriod = (m_config.remmyEmaPeriod > 0) ? m_config.remmyEmaPeriod : 20;
   m_emaHandle   = iMA(m_symbol, PERIOD_M15, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_atrHandle   = iATR(m_symbol, PERIOD_M15, 14);

   m_isInitialized = true;
   LogState(StringFormat("REMMY Strategy initialized on %s %s (Magic: %I64u)",
            m_symbol, EnumToString(m_timeframe), m_magicNumber));
   return true;
}

//+------------------------------------------------------------------+
//| Advanced Dependency Injection Initializer                        |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::InitWithEngines(const string symbol,
                                           ENUM_TIMEFRAMES timeframe,
                                           const SStrategyConfig &config,
                                           CSymbolHelper *symHelper,
                                           CRiskEngine *riskEngine,
                                           CExecutionEngine *execEngine,
                                           CPositionManager *posMgr,
                                           CLogger *logger)
{
   m_symbol        = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe     = timeframe;
   m_config        = config;
   m_magicNumber   = config.magicNumber;
   m_symbolHelper  = symHelper;
   m_riskEngine    = riskEngine;
   m_execEngine    = execEngine;
   m_posManager    = posMgr;
   m_logger        = logger;
   m_ownsEngines   = false;

   if(m_fractalDetector == NULL)
   {
      m_fractalDetector = new CFractalDetector();
      m_fractalDetector.Init(m_symbol, m_timeframe, 100);
      m_ownsFractalDetector = true;
   }

   if(m_stateMachine != NULL)
   {
      m_stateMachine.Init(m_logger, m_strategyName, EA_STATE_IDLE);
   }

   int emaPeriod = (config.remmyEmaPeriod > 0) ? config.remmyEmaPeriod : 20;
   m_emaHandle   = iMA(m_symbol, PERIOD_M15, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_atrHandle   = iATR(m_symbol, PERIOD_M15, 14);

   m_isInitialized = true;
   LogState(StringFormat("REMMY Strategy initialized via DI on %s %s (Magic: %I64u)",
            m_symbol, EnumToString(m_timeframe), m_magicNumber));
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::Deinit()
{
   CBaseStrategy::Deinit();
   if(m_emaHandle != INVALID_HANDLE) { IndicatorRelease(m_emaHandle); m_emaHandle = INVALID_HANDLE; }
   if(m_atrHandle != INVALID_HANDLE) { IndicatorRelease(m_atrHandle); m_atrHandle = INVALID_HANDLE; }
   m_setupBuy.Reset();
   m_setupSell.Reset();
   m_lastSignal.Clear();
}

//+------------------------------------------------------------------+
//| Set Mock Mode for Offline Deterministic Testing                  |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::SetMockMode(bool enabled)
{
   m_mockMode = enabled;
   if(m_execEngine != NULL) m_execEngine.SetMockExecutionMode(enabled);
   if(m_posManager != NULL) m_posManager.SetMockMode(enabled);
}

//+------------------------------------------------------------------+
//| Set Synthetic Rates for Deterministic Test Evaluation            |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::SetSyntheticRates(const MqlRates &rates[], int count)
{
   m_syntheticRatesCount = count;
   ArrayResize(m_syntheticRates, count);
   for(int i = 0; i < count; i++)
   {
      m_syntheticRates[i] = rates[i];
   }
}

//+------------------------------------------------------------------+
//| OnTick Event Handler                                             |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::OnTickHandler()
{
   if(!m_isInitialized)
      return;

   // Check for New Bar on M15 timeframe
   if(IsNewBar(m_timeframe))
   {
      OnBarHandler(m_timeframe);
   }

   // Active Trade Management on every tick
   ENUM_EA_STATE state = GetState();
   if(state == EA_STATE_MANAGING)
   {
      ManageOpenPositions();
   }
}

//+------------------------------------------------------------------+
//| OnBar Event Handler (PERIOD_M15 Guard)                           |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::OnBarHandler(ENUM_TIMEFRAMES tf)
{
   if(!m_isInitialized || tf != m_timeframe)
      return;

   ENUM_EA_STATE state = GetState();

   if(state == EA_STATE_IDLE || state == EA_STATE_ANALYSING ||
      state == EA_STATE_SETUP_FOUND || state == EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP)
   {
      EvaluateSetup();

      if(GetState() == EA_STATE_ENTRY_READY)
      {
         ExecuteCurrentSignal();
      }
   }
   else if(state == EA_STATE_MANAGING)
   {
      ManageOpenPositions();
   }
}

//+------------------------------------------------------------------+
//| Step 1: Daily Market Direction (D1 Timeframe)                    |
//+------------------------------------------------------------------+
inline ENUM_DAILY_BIAS CStrategyRemmy::GetDailyBias()
{
   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   return DAILY_BIAS_NONE;
}

//+------------------------------------------------------------------+
//| Step 2: H4 Market Confirmation                                   |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::CheckH4Confirmation(ENUM_DAILY_BIAS dailyBias)
{
   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   return (dailyBias != DAILY_BIAS_NONE && false);
}

//+------------------------------------------------------------------+
//| Step 3: H1 Momentum Alignment                                    |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::CheckH1Momentum(ENUM_DAILY_BIAS dailyBias)
{
   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   return (dailyBias != DAILY_BIAS_NONE && false);
}

//+------------------------------------------------------------------+
//| Step 4: M15 Fractal Trigger & Retracement Confirmation           |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::CheckM15FractalTrigger(ENUM_DAILY_BIAS dailyBias, const MqlRates &rates[], int totalRates, SFractalPoint &outFractal)
{
   outFractal.Reset();
   if(m_fractalDetector == NULL || totalRates < 7)
      return false;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   return (dailyBias != DAILY_BIAS_NONE && rates[0].time > 0 && false);
}

//+------------------------------------------------------------------+
//| Evaluate Market Setup from Live Chart Data                       |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::EvaluateSetup()
{
   if(!m_isInitialized || m_fractalDetector == NULL)
      return;

   if(m_config.useSessionFilter)
   {
      MqlDateTime dt;
      datetime curTime = (m_symbolHelper != NULL) ? m_symbolHelper.GetTickTime() : TimeCurrent();
      TimeToStruct(curTime, dt);
      if(dt.hour < m_config.sessionStartHour || dt.hour >= m_config.sessionEndHour)
         return;
   }

   if(m_mockMode && m_syntheticRatesCount >= 10)
   {
      EvaluateSetupFromRates(m_syntheticRates, m_syntheticRatesCount);
      return;
   }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(m_symbol, m_timeframe, 0, 100, rates);
   if(copied < 10)
   {
      LogState("EvaluateSetup: Insufficient M15 rates available.");
      return;
   }

   ProcessRates(rates, copied);
}

//+------------------------------------------------------------------+
//| Evaluate Setup from Synthetic Rates Array (Offline Compatible)   |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::EvaluateSetupFromRates(const MqlRates &rates[], int totalRates)
{
   if(totalRates < 10 || m_fractalDetector == NULL)
      return false;

   return ProcessRates(rates, totalRates);
}

//+------------------------------------------------------------------+
//| Core Market Rate Processing (Public Baseline Placeholder)        |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::ProcessRates(const MqlRates &rates[], int totalRates)
{
   ENUM_EA_STATE currentState = GetState();
   if(currentState == EA_STATE_EXECUTED || currentState == EA_STATE_MANAGING)
      return false;

   if(m_posManager != NULL && m_posManager.GetActiveTicketCount() > 0)
      return false;

   if(currentState == EA_STATE_IDLE && m_stateMachine != NULL)
      m_stateMachine.TransitionTo(EA_STATE_ANALYSING, "Scanning M15 Baseline");

   if(m_config.remmyUseSessionFilter)
   {
      if(!CSessionFilter::IsInsideGmtTradingWindow(m_config.remmySessionStartGmt, m_config.remmySessionEndGmt))
         return false;
   }

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   // Public baseline placeholder: returns no signal in mirror build; live alpha weights reside in private vault.
   if(totalRates < 20)
      return false;

   ENUM_DAILY_BIAS dailyBias = GetDailyBias();
   if(dailyBias == DAILY_BIAS_NONE)
   {
      m_setupBuy.Reset();
      m_setupSell.Reset();
      m_lastSignal.Clear();
      return false;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check Overextension (EMA/ATR Guard)                              |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::CheckOverextensionAndTrend(bool isBuy, const MqlRates &rates[], int totalRates)
{
   if(totalRates < 2) return true;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   // Indicator handle health check preserved for deterministic resource verification
   if(m_emaHandle == INVALID_HANDLE || m_atrHandle == INVALID_HANDLE)
      return (isBuy || !isBuy);

   return true;
}

//+------------------------------------------------------------------+
//| Build Valid STradeSignal from Setup Structure                    |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::BuildSignal(bool isBuy, const SRemmyStructure &setup, STradeSignal &outSignal)
{
   outSignal.Clear();
   if(!setup.isValid || m_symbolHelper == NULL)
      return false;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   // Baseline placeholder structural SL/TP construction
   double pipDist = m_symbolHelper.PipToPrice(100.0);
   outSignal.type             = isBuy ? SIGNAL_BUY : SIGNAL_SELL;
   outSignal.strategy         = STRATEGY_REMMY;
   outSignal.symbol           = m_symbol;
   outSignal.timestamp        = TimeCurrent();
   outSignal.entryPrice       = isBuy ? m_symbolHelper.GetAsk() : m_symbolHelper.GetBid();
   outSignal.stopLossPrice    = isBuy ? (outSignal.entryPrice - pipDist) : (outSignal.entryPrice + pipDist);
   outSignal.takeProfit1Price = isBuy ? (outSignal.entryPrice + pipDist) : (outSignal.entryPrice - pipDist);
   outSignal.takeProfit2Price = 0.0;
   outSignal.isDualPosition   = m_config.remmyRunnerEnabled;
   outSignal.riskAmountOrPct  = (m_config.riskMode == RISK_MODE_FIXED_LOT) ? m_config.fixedLotSize : m_config.riskPercent;
   outSignal.magicNumber      = m_magicNumber;
   outSignal.setupDescription = "RM Public Baseline Placeholder";

   return ValidateSignal(outSignal);
}

//+------------------------------------------------------------------+
//| Execute Validated Signal through Execution Engine                |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::ExecuteCurrentSignal()
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

   // 1. Safety Filters & Trading Permission Verification
   string denyReason;
   if(!m_riskEngine.IsTradingAllowed(denyReason))
   {
      LogState(StringFormat("Execution BLOCKED by RiskEngine: %s", denyReason));
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "RiskEngine Guard Trip");
      m_lastSignal.Clear();
      return false;
   }

   // 2. Dynamic Risk & Lot Sizing Calculation
   double lot1 = 0.0, lot2 = 0.0;
   if(!m_riskEngine.CalculateLotSize(m_lastSignal.entryPrice, m_lastSignal.stopLossPrice, lot1, lot2, m_lastSignal.isDualPosition, m_lastSignal.riskAmountOrPct))
   {
      LogState("Execution BLOCKED: Lot size calculation failed.");
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Lot Size Calc Failure");
      m_lastSignal.Clear();
      return false;
   }

   ENUM_ORDER_TYPE orderType = (m_lastSignal.type == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   // 3. Margin Pre-Check
   if(!m_riskEngine.CheckMargin(orderType, lot1 + lot2, denyReason))
   {
      LogState(StringFormat("Execution BLOCKED by Margin Guard: %s", denyReason));
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Insufficient Margin");
      m_lastSignal.Clear();
      return false;
   }

   // 3.1 Cross-chart execution mutex lock
   if(!m_riskEngine.AcquireExecutionLock(3))
   {
      LogState("Execution BLOCKED: Another chart instance is executing orders on this symbol. Waiting for lock release...");
      return false;
   }

   // 4. Dispatch Order(s)
   m_execEngine.SetMagicNumber(m_magicNumber);
   ulong ticket1 = 0, ticket2 = 0;
   bool executed = false;

   if(m_lastSignal.isDualPosition && lot2 > 0.0)
   {
      executed = m_execEngine.ExecuteDualPositionOrder(orderType, lot1, lot2,
                                                       m_lastSignal.stopLossPrice,
                                                       m_lastSignal.takeProfit1Price,
                                                       m_lastSignal.takeProfit2Price,
                                                       "RM", ticket1, ticket2);
   }
   else
   {
      executed = m_execEngine.ExecuteMarketOrder(orderType, lot1,
                                                 m_lastSignal.stopLossPrice,
                                                 m_lastSignal.takeProfit1Price,
                                                 "RM", ticket1);
   }

   m_riskEngine.ReleaseExecutionLock();

   if(!executed || ticket1 == 0)
   {
      LogState("Execution Engine Failed to dispatch orders.");
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Execution Engine Failure");
      m_lastSignal.Clear();
      return false;
   }

   // 5. Register with Position Manager
   m_posManager.RegisterPositions(ticket1, ticket2, STRATEGY_REMMY, orderType,
                                  m_lastSignal.entryPrice, m_lastSignal.stopLossPrice,
                                  m_lastSignal.takeProfit1Price);

   // 6. Cache Position Info
   m_positionInfo.ticket1            = ticket1;
   m_positionInfo.ticket2            = ticket2;
   m_positionInfo.strategy           = STRATEGY_REMMY;
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
   m_positionInfo.comment            = "RM";

   // 7. Advance FSM
   m_stateMachine.TransitionTo(EA_STATE_EXECUTED, "Orders Filled");
   m_stateMachine.TransitionTo(EA_STATE_MANAGING, "Managing Active Positions (Auto-BE & Runner)");

   LogState(StringFormat("RM Executed Successfully: Ticket1=#%I64u (Lot=%.2f, TP1=%.5f), Ticket2=#%I64u (Lot=%.2f, RUNNER)",
            ticket1, lot1, m_lastSignal.takeProfit1Price, ticket2, lot2));
   return true;
}

//+------------------------------------------------------------------+
//| Manage Open Positions (Live Tick Mode)                           |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::ManageOpenPositions()
{
   if(!m_isInitialized || m_posManager == NULL)
      return;

   m_posManager.ApplyActiveTrailing(m_config);

   if(m_config.remmyAutoBeOnTp1)
   {
      m_posManager.UpdatePositionState(m_config.remmyBeLockPips);
   }

   if(m_mockMode && m_syntheticRatesCount >= 5)
   {
      HandleManagingState(m_syntheticRates, m_syntheticRatesCount);
   }
   else
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, 0, 50, rates);
      if(copied >= 5)
      {
         HandleManagingState(rates, copied);
      }
   }

   if(m_posManager.GetActiveTicketCount() == 0)
   {
      m_positionInfo.isPosition1Closed = true;
      m_positionInfo.isPosition2Closed = true;

      if(GetState() == EA_STATE_MANAGING)
      {
         m_stateMachine.TransitionTo(EA_STATE_CLOSED, "All Positions Terminated");
         m_stateMachine.TransitionTo(EA_STATE_IDLE, "Ready for Next Cycle");
      }
      m_setupBuy.Reset();
      m_setupSell.Reset();
      m_lastSignal.Clear();
   }
}

//+------------------------------------------------------------------+
//| Manage Open Positions from Synthetic Rates (Offline Mode)        |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::ManageOpenPositionsFromRates(const MqlRates &rates[], int totalRates)
{
   if(!m_isInitialized || m_posManager == NULL || totalRates < 5)
      return;

   if(m_config.remmyAutoBeOnTp1)
   {
      m_posManager.UpdatePositionState(m_config.remmyBeLockPips);
   }
   HandleManagingState(rates, totalRates);

   if(m_posManager.GetActiveTicketCount() == 0)
   {
      m_positionInfo.isPosition1Closed = true;
      m_positionInfo.isPosition2Closed = true;

      if(GetState() == EA_STATE_MANAGING)
      {
         m_stateMachine.TransitionTo(EA_STATE_CLOSED, "All Positions Terminated");
         m_stateMachine.TransitionTo(EA_STATE_IDLE, "Ready for Next Cycle");
      }
      m_setupBuy.Reset();
      m_setupSell.Reset();
      m_lastSignal.Clear();
   }
}

//+------------------------------------------------------------------+
//| Handle Runner Opposite Fractal Exit Logic                        |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::HandleManagingState(const MqlRates &rates[], int totalRates)
{
   if(m_posManager == NULL || m_fractalDetector == NULL || totalRates < 5)
      return;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
}

//+------------------------------------------------------------------+
//| Retrieve Active Trade Signals                                    |
//+------------------------------------------------------------------+
inline bool CStrategyRemmy::GetTradeSignals(STradeSignal &outSignal)
{
   return CBaseStrategy::GetTradeSignals(outSignal);
}

//+------------------------------------------------------------------+
//| Reset Strategy Internal State                                    |
//+------------------------------------------------------------------+
inline void CStrategyRemmy::Reset()
{
   CBaseStrategy::Reset();
   m_setupBuy.Reset();
   m_setupSell.Reset();
   m_syntheticRatesCount = 0;
   ArrayResize(m_syntheticRates, 0);
}

//+------------------------------------------------------------------+
//| Generate Strategy Telemetry Status String                        |
//+------------------------------------------------------------------+
inline string CStrategyRemmy::GetStatusString()
{
   return StringFormat("RM | State: %s | TF: M15 | ActiveTickets: %d",
                       (m_stateMachine != NULL) ? m_stateMachine.GetCurrentStateName() : "N/A",
                       (m_posManager != NULL) ? m_posManager.GetActiveTicketCount() : 0);
}

#endif // LEGSTECH_STRATEGIES_STRATEGYREMMY_MQH
