//+------------------------------------------------------------------+
//|                                                       EMA_EA模板 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "ChildsPlay_EA模板"
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| 引入程序需要的类库并创建对象                                     |
//+------------------------------------------------------------------+
#include <MyClass\shuju.mqh>
#include <MyClass\交易类\信息类.mqh>
#include <MyClass\交易类\交易指令.mqh>

ShuJu shuju;
账户信息 zh;
仓位信息 cw;
交易指令 jy;

//+------------------------------------------------------------------+
//| 初始化全局变量                                                   |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES TIMEFRAMES_MAIN_CHART = PERIOD_M5;    // 操作图表周期
input ENUM_TIMEFRAMES TIMEFRAMES_ANCHOR_CHART = PERIOD_M15; // 参考锚图周期
input double MaxRisk = 2;        //最大本金损失比例(正整数 %)
input int EMA_K = 3;             //快速指数移动平均线取值
input int EMA_Z = 5;             //中速指数移动平均线取值
input int EMA_M = 13;            //慢速指数移动平均线取值
input int CCI_PERIOD = 24;       //CCI指标周期 
input int COUNT = 5;             //获取最高最低价的范围
input int TP_PERCENTAGE = 50;    //首次获利占开仓比例
input double TP_DISCOUNT = 0.5;    //止盈为止损的倍数

int DEVIATION = 3;               //允许最大滑点
int MAGIC = 686868;              //自定义EA编码

int N_ORDER_BUY  = 0;            //已开多单数量
int N_ORDER_SELL = 0;            //已开空单数量
double HIGH_PRICE = 0.0;         //五日内最高价
double LOW_PRICE  = 0.0;         //五日内最低价
double ASK, BID = 0.0;

double EMA_K_MAIN[];             //获取主图EMA快速均线值 
double EMA_Z_MAIN[];             //获取主图EMA中速均线值 
double EMA_M_MAIN[];             //获取主图EMA慢速均线值 

double EMA_K_ANCHOR[];           //获取锚图EMA快速均线值 
double EMA_Z_ANCHOR[];           //获取锚图EMA中速均线值 
double EMA_M_ANCHOR[];           //获取锚图EMA慢速均线值 

double HIGH_MAIN[];              //按指定数量获取主图K线最高价
double LOW_MAIN[];               //按指定数量获取主图K线最低价

double CCI_DATA[];               //获取CCI指标值 
//+------------------------------------------------------------------+
//| 初始化函数，程序首次运行仅执行一次                               |
//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 主函数，价格每波动一次执行一次                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   //获取当前买入卖出价格
   ASK = shuju.getask(Symbol());
   BID = shuju.getbid(Symbol());
   
   //获取仓位信息
   N_ORDER_BUY  = cw.OrderNumber(Symbol(), 0, MAGIC);
   N_ORDER_SELL = cw.OrderNumber(Symbol(), 1, MAGIC);
   
   //检查开仓状态
   if(N_ORDER_BUY + N_ORDER_SELL == 0)
   {
      // 未开仓时，调用开仓条件扫描函数
      int OrderType = OpeningCondition();
      
      // OpeningCondition()返回值如下：
      //   0  开BUY单
      //   1  开SELL单   
      //  -1  不开仓
           
      if(OrderType >= 0)
      {
         //满足开仓条件时，调用开仓函数
         OpenOrder(OrderType);
      } 
   }
   else
   {
      //根据条件关闭订单
      OpenClose();
      
      // 初始化已开仓订单信息
      double OPEN_PRICE = 0.0;
      
      if(N_ORDER_BUY == 1)
      {  
         cw.OrderZJ(Symbol(), MAGIC, OPEN_PRICE);
         jy.OrderModify(Symbol(), POSITION_TYPE_BUY, OPEN_PRICE, -1, MAGIC);
      }
   }
}

//+------------------------------------------------------------------+
//| 程序关闭时执行一次，释放占用内存                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   printf("智能交易程序已关闭！");
   printf("图表窗口被关闭或者智能程序被卸载！");
}

//+------------------------------------------------------------------+
//|  开仓条件扫描函数                                                |
//+------------------------------------------------------------------+
int OpeningCondition()
{
   // 初始化返回值
   int OrderType = -1;

   //获取CCI指标值
   shuju.CCI(CCI_DATA, 3, Symbol(), TIMEFRAMES_MAIN_CHART, CCI_PERIOD, PRICE_TYPICAL);
   
   // 调用获取EMA均线数据函数
   GetEMA();
   
   //第一步 判断锚图是否达到开多条件
   if(EMA_K_ANCHOR[0] > EMA_Z_ANCHOR[0])
   {
      //获取主图指定周期内的最高最低价
      H_L_Price();
      // 第二步 判断主图是否达到开多单单条件
      if(EMA_K_MAIN[2] < EMA_M_MAIN[2] && EMA_K_MAIN[1] > EMA_M_MAIN[1] && CCI_DATA[1] > 0  && CCI_DATA[1] > CCI_DATA[2])
      {
         OrderType = 0 ; // 【0】允许开多单
      }
   }
   
   if(EMA_K_ANCHOR[2] < EMA_Z_ANCHOR[2] && EMA_Z_ANCHOR[2] < EMA_M_ANCHOR[2])
   {
      if(EMA_M_ANCHOR[1] - EMA_Z_ANCHOR[1] > EMA_M_ANCHOR[2] - EMA_Z_ANCHOR[2] && EMA_Z_ANCHOR[1] - EMA_K_ANCHOR[1] > EMA_Z_ANCHOR[2] - EMA_K_ANCHOR[2])
      {
      
      }
   }
   
   return OrderType;
} 

void OpenOrder(int OrderType)
{
   //初始化止损、止盈
   int SL, TP = 0;
   // 计算止损点位
   SL = int((ASK - LOW_PRICE) / Point() + 3);
   // 根据TP_DISCOUNT变量指定的比例，计算首次止盈点位
   TP = int(SL * TP_DISCOUNT);
   
   //开仓函数
   if(OrderType == 0)
   {
      jy.OrderOpen(Symbol(),ORDER_TYPE_BUY, 0.5, SL, TP, string(TP_PERCENTAGE) + "%_首单_BUY", MAGIC, DEVIATION);
      if(jy.OrderOpen(Symbol(),ORDER_TYPE_BUY, 0.5, SL, TP, string(TP_PERCENTAGE) + "%_次单_BUY", MAGIC, DEVIATION) > 0)
      {
         OrderModify(POSITION_TYPE_BUY, -1, 0);
      }
   }
}

// 根据条件关闭订单
void OpenClose()
{
   // 初始化已开仓订单信息
   //double OPEN_PRICE, OPEN_LOTS, OPEN_SL, OPEN_TP = 0.0;
   
   // 调用获取EMA均线数据函数
   GetEMA();
   /*
   if(N_ORDER_BUY > 0 )
   {
      //获取已开仓订单的开仓价
      cw.OrderZJ(Symbol(), POSITION_TYPE_BUY, MAGIC, OPEN_PRICE, OPEN_LOTS, OPEN_SL, OPEN_TP);
      
      //根据TP_DISCOUNT变量指定的比例，计算首次获利价格
      double TP_PRICE = OPEN_PRICE + (OPEN_PRICE - OPEN_SL) * TP_DISCOUNT * 0.1;
      
      //检查是否达到首次获利目标（按TP_PERCENTAGE变量的比例获利平仓）
      if(BID >= TP_PRICE)
      {        
         if(ct.PositionClosePartial(Symbol(), 0.05, 100) == true)
         {
            printf("达到第一获利目标！平仓量：" + NormalizeDouble(OPEN_LOTS * TP_PERCENTAGE * 0.01, 2));
         }
         else
         {
            printf("第一获利目标平仓失败！");
         }
      }*/
   //检查是否达到二次获利目标（平仓剩余30%）
   if(N_ORDER_BUY > 0 && EMA_K_MAIN[1] < EMA_M_MAIN[1])
   {
      jy.OrderClose(Symbol(), ORDER_TYPE_BUY, DEVIATION, MAGIC);
   }
   
   if(N_ORDER_SELL > 0 && EMA_K_MAIN[1] > EMA_M_MAIN[1])
   {
      jy.OrderClose(Symbol(), ORDER_TYPE_SELL, DEVIATION, MAGIC);
   }
}

// 获取最高最低价
void H_L_Price()
{
   //获取指定范围内每根K线的最高最低价格
   shuju.gethigh(HIGH_MAIN, COUNT, Symbol(), TIMEFRAMES_MAIN_CHART);
   shuju.getlow(LOW_MAIN, COUNT, Symbol(), TIMEFRAMES_MAIN_CHART);  
   
   // 获取主图指定范围内的最高最低价格
   HIGH_PRICE = HIGH_MAIN[ArrayMaximum(HIGH_MAIN, 1)];  
   LOW_PRICE = LOW_MAIN[ArrayMinimum(LOW_MAIN, 1)];        
}

//获取EMA均线数据函数
void GetEMA()
{
   //获取EMA均线数据
   shuju.MA(EMA_K_ANCHOR, 3, Symbol(), TIMEFRAMES_ANCHOR_CHART, EMA_K, 0, MODE_EMA, PRICE_CLOSE);
   shuju.MA(EMA_Z_ANCHOR, 3, Symbol(), TIMEFRAMES_ANCHOR_CHART, EMA_Z, 0, MODE_EMA, PRICE_CLOSE);
   shuju.MA(EMA_M_ANCHOR, 3, Symbol(), TIMEFRAMES_ANCHOR_CHART, EMA_M, 0, MODE_EMA, PRICE_CLOSE);
   
   shuju.MA(EMA_K_MAIN, 3, Symbol(), TIMEFRAMES_MAIN_CHART, EMA_K, 0, MODE_EMA, PRICE_CLOSE);
   shuju.MA(EMA_Z_MAIN, 3, Symbol(), TIMEFRAMES_MAIN_CHART, EMA_Z, 0, MODE_EMA, PRICE_CLOSE);
   shuju.MA(EMA_M_MAIN, 3, Symbol(), TIMEFRAMES_MAIN_CHART, EMA_M, 0, MODE_EMA, PRICE_CLOSE);
}

//根据本EA特殊定制的改单函数
void OrderModify(ENUM_POSITION_TYPE OPEN_TYPE, double SL, double TP)
{
   //暂停500毫秒后执行(不然服务器ping值高的话，修改会失败)
   Sleep(500); 
   
   //获取持仓订单总数
   int N_ORDER = PositionsTotal();
   
   //获取最后一个索引单的单号
   if(N_ORDER == 2 && PositionGetTicket(N_ORDER - 1) > 0)
   {
      if(PositionGetString(POSITION_SYMBOL)==Symbol() && OPEN_TYPE == POSITION_TYPE_BUY && PositionGetInteger(POSITION_MAGIC)==MAGIC)
      {
         MqlTradeRequest request={0};
         MqlTradeResult  result={0};
         request.action=TRADE_ACTION_SLTP;
         request.position=PositionGetTicket(N_ORDER - 1);
         request.symbol=Symbol();
         request.sl=NormalizeDouble(SL,(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS));
         request.tp=NormalizeDouble(TP,(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS));
         if(SL<0) request.sl=NormalizeDouble(PositionGetDouble(POSITION_SL),(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS));
         if(TP<0) request.tp=NormalizeDouble(PositionGetDouble(POSITION_TP),(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS));
         if(!OrderSend(request,result))
         {
            PrintFormat("BUY单止损止盈修改错误代码： %d",GetLastError()); 
         }
      }
   }
}
//=========================== 程序的最后一行==========================

