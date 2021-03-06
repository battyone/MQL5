#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

class 仓位管理
{
   public:
   
   double PIP_Value(const string 交易品种, const double 下单量 = 1);
   //double N_Value(const string 交易品种, const ENUM_TIMEFRAMES 时间周期, const int ATR指标周期);
   double HG_LOTS(const string 交易品种, const double 单量占余额比 = 1.0);
   double HG_LOTS1(const string 交易品种, const double 海龟N值, const double 每笔亏损占余额比例 = 2.0);
   double HG_SL(const string 交易品种, const double 海龟N值, const ENUM_ORDER_TYPE 订单类型);
   
};
/*
double 仓位管理::N_Value(const string 交易品种, const ENUM_TIMEFRAMES 时间周期, const int ATR指标周期)
{
   //根据【ATR指标周期】参数获取指标值，用来计算海龟法则中的N值
   double data[];
   int h = iATR(交易品种, 时间周期, ATR指标周期); 
   ArraySetAsSeries(data, true);
   CopyBuffer(h, 0, 0, 1, data);
   double N = NormalizeDouble(data[0], 5);
   
   return N;
}*/

//遵照海龟法则中仓位管理方法构建的函数(当前N值的点位相当于余额的百分之一)
double 仓位管理::HG_LOTS(const string 交易品种, const double 单量占余额比 = 1.0)
{  
   double LOTS = 0.0; 
   double 余额 = AccountInfoDouble(ACCOUNT_BALANCE);
   double 预付款 = YuFuKuan(交易品种); 
   
   LOTS = NormalizeDouble(余额 / 预付款 * 0.01, 2);
   
   return LOTS;   
}

double 仓位管理::HG_LOTS1(const string 交易品种, const double 海龟N值, const double 每笔亏损占余额比例 = 2.0)
{
   //根据【账户余额】【每笔亏损占余额比例】两个参数计算【允许单笔最大损失】额度
   double 允许单笔最大损失 = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) * 每笔亏损占余额比例 * 0.01, 2);
   
   //计算下单量
   double LOTS =  NormalizeDouble(允许单笔最大损失 / (2 * 海龟N值) * SymbolInfoDouble(交易品种, SYMBOL_POINT), 2);
   
   return LOTS;
}

double 仓位管理::HG_SL(const string 交易品种, const double 海龟N值, const ENUM_ORDER_TYPE 订单类型)
{
   double 止损 = 0.0;
   double ASK = SymbolInfoDouble(交易品种, SYMBOL_ASK);
   double BID = SymbolInfoDouble(交易品种, SYMBOL_BID);
   
   //根据做空做多设置止损点位(在该点位止损的话损失金额 约等于 账户余额的2%。 【手续费、滑点并未计算在内】)
   if(订单类型 == ORDER_TYPE_BUY)
   {
      止损 = ASK - 2 * 海龟N值;    // 价格下跌2N 账户资金损失2%  
   }
   if(订单类型 == ORDER_TYPE_SELL)
   {
      止损 = BID + 2 * 海龟N值;    // 价格上涨2N 账户资金损失2%
   }
   
   return NormalizeDouble(止损, int(SymbolInfoInteger(交易品种,SYMBOL_DIGITS)));
}

//计算交易品种最小点值函数
double 仓位管理::PIP_Value(const string 交易品种, const double 下单量 = 1)
{
   double 点值 = 0.0;
   double close1;
   double close2;
   
   string 基础货币 = SymbolInfoString(交易品种, SYMBOL_CURRENCY_BASE);
   string 计价货币 = SymbolInfoString(交易品种, SYMBOL_CURRENCY_PROFIT);
   string 账户货币 = AccountInfoString(ACCOUNT_CURRENCY);
   
   double 标准手合约数量 = SymbolInfoDouble(交易品种, SYMBOL_TRADE_CONTRACT_SIZE);
   double 基点 = SymbolInfoDouble(交易品种, SYMBOL_TRADE_TICK_SIZE);
   
   //直盘货币对的点值计算(公式：点值 =下单量(Lot Size) * 标准手合约数量(Contract Size) * 基点(Tick Size))
   if(计价货币 == 账户货币)
   {
      点值 = 下单量 * 标准手合约数量 * 基点;
   }
   
   //非直盘货币对的点值计算(公式：点值=下单量(Lot Size) * 标准手合约数量(Contract Size) * 基点(Tick Size) / 本货币对的汇率 (Current Rate))
   if(基础货币 == 账户货币)
   {
      close1 = SymbolInfoDouble(交易品种, SYMBOL_BID);     
      点值 = 下单量 * 标准手合约数量 * 基点 / close1;
   }
   
   //交叉盘货币对的点值计算(公式：点值=下单量(Lot Size) * 标准手合约数量(Contract Size) * 基点(Tick Size) * [基础货币/账户货币]货币对的汇率 / 本货币对的汇率 (Current Rate))
   if(基础货币 != 账户货币 && 计价货币 != 账户货币)
   {

      close1 = SymbolInfoDouble(交易品种, SYMBOL_BID);
      close2 = SymbolInfoDouble(基础货币+账户货币, SYMBOL_BID);
      
      点值 = 下单量 * 标准手合约数量 * 基点 * close2 / close1;
   }
   
   return NormalizeDouble(点值, 5); 
}

double YuFuKuan(const string 交易品种, const double 下单量 = 1.0)
{
   double 预付款 = 0.0;
   string 基础货币 = SymbolInfoString(交易品种, SYMBOL_CURRENCY_BASE);
   string 计价货币 = SymbolInfoString(交易品种, SYMBOL_CURRENCY_PROFIT);
   string 账户货币 = AccountInfoString(ACCOUNT_CURRENCY);
   
   long 杠杆 = AccountInfoInteger(ACCOUNT_LEVERAGE);
   double 市价 = SymbolInfoDouble(交易品种, SYMBOL_BID);
   double 合约大小 = SymbolInfoDouble(交易品种, SYMBOL_TRADE_CONTRACT_SIZE); 
   
   //直盘货币对 如：EURUSD
   if(计价货币 == 账户货币)
   {
      
      预付款 = 合约大小 * 下单量 * 市价 / 杠杆;
   }
   
   //非直盘货币对 如：USDJPY
   if(基础货币 == 账户货币)
   {
      预付款 = 合约大小 * 下单量 / 杠杆;
   }
   
   //交叉盘货币对 如：EURGBP
   if(基础货币 != 账户货币 && 计价货币 != 账户货币)
   {
      市价 = SymbolInfoDouble(基础货币 + 账户货币, SYMBOL_BID);
      预付款 = 合约大小 * 下单量 * 市价 / 杠杆;
   }
   
   return 预付款;
}