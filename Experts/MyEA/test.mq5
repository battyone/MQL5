//+------------------------------------------------------------------+
//|                      htTPs://www.youtube.com/watch?v=zhEukjCzXwM |
//|                                 上面链接中介绍的五分钟剥头皮策略 |
//|                                             htTPs://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "五分钟剥头皮策略"
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| 引入程序需要的类库并创建对象                                     |
//+------------------------------------------------------------------+
#include <MyClass\shuju.mqh>
#include <MyClass\交易类\信息类.mqh>
#include <MyClass\交易类\交易指令.mqh>
#include <MyClass\交易类\仓位管理.mqh>

ShuJu shuju;
账户信息 zh;
交易指令 jy;
仓位信息 cwx;
仓位管理 cwg;

//+------------------------------------------------------------------+
//| 初始化全局变量                                                   |
//+------------------------------------------------------------------+
input double MaxRisk = 2;

string SYMBOL = Symbol();
int MAGIC = 123;
int DEVIATION = 3;
int SL_PIP, TP_PIP = 0;
int N_ORDER_BUY, N_ORDER_SELL = 0;      
double LOTS_ORDER = 0;
double BUY_PRICE, SELL_PRICE, SL_PRICE, TP_PRICE, P2_TP_PRICE, ASK_PRICE, BID_PRICE = 0.0;
string ORDER_SWITCH = "off";
string COMM_BUY = "_BUY";
string COMM_SELL= "_SELL";
string OBJECT_NAME = "预开仓提示标识";
datetime O_TIME = 0;
datetime OPEN_TIME[];

double CLOSE_H1[];
double OPEN_M5[];
double HIGH_M5[];
double LOW_M5[];
double CLOSE_M5[];

int PERIOD_K_H1 = 8;
int PERIOD_M_H1 = 21;
int PERIOD_K_M5 = 8;
int PERIOD_Z_M5 = 13;
int PERIOD_M_M5 = 21;
double KMA_H1[];
double MMA_H1[];
double KMA_M5[];
double ZMA_M5[];
double MMA_M5[];

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
   ASK_PRICE = shuju.getask(SYMBOL);  //当前做多价格
   BID_PRICE = shuju.getbid(SYMBOL);  //当前做空价格
   N_ORDER_BUY  = cwx.OrderNumber(SYMBOL, 0, MAGIC);
   N_ORDER_SELL = cwx.OrderNumber(SYMBOL, 1, MAGIC);
   shuju.getopen (OPEN_M5, 3, SYMBOL, PERIOD_M5);
   shuju.gethigh (HIGH_M5, 3, SYMBOL, PERIOD_M5);
   shuju.getlow  (LOW_M5, 3, SYMBOL, PERIOD_M5);
   shuju.getclose(CLOSE_M5, 3, SYMBOL, PERIOD_M5);
   shuju.getclose(CLOSE_H1, 3, SYMBOL, PERIOD_H1);
   //调用市价扫描函数
   ScanPrice();
   //开仓
   OpenOrder();
   //扫描失效的预开仓标识
   ScanObject();
   //移动止损函数
   OrderModify();
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
//|  市价扫描函数——寻找开仓条件                                      |
//+------------------------------------------------------------------+
void ScanPrice()
{
   //初始化必要的账户、市场、仓位等信息变量
   shuju.gettime(OPEN_TIME, 1);       //开盘时间  
   shuju.MA(KMA_H1, 10, SYMBOL, PERIOD_H1, PERIOD_K_H1, 0, MODE_EMA, PRICE_CLOSE); 
   shuju.MA(MMA_H1, 10, SYMBOL, PERIOD_H1, PERIOD_M_H1, 0, MODE_EMA, PRICE_CLOSE);
   shuju.MA(KMA_M5, 10, SYMBOL, PERIOD_M5, PERIOD_K_M5, 0, MODE_EMA, PRICE_CLOSE); 
   shuju.MA(ZMA_M5, 10, SYMBOL, PERIOD_M5, PERIOD_Z_M5, 0, MODE_EMA, PRICE_CLOSE); 
   shuju.MA(MMA_M5, 10, SYMBOL, PERIOD_M5, PERIOD_M_M5, 0, MODE_EMA, PRICE_CLOSE);
   
   if(N_ORDER_BUY + N_ORDER_SELL == 0 && ORDER_SWITCH == "off" && O_TIME != OPEN_TIME[0])
   {
      if(KMA_H1[0] < MMA_H1[0] && CLOSE_H1[0] < KMA_H1[0] && KMA_H1[0] < KMA_H1[1])
      {
         if(KMA_M5[1]<ZMA_M5[1] && KMA_M5[1] < KMA_M5[2] && MMA_M5[1] - KMA_M5[1] > 15 * Point())
         {
            if(HIGH_M5[1] > KMA_M5[1] && HIGH_M5[1] < ZMA_M5[1])
            {
               ORDER_SWITCH = "on-sell";
               Arrow(ORDER_SWITCH);
               Operation_Lots(ORDER_SWITCH);
               O_TIME = OPEN_TIME[0];
               printf("预开仓标记,已放置");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 计算下单量函数——计算触发止损后每单最大可承受本金损失比例的金额   |
//+------------------------------------------------------------------+
void Operation_Lots(string orderType)
{
   //初始化必要的账户、市场、仓位等信息变量
   double HIGH_PRICE = HIGH_M5[ArrayMaximum(HIGH_M5, 1)];        //寻找前5根K线最高价
   double LOW_PRICE = LOW_M5[ArrayMinimum(LOW_M5, 1)];           //寻找前5根K线最低价
   
   double pip = cwg.PIP_Value(SYMBOL);                  // 一标准手价格波动1pip对应的账户资金价值
   double maxLoss = 0.01 * MaxRisk * zh.账户余额();       // 允许的最大损失所对应的余额价值
   
   if(orderType == "on-sell")
   {
      //计算开仓价、止损点位及下单手数
      SELL_PRICE = LOW_PRICE - 3 * Point();               //以前六日价格以下三个点为做空价格
      SL_PRICE = HIGH_M5[1] + 5 * Point();                //以前一日内最高价格加三个点为止损价格
      SL_PIP = int((SL_PRICE - SELL_PRICE) / Point());   //计算买入价与止损价之间点位
      TP_PIP = SL_PIP;                                  //止盈点数等于止损点数
      TP_PRICE = SELL_PRICE - SL_PIP*Point();  
      P2_TP_PRICE = SELL_PRICE - SL_PIP*2*Point();
      
      Arrow(orderType); //绘制预开仓标记
   }
   
   LOTS_ORDER = NormalizeDouble(maxLoss / 2 / (SL_PIP * pip), 2);    //计算下单手数(因为同时下2单所以要除以2)
}

//+------------------------------------------------------------------+
//| 开单函数                                                         |
//+------------------------------------------------------------------+

void OpenOrder()
{
   if(ORDER_SWITCH == "on-sell" && BID_PRICE <= SELL_PRICE && N_ORDER_BUY + N_ORDER_SELL == 0)
   {
      for(int i=0; i<2; i++)
      {
         if(i == 0)
         {
            printf("ORDER_SWITCH: " + ORDER_SWITCH);
            jy.OrderOpen(SYMBOL,ORDER_TYPE_SELL, LOTS_ORDER, SL_PIP, TP_PIP, "P1"+COMM_SELL, MAGIC, DEVIATION);
         }
         else
         {
            jy.OrderOpen(SYMBOL,ORDER_TYPE_SELL, LOTS_ORDER, SL_PIP, TP_PIP*2, "P2"+COMM_SELL, MAGIC, DEVIATION);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 移动止损修改订单函数                                                     |
//+------------------------------------------------------------------+
void OrderModify()
{
   if(N_ORDER_BUY + N_ORDER_SELL == 1)
   {
      double openPrice_k = 0.0;
      cwx.OrderZJ(SYMBOL, MAGIC, openPrice_k);
      
      if(N_ORDER_BUY == 1)
         jy.OrderModify(SYMBOL, POSITION_TYPE_BUY, openPrice_k, -1, MAGIC);
      if(N_ORDER_SELL == 1)
         jy.OrderModify(SYMBOL, POSITION_TYPE_SELL, openPrice_k, -1, MAGIC);
   }
}

//+------------------------------------------------------------------+
//|  失效的预开仓标记扫描函数                                        |
//+------------------------------------------------------------------+
void ScanObject()
{
   if(ObjectFind(0, OBJECT_NAME) >= 0)
   {
      if(BID_PRICE <= SELL_PRICE || BID_PRICE > SL_PRICE)
      {
         ObjectDelete(0, OBJECT_NAME);
         printf("失效的预开仓标记,已删除！");
         ORDER_SWITCH = "off";
      }
   }
} 

//+------------------------------------------------------------------+
//| 绘制预开仓标记                                                   |
//+------------------------------------------------------------------+
void Arrow(string orderType)
{
   if(orderType == "on-sell")
   {
      ObjectCreate(0,OBJECT_NAME,OBJ_ARROW,0,0,0,0,0);                      //创建一个箭头 
      ObjectSetInteger(0,OBJECT_NAME,OBJPROP_TIME,OPEN_TIME[0]);            //设置时间 
      ObjectSetInteger(0,OBJECT_NAME,OBJPROP_COLOR, clrGreenYellow);        //设置箭头颜色
      ObjectSetInteger(0,OBJECT_NAME,OBJPROP_ARROWCODE,108);                //设置箭头代码    
      ObjectSetDouble(0,OBJECT_NAME,OBJPROP_PRICE,LOW_M5[1] - 10*Point());  //预定价格 
      ChartRedraw(0);  //绘制箭头
   }
   if(orderType == "on-buy")
   {
      ObjectCreate(0,OBJECT_NAME,OBJ_ARROW,0,0,0,0,0);                      //创建一个箭头 
      ObjectSetInteger(0,OBJECT_NAME,OBJPROP_TIME,OPEN_TIME[0]);            //设置时间 
      ObjectSetInteger(0,OBJECT_NAME,OBJPROP_COLOR, clrRed);                //设置箭头颜色
      ObjectSetInteger(0,OBJECT_NAME,OBJPROP_ARROWCODE,233);                //设置箭头代码    
      ObjectSetDouble(0,OBJECT_NAME,OBJPROP_PRICE,HIGH_M5[1] + 10*Point()); //预定价格 
      ChartRedraw(0);  //绘制箭头
   }
}
//=========================== 程序的最后一行==========================

