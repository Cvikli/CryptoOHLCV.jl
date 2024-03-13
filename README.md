# CryptoOHLCV.jl
Simplest Crypto Data management. 
Built upon [UltimateStruct.jl](https://github.com/Cvikli/UniversalStruct.jl).

```julia
using CryptoOHLCV

d = ohlcv"1h"           # the 1h candles of the train set for the market and range that is configured by the "ctx" module variable
d = ohlcv"5m"
d = ohlcv"1m"
d = ohlcv"tick100"
d = ohlcv_v"5m"         # validation 5m candles for the configured market
d = ohlcv_v"30m"   
d = ohlcv_v"tick500"
```

Basically you can get the timeframe data anytime.

To configure your dataset you have to set the `OHLCVConfig`

```julia
using CryptoOHLCV
ctx.exchange    = "binance"
ctx.market      = "BTC_USDT"
ctx.is_futures  = false
ctx.dayframe    = 0:2
```

`ctx` is a OHLCVConfig struct, the important things are: 
```julia
@kwdef mutable struct OHLCVConfig
  use_cache::Bool   = true 
  source::String    ="binance:BTC_USDT:futures"
	dayframe::UnitRange{Int}     = 30:41
	timestamps::UnitRange{Int}   = -1:-1
  maximum_candle_size::Int     = 3600
  data_path::String = "./data"
end
```
So the key is to  define the data accurately ranges => Then query with different market/timeframe/spot&futures or even exchanges(by CCXT later on). 


LIVE trading...
```julia
d = ohlcv"1h"

stop_LIVE_data(d) 
start_LIVE_data(d)

trade_on_notify() #  function that shows the pattern where you can implement the trading 

```

# Features
- It handles different timeframes
- Configurable timerange and dataset with days (or timestamps) with `ctx`.
- Caches locally (so the next time you access the ohlcv"5m" on this range it is just map out the value from the dictionary)
- Caches to the disk, so whenever you download some new dataset, it will be reused later on by extending this further.
- Automatically cleans the data that is overlapped by bigger dataset.
- `tick100` or... so `tick`N options to address tick data on a range
- Candle sync, so basically we cut every "start timestamp" to be divideable with a "hour" so if you use different timeframes, you still work on the same dataset, till you are below 1 hour. If you are over that, then you have to change the "maximum_candle_size" (in seconds)
- It handles validation and train dataset with a `_v` suffix. So we can make sure we don't overlap due to we select diffferent ranges for sure. 
- CCXT is used, it can be easily extended to handle even more exchange. (Not sure if it is working atm but it is easily implementable for sure from here)



# TODO:
- "LIVE" feature is ready but we coud add the "from:LIVE" range. VERY easy to do... so later on!
- use this: https://github.com/baggepinnen/SignalAlignment.jl
- need to handle multiple slices... also recognize gaps and create slices...

# Any advice is appreciated!


