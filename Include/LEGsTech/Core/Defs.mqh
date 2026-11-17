//+------------------------------------------------------------------+
//|                                                         Defs.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_CORE_DEFS_MQH
#define LEGSTECH_CORE_DEFS_MQH

//+------------------------------------------------------------------+
//| System Branding & Metadata Constants                             |
//+------------------------------------------------------------------+
#define LEGSTECH_BRAND_NAME        "LEGsTECH"
#define LEGSTECH_TAGLINE           "SOLUTIONS FOR TOMORROW"
#define LEGSTECH_VERSION           "1.30"
#define LEGSTECH_BUILD_DATE        "2026.09.21"
#define LEGSTECH_COPYRIGHT         "Copyright 2026, LEGsTECH"

//+------------------------------------------------------------------+
//| Default Magic Numbers & Identifiers                              |
//+------------------------------------------------------------------+
#define DEFAULT_MAGIC_RM           103001
#define DEFAULT_MAGIC_CL           103002
#define DEFAULT_MAGIC_DB           103003
#define DEFAULT_TEST_MAGIC         999001
// Aliases for backwards compatibility
#define DEFAULT_MAGIC_REMMY        DEFAULT_MAGIC_RM
#define DEFAULT_MAGIC_CALLISTO     DEFAULT_MAGIC_CL

//+------------------------------------------------------------------+
//| Custom Error Codes (Range: 65536+)                               |
//+------------------------------------------------------------------+
#define ERR_LEGSTECH_SUCCESS               0
#define ERR_LEGSTECH_INVALID_STATE         65537
#define ERR_LEGSTECH_INVALID_PARAMETER     65538
#define ERR_LEGSTECH_MAX_SPREAD_EXCEEDED   65539
#define ERR_LEGSTECH_DAILY_DD_REACHED      65540
#define ERR_LEGSTECH_MAX_POS_REACHED       65541
#define ERR_LEGSTECH_EXECUTION_FAILED      65542
#define ERR_LEGSTECH_SL_MOD_FAILED         65543
#define ERR_LEGSTECH_ORDER_REJECTED        65544
#define ERR_LEGSTECH_INVALID_SIGNAL        65545
#define ERR_LEGSTECH_KILL_SWITCH_ACTIVE    65546
#define ERR_LEGSTECH_SYMBOL_NOT_FOUND      65547
#define ERR_LEGSTECH_INSUFFICIENT_MARGIN   65548
#define ERR_LEGSTECH_OUT_OF_SESSION        65549

//+------------------------------------------------------------------+
//| Strategy Type Enumeration                                        |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_TYPE
{
   STRATEGY_REMMY      = 0,  // RM: 15M Momentum & Fractal Continuation
   STRATEGY_CALLISTO   = 1,  // CL: HTF POI & Multi-Timeframe Confirmation
   STRATEGY_DB         = 2,  // DB: Daily Bias & Session Window M30
   STRATEGY_PORTFOLIO  = 3   // PORTFOLIO: Multi-Strategy Blend (RM + CL + DB)
};

//+------------------------------------------------------------------+
//| Trade Execution Profile (Scalp / Day / Swing)                    |
//+------------------------------------------------------------------+
enum ENUM_TRADE_PROFILE
{
   PROFILE_SCALP      = 0,  // SCALP: Fast momentum, fixed SL, reduced risk, active +30p trail
   PROFILE_DAY_TRADE  = 1,  // DAY TRADE: Session structure, fractal/POI SL, balanced TP + runner
   PROFILE_SWING      = 2   // SWING: Macro high-conviction wave, wide structural SL, large multi-R targets
};

//+------------------------------------------------------------------+
//| Finite State Machine States (8 Formal States)                    |
//+------------------------------------------------------------------+
enum ENUM_EA_STATE
{
   EA_STATE_IDLE                           = 0,  // IDLE: Neutral, waiting for conditions
   EA_STATE_ANALYSING                      = 1,  // ANALYSING: Active market scan
   EA_STATE_SETUP_FOUND                    = 2,  // SETUP_FOUND: Bias / Structure / POI detected
   EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP= 3,  // WAITING_FOR_CONFIRMATION_OR_TAP: Waiting for LTF trigger/tap
   EA_STATE_ENTRY_READY                    = 4,  // ENTRY_READY: Execution conditions fully validated
   EA_STATE_EXECUTED                       = 5,  // EXECUTED: Order(s) dispatched and tickets registered
   EA_STATE_MANAGING                       = 6,  // MANAGING: Managing active positions (BE / Runners)
   EA_STATE_CLOSED                         = 7   // CLOSED: Positions terminated, post-trade cleanup
};

//+------------------------------------------------------------------+
//| Risk Calculation Modes                                           |
//+------------------------------------------------------------------+
enum ENUM_RISK_MODE
{
   RISK_MODE_FIXED_LOT         = 0,  // Fixed Lot Size
   RISK_MODE_PERCENT_EQUITY    = 1,  // Percentage of Account Equity
   RISK_MODE_PERCENT_BALANCE   = 2   // Percentage of Account Balance
};

//+------------------------------------------------------------------+
//| Twin Position Lot Allocation Mode                                |
//+------------------------------------------------------------------+
enum ENUM_TWIN_LOT_MODE
{
   TWIN_LOT_SPLIT_50_50 = 0, // Split total risk volume 50/50 across Pos 1 & Pos 2
   TWIN_LOT_FULL_EACH   = 1, // Full lot on BOTH Pos 1 & Pos 2 (Scales risk: e.g. 0.01 + 0.01)
   TWIN_LOT_CUSTOM      = 2  // Custom ratio (e.g. 60% Pos 1 / 40% Pos 2)
};

//+------------------------------------------------------------------+
//| Entry Confirmation Modes (CALLISTO Strategy)                     |
//+------------------------------------------------------------------+
enum ENUM_CONFIRMATION_MODE
{
   CONFIRM_MODE_CHOCH      = 0,  // LTF Change of Character (CHoCH)
   CONFIRM_MODE_IFVG       = 1,  // LTF Inversion Fair Value Gap (iFVG)
   CONFIRM_MODE_ENGULFING  = 2   // LTF Directional Engulfing Candle
};

//+------------------------------------------------------------------+
//| Daily Directional Bias (DB Strategy)                             |
//+------------------------------------------------------------------+
enum ENUM_DAILY_BIAS
{
   DAILY_BIAS_NONE     = 0,  // Neutral / Undetermined Bias
   DAILY_BIAS_BULLISH  = 1,  // Bullish Bias (Long Only)
   DAILY_BIAS_BEARISH  = 2,  // Bearish Bias (Short Only)
   BIAS_NEUTRAL        = 0,  // Alias Neutral
   BIAS_BULLISH        = 1,  // Alias Bullish
   BIAS_BEARISH        = 2   // Alias Bearish (-1 for indicator calculations)
};

//+------------------------------------------------------------------+
//| Trade Signal Direction                                           |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE = 0,  // No Signal
   SIGNAL_BUY  = 1,  // Buy (Long) Signal
   SIGNAL_SELL = 2   // Sell (Short) Signal
};

//+------------------------------------------------------------------+
//| Asset Classification                                             |
//+------------------------------------------------------------------+
enum ENUM_ASSET_CLASS
{
   ASSET_CLASS_FX_MAJORS = 0,  // Forex 5-digit / 4-digit major & minor pairs
   ASSET_CLASS_FX_JPY    = 1,  // Forex 3-digit / 2-digit JPY pairs
   ASSET_CLASS_METALS    = 2,  // Gold (XAUUSD), Silver (XAGUSD)
   ASSET_CLASS_INDICES   = 3,  // US30, NAS100, SPX500, GER40
   ASSET_CLASS_CRYPTO    = 4   // BTCUSD, ETHUSD
};

//+------------------------------------------------------------------+
//| Fractal Point Type                                               |
//+------------------------------------------------------------------+
enum ENUM_FRACTAL_TYPE
{
   FRACTAL_NONE  = 0,   // No fractal
   FRACTAL_UPPER = 1,   // Swing High / Top Peak (Bearish reversal point)
   FRACTAL_LOWER = -1   // Swing Low / Bottom Trough (Bullish reversal point)
};

//+------------------------------------------------------------------+
//| Fair Value Gap (FVG) Type and Polarity                           |
//+------------------------------------------------------------------+
enum ENUM_FVG_TYPE
{
   FVG_NONE             = 0,   // None
   FVG_BULLISH          = 1,   // Standard Bullish Imbalance (Demand)
   FVG_BEARISH          = -1,  // Standard Bearish Imbalance (Supply)
   FVG_INVERTED_BULLISH = 2,   // Bearish FVG breached upward -> Bullish Support
   FVG_INVERTED_BEARISH = -2   // Bullish FVG breached downward -> Bearish Resistance
};

//+------------------------------------------------------------------+
//| FVG Lifecycle State                                              |
//+------------------------------------------------------------------+
enum ENUM_FVG_STATE
{
   FVG_STATE_FRESH            = 0,  // Untapped, active zone
   FVG_STATE_PARTIALLY_TAPPED = 1,  // Price wicked into zone without breach
   FVG_STATE_MITIGATED        = 2,  // Price fully tested / reached 50% CE
   FVG_STATE_BREACHED         = 3,  // Closed beyond boundary (ready for inversion)
   FVG_STATE_INVERTED_ACTIVE  = 4,  // Active iFVG awaiting retest
   FVG_STATE_INVALIDATED      = 5   // Fully violated / cancelled
};

//+------------------------------------------------------------------+
//| Market Structure Event Type                                      |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_EVENT
{
   STRUCT_EVENT_NONE          = 0,   // No structural event
   STRUCT_EVENT_BOS_BULLISH   = 1,   // Break of Structure (Bullish continuation)
   STRUCT_EVENT_BOS_BEARISH   = -1,  // Break of Structure (Bearish continuation)
   STRUCT_EVENT_CHOCH_BULLISH = 2,   // Change of Character (Reversal to Bullish)
   STRUCT_EVENT_CHOCH_BEARISH = -2,  // Change of Character (Reversal to Bearish)
   STRUCT_EVENT_SWEEP_BULLISH = 3,   // Wick sweep above high (Liquidity grab)
   STRUCT_EVENT_SWEEP_BEARISH = -3   // Wick sweep below low (Liquidity grab)
};

//+------------------------------------------------------------------+
//| Candlestick Engulfing Pattern Type                               |
//+------------------------------------------------------------------+
enum ENUM_ENGULFING_TYPE
{
   ENGULFING_NONE    = 0,   // No engulfing pattern
   ENGULFING_BULLISH = 1,   // Bullish Engulfing
   ENGULFING_BEARISH = -1   // Bearish Engulfing
};

//+------------------------------------------------------------------+
//| Runner Exit Trigger Reasons                                      |
//+------------------------------------------------------------------+
enum ENUM_RUNNER_EXIT_REASON
{
   RUNNER_EXIT_NONE              = 0,  // None
   RUNNER_EXIT_OPPOSITE_FRACTAL  = 1,  // Opposite Fractal Break
   RUNNER_EXIT_TRAILING_STOP     = 2,  // Trailing Stop Hit
   RUNNER_EXIT_TARGET_HIT        = 3,  // Fixed Profit Target Hit
   RUNNER_EXIT_SESSION_CLOSE     = 4,  // Session End / Daily Reset
   RUNNER_EXIT_EMERGENCY         = 5   // Emergency Kill Switch / Manual Close
};

//+------------------------------------------------------------------+
//| Logging Severity Levels                                          |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_DEBUG    = 0,  // Detailed internal telemetry & state transitions
   LOG_LEVEL_INFO     = 1,  // Operational milestones and execution summaries
   LOG_LEVEL_WARNING  = 2,  // Non-fatal irregularities (slippage, spread spike)
   LOG_LEVEL_ERROR    = 3,  // Recoverable errors (failed order, invalid stop)
   LOG_LEVEL_CRITICAL = 4   // Unrecoverable errors (kill switch, fatal drawdown)
};

//+------------------------------------------------------------------+
//| Logging Target Channel Flags                                     |
//+------------------------------------------------------------------+
enum ENUM_LOG_TARGET
{
   LOG_TARGET_NONE      = 0,
   LOG_TARGET_CONSOLE   = 1,  // Terminal Expert log (Print)
   LOG_TARGET_FILE      = 2,  // Daily rotating log file in MQL5/Files
   LOG_TARGET_DASHBOARD = 4,  // On-chart UI telemetry ring buffer
   LOG_TARGET_ALL       = 7   // All channels
};

//+------------------------------------------------------------------+
//| Trade Signal Structure                                           |
//+------------------------------------------------------------------+
struct STradeSignal
{
   ENUM_SIGNAL_TYPE     type;                  // BUY, SELL, or NONE
   ENUM_STRATEGY_TYPE   strategy;              // Originating strategy
   string               symbol;                // Symbol name
   datetime             timestamp;             // Signal generation time
   double               entryPrice;            // Proposed entry price (0.0 for market)
   double               stopLossPrice;         // Stop Loss price level
   double               takeProfit1Price;      // Position 1 Take Profit (e.g. 100 pips)
   double               takeProfit2Price;      // Position 2 Take Profit (0.0 = Open Runner)
   bool                 isDualPosition;        // True if 2-position execution model
   double               riskAmountOrPct;       // Risk percentage or fixed lot sizing
   string               setupDescription;      // Human-readable setup rationale
   int                  confirmationBarShift;  // Bar index where confirmation triggered
   ulong                magicNumber;           // Strategy magic number

   void Clear()
   {
      type                 = SIGNAL_NONE;
      strategy             = STRATEGY_REMMY;
      symbol               = "";
      timestamp            = 0;
      entryPrice           = 0.0;
      stopLossPrice        = 0.0;
      takeProfit1Price     = 0.0;
      takeProfit2Price     = 0.0;
      isDualPosition       = false;
      riskAmountOrPct      = 0.0;
      setupDescription     = "";
      confirmationBarShift = -1;
      magicNumber          = 0;
   }

   bool IsValid() const
   {
      return (type != SIGNAL_NONE && symbol != "" && stopLossPrice > 0.0 && takeProfit1Price > 0.0);
   }
};

//+------------------------------------------------------------------+
//| Managed Position State Structure                                 |
//+------------------------------------------------------------------+
struct SPositionInfo
{
   ulong                ticket1;               // Primary position ticket (Fixed TP)
   ulong                ticket2;               // Runner position ticket (Open / Trailing)
   ENUM_STRATEGY_TYPE   strategy;              // Strategy owner
   string               symbol;                // Trade symbol
   ENUM_POSITION_TYPE   positionType;          // POSITION_TYPE_BUY or POSITION_TYPE_SELL
   double               openPrice1;            // Fill price Position 1
   double               openPrice2;            // Fill price Position 2
   double               initialLot1;           // Lot volume Position 1
   double               initialLot2;           // Lot volume Position 2
   double               currentSL1;            // Current active SL Position 1
   double               currentSL2;            // Current active SL Position 2
   double               currentTP1;            // Current active TP Position 1
   double               currentTP2;            // Current active TP Position 2
   datetime             openTime;              // Position execution timestamp
   bool                 isPosition1Closed;     // True if Pos 1 closed (e.g. TP hit)
   bool                 isPosition2Closed;     // True if Pos 2 closed
   bool                 isBreakEvenApplied;    // True if Pos 2 SL moved to BE + buffer
   double               realizedPnL;           // Realized profit/loss on closed portions
   string               comment;               // Order comment tag

   void Clear()
   {
      ticket1              = 0;
      ticket2              = 0;
      strategy             = STRATEGY_REMMY;
      symbol               = "";
      positionType         = WRONG_VALUE;
      openPrice1           = 0.0;
      openPrice2           = 0.0;
      initialLot1          = 0.0;
      initialLot2          = 0.0;
      currentSL1           = 0.0;
      currentSL2           = 0.0;
      currentTP1           = 0.0;
      currentTP2           = 0.0;
      openTime             = 0;
      isPosition1Closed    = true;
      isPosition2Closed    = true;
      isBreakEvenApplied   = false;
      realizedPnL          = 0.0;
      comment              = "";
   }

   bool HasActivePositions() const
   {
      return (!isPosition1Closed || !isPosition2Closed);
   }
};

//+------------------------------------------------------------------+
//| Unified Strategy Configuration Structure                         |
//+------------------------------------------------------------------+
struct SStrategyConfig
{
   ENUM_STRATEGY_TYPE   strategyType;          // Selected strategy
   bool                 isEnabled;             // Enable / Disable master switch
   ulong                magicNumber;           // Order tracking magic number
   ENUM_RISK_MODE       riskMode;              // Fixed lot vs % equity
   double               fixedLotSize;          // Fixed lot size (if mode = FIXED_LOT)
   double               riskPercent;           // Risk % per trade (if mode = PERCENT_EQUITY)
   double               maxDailyLossPercent;   // Daily Drawdown halt threshold (e.g. 5.0%)
   int                  maxDailyTrades;        // Daily trade execution ceiling
   int                  maxSpreadPips;         // Max allowable spread in pips
   int                  slippagePoints;        // Maximum slippage tolerance in points

   // Optional Time & Session Filter (Universal)
   bool                 useSessionFilter;      // Enable / Disable optional session filter (default: false)
   int                  sessionStartHour;      // Active trading window start hour (UTC, default: 6)
   int                  sessionEndHour;        // Active trading window end hour (UTC, default: 18)

   // Profile Selector & Parameters
   ENUM_TRADE_PROFILE   tradeProfile;          // Active Profile: Scalp, Day Trade, or Swing
   
   // Scalp Profile Settings
   double               scalpRiskPercent;      // Scalp risk percentage (default 0.5%)
   double               scalpSlPips;           // Scalp fixed emergency SL (default 100.0 pips)
   double               scalpTpPips;           // Scalp Take Profit (default 100.0 pips)
   double               scalpTrailTriggerPips; // Profit pips to activate aggressive trailing (default 30.0 pips)
   double               scalpTrailDistPips;    // Trailing distance behind peak (default 20.0 pips)
   double               scalpTrailStepPips;    // Trailing update step buffer (default 5.0 pips)
   
   // Day Trade Profile Settings
   double               dayRiskPercent;        // Day trade risk percentage (default 1.0%)
   double               dayTpPips;             // Day trade TP1 distance (default 100.0 pips)
   double               dayBeTriggerPips;      // Profit pips to trigger BE lock (default 50.0 pips)
   double               dayBeLockPips;         // Profit pips locked above entry (default 5.0 pips)
   
   // Swing Profile Settings
   double               swingRiskPercent;      // Swing risk percentage (default 1.0%)
   double               swingTpPips;           // Swing Take Profit distance (default 400.0 pips)
   double               swingTrailTriggerPips; // Profit pips to trigger swing trail (default 100.0 pips)
   double               swingTrailDistPips;    // Swing trail distance (default 100.0 pips)
   
   // Adaptive Tiered Trailing Engine Settings
   double               swingTpThresholdPips;     // Minimum TP distance to qualify for Swing Ratchet logic (default: 250.0 pips)
   double               swingBeTriggerPips;       // Profit pips to trigger initial Swing lock (default: 100.0 pips)
   double               swingInitialLockPips;     // Profit pips locked on initial Swing trigger (default: 50.0 pips)
   double               swingTrailStepPips;       // Step ratchet interval for Swing trailing (default: 50.0 pips)

   double               intradayBeTriggerPips;    // Profit pips to trigger Intraday BE lock (default: 50.0 pips)
   double               intradayBeLockPips;       // Buffer pips locked above entry on Intraday BE (default: 5.0 pips)
   double               intradayTrailTriggerPips; // Profit pips to trigger Intraday trailing (default: 70.0 pips)
   double               intradayTrailDistPips;    // Intraday trailing buffer distance (default: 30.0 pips)
   double               intradayTrailStepPips;    // Intraday trailing ratchet step (default: 10.0 pips)

   // Universal Break-Even & Trailing Controls
   bool                 useBreakEven;          // Enable / Disable Automatic Break-Even (Default: true)
   double               beTriggerPips;         // Profit pips to trigger Break-Even (Default: 50.0 pips)
   double               beLockPips;            // Buffer pips to lock in above entry on BE (Default: 2.0 pips)

   bool                 useTrailingStop;       // Enable / Disable Trailing Stop (Default: true)
   double               trailTriggerPips;      // Profit pips to activate Trailing Stop (Default: 30.0 pips)
   double               trailDistPips;         // Trailing distance behind price (Default: 20.0 pips)
   double               trailStepPips;         // Trailing update step buffer (Default: 5.0 pips)
   int                  maxPositions;          // Max concurrent open positions limit (Default: 2)
   bool                 enableDoublePosition;  // Global Double Position switch (Pos 1 Fixed TP + Pos 2 Runner)
   bool                 trailOnlyRunners;      // Asymmetric: Only trail runner (TP==0), let fixed TP reach target (Default: true)
   bool                 blockRolloverWindow;   // Block new entries during 17:00-21:00 UTC rollover/low-liquidity (Default: true)

   // Portfolio Sub-Strategy Toggles (Institutional Allocation)
   bool                 enableRemmy;           // Enable Strategy REMMY in Portfolio (Default: true)
   bool                 enableCallisto;        // Enable Strategy CALLISTO in Portfolio (Default: true)
   bool                 enableDb;              // Enable Strategy DB in Portfolio (Default: false)

   // REMMY-Specific (V1.3 4-Timeframe Cascade Specification)
   bool                 remmyUseD1Filter;      // REMMY: Enable D1 Daily Bias (Default: true)
   bool                 remmyUseH4Filter;      // REMMY: Enable H4 Candle Color Confirmation (Default: true)
   bool                 remmyUseH1Filter;      // REMMY: Enable H1 Forming Candle Alignment (Default: true)
   bool                 remmyH1RequireClosedAlso; // REMMY: Also require closed H1 candle to agree (Default: false)
   bool                 remmyUseSessionFilter; // REMMY: Enable GMT Session Window (Default: true)
   int                  remmySessionStartGmt;  // REMMY: Active Window Start Hour GMT (Default: 7)
   int                  remmySessionEndGmt;    // REMMY: Active Window End Hour GMT (Default: 20)
   int                  remmyFractalBars;      // Fractal detection window (5 bars)
   int                  remmyFractalMaxAge;    // Maximum age of confirmed fractal in bars (Default: 3)
   int                  remmyEmaPeriod;        // REMMY: Baseline EMA period for overextension guard (Default: 20)
   double               remmyAtrMultiplier;    // REMMY: Max allowable ATR distance before overextension block (Default: 2.0)
   double               remmySlPips;           // REMMY Stop Loss distance (default fallback)
   double               remmySlBufferPips;     // REMMY SL Buffer beyond confirmed fractal (pips, Default: 5.0)
   double               remmyMinSlPips;        // REMMY Minimum SL distance floor (pips, Default: 20.0)
   double               remmyMaxSlPips;        // REMMY Maximum allowable SL in pips (e.g. 200.0)
   double               remmyHalfLotSlPips;    // REMMY Half-lot threshold in pips (e.g. 150.0)
   double               remmyTpPips;           // Position 1 TP distance (100 pips)
   bool                 remmyAutoBeOnTp1;      // Automatically move Pos 2 to BE when Pos 1 hits TP (Default: true)
   double               remmyBeBufferPips;     // BE offset above entry (spread buffer)
   double               remmyBeLockPips;       // BE profit lock pips (Default: 2.0)
   bool                 remmyRunnerEnabled;    // Enable runner position

   // CALLISTO-Specific
   bool                 callistoUseSessionFilter; // CALLISTO: Enable GMT Session Window (Default: false = 24/7)
   int                  callistoSessionStartGmt;  // CALLISTO: Active Window Start Hour GMT (Default: 7)
   int                  callistoSessionEndGmt;    // CALLISTO: Active Window End Hour GMT (Default: 20)
   ENUM_TIMEFRAMES      callistoHtfTf;         // High Timeframe for POI (e.g. H1/H4)
   ENUM_TIMEFRAMES      callistoLtfTf;         // Low Timeframe for confirmation (e.g. M5/M15)
   ENUM_CONFIRMATION_MODE callistoConfirmMode; // CHoCH, iFVG, or Engulfing
   double               callistoSlPips;        // 100-pip fixed SL
   double               callistoTpPips;        // 100-pip fixed TP
   bool                 callistoRunnerEnabled; // Configurable double-position mode
   double               callistoStaleGuardPips;// Max pips beyond POI zone edge to accept entry (0=disabled)
   bool                 callistoUseTrailing;      // CL: Enable Dedicated Trailing Stop
   double               callistoTrailDistPips;    // CL: Trailing Stop Distance Cushion from Current Price (pips, default: 100.0)
   double               callistoTrailTriggerPips; // CL: Trailing Activation Profit (pips, default: 100.0)
   double               callistoTrailStepPips;    // CL: Trailing Step Interval (pips, default: 10.0)
   bool                 callistoUseBreakEven;     // CL: Enable Break-Even
   double               callistoBeTriggerPips;    // CL: Break-Even Trigger Profit (pips, default: 100.0)
   double               callistoBeLockPips;       // CL: Break-Even Profit Lock Buffer (pips, default: 2.0)
   bool                 callistoUseM1Confirmation;// CL: Require M1 Directional Candle Close Confirmation inside Retest (default: true)
   bool                 callistoTargetOpposingPoi;// CL: Position 2 Targets Opposing H1 Institutional POI (default: true)

   // DB-Specific
   bool                 dbUseSessionFilter;    // DB: Enable GMT Session Window (Default: true)
   int                  dbSessionStartGmt;     // DB: Active Window Start Hour GMT (Default: 7)
   int                  dbSessionEndGmt;       // DB: Active Window End Hour GMT (Default: 20)
   bool                 dbTradeAllSessions;    // DB: Trade all sessions 24/7 (ignore strict 8AM/8PM UTC lock)
   bool                 dbRunnerEnabled;       // DB: Enable double-position runner mode
   int                  dbStartHour1;          // Morning Session Window (8:00 AM)
   int                  dbStartHour2;          // Evening Session Window (8:00 PM)
   int                  dbUtcOffset;           // Broker Server UTC Offset (Hours)
   double               dbSwingBufferPips;     // Safety buffer added to 30M swing SL (15 pips)
   double               dbSlPips;              // DB Stop Loss distance (100 pips)
   double               dbTpPips;              // 100-pip fixed TP
   int                  dbPullbackCandles;     // M15 counter-trend candles required to reset lock (>=1)

   // Twin Position Execution Controls (Institutional Dual Order Architecture)
   bool                 enableTwinPositions;   // Enable 2-Position Model (Pos 1 Banker 100p + Pos 2 Runner)
   ENUM_TWIN_LOT_MODE   twinLotMode;           // TWIN_LOT_SPLIT_50_50, TWIN_LOT_FULL_EACH, or TWIN_LOT_CUSTOM
   double               twinTP1_Pips;          // Position 1 Fixed TP (Default: 100.0 pips)
   double               twinPos1Ratio;         // Custom lot ratio for Pos 1 (Default: 0.50)
   double               twinBeTriggerPips;     // Simultaneous Break-Even Trigger (Default: 50.0 pips)
   double               twinBeLockPips;        // Simultaneous Break-Even Lock Buffer (Default: 5.0 pips)
   double               twinTrailDistPips;     // Runner Trailing Stop Distance (Default: 60.0 pips)
   double               twinTrailStepPips;     // Runner Trailing Stop Step Buffer (Default: 10.0 pips)

   void SetDefaults()
   {
      strategyType         = STRATEGY_REMMY;
      tradeProfile         = PROFILE_DAY_TRADE;
      isEnabled            = true;
      magicNumber          = DEFAULT_MAGIC_REMMY;
      riskMode             = RISK_MODE_PERCENT_EQUITY;
      fixedLotSize         = 0.01;
      riskPercent          = 1.0;
      maxDailyLossPercent  = 5.0;
      maxDailyTrades       = 10;
      maxSpreadPips        = 7;
      slippagePoints       = 10;
      maxPositions         = 2;

      // Universal Break-Even & Trailing Defaults
      useBreakEven         = true;
      beTriggerPips        = 50.0;
      beLockPips           = 2.0;
      useTrailingStop      = true;
      trailTriggerPips     = 80.0;
      trailDistPips        = 60.0;
      trailStepPips        = 10.0;
      enableDoublePosition = true;
      enableTwinPositions  = false;
      twinLotMode          = TWIN_LOT_FULL_EACH;
      twinTP1_Pips         = 100.0;
      twinPos1Ratio        = 0.50;
      twinBeTriggerPips    = 50.0;
      twinBeLockPips       = 5.0;
      twinTrailDistPips    = 60.0;
      twinTrailStepPips    = 10.0;
      trailOnlyRunners     = true;
      blockRolloverWindow  = true;
      enableRemmy          = true;
      enableCallisto       = true;
      enableDb             = false;

      // Session Filter Defaults (Optional, default OFF)
      useSessionFilter     = false;
      sessionStartHour     = 6;
      sessionEndHour       = 18;

      // Scalp Defaults
      scalpRiskPercent      = 0.5;
      scalpSlPips           = 100.0;
      scalpTpPips           = 100.0;
      scalpTrailTriggerPips = 30.0;
      scalpTrailDistPips    = 20.0;
      scalpTrailStepPips    = 5.0;

      // Day Trade Defaults
      dayRiskPercent        = 1.0;
      dayTpPips             = 100.0;
      dayBeTriggerPips      = 50.0;
      dayBeLockPips         = 5.0;

      // Swing Defaults
      swingRiskPercent         = 1.0;
      swingTpPips              = 400.0;
      swingTpThresholdPips     = 250.0;
      swingTrailTriggerPips    = 100.0;
      swingBeTriggerPips       = 100.0;
      swingInitialLockPips     = 50.0;
      swingTrailStepPips       = 50.0;
      swingTrailDistPips       = 100.0;

      // Intraday Defaults
      intradayBeTriggerPips    = 50.0;
      intradayBeLockPips       = 5.0;
      intradayTrailTriggerPips = 70.0;
      intradayTrailDistPips    = 30.0;
      intradayTrailStepPips    = 10.0;

      // REMMY V1.3
      remmyUseD1Filter         = true;
      remmyUseH4Filter         = true;
      remmyUseH1Filter         = true;
      remmyH1RequireClosedAlso = false;
      remmyUseSessionFilter    = true;
      remmySessionStartGmt     = 7;
      remmySessionEndGmt       = 20;
      remmyFractalBars         = 5;
      remmyFractalMaxAge       = 3;
      remmyEmaPeriod           = 20;
      remmyAtrMultiplier       = 2.0;
      remmySlPips              = 100.0;
      remmySlBufferPips        = 5.0;
      remmyMinSlPips           = 20.0;
      remmyMaxSlPips           = 200.0;
      remmyHalfLotSlPips       = 150.0;
      remmyTpPips              = 100.0;
      remmyAutoBeOnTp1         = true;
      remmyBeBufferPips        = 2.0;
      remmyBeLockPips          = 2.0;
      remmyRunnerEnabled       = true;

      // CALLISTO
      callistoUseSessionFilter = false;
      callistoSessionStartGmt  = 7;
      callistoSessionEndGmt    = 20;
      callistoHtfTf        = PERIOD_H1;
      callistoLtfTf        = PERIOD_M5;
      callistoConfirmMode  = CONFIRM_MODE_CHOCH;
      callistoSlPips       = 100.0;
      callistoTpPips       = 100.0;
      callistoRunnerEnabled= false;
      callistoStaleGuardPips= 50.0;
      callistoUseTrailing     = true;
      callistoTrailDistPips   = 100.0;
      callistoTrailTriggerPips= 100.0;
      callistoTrailStepPips   = 10.0;
      callistoUseBreakEven    = true;
      callistoBeTriggerPips   = 100.0;
      callistoBeLockPips      = 2.0;
      callistoUseM1Confirmation = true;
      callistoTargetOpposingPoi = true;

      // DB
      dbUseSessionFilter   = true;
      dbSessionStartGmt    = 7;
      dbSessionEndGmt      = 20;
      dbTradeAllSessions   = true;
      dbRunnerEnabled      = true;
      dbStartHour1         = 8;
      dbStartHour2         = 20;
      dbUtcOffset          = 2;
      dbSwingBufferPips    = 15.0;
      dbSlPips             = 100.0;
      dbTpPips             = 100.0;
      dbPullbackCandles    = 1;
   }
};

//+------------------------------------------------------------------+
//| Struct for Fractal Point Data                                    |
//+------------------------------------------------------------------+
struct SFractalPoint
{
   ENUM_FRACTAL_TYPE type;          // Upper or Lower
   datetime          time;          // Bar open time
   double            price;         // High or Low price
   int               barIndex;      // Bar shift index
   bool              isConfirmed;   // Confirmed 5-bar formation
   
   void Reset()
   {
      type        = FRACTAL_NONE;
      time        = 0;
      price       = 0.0;
      barIndex    = -1;
      isConfirmed = false;
   }
};

//+------------------------------------------------------------------+
//| Struct for REMMY 4-Timeframe Cascade & Setup Structure           |
//+------------------------------------------------------------------+
struct SRemmyStructure
{
   bool              isValid;             // True if complete setup pattern identified
   bool              isBuy;               // True = BUY setup, False = SELL setup
   ENUM_DAILY_BIAS   dailyBias;           // D1 Bias (BULLISH / BEARISH / NONE)
   bool              h4Confirmed;         // H4 closed candle matches D1
   bool              h1Confirmed;         // H1 forming candle matches D1
   SFractalPoint     refFractal;          // Confirmed M15 Fractal (SL anchor)
   SFractalPoint     priorSwing;          // Prior Swing Low/High (auxiliary anchor)
   double            pushPrice;           // Push High/Low (reference)
   datetime          pushTime;            // Push timestamp
   int               pushBarIndex;        // Push bar index
   bool              isBreakConfirmed;    // True if trigger validated
   double            triggerClosePrice;   // Close price of trigger bar
   datetime          triggerTime;         // Trigger timestamp
   double            entryPrice;          // Entry market price
   
   void Reset()
   {
      isValid           = false;
      isBuy             = false;
      dailyBias         = DAILY_BIAS_NONE;
      h4Confirmed       = false;
      h1Confirmed       = false;
      refFractal.Reset();
      priorSwing.Reset();
      pushPrice         = 0.0;
      pushTime          = 0;
      pushBarIndex      = -1;
      isBreakConfirmed  = false;
      triggerClosePrice = 0.0;
      triggerTime       = 0;
      entryPrice        = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Struct for FVG / iFVG Zone Instance                              |
//+------------------------------------------------------------------+
struct SFVGZone
{
   ulong             id;                // Unique incremental ID
   ENUM_FVG_TYPE     type;              // FVG type
   ENUM_FVG_STATE    state;             // Current lifecycle state
   datetime          creationTime;      // Bar i open time
   int               barIndex;          // Index where FVG was formed
   double            topPrice;          // Upper zone boundary
   double            bottomPrice;       // Lower zone boundary
   double            midPrice;          // Consequent Encroachment (50% CE)
   double            gapSizePoints;     // Height in points
   bool              isMitigated;       // Tapped or filled
   bool              isInverted;        // Flipped to iFVG
   datetime          inversionTime;     // Timestamp when breach occurred
   int               tapCount;          // Number of times price tapped into zone
   
   void Reset()
   {
      id            = 0;
      type          = FVG_NONE;
      state         = FVG_STATE_FRESH;
      creationTime  = 0;
      barIndex      = -1;
      topPrice      = 0.0;
      bottomPrice   = 0.0;
      midPrice      = 0.0;
      gapSizePoints = 0.0;
      isMitigated   = false;
      isInverted    = false;
      inversionTime = 0;
      tapCount      = 0;
   }
};

//+------------------------------------------------------------------+
//| Struct for Market Structure Result                               |
//+------------------------------------------------------------------+
struct SStructureResult
{
   ENUM_STRUCTURE_EVENT eventType;        // Event detected
   datetime             eventTime;        // Time of trigger bar
   int                  barIndex;         // Trigger bar index
   double               brokenPrice;      // Reference swing level that was broken
   double               triggerClose;     // Close price of confirming candle
   bool                 isBodyClose;      // True = Confirmed Body Close, False = Wick Sweep
   double               displacementAtr;  // Size in ATR multiples
   
   void Reset()
   {
      eventType       = STRUCT_EVENT_NONE;
      eventTime       = 0;
      barIndex        = -1;
      brokenPrice     = 0.0;
      triggerClose    = 0.0;
      isBodyClose     = false;
      displacementAtr = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Struct for Session & Bias Evaluation State                       |
//+------------------------------------------------------------------+
struct SSessionState
{
   ENUM_DAILY_BIAS   dailyBias;              // Current D1 bias
   datetime          biasDate;               // Date of evaluated D1 bar
   bool              isInMorningWindow;      // True if inside 8:00 AM window
   bool              isInEveningWindow;      // True if inside 8:00 PM window
   bool              isInTradingWindow;      // True if morning or evening window active
   int               serverHour;             // Current server hour
   int               serverMinute;           // Current server minute
   bool              continuationLocked;     // True if locked against duplicate entries
   int               m15PullbackCount;       // Count of consecutive M15 counter-trend candles
   bool              pullbackResetAchieved;  // True if >= 2 counter candles observed
   
   void Reset()
   {
      dailyBias             = DAILY_BIAS_NONE;
      biasDate              = 0;
      isInMorningWindow     = false;
      isInEveningWindow     = false;
      isInTradingWindow     = false;
      serverHour            = 0;
      serverMinute          = 0;
      continuationLocked    = false;
      m15PullbackCount      = 0;
      pullbackResetAchieved = false;
   }
};

//+------------------------------------------------------------------+
//| Structure for Tracked Position Pair                              |
//+------------------------------------------------------------------+
struct STrackedPair
{
   ulong                ticket1;          // Target 100-pip TP position
   ulong                ticket2;          // Runner position
   ENUM_STRATEGY_TYPE   strategy;         // Originating strategy
   ENUM_ORDER_TYPE      orderType;        // ORDER_TYPE_BUY or ORDER_TYPE_SELL
   double               entryPrice;       // Execution entry price
   double               initialSL;        // Initial Stop Loss level
   double               tp1Price;         // Target Take Profit 1 level
   bool                 p1BEApplied;      // True if BE is applied on Position 1
   bool                 p1Closed;         // True if Position 1 is closed
   bool                 p2BEApplied;      // True if BE is applied on Position 2
   bool                 p2Closed;         // True if Position 2 is closed
   bool                 trailingActive;   // True once Position 1 hits TP1 and Runner trailing is unlocked
   datetime             openTime;         // Open timestamp

   void Reset()
   {
      ticket1        = 0;
      ticket2        = 0;
      strategy       = STRATEGY_REMMY;
      orderType      = WRONG_VALUE;
      entryPrice     = 0.0;
      initialSL      = 0.0;
      tp1Price       = 0.0;
      p1BEApplied    = false;
      p1Closed       = false;
      p2BEApplied    = false;
      p2Closed       = false;
      trailingActive = false;
      openTime       = 0;
   }
};

//+------------------------------------------------------------------+
//| Struct for Dashboard Runtime Telemetry                           |
//+------------------------------------------------------------------+
struct SDashboardTelemetry
{
   string            strategyName;       // "REMMY", "CALLISTO", "DB", "PORTFOLIO"
   string            tradeProfileName;   // "SCALP (+30p Trail)", "DAY TRADE (100p TP)", "SWING (400p TP)"
   string            trailingStatus;     // e.g. "ACTIVE (+35.2p | Locked +20.0p)"
   ENUM_EA_STATE     currentState;       // Current FSM state
   string            stateDesc;          // Descriptive state text
   double            accountBalance;     // Live balance
   double            accountEquity;      // Live equity
   double            dailyRealizedPnL;   // Closed PnL today
   double            dailyFloatingPnL;   // Current floating PnL
   double            dailyDrawdownPct;   // Current daily drawdown %
   double            maxDrawdownLimitPct;// Allowed daily drawdown limit
   int               tradesToday;        // Count of closed trades today
   int               winningTradesToday; // Count of winners today
   double            winRatePct;         // Win rate %
   double            currentSpreadPips;  // Live spread in pips
   double            maxSpreadLimitPips; // Max allowed spread
   int               openTicketsCount;   // Number of active open positions
   ulong             ticket1;            // Primary ticket ID
   double            ticket1PnL;         // Primary ticket floating PnL
   string            ticket1Status;      // e.g. "TP1 Hit (+100p)" or "Open"
   ulong             ticket2;            // Runner ticket ID
   double            ticket2PnL;         // Runner ticket floating PnL
   string            ticket2Status;      // e.g. "SL at BE (+spread)"
   string            lastSignalInfo;     // Short description of latest setup
   string            remmyStatus;        // REMMY Strategy Status
   string            callistoStatus;     // CALLISTO Strategy Status
   string            dbStatus;           // DB Strategy Status
   bool              isEmergencyHalted;  // True if Kill Switch engaged

   // Universal BE & Trailing Telemetry
   bool              isBreakEvenEnabled; // True if BE active
   double            beTriggerPips;      // BE Trigger (pips)
   double            beLockPips;         // BE Lock Buffer (pips)
   bool              isTrailingEnabled;  // True if Trailing active
   double            trailTriggerPips;   // Trailing Trigger (pips)
   double            trailDistPips;      // Trailing Distance (pips)

   void Reset()
   {
      strategyName        = "RM";
      tradeProfileName    = "SCALP";
      trailingStatus      = "STANDBY";
      currentState        = EA_STATE_IDLE;
      stateDesc           = "IDLE";
      remmyStatus         = "RM: Idle";
      callistoStatus      = "CL: Idle";
      dbStatus            = "DB: Idle";
      accountBalance      = 0.0;
      accountEquity       = 0.0;
      dailyRealizedPnL    = 0.0;
      dailyFloatingPnL    = 0.0;
      dailyDrawdownPct    = 0.0;
      maxDrawdownLimitPct = 5.0;
      tradesToday         = 0;
      winningTradesToday  = 0;
      winRatePct          = 0.0;
      currentSpreadPips   = 0.0;
      maxSpreadLimitPips  = 3.0;
      openTicketsCount    = 0;
      ticket1             = 0;
      ticket1PnL          = 0.0;
      ticket1Status       = "None";
      ticket2             = 0;
      ticket2PnL          = 0.0;
      ticket2Status       = "None";
      lastSignalInfo      = "Waiting for setup...";
      isEmergencyHalted   = false;

      isBreakEvenEnabled  = true;
      beTriggerPips       = 50.0;
      beLockPips          = 2.0;
      isTrailingEnabled   = true;
      trailTriggerPips    = 30.0;
      trailDistPips       = 20.0;
   }
};

//+------------------------------------------------------------------+
//| String Formatting Helper Functions                               |
//+------------------------------------------------------------------+
inline string StateToString(ENUM_EA_STATE state)
{
   switch(state)
   {
      case EA_STATE_IDLE:                            return "IDLE";
      case EA_STATE_ANALYSING:                       return "ANALYSING";
      case EA_STATE_SETUP_FOUND:                     return "SETUP_FOUND";
      case EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP: return "WAITING_FOR_CONFIRMATION_OR_TAP";
      case EA_STATE_ENTRY_READY:                     return "ENTRY_READY";
      case EA_STATE_EXECUTED:                        return "EXECUTED";
      case EA_STATE_MANAGING:                        return "MANAGING";
      case EA_STATE_CLOSED:                          return "CLOSED";
      default:                                       return "UNKNOWN_STATE";
   }
}

inline string StrategyTypeToString(ENUM_STRATEGY_TYPE strat)
{
   switch(strat)
   {
      case STRATEGY_REMMY:      return "RM";
      case STRATEGY_CALLISTO:   return "CL";
      case STRATEGY_DB:         return "DB";
      case STRATEGY_PORTFOLIO:  return "PORTFOLIO";
      default:                  return "UNKNOWN_STRATEGY";
   }
}

inline string SignalTypeToString(ENUM_SIGNAL_TYPE sig)
{
   switch(sig)
   {
      case SIGNAL_BUY:  return "BUY";
      case SIGNAL_SELL: return "SELL";
      default:          return "NONE";
   }
}

inline string DailyBiasToString(ENUM_DAILY_BIAS bias)
{
   switch(bias)
   {
      case DAILY_BIAS_BULLISH: return "BULLISH";
      case DAILY_BIAS_BEARISH: return "BEARISH";
      default:                 return "NEUTRAL";
   }
}

inline string LogLevelToString(ENUM_LOG_LEVEL level)
{
   switch(level)
   {
      case LOG_LEVEL_DEBUG:    return "DEBUG";
      case LOG_LEVEL_INFO:     return "INFO";
      case LOG_LEVEL_WARNING:  return "WARN";
      case LOG_LEVEL_ERROR:    return "ERROR";
      case LOG_LEVEL_CRITICAL: return "CRITICAL";
      default:                 return "UNKNOWN";
   }
}

inline string AssetClassToString(ENUM_ASSET_CLASS assetClass)
{
   switch(assetClass)
   {
      case ASSET_CLASS_FX_MAJORS: return "FX_MAJORS";
      case ASSET_CLASS_FX_JPY:    return "FX_JPY";
      case ASSET_CLASS_METALS:    return "METALS";
      case ASSET_CLASS_INDICES:   return "INDICES";
      case ASSET_CLASS_CRYPTO:    return "CRYPTO";
      default:                    return "UNKNOWN";
   }
}

inline string FractalTypeToString(ENUM_FRACTAL_TYPE fractalType)
{
   switch(fractalType)
   {
      case FRACTAL_UPPER: return "UPPER";
      case FRACTAL_LOWER: return "LOWER";
      default:            return "NONE";
   }
}

inline string FVGTypeToString(ENUM_FVG_TYPE fvgType)
{
   switch(fvgType)
   {
      case FVG_BULLISH:          return "BULLISH_FVG";
      case FVG_BEARISH:          return "BEARISH_FVG";
      case FVG_INVERTED_BULLISH: return "INVERTED_BULLISH_FVG";
      case FVG_INVERTED_BEARISH: return "INVERTED_BEARISH_FVG";
      default:                   return "NONE";
   }
}

inline string StructureEventToString(ENUM_STRUCTURE_EVENT eventType)
{
   switch(eventType)
   {
      case STRUCT_EVENT_BOS_BULLISH:   return "BOS_BULLISH";
      case STRUCT_EVENT_BOS_BEARISH:   return "BOS_BEARISH";
      case STRUCT_EVENT_CHOCH_BULLISH: return "CHOCH_BULLISH";
      case STRUCT_EVENT_CHOCH_BEARISH: return "CHOCH_BEARISH";
      case STRUCT_EVENT_SWEEP_BULLISH: return "SWEEP_BULLISH";
      case STRUCT_EVENT_SWEEP_BEARISH: return "SWEEP_BEARISH";
      default:                         return "NONE";
   }
}

inline string EngulfingTypeToString(ENUM_ENGULFING_TYPE engulfingType)
{
   switch(engulfingType)
   {
      case ENGULFING_BULLISH: return "BULLISH_ENGULFING";
      case ENGULFING_BEARISH: return "BEARISH_ENGULFING";
      default:                return "NONE";
   }
}

#endif // LEGSTECH_CORE_DEFS_MQH
