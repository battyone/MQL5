#property copyright "Copyright 2018, MetaQuotes Software Corp."
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
double lots = 0.01;
int sl = 200;
int tp = 200;
int magic_RL_DQN = 321;
int deviation = 5;
string commBuy = "BUY";
string commSell = "SELL";

datetime 开盘时间 = 0;
datetime openTime[];

double EMA_3[];
double EMA_5[];
double EMA_8[];
double EMA_10[];
double EMA_12[];
double EMA_15[];
double EMA_30[];
double EMA_35[];
double EMA_40[];
double EMA_45[];
double EMA_50[];
double EMA_60[];

string 记录余额开关 = "off";  //当空仓时得到开仓指令后，记录当前余额并打开开关
double 记录余额 = 0.0;     //记录开单前的余额，用于计算平仓后的盈亏 =（实时余额 - 记录余额）

int tick_counter = 0;      //价格变动计数器
double reward = 0.0;       //记录奖励值的变量
string action = "";        //初始化一个接收动作指令的变量action,值为：“空”

string 回合开关 = "off";

int orderNum_BUY = 0;
int orderNum_SELL = 0;

input int max_order = 21;
input string 交易品种名称 = "EURUSD";
input ENUM_TIMEFRAMES 图表周期 = PERIOD_CURRENT;

//int tickNumber = 2;         //价格每波动?次后返回状态[数值不能低于2]
//int tickCounter = 0;        //价格波动计数器，每次波动tickCounter + 1
string state_switch = "off";  //调用存储状态函数的开关

//初始化状态文件名称   
string FileName_init = "Init_State_MT5.csv";
string FileName_env  = "Next_State_MT5.csv";

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
   //获取当前开盘时间
   shuju.gettime(openTime, 3);
   
   //价格变动计数器+1
   tick_counter += 1;
   //价格每变动N次后，写入初始化状态
   if(tick_counter == 0 || tick_counter == 50)
   {
      SaveFile(FileName_init, 0);  
      tick_counter = 1;
   }
   
   //每一根K线开盘时
   if(开盘时间 != openTime[0])
   {
      if(state_switch == "on")   //状态开关打开时
      {
         SaveFile(FileName_env, 1); //写入下一步状态
         state_switch = "off";   //关闭状态开关
         开盘时间 = openTime[0];
      }       
   }
   
   //监听动作指令
   if(state_switch == "off")
   {
      if(Action() == 1)
      {     
         state_switch = "on"; 
         开盘时间 = openTime[0];  
      }
   }
}
  
//+------------------------------------------------------------------+
//| Action函数的作用——接收指令执行动作(动作指令监听器)             |
//+------------------------------------------------------------------+
int Action()
{  
   //获取开仓订单数量
   orderNum_BUY = cw.OrderNumber(交易品种名称, 0, magic_RL_DQN);
   orderNum_SELL= cw.OrderNumber(交易品种名称, 1, magic_RL_DQN);
   
   //以只读方式打开动作指令文件
   int 文件句柄 = FileOpen("Action.csv", FILE_READ|FILE_SHARE_READ|FILE_CSV|FILE_ANSI, ",");
   
   //判断文件是否存在
   if(文件句柄 != INVALID_HANDLE)
   {
      //如果文件存在，读取动作指令
      action = FileReadString(文件句柄);
      //关闭文件
      FileClose(文件句柄);
      //读取动作指令后删除文件
      FileDelete("Action.csv");
      
      //当空仓时得到开仓指令后，记录当前余额并打开开关
      if(orderNum_BUY + orderNum_SELL == 0 && 记录余额开关 =="off")
      {
         if(action == "1" || action == "2")
         {
            记录余额开关 = "on";
            记录余额 = zh.账户余额();
         }
      } 
      
      //执行指令
      if(action == "0")
      {
         printf("观望中...");
      }
      
      if(orderNum_BUY + orderNum_SELL < max_order)
      {
         if(action == "1")
         {
            if(jy.OrderOpen(交易品种名称, ORDER_TYPE_BUY, 0.01, sl, tp, IntegerToString(cw.OrderNumber(交易品种名称, 0, magic_RL_DQN) + 1 ) + "_" + commBuy, magic_RL_DQN, deviation) > 0)
            {
               printf("[BUY] 开仓");  
            }
         }
         if(action == "2")
         {
            if(jy.OrderOpen(交易品种名称, ORDER_TYPE_SELL, 0.01, sl, tp, IntegerToString(cw.OrderNumber(交易品种名称, 1, magic_RL_DQN) + 1 ) + "_" + commSell, magic_RL_DQN, deviation) > 0)
            {
               printf("[SELL] 开仓");
            }
         }
      }

      return 1;  
   }
   else
   {
      return 0;
   }
}

//+------------------------------------------------------------------+
//| Reward函数的作用——计算奖励值                                     |
//|                                                                  |
//|1.状态：  空仓 且 记录余额不等于0 正收益 奖励：1 负收益 奖励：-1  |
//|2.状态：  空仓    动作：观望（0）   奖励：-0.1
//|3.状态：  其他    动作：观望（0）   奖励：0
//|4.状态： 未满仓   动作：做空（1）   奖励：0.01
//|5.状态： 未满仓   动作：做多（2）   奖励：0.01
//|6.状态： 已满仓   动作：做空（1）   奖励：-1
//|7.状态： 已满仓   动作：做多（2）   奖励：-1
//|8.状态：多等于空  动作：观望（0）   奖励：-0.01
//|
//+------------------------------------------------------------------+
void Reward()
{
   //获取开仓订单数量
   orderNum_BUY = cw.OrderNumber(交易品种名称, 0, magic_RL_DQN);
   orderNum_SELL= cw.OrderNumber(交易品种名称, 1, magic_RL_DQN);

   //每次计算前清零
   reward = 0;
   
   if(orderNum_BUY + orderNum_SELL >= max_order)
   {
      if(action == "1" || action == "2")
      {
         reward = -1;
      }
   }
   if(orderNum_BUY + orderNum_SELL == 0)
   {
      if(action == "0")
      {
         reward = -5;
      }
   }
   else
   {
      if(action == "1" && action == "2")
      {
         // 随着单数增加而增加惩罚
         reward = -1 / (max_order - 1) * (orderNum_BUY + orderNum_SELL);
      }
      else
      {
         reward = 0.01;
      }
   }
   
   //空仓
   if(orderNum_BUY + orderNum_SELL == 0)
   {
      if(记录余额开关 == "on")
      {  
         //回合结束的奖励
         if(记录余额 > 0)
         {
            reward += zh.账户余额() - 记录余额;
            记录余额开关 = "off";
         }
      }
   } 
}
//+------------------------------------------------------------------+
//| SaveFile函数的作用——把数据写入文件                               |
//+------------------------------------------------------------------+
void SaveFile(string FileName, int num)
{
   // num = 0 为初始化状态
   // num = 1 为下一步状态，再去计算奖励
   if(num == 1)
   {
      Reward(); 
   }
   //获取顾比均线组合数据
   shuju.MA(EMA_3,  60, 交易品种名称, 图表周期, 3,  0, MODE_EMA, PRICE_CLOSE);
      
   //以读写方式打开文件(如果没有此文件将创建此文件)
   int SaveData = FileOpen(FileName, FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_CSV|FILE_ANSI, ",");
   //判断文件是否正确打开
   if(SaveData != INVALID_HANDLE)
   {
      //把开盘时间和开盘价格写入文件
      FileWrite(SaveData, NormalizeDouble((zh.当前净值() - zh.账户余额()) * 0.01, 5) , orderNum_BUY * 0.01, orderNum_SELL * 0.01, reward);
      //关闭文件
      FileClose(SaveData);
      //写入文件成功的提示
      //printf("环境数据已写入！");
   }
   else
   {
      printf("环境数据写入失败！");
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