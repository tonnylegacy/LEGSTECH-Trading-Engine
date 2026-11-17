//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_UI_DASHBOARD_MQH
#define LEGSTECH_UI_DASHBOARD_MQH

#include <Object.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>
#include "..\Core\Defs.mqh"
#include "Theme.mqh"

//+------------------------------------------------------------------+
//| GUI Object Identifiers & Prefixes                                |
//+------------------------------------------------------------------+
#define LEGSTECH_GUI_PREFIX     "LEGsTech_GUI_"
#define LEGSTECH_GUI_KILL_BTN   "LEGsTech_GUI_KillBtn"
#define LEGSTECH_GUI_BTN_KILL   "LEGsTech_GUI_BTN_KILL"
#define LEGSTECH_GUI_BTN_BE     "LEGsTech_GUI_BtnBE"
#define LEGSTECH_GUI_BTN_TRAIL  "LEGsTech_GUI_BtnTrail"

//+------------------------------------------------------------------+
//| Class CDashboard                                                 |
//| On-Chart Graphical Dashboard & Interactive Emergency Kill Switch|
//+------------------------------------------------------------------+
class CDashboard : public CObject
{
private:
   long                 m_chartId;              // Target chart window handle
   int                  m_subWindow;            // Target sub-window index (0 = main)
   string               m_objPrefix;            // Prefix for namespace isolation
   bool                 m_isCreated;            // True if UI components exist
   bool                 m_isVisualEnabled;      // Visual render master switch
   bool                 m_isHeadlessMock;       // Headless test bypass flag
   bool                 m_killSwitchTriggered;  // Live kill switch trigger state
   
   // Coordinate & Geometry
   int                  m_xPos;                 // Left X distance (px)
   int                  m_yPos;                 // Top Y distance (px)
   int                  m_width;                // Panel width (px)
   int                  m_height;               // Panel height (px)
   ENUM_BASE_CORNER     m_corner;               // Anchor corner on chart

   // Subsystems & Telemetry
   SUITheme             m_theme;                // Active theme tokens
   CTheme               m_themeHelper;          // Theme & formatter helper
   SDashboardTelemetry  m_telemetry;            // Current runtime telemetry snapshot
   
   // Object registry for leak-free memory management
   string               m_objectNames[];        // Array of all created object names
   int                  m_objectCount;          // Count of tracked objects

   // Low-Level Primitive Creation
   bool                 CreateRectLabel(const string name, int x, int y, int w, int h, color bgClr, color borderClr, int borderWidth = 1);
   bool                 CreateLabel(const string name, int x, int y, const string text, color clr, int fontSize, const string font = "", bool bold = false);
   bool                 CreateButton(const string name, int x, int y, int w, int h, const string text, color bgClr, color txtClr, color borderClr, int fontSize = 9, const string font = "");
   bool                 CreateBitmapLabel(const string name, int x, int y, const string bmpFile);
   void                 UpdateLabel(const string name, const string text, color clr = clrNONE);
   void                 UpdateRectColor(const string name, color bgClr);
   void                 UpdateButton(const string name, const string text, color bgClr = clrNONE, color txtClr = clrNONE, color borderClr = clrNONE);
   void                 RegisterObject(const string name);
   void                 DeleteObject(const string name);
   void                 DeleteAllObjects();

public:
                        CDashboard();
   virtual             ~CDashboard();

   // Initialization Overloads
   bool                 Init(long chartId = 0,
                             int x = 15,
                             int y = 25,
                             int width = 340,
                             int height = 540,
                             int subWindow = 0,
                             ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
                             bool isVisualEnabled = true);

   void                 Destroy();

   // Lifecycle & Visual Updates
   bool                 CreateUI();
   void                 Update(const SDashboardTelemetry &telemetry);
   void                 Redraw();

   // Event Handling (Interactive Emergency Kill Button & Toggles)
   bool                 OnChartEvent(const int id,
                                     const long &lparam,
                                     const double &dparam,
                                     const string &sparam,
                                     bool &outKillEngaged,
                                     bool &outToggleBE,
                                     bool &outToggleTrail);

   bool                 OnChartEvent(const int id,
                                     const long &lparam,
                                     const double &dparam,
                                     const string &sparam,
                                     bool &outKillEngaged);

   // Status & Controls
   void                 SetEmergencyHalt(bool halted);
   bool                 IsKillSwitchTriggered() const  { return m_killSwitchTriggered; }
   void                 ResetKillSwitch();
   void                 SetHeadlessMock(bool mock);
   void                 SetVisualEnabled(bool visual)  { m_isVisualEnabled = visual; }
   
   bool                 IsCreated() const              { return m_isCreated; }
   bool                 IsVisualEnabled() const        { return m_isVisualEnabled; }
   long                 GetChartID() const             { return m_chartId; }
   
   // Telemetry Getters
   void                 GetTelemetry(SDashboardTelemetry &outTelem) const { outTelem = m_telemetry; }
   SDashboardTelemetry  GetTelemetry() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDashboard::CDashboard()
{
   m_chartId             = 0;
   m_subWindow           = 0;
   m_objPrefix           = LEGSTECH_GUI_PREFIX;
   m_isCreated           = false;
   m_isVisualEnabled     = true;
   m_isHeadlessMock      = false;
   m_killSwitchTriggered = false;
   m_xPos                = 15;
   m_yPos                = 25;
   m_width               = 340;
   m_height              = 540;
   m_corner              = CORNER_LEFT_UPPER;
   m_objectCount         = 0;

   m_theme.SetDefaultDarkTheme();
   m_themeHelper.SetTheme(m_theme);
   m_telemetry.Reset();
   ArrayResize(m_objectNames, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDashboard::~CDashboard()
{
   Destroy();
}

//+------------------------------------------------------------------+
//| Telemetry Getter by Value                                        |
//+------------------------------------------------------------------+
SDashboardTelemetry CDashboard::GetTelemetry() const
{
   return m_telemetry;
}

//+------------------------------------------------------------------+
//| Initialize Dashboard Subsystem                                   |
//+------------------------------------------------------------------+
bool CDashboard::Init(long chartId, int x, int y, int width, int height, int subWindow, ENUM_BASE_CORNER corner, bool isVisualEnabled)
{
   m_chartId         = (chartId == 0) ? ChartID() : chartId;
   m_xPos            = x;
   m_yPos            = y;
   m_width           = (width > 0) ? width : 340;
   m_height          = (height > 0) ? height : 510;
   m_subWindow       = subWindow;
   m_corner          = corner;
   m_isVisualEnabled = isVisualEnabled;
   m_isCreated       = false;

   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0)
   {
      m_isCreated = true;
      return true;
   }

   return CreateUI();
}

//+------------------------------------------------------------------+
//| Destroy all graphical dashboard primitives                       |
//+------------------------------------------------------------------+
void CDashboard::Destroy()
{
   DeleteAllObjects();
   m_isCreated = false;
}

//+------------------------------------------------------------------+
//| Mock Mode Switcher for Unit Tests                                |
//+------------------------------------------------------------------+
void CDashboard::SetHeadlessMock(bool mock)
{
   m_isHeadlessMock = mock;
   if(mock)
   {
      m_isCreated = true;
   }
}

//+------------------------------------------------------------------+
//| Reset Kill Switch State                                          |
//+------------------------------------------------------------------+
void CDashboard::ResetKillSwitch()
{
   m_killSwitchTriggered = false;
   m_telemetry.isEmergencyHalted = false;
   SetEmergencyHalt(false);
}

//+------------------------------------------------------------------+
//| Register created object name for leak-free destruction           |
//+------------------------------------------------------------------+
void CDashboard::RegisterObject(const string name)
{
   for(int i = 0; i < m_objectCount; i++)
   {
      if(m_objectNames[i] == name)
         return;
   }
   m_objectCount++;
   ArrayResize(m_objectNames, m_objectCount);
   m_objectNames[m_objectCount - 1] = name;
}

//+------------------------------------------------------------------+
//| Create OBJ_RECTANGLE_LABEL primitive                             |
//+------------------------------------------------------------------+
bool CDashboard::CreateRectLabel(const string name, int x, int y, int w, int h, color bgClr, color borderClr, int borderWidth)
{
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0) return true;

   string objName = (StringFind(name, m_objPrefix) == 0) ? name : (m_objPrefix + name);
   if(ObjectFind(m_chartId, objName) >= 0)
      ObjectDelete(m_chartId, objName);

   if(!ObjectCreate(m_chartId, objName, OBJ_RECTANGLE_LABEL, m_subWindow, 0, 0))
      return false;

   ObjectSetInteger(m_chartId, objName, OBJPROP_CORNER, m_corner);
   ObjectSetInteger(m_chartId, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chartId, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(m_chartId, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(m_chartId, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(m_chartId, objName, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(m_chartId, objName, OBJPROP_COLOR, borderClr);
   ObjectSetInteger(m_chartId, objName, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(m_chartId, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(m_chartId, objName, OBJPROP_WIDTH, borderWidth);
   ObjectSetInteger(m_chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartId, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(m_chartId, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(m_chartId, objName, OBJPROP_BACK, false);

   RegisterObject(objName);
   return true;
}

//+------------------------------------------------------------------+
//| Create OBJ_LABEL text primitive                                  |
//+------------------------------------------------------------------+
bool CDashboard::CreateLabel(const string name, int x, int y, const string text, color clr, int fontSize, const string font, bool bold)
{
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0) return true;

   string objName = (StringFind(name, m_objPrefix) == 0) ? name : (m_objPrefix + name);
   if(ObjectFind(m_chartId, objName) >= 0)
      ObjectDelete(m_chartId, objName);

   if(!ObjectCreate(m_chartId, objName, OBJ_LABEL, m_subWindow, 0, 0))
      return false;

   string fontFace = (font != "" && font != NULL) ? font : m_theme.fontBody;
   ObjectSetInteger(m_chartId, objName, OBJPROP_CORNER, m_corner);
   ObjectSetInteger(m_chartId, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chartId, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(m_chartId, objName, OBJPROP_TEXT, text);
   ObjectSetString(m_chartId, objName, OBJPROP_FONT, fontFace);
   ObjectSetInteger(m_chartId, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(m_chartId, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(m_chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartId, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(m_chartId, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(m_chartId, objName, OBJPROP_BACK, false);

   RegisterObject(objName);
   return true;
}

//+------------------------------------------------------------------+
//| Create OBJ_BUTTON interactive primitive                          |
//+------------------------------------------------------------------+
bool CDashboard::CreateButton(const string name, int x, int y, int w, int h, const string text, color bgClr, color txtClr, color borderClr, int fontSize, const string font)
{
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0) return true;

   string objName = (StringFind(name, m_objPrefix) == 0) ? name : (m_objPrefix + name);
   if(ObjectFind(m_chartId, objName) >= 0)
      ObjectDelete(m_chartId, objName);

   if(!ObjectCreate(m_chartId, objName, OBJ_BUTTON, m_subWindow, 0, 0))
      return false;

   string fontFace = (font != "" && font != NULL) ? font : m_theme.fontTitle;
   ObjectSetInteger(m_chartId, objName, OBJPROP_CORNER, m_corner);
   ObjectSetInteger(m_chartId, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chartId, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(m_chartId, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(m_chartId, objName, OBJPROP_YSIZE, h);
   ObjectSetString(m_chartId, objName, OBJPROP_TEXT, text);
   ObjectSetString(m_chartId, objName, OBJPROP_FONT, fontFace);
   ObjectSetInteger(m_chartId, objName, OBJPROP_FONTSIZE, (fontSize > 0) ? fontSize : m_theme.fontSizeHeader);
   ObjectSetInteger(m_chartId, objName, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(m_chartId, objName, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(m_chartId, objName, OBJPROP_BORDER_COLOR, borderClr);
   ObjectSetInteger(m_chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartId, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(m_chartId, objName, OBJPROP_STATE, false);
   ObjectSetInteger(m_chartId, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(m_chartId, objName, OBJPROP_BACK, false);

   RegisterObject(objName);
   return true;
}

//+------------------------------------------------------------------+
//| Create Bitmap Label (Brand Logo)                                 |
//+------------------------------------------------------------------+
bool CDashboard::CreateBitmapLabel(const string name, int x, int y, const string bmpFile)
{
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0) return true;

   string objName = (StringFind(name, m_objPrefix) == 0) ? name : (m_objPrefix + name);
   ObjectDelete(m_chartId, objName);

   if(!ObjectCreate(m_chartId, objName, OBJ_BITMAP_LABEL, m_subWindow, 0, 0))
      return false;

   ObjectSetString(m_chartId, objName, OBJPROP_BMPFILE, 0, bmpFile);
   ObjectSetInteger(m_chartId, objName, OBJPROP_CORNER, m_corner);
   ObjectSetInteger(m_chartId, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(m_chartId, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(m_chartId, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartId, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(m_chartId, objName, OBJPROP_BACK, false);

   RegisterObject(objName);
   return true;
}

//+------------------------------------------------------------------+
//| Update text and color of existing label                          |
//+------------------------------------------------------------------+
void CDashboard::UpdateLabel(const string name, const string text, color clr)
{
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0) return;

   string objName = (StringFind(name, m_objPrefix) == 0) ? name : (m_objPrefix + name);
   if(ObjectFind(m_chartId, objName) >= 0)
   {
      ObjectSetString(m_chartId, objName, OBJPROP_TEXT, text);
      if(clr != clrNONE)
      {
         ObjectSetInteger(m_chartId, objName, OBJPROP_COLOR, clr);
      }
   }
}

//+------------------------------------------------------------------+
//| Update background color of existing rectangle                    |
//+------------------------------------------------------------------+
void CDashboard::UpdateRectColor(const string name, color bgClr)
{
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0) return;
   
   string objName = (StringFind(name, m_objPrefix) == 0) ? name : (m_objPrefix + name);
   if(ObjectFind(m_chartId, objName) >= 0)
   {
      ObjectSetInteger(m_chartId, objName, OBJPROP_BGCOLOR, bgClr);
   }
}

//+------------------------------------------------------------------+
//| Update interactive button appearance                             |
//+------------------------------------------------------------------+
void CDashboard::UpdateButton(const string name, const string text, color bgClr, color txtClr, color borderClr)
{
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0) return;

   string objName = (StringFind(name, m_objPrefix) == 0) ? name : (m_objPrefix + name);
   if(ObjectFind(m_chartId, objName) >= 0)
   {
      ObjectSetString(m_chartId, objName, OBJPROP_TEXT, text);
      if(bgClr != clrNONE)
         ObjectSetInteger(m_chartId, objName, OBJPROP_BGCOLOR, bgClr);
      if(txtClr != clrNONE)
         ObjectSetInteger(m_chartId, objName, OBJPROP_COLOR, txtClr);
      if(borderClr != clrNONE)
         ObjectSetInteger(m_chartId, objName, OBJPROP_BORDER_COLOR, borderClr);
   }
}

//+------------------------------------------------------------------+
//| Delete single object by name                                     |
//+------------------------------------------------------------------+
void CDashboard::DeleteObject(const string name)
{
   if(m_isHeadlessMock || m_chartId < 0) return;

   string objName = (StringFind(name, m_objPrefix) == 0) ? name : (m_objPrefix + name);
   if(ObjectFind(m_chartId, objName) >= 0)
   {
      ObjectDelete(m_chartId, objName);
   }
}

//+------------------------------------------------------------------+
//| Delete all objects starting with prefix                          |
//+------------------------------------------------------------------+
void CDashboard::DeleteAllObjects()
{
   if(m_isHeadlessMock || m_chartId < 0) return;

   for(int i = 0; i < m_objectCount; i++)
   {
      if(m_objectNames[i] != "")
      {
         ObjectDelete(m_chartId, m_objectNames[i]);
      }
   }
   ObjectsDeleteAll(m_chartId, m_objPrefix);
   ArrayResize(m_objectNames, 0);
   m_objectCount = 0;
}

//+------------------------------------------------------------------+
//| Create Complete UI Layout & All Cards                            |
//+------------------------------------------------------------------+
bool CDashboard::CreateUI()
{
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0)
   {
      m_isCreated = true;
      return true;
   }

   DeleteAllObjects();

   int x = m_xPos;
   int y = m_yPos;
   int w = m_width;
   int innerW = w - 16;
   int cardX  = x + 8;

   // 1. Outer Container Frame with Deep Navy Glass & Subtle Steel Border
   CreateRectLabel("Bg", x, y, w, m_height, m_theme.clrBackground, m_theme.clrCardBorder);

   // 2. Top Header with Official LEGsTECH Bitmap Logo & Badges
   CreateRectLabel("HeaderStripe", x, y, w, 4, m_theme.clrPrimaryRed, m_theme.clrPrimaryRed);
   CreateBitmapLabel("Logo", cardX + 2, y + 8, "\\Images\\LEGsTech\\logo_dark.bmp");
   CreateLabel("Version", cardX + innerW - 96, y + 14, StringFormat("v%s [XAUUSD]", LEGSTECH_VERSION), m_theme.clrAccentCyan, m_theme.fontSizeSmall, m_theme.fontMono);
   CreateLabel("SysStatus", cardX + innerW - 96, y + 34, "● LIVE ACTIVE", m_theme.clrSuccess, m_theme.fontSizeSmall, m_theme.fontBody, true);

   // 3. Card 1: Strategy, Mode & Live Trailing Badge (Y: y + 66, H: 62)
   int yCard1 = y + 66;
   CreateRectLabel("CardStateBg", cardX, yCard1, innerW, 62, m_theme.clrCardBg, m_theme.clrCardBorder);
   CreateRectLabel("StateAccent", cardX, yCard1, 4, 62, m_theme.clrSuccess, m_theme.clrSuccess);
   CreateLabel("StrategyName", cardX + 10, yCard1 + 6, "STRATEGY: RM (15M SCALP)", m_theme.clrTextPrimary, m_theme.fontSizeBody, m_theme.fontBody, true);
   CreateLabel("ProfileBadge", cardX + 10, yCard1 + 24, "⚡ TRAIL: +80p Trigger / 60p Dist", m_theme.clrAccentGold, m_theme.fontSizeSmall, m_theme.fontBody, true);
   CreateLabel("StateBadge", cardX + 10, yCard1 + 42, "● STATE: IDLE", m_theme.clrStateIdle, m_theme.fontSizeSmall, m_theme.fontBody, true);
   CreateLabel("ServerTime", cardX + innerW - 85, yCard1 + 42, "TIME: --:--:--", m_theme.clrTextSecondary, m_theme.fontSizeSmall, m_theme.fontMono);

   // 4. Card 2: Live Account Growth & Win Matrix (Y: yCard1 + 68, H: 80)
   int yCard2 = yCard1 + 68;
   CreateRectLabel("CardMetricsBg", cardX, yCard2, innerW, 80, m_theme.clrCardBg, m_theme.clrCardBorder);
   CreateLabel("MetricsTitle", cardX + 10, yCard2 + 6, "LIVE PERFORMANCE & METRICS", m_theme.clrTextSecondary, m_theme.fontSizeSmall, m_theme.fontTitle, true);
   CreateLabel("BalanceEquity", cardX + 10, yCard2 + 24, "Bal: $1,000.00  |  Eq: $1,000.00", m_theme.clrTextPrimary, m_theme.fontSizeBody, m_theme.fontMono);
   CreateLabel("DailyPnL", cardX + 10, yCard2 + 42, "Today P&L: +$0.00 (+0.00%)", m_theme.clrSuccess, m_theme.fontSizeBody, m_theme.fontBody, true);
   CreateLabel("Drawdown", cardX + 10, yCard2 + 60, "Daily DD: 0.00% / Max 5.00%  |  Win: 74.5%", m_theme.clrTextSecondary, m_theme.fontSizeSmall, m_theme.fontBody);

   // 5. Card 3: Active Position & Trailing Monitor (Y: yCard2 + 86, H: 80)
   int yCard3 = yCard2 + 86;
   CreateRectLabel("CardPosBg", cardX, yCard3, innerW, 80, m_theme.clrCardBg, m_theme.clrCardBorder);
   CreateLabel("PosTitle", cardX + 10, yCard3 + 6, "ACTIVE POSITIONS & TRAILING STATUS", m_theme.clrTextSecondary, m_theme.fontSizeSmall, m_theme.fontTitle, true);
   CreateLabel("Ticket1", cardX + 10, yCard3 + 24, "T1: No active position", m_theme.clrTextSecondary, m_theme.fontSizeSmall, m_theme.fontMono);
   CreateLabel("Ticket2", cardX + 10, yCard3 + 42, "T2: No active runner", m_theme.clrTextSecondary, m_theme.fontSizeSmall, m_theme.fontMono);
   CreateLabel("FloatingPnL", cardX + 10, yCard3 + 60, "Floating P&L: $0.00 (0 Tickets)", m_theme.clrTextPrimary, m_theme.fontSizeSmall, m_theme.fontBody, true);

   // 6. Card 4: Market Telemetry & Multi-Strategy Scanner (Y: yCard3 + 86, H: 92)
   int yCard4 = yCard3 + 86;
   CreateRectLabel("CardDiagBg", cardX, yCard4, innerW, 92, m_theme.clrCardBg, m_theme.clrCardBorder);
   CreateLabel("DiagTitle", cardX + 10, yCard4 + 6, "MARKET SIGNALS & SCANNER", m_theme.clrTextSecondary, m_theme.fontSizeSmall, m_theme.fontTitle, true);
   CreateLabel("SpreadDiag", cardX + 10, yCard4 + 22, "Spread: 0.0 pips [OK] | Max DD Guard: 5.0%", m_theme.clrTextPrimary, m_theme.fontSizeSmall, m_theme.fontBody);
   CreateLabel("RemmyDiag", cardX + 10, yCard4 + 38, "RM [M15]      : Scanning fractals...", m_theme.clrAccentCyan, m_theme.fontSizeSmall, m_theme.fontMono);
   CreateLabel("CallistoDiag", cardX + 10, yCard4 + 54, "CL [H1]       : Scanning POIs...", m_theme.clrAccentGold, m_theme.fontSizeSmall, m_theme.fontMono);
   CreateLabel("DbDiag", cardX + 10, yCard4 + 70, "DB [D1/M30]   : Scanning D1 bias...", m_theme.clrSuccess, m_theme.fontSizeSmall, m_theme.fontMono);

   // 7. Card 5: Interactive BE & Trailing Toggles (Y: yCard4 + 98, H: 34)
   int yCard5 = yCard4 + 98;
   int btnHalfW = (innerW - 6) / 2;
   CreateButton(LEGSTECH_GUI_BTN_BE, cardX, yCard5, btnHalfW, 32,
                "🟢 BE: ON (50p/+2p)",
                m_theme.clrCardBg, m_theme.clrSuccess, m_theme.clrSuccess, 8);
   CreateButton(LEGSTECH_GUI_BTN_TRAIL, cardX + btnHalfW + 6, yCard5, btnHalfW, 32,
                "🟢 TRAIL: ON (80p/60p)",
                m_theme.clrCardBg, m_theme.clrAccentCyan, m_theme.clrAccentCyan, 8);

   // 8. Card 6: Interactive Emergency Kill Switch (Y: yCard5 + 38, H: 38)
   int yCard6 = yCard5 + 38;
   CreateButton(LEGSTECH_GUI_KILL_BTN, cardX, yCard6, innerW, 38,
                "🛑 EMERGENCY CLOSE ALL / HALT",
                m_theme.clrPrimaryRed, m_theme.clrTextPrimary, m_theme.clrAccentGold);

   m_isCreated = true;
   Redraw();
   return true;
}

//+------------------------------------------------------------------+
//| Update Telemetry & Visual State In-Place                         |
//+------------------------------------------------------------------+
void CDashboard::Update(const SDashboardTelemetry &telemetry)
{
   m_telemetry = telemetry;

   if(!m_isCreated)
   {
      CreateUI();
   }

   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0)
      return;

   // 1. Strategy & State Card
   string stratDisplayName = (m_telemetry.strategyName != "") ? m_telemetry.strategyName : "RM";
   string stratText = StringFormat("STRATEGY: %s", stratDisplayName);
   UpdateLabel("StrategyName", stratText);

   string profileText = (m_telemetry.tradeProfileName != "") ? m_telemetry.tradeProfileName : "⚡ TRAILING ENGINE ACTIVE";
   UpdateLabel("ProfileBadge", profileText, m_theme.clrAccentGold);

   color stateClr = m_themeHelper.GetStateBadgeColor(m_telemetry.currentState);
   string stateText = StringFormat("● STATE: %s", StateToString(m_telemetry.currentState));
   UpdateLabel("StateBadge", stateText, stateClr);
   UpdateRectColor("StateAccent", stateClr);

   MqlDateTime dt;
   TimeCurrent(dt);
   string timeText = StringFormat("TIME: %02d:%02d:%02d", dt.hour, dt.min, dt.sec);
   UpdateLabel("ServerTime", timeText);

   // 2. Account & Metrics Card
   double balance = (m_telemetry.accountBalance > 0.0) ? m_telemetry.accountBalance : 0.0;
   double equity  = (m_telemetry.accountEquity > 0.0)  ? m_telemetry.accountEquity  : balance;
   string balEqText = StringFormat("Bal: %s  |  Eq: %s", CTheme::FormatMoney(balance, "$", 2, false), CTheme::FormatMoney(equity, "$", 2, false));
   UpdateLabel("BalanceEquity", balEqText);

   double totalDailyPnL = m_telemetry.dailyRealizedPnL + m_telemetry.dailyFloatingPnL;
   double pnlPct = (balance > 0.0) ? (totalDailyPnL / balance) * 100.0 : 0.0;
   color pnlClr = m_themeHelper.GetPnLColor(totalDailyPnL);
   string pnlText = StringFormat("Today P&L: %s (%s)", CTheme::FormatMoney(totalDailyPnL, "$", 2, true), CTheme::FormatPercent(pnlPct, true, 2));
   UpdateLabel("DailyPnL", pnlText, pnlClr);

   color ddClr = m_themeHelper.GetDrawdownColor(m_telemetry.dailyDrawdownPct, m_telemetry.maxDrawdownLimitPct);
   string ddText = StringFormat("Daily DD: %.2f%% / Max %.2f%%  |  Win: %.1f%% (%d/%d)",
                                m_telemetry.dailyDrawdownPct,
                                m_telemetry.maxDrawdownLimitPct,
                                m_telemetry.winRatePct,
                                m_telemetry.winningTradesToday,
                                m_telemetry.tradesToday);
   UpdateLabel("Drawdown", ddText, ddClr);

   // 3. Positions Card & Live Trailing Info
   if(m_telemetry.ticket1 > 0)
   {
      string t1Text = StringFormat("T1 #%I64u: %s (%s)", m_telemetry.ticket1, CTheme::FormatMoney(m_telemetry.ticket1PnL, "$", 2, true), m_telemetry.ticket1Status);
      UpdateLabel("Ticket1", t1Text, m_themeHelper.GetPnLColor(m_telemetry.ticket1PnL));
   }
   else
   {
      UpdateLabel("Ticket1", "T1: No active position", m_theme.clrTextSecondary);
   }

   if(m_telemetry.ticket2 > 0)
   {
      string t2Text = StringFormat("T2 #%I64u: %s (%s)", m_telemetry.ticket2, CTheme::FormatMoney(m_telemetry.ticket2PnL, "$", 2, true), m_telemetry.ticket2Status);
      UpdateLabel("Ticket2", t2Text, m_theme.clrAccentCyan);
   }
   else
   {
      UpdateLabel("Ticket2", "T2: No active runner", m_theme.clrTextSecondary);
   }

   string floatText = StringFormat("Floating P&L: %s (%d Tickets)", CTheme::FormatMoney(m_telemetry.dailyFloatingPnL, "$", 2, true), m_telemetry.openTicketsCount);
   UpdateLabel("FloatingPnL", floatText, m_themeHelper.GetPnLColor(m_telemetry.dailyFloatingPnL));

   // 4. Diagnostics Card
   color spreadClr = m_themeHelper.GetSpreadColor(m_telemetry.currentSpreadPips, m_telemetry.maxSpreadLimitPips);
   string spreadStatus = (m_telemetry.currentSpreadPips <= m_telemetry.maxSpreadLimitPips) ? "[OK]" : "[HIGH]";
   string spreadText = StringFormat("Spread: %.1f pips %s (Max: %.1f)", m_telemetry.currentSpreadPips, spreadStatus, m_telemetry.maxSpreadLimitPips);
   UpdateLabel("SpreadDiag", spreadText, spreadClr);

   if(m_telemetry.strategyName != "PORTFOLIO" && m_telemetry.strategyName != "PORTFOLIO (MULTI-STRATEGY)")
   {
      UpdateLabel("RemmyDiag", StringFormat("ACTIVE   : %s", m_telemetry.strategyName), m_theme.clrAccentCyan);
      UpdateLabel("CallistoDiag", StringFormat("STATUS   : %s", (m_telemetry.lastSignalInfo != "") ? m_telemetry.lastSignalInfo : "Scanning market..."), m_theme.clrAccentGold);
      UpdateLabel("DbDiag", "MODE     : Single Strategy Dedicated", m_theme.clrTextSecondary);
   }
   else
   {
      UpdateLabel("RemmyDiag", m_telemetry.remmyStatus, m_theme.clrAccentCyan);
      UpdateLabel("CallistoDiag", m_telemetry.callistoStatus, m_theme.clrAccentGold);
      UpdateLabel("DbDiag", m_telemetry.dbStatus, m_theme.clrSuccess);
   }

   // 5. Interactive BE & Trailing Button States
   if(m_telemetry.isBreakEvenEnabled)
   {
      string beText = StringFormat("🟢 BE: ON (%.0fp/+%.0fp)", m_telemetry.beTriggerPips, m_telemetry.beLockPips);
      UpdateButton(LEGSTECH_GUI_BTN_BE, beText, m_theme.clrCardBg, m_theme.clrSuccess, m_theme.clrSuccess);
   }
   else
   {
      UpdateButton(LEGSTECH_GUI_BTN_BE, "⚪ BE: OFF", m_theme.clrCardBg, m_theme.clrTextSecondary, m_theme.clrCardBorder);
   }

   if(m_telemetry.isTrailingEnabled)
   {
      string trText = StringFormat("🟢 TRAIL: ON (%.0fp/%.0fp)", m_telemetry.trailTriggerPips, m_telemetry.trailDistPips);
      UpdateButton(LEGSTECH_GUI_BTN_TRAIL, trText, m_theme.clrCardBg, m_theme.clrAccentCyan, m_theme.clrAccentCyan);
   }
   else
   {
      UpdateButton(LEGSTECH_GUI_BTN_TRAIL, "⚪ TRAIL: OFF", m_theme.clrCardBg, m_theme.clrTextSecondary, m_theme.clrCardBorder);
   }

   // 6. Emergency Kill State Check
   SetEmergencyHalt(m_telemetry.isEmergencyHalted || m_killSwitchTriggered);

   Redraw();
}

//+------------------------------------------------------------------+
//| Set Emergency Halt State UI Style                                |
//+------------------------------------------------------------------+
void CDashboard::SetEmergencyHalt(bool halted)
{
   m_killSwitchTriggered = halted;
   m_telemetry.isEmergencyHalted = halted;
   
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0) return;

   if(halted)
   {
      UpdateButton(LEGSTECH_GUI_KILL_BTN, "⚠️ TRADING HALTED — KILL ACTIVE", m_theme.clrDanger, m_theme.clrTextPrimary, m_theme.clrWarning);
      UpdateButton(LEGSTECH_GUI_BTN_KILL, "⚠️ TRADING HALTED — KILL ACTIVE", m_theme.clrDanger, m_theme.clrTextPrimary, m_theme.clrWarning);
      UpdateLabel("SysStatus", "● HALTED", m_theme.clrDanger);
   }
   else
   {
      UpdateButton(LEGSTECH_GUI_KILL_BTN, "🛑 EMERGENCY CLOSE ALL / HALT", m_theme.clrPrimaryRed, m_theme.clrTextPrimary, m_theme.clrAccentGold);
      UpdateButton(LEGSTECH_GUI_BTN_KILL, "🛑 EMERGENCY CLOSE ALL / HALT", m_theme.clrPrimaryRed, m_theme.clrTextPrimary, m_theme.clrAccentGold);
      UpdateLabel("SysStatus", "● LIVE ACTIVE", m_theme.clrSuccess);
   }
}

//+------------------------------------------------------------------+
//| Chart Event Handler for Interactive Buttons & Toggles            |
//+------------------------------------------------------------------+
bool CDashboard::OnChartEvent(const int id,
                              const long &lparam,
                              const double &dparam,
                              const string &sparam,
                              bool &outKillEngaged,
                              bool &outToggleBE,
                              bool &outToggleTrail)
{
   outKillEngaged = false;
   outToggleBE    = false;
   outToggleTrail = false;

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == LEGSTECH_GUI_KILL_BTN || sparam == (m_objPrefix + "KillBtn") ||
         sparam == LEGSTECH_GUI_BTN_KILL || sparam == (m_objPrefix + "BTN_KILL") ||
         sparam == "LEGsTech_GUI_KillBtn" || sparam == "LEGsTech_GUI_BTN_KILL")
      {
         m_killSwitchTriggered = true;
         m_telemetry.isEmergencyHalted = true;
         outKillEngaged = true;
         SetEmergencyHalt(true);

         if(!m_isHeadlessMock && m_chartId >= 0)
         {
            ObjectSetInteger(m_chartId, sparam, OBJPROP_STATE, false);
            Redraw();
         }
         return true;
      }
      else if(sparam == LEGSTECH_GUI_BTN_BE || sparam == (m_objPrefix + "BtnBE") || sparam == "LEGsTech_GUI_BtnBE")
      {
         m_telemetry.isBreakEvenEnabled = !m_telemetry.isBreakEvenEnabled;
         outToggleBE = true;
         if(!m_isHeadlessMock && m_chartId >= 0)
         {
            ObjectSetInteger(m_chartId, sparam, OBJPROP_STATE, false);
            Redraw();
         }
         return true;
      }
      else if(sparam == LEGSTECH_GUI_BTN_TRAIL || sparam == (m_objPrefix + "BtnTrail") || sparam == "LEGsTech_GUI_BtnTrail")
      {
         m_telemetry.isTrailingEnabled = !m_telemetry.isTrailingEnabled;
         outToggleTrail = true;
         if(!m_isHeadlessMock && m_chartId >= 0)
         {
            ObjectSetInteger(m_chartId, sparam, OBJPROP_STATE, false);
            Redraw();
         }
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Chart Event Handler Overload (Backward Compatibility)            |
//+------------------------------------------------------------------+
bool CDashboard::OnChartEvent(const int id,
                              const long &lparam,
                              const double &dparam,
                              const string &sparam,
                              bool &outKillEngaged)
{
   bool dummyBE = false, dummyTrail = false;
   return OnChartEvent(id, lparam, dparam, sparam, outKillEngaged, dummyBE, dummyTrail);
}

//+------------------------------------------------------------------+
//| Redraw Chart Window                                              |
//+------------------------------------------------------------------+
void CDashboard::Redraw()
{
   if(!m_isVisualEnabled || m_isHeadlessMock || m_chartId < 0) return;
   ChartRedraw(m_chartId);
}

#endif // LEGSTECH_UI_DASHBOARD_MQH
