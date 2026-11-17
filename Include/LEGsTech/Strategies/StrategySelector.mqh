//+------------------------------------------------------------------+
//|                                             StrategySelector.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_STRATEGIES_STRATEGYSELECTOR_MQH
#define LEGSTECH_STRATEGIES_STRATEGYSELECTOR_MQH

#include <Object.mqh>
#include "..\Core\Defs.mqh"
#include "..\Core\Logger.mqh"
#include "..\Core\StateMachine.mqh"
#include "..\Core\BaseStrategy.mqh"
#include "..\Engine\SymbolHelper.mqh"
#include "..\Engine\RiskEngine.mqh"
#include "..\Engine\ExecutionEngine.mqh"
#include "..\Engine\PositionManager.mqh"
#include "StrategyRemmy.mqh"
#include "StrategyCallisto.mqh"
#include "StrategyDB.mqh"
#include "StrategyPortfolio.mqh"

//+------------------------------------------------------------------+
//| Class CStrategySelector                                          |
//| Polymorphic Factory & Lifecycle Manager for LEGsTECH Strategies  |
//+------------------------------------------------------------------+
class CStrategySelector : public CObject
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   ENUM_STRATEGY_TYPE   m_activeType;
   SStrategyConfig      m_config;
   
   IStrategy           *m_activeStrategy;
   bool                 m_isInitialized;
   bool                 m_mockMode;
   
   // Collaborator Subsystems (Injected or Owned)
   CSymbolHelper       *m_symbolHelper;
   CRiskEngine         *m_riskEngine;
   CExecutionEngine    *m_execEngine;
   CPositionManager    *m_posManager;
   CLogger             *m_logger;
   bool                 m_ownsEngines;

   // Internal factory methods
   IStrategy*           CreateStrategyInstance(ENUM_STRATEGY_TYPE type);
   void                 DestroyActiveStrategy();
   void                 ResolveDefaultMagicNumber();

public:
                        CStrategySelector();
   virtual             ~CStrategySelector();

   // Dependency Injection Initializer
   bool                 Init(const string symbol,
                             ENUM_STRATEGY_TYPE stratType,
                             const SStrategyConfig &config,
                             CSymbolHelper *symHelper,
                             CRiskEngine *riskEngine,
                             CExecutionEngine *execEngine,
                             CPositionManager *posMgr,
                             CLogger *logger);

   // Standalone Initializer (for isolated testing)
   bool                 Init(const string symbol,
                             ENUM_STRATEGY_TYPE stratType,
                             ENUM_TIMEFRAMES tf = PERIOD_M15);

   void                 Deinit();

   // Strategy Switching & Re-configuration
   bool                 SetStrategy(ENUM_STRATEGY_TYPE newType, const SStrategyConfig &config);
   bool                 SetStrategy(ENUM_STRATEGY_TYPE newType);
   void                 SetConfig(const SStrategyConfig &config);
   void                 GetConfig(SStrategyConfig &outConfig) const { outConfig = m_config; }

   // Polymorphic Delegations (IStrategy Contract)
   void                 OnTickHandler();
   void                 OnBarHandler(ENUM_TIMEFRAMES tf);
   void                 EvaluateSetup();
   bool                 GetTradeSignals(STradeSignal &outSignal);
   void                 ManageOpenPositions();
   bool                 ExecuteCurrentSignal();
   void                 Reset();

   // Getters & Inquiries
   IStrategy*           GetActiveStrategy()          { return m_activeStrategy; }
   ENUM_STRATEGY_TYPE   GetActiveStrategyType() const{ return m_activeType; }
   string               GetActiveStrategyName() const;
   ENUM_EA_STATE        GetState();
   void                 SetState(ENUM_EA_STATE newState);
   string               GetStatusString();
   bool                 IsInitialized() const        { return m_isInitialized; }
   ulong                GetActiveMagicNumber() const { return m_config.magicNumber; }

   // Concrete Accessors for Testing & Specialized Diagnostics
   CStrategyRemmy*      GetRemmyStrategy();
   CStrategyCallisto*   GetCallistoStrategy();
   CStrategyDB*         GetDBStrategy();
   CStrategyPortfolio*  GetPortfolioStrategy();

   // Mock Controls for Offline Test Harness
   void                 SetMockMode(bool enabled);
   bool                 IsMockMode() const           { return m_mockMode; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStrategySelector::CStrategySelector()
{
   m_symbol         = "";
   m_timeframe      = PERIOD_M15;
   m_activeType     = STRATEGY_REMMY;
   m_activeStrategy = NULL;
   m_isInitialized  = false;
   m_mockMode       = false;
   m_ownsEngines    = false;

   m_symbolHelper   = NULL;
   m_riskEngine     = NULL;
   m_execEngine     = NULL;
   m_posManager     = NULL;
   m_logger         = NULL;

   m_config.SetDefaults();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStrategySelector::~CStrategySelector()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Dependency Injection Initializer                                 |
//+------------------------------------------------------------------+
bool CStrategySelector::Init(const string symbol,
                             ENUM_STRATEGY_TYPE stratType,
                             const SStrategyConfig &config,
                             CSymbolHelper *symHelper,
                             CRiskEngine *riskEngine,
                             CExecutionEngine *execEngine,
                             CPositionManager *posMgr,
                             CLogger *logger)
{
   Deinit();

   m_symbol       = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_activeType   = stratType;
   m_config       = config;
   m_symbolHelper = symHelper;
   m_riskEngine   = riskEngine;
   m_execEngine   = execEngine;
   m_posManager   = posMgr;
   m_logger       = logger;
   m_ownsEngines  = false;

   // Auto-resolve default magic number if not specified (0)
   ResolveDefaultMagicNumber();

   // Instantiate active strategy
   m_activeStrategy = CreateStrategyInstance(m_activeType);
   if(m_activeStrategy == NULL)
   {
      if(m_logger != NULL)
         m_logger.Error("Failed to instantiate active strategy instance in StrategySelector!", "SELECTOR");
      return false;
   }

   m_isInitialized = true;
   if(m_logger != NULL)
   {
      m_logger.Info(StringFormat("StrategySelector initialized successfully: Type = %s, Magic = %I64u, Symbol = %s",
                                 StrategyTypeToString(m_activeType), m_config.magicNumber, m_symbol), "SELECTOR");
   }

   return true;
}

//+------------------------------------------------------------------+
//| Standalone Initializer (Creates internal engines for tests)       |
//+------------------------------------------------------------------+
bool CStrategySelector::Init(const string symbol,
                             ENUM_STRATEGY_TYPE stratType,
                             ENUM_TIMEFRAMES tf)
{
   Deinit();

   m_symbol      = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe   = tf;
   m_activeType  = stratType;
   m_ownsEngines = true;

   m_config.SetDefaults();
   m_config.strategyType = stratType;
   ResolveDefaultMagicNumber();

   // Allocate standalone collaborator subsystem objects
   m_logger       = new CLogger();
   m_symbolHelper = new CSymbolHelper();
   m_riskEngine   = new CRiskEngine();
   m_execEngine   = new CExecutionEngine();
   m_posManager   = new CPositionManager();

   m_logger.Init("SELECTOR_STANDALONE", LOG_LEVEL_INFO, LOG_TARGET_CONSOLE);
   m_symbolHelper.Init(m_symbol);
   m_riskEngine.Init(m_symbol, m_config.riskPercent, m_config.riskMode, m_config.maxDailyLossPercent, m_config.maxSpreadPips, 2, m_symbolHelper);
   m_execEngine.Init(m_symbol, m_config.magicNumber, m_config.slippagePoints, m_symbolHelper);
   m_posManager.Init(m_symbol, m_config.magicNumber, m_execEngine, m_symbolHelper);

   m_activeStrategy = CreateStrategyInstance(m_activeType);
   if(m_activeStrategy == NULL)
   {
      m_logger.Error("Failed to instantiate standalone strategy instance!", "SELECTOR");
      return false;
   }

   m_isInitialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialization & Cleanup                                       |
//+------------------------------------------------------------------+
void CStrategySelector::Deinit()
{
   DestroyActiveStrategy();

   if(m_ownsEngines)
   {
      if(CheckPointer(m_posManager) == POINTER_DYNAMIC)   { delete m_posManager;   m_posManager = NULL; }
      if(CheckPointer(m_execEngine) == POINTER_DYNAMIC)   { delete m_execEngine;   m_execEngine = NULL; }
      if(CheckPointer(m_riskEngine) == POINTER_DYNAMIC)   { delete m_riskEngine;   m_riskEngine = NULL; }
      if(CheckPointer(m_symbolHelper) == POINTER_DYNAMIC) { delete m_symbolHelper; m_symbolHelper = NULL; }
      if(CheckPointer(m_logger) == POINTER_DYNAMIC)       { delete m_logger;       m_logger = NULL; }
      m_ownsEngines = false;
   }

   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Strategy Switching with Full Configuration                       |
//+------------------------------------------------------------------+
bool CStrategySelector::SetStrategy(ENUM_STRATEGY_TYPE newType, const SStrategyConfig &config)
{
   DestroyActiveStrategy();

   m_activeType = newType;
   m_config     = config;
   m_config.strategyType = newType;
   ResolveDefaultMagicNumber();

   // Update collaborator engines with new magic number
   if(m_execEngine != NULL && m_symbolHelper != NULL)
   {
      m_execEngine.Init(m_symbol, m_config.magicNumber, m_config.slippagePoints, m_symbolHelper);
   }
   if(m_posManager != NULL && m_execEngine != NULL && m_symbolHelper != NULL)
   {
      m_posManager.Init(m_symbol, m_config.magicNumber, m_execEngine, m_symbolHelper);
   }

   m_activeStrategy = CreateStrategyInstance(m_activeType);
   if(m_activeStrategy == NULL)
   {
      if(m_logger != NULL)
         m_logger.Error(StringFormat("Failed to switch strategy to: %s", StrategyTypeToString(newType)), "SELECTOR");
      return false;
   }

   if(m_logger != NULL)
   {
      m_logger.Info(StringFormat("Strategy switched to: %s (Magic: %I64u)",
                                 StrategyTypeToString(newType), m_config.magicNumber), "SELECTOR");
   }

   return true;
}

//+------------------------------------------------------------------+
//| Strategy Switching Overload                                      |
//+------------------------------------------------------------------+
bool CStrategySelector::SetStrategy(ENUM_STRATEGY_TYPE newType)
{
   return SetStrategy(newType, m_config);
}

//+------------------------------------------------------------------+
//| Update Active Strategy Configuration                             |
//+------------------------------------------------------------------+
void CStrategySelector::SetConfig(const SStrategyConfig &config)
{
   m_config = config;
   if(m_activeStrategy != NULL)
   {
      switch(m_activeType)
      {
         case STRATEGY_REMMY:
         {
            CStrategyRemmy *remmy = (CStrategyRemmy*)m_activeStrategy;
            remmy.SetConfig(m_config);
            break;
         }
         case STRATEGY_CALLISTO:
         {
            CStrategyCallisto *callisto = (CStrategyCallisto*)m_activeStrategy;
            callisto.SetConfig(m_config);
            break;
         }
         case STRATEGY_DB:
         {
            CStrategyDB *db = (CStrategyDB*)m_activeStrategy;
            db.SetConfig(m_config);
            break;
         }
         case STRATEGY_PORTFOLIO:
         {
            CStrategyPortfolio *portfolio = (CStrategyPortfolio*)m_activeStrategy;
            portfolio.SetConfig(m_config);
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Factory: Create Concrete Strategy Instance                       |
//+------------------------------------------------------------------+
IStrategy* CStrategySelector::CreateStrategyInstance(ENUM_STRATEGY_TYPE type)
{
   switch(type)
   {
      case STRATEGY_REMMY:
      {
         CStrategyRemmy *remmy = new CStrategyRemmy();
         if(m_symbolHelper != NULL && m_riskEngine != NULL && m_execEngine != NULL && m_posManager != NULL)
         {
            remmy.InitWithEngines(m_symbol, m_timeframe, m_config, m_symbolHelper, m_riskEngine, m_execEngine, m_posManager, m_logger);
         }
         else
         {
            remmy.Init(m_symbol, m_timeframe);
         }
         if(m_mockMode) remmy.SetMockMode(true);
         return remmy;
      }
      case STRATEGY_CALLISTO:
      {
         CStrategyCallisto *callisto = new CStrategyCallisto();
         ENUM_TIMEFRAMES htf = (m_config.callistoHtfTf != 0) ? m_config.callistoHtfTf : PERIOD_H1;
         if(m_symbolHelper != NULL && m_riskEngine != NULL && m_execEngine != NULL && m_posManager != NULL)
         {
            callisto.InitWithEngines(m_symbol, htf, m_config, m_symbolHelper, m_riskEngine, m_execEngine, m_posManager, m_logger);
         }
         else
         {
            callisto.Init(m_symbol, htf);
         }
         if(m_mockMode) callisto.SetMockMode(true);
         return callisto;
      }
      case STRATEGY_DB:
      {
         CStrategyDB *db = new CStrategyDB();
         if(m_symbolHelper != NULL && m_riskEngine != NULL && m_execEngine != NULL && m_posManager != NULL)
         {
            db.InitWithEngines(m_symbol, PERIOD_M30, m_config, m_symbolHelper, m_riskEngine, m_execEngine, m_posManager, m_logger);
         }
         else
         {
            db.Init(m_symbol, PERIOD_M30);
         }
         if(m_mockMode) db.SetMockMode(true);
         return db;
      }
      case STRATEGY_PORTFOLIO:
      {
         CStrategyPortfolio *portfolio = new CStrategyPortfolio();
         if(m_symbolHelper != NULL && m_riskEngine != NULL && m_execEngine != NULL && m_posManager != NULL)
         {
            portfolio.InitWithEngines(m_symbol, m_config, m_symbolHelper, m_riskEngine, m_execEngine, m_posManager, m_logger);
         }
         return portfolio;
      }
      default:
         return NULL;
   }
}

//+------------------------------------------------------------------+
//| Factory: Safely Dispose Active Strategy                          |
//+------------------------------------------------------------------+
void CStrategySelector::DestroyActiveStrategy()
{
   if(m_activeStrategy != NULL)
   {
      m_activeStrategy.Deinit();
      delete m_activeStrategy;
      m_activeStrategy = NULL;
   }
}

//+------------------------------------------------------------------+
//| Resolve Default Magic Number if not set                          |
//+------------------------------------------------------------------+
void CStrategySelector::ResolveDefaultMagicNumber()
{
   if(m_config.magicNumber == 0)
   {
      switch(m_activeType)
      {
         case STRATEGY_REMMY:
            m_config.magicNumber = DEFAULT_MAGIC_REMMY;
            break;
         case STRATEGY_CALLISTO:
            m_config.magicNumber = DEFAULT_MAGIC_CALLISTO;
            break;
         case STRATEGY_DB:
            m_config.magicNumber = DEFAULT_MAGIC_DB;
            break;
         default:
            m_config.magicNumber = DEFAULT_MAGIC_REMMY;
            break;
      }
   }
}

//+------------------------------------------------------------------+
//| Polymorphic OnTick Handler                                       |
//+------------------------------------------------------------------+
void CStrategySelector::OnTickHandler()
{
   if(m_activeStrategy != NULL)
   {
      m_activeStrategy.OnTickHandler();
   }
}

//+------------------------------------------------------------------+
//| Polymorphic OnBar Handler                                        |
//+------------------------------------------------------------------+
void CStrategySelector::OnBarHandler(ENUM_TIMEFRAMES tf)
{
   if(m_activeStrategy != NULL)
   {
      m_activeStrategy.OnBarHandler(tf);
   }
}

//+------------------------------------------------------------------+
//| Polymorphic Setup Evaluator                                      |
//+------------------------------------------------------------------+
void CStrategySelector::EvaluateSetup()
{
   if(m_activeStrategy != NULL)
   {
      m_activeStrategy.EvaluateSetup();
   }
}

//+------------------------------------------------------------------+
//| Polymorphic Trade Signal Retrieval                               |
//+------------------------------------------------------------------+
bool CStrategySelector::GetTradeSignals(STradeSignal &outSignal)
{
   if(m_activeStrategy != NULL)
   {
      return m_activeStrategy.GetTradeSignals(outSignal);
   }
   outSignal.Clear();
   return false;
}

//+------------------------------------------------------------------+
//| Polymorphic Position Management                                  |
//+------------------------------------------------------------------+
void CStrategySelector::ManageOpenPositions()
{
   if(m_activeStrategy != NULL)
   {
      m_activeStrategy.ManageOpenPositions();
   }
}

//+------------------------------------------------------------------+
//| Polymorphic Signal Execution Dispatcher                          |
//+------------------------------------------------------------------+
bool CStrategySelector::ExecuteCurrentSignal()
{
   if(m_activeStrategy == NULL)
      return false;

   switch(m_activeType)
   {
      case STRATEGY_REMMY:
         return ((CStrategyRemmy*)m_activeStrategy).ExecuteCurrentSignal();
      case STRATEGY_CALLISTO:
         return ((CStrategyCallisto*)m_activeStrategy).ExecuteCurrentSignal();
      case STRATEGY_DB:
         return ((CStrategyDB*)m_activeStrategy).ExecuteCurrentSignal();
      case STRATEGY_PORTFOLIO:
         return ((CStrategyPortfolio*)m_activeStrategy).ExecuteCurrentSignal();
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Polymorphic Strategy Reset                                       |
//+------------------------------------------------------------------+
void CStrategySelector::Reset()
{
   if(m_activeStrategy != NULL)
   {
      m_activeStrategy.Reset();
   }
}

//+------------------------------------------------------------------+
//| Strategy Name Getter                                             |
//+------------------------------------------------------------------+
string CStrategySelector::GetActiveStrategyName() const
{
   if(m_activeStrategy != NULL)
      return m_activeStrategy.GetStrategyName();
   return StrategyTypeToString(m_activeType);
}

//+------------------------------------------------------------------+
//| State Getter                                                     |
//+------------------------------------------------------------------+
ENUM_EA_STATE CStrategySelector::GetState()
{
   if(m_activeStrategy != NULL)
      return m_activeStrategy.GetState();
   return EA_STATE_IDLE;
}

//+------------------------------------------------------------------+
//| State Setter                                                     |
//+------------------------------------------------------------------+
void CStrategySelector::SetState(ENUM_EA_STATE newState)
{
   if(m_activeStrategy != NULL)
   {
      m_activeStrategy.SetState(newState);
   }
}

//+------------------------------------------------------------------+
//| Status String Getter                                             |
//+------------------------------------------------------------------+
string CStrategySelector::GetStatusString()
{
   if(m_activeStrategy != NULL)
      return m_activeStrategy.GetStatusString();
   return "NO_ACTIVE_STRATEGY";
}

//+------------------------------------------------------------------+
//| Concrete Accessor: REMMY Strategy                                |
//+------------------------------------------------------------------+
CStrategyRemmy* CStrategySelector::GetRemmyStrategy()
{
   if(m_activeType == STRATEGY_REMMY && m_activeStrategy != NULL)
      return (CStrategyRemmy*)m_activeStrategy;
   return NULL;
}

//+------------------------------------------------------------------+
//| Concrete Accessor: CALLISTO Strategy                             |
//+------------------------------------------------------------------+
CStrategyCallisto* CStrategySelector::GetCallistoStrategy()
{
   if(m_activeType == STRATEGY_CALLISTO && m_activeStrategy != NULL)
      return (CStrategyCallisto*)m_activeStrategy;
   return NULL;
}

//+------------------------------------------------------------------+
//| Concrete Accessor: DB Strategy                                   |
//+------------------------------------------------------------------+
CStrategyDB* CStrategySelector::GetDBStrategy()
{
   if(m_activeType == STRATEGY_DB && m_activeStrategy != NULL)
      return (CStrategyDB*)m_activeStrategy;
   return NULL;
}

//+------------------------------------------------------------------+
//| Concrete Accessor: PORTFOLIO Strategy                            |
//+------------------------------------------------------------------+
CStrategyPortfolio* CStrategySelector::GetPortfolioStrategy()
{
   if(m_activeType == STRATEGY_PORTFOLIO && m_activeStrategy != NULL)
      return (CStrategyPortfolio*)m_activeStrategy;
   return NULL;
}

//+------------------------------------------------------------------+
//| Mock Mode Switcher for Testing                                   |
//+------------------------------------------------------------------+
void CStrategySelector::SetMockMode(bool enabled)
{
   m_mockMode = enabled;
   if(m_activeStrategy != NULL)
   {
      switch(m_activeType)
      {
         case STRATEGY_REMMY:
            ((CStrategyRemmy*)m_activeStrategy).SetMockMode(enabled);
            break;
         case STRATEGY_CALLISTO:
            ((CStrategyCallisto*)m_activeStrategy).SetMockMode(enabled);
            break;
         case STRATEGY_DB:
            ((CStrategyDB*)m_activeStrategy).SetMockMode(enabled);
            break;
      }
   }
}

#endif // LEGSTECH_STRATEGIES_STRATEGYSELECTOR_MQH
