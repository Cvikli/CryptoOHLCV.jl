# DataLoader.jl - Simple interface for loading market data

export load_market_data, get_ohlcv_pro

"""
Simple interface for loading OHLCV data with three main methods:

1. Direct string syntax:
    get_ohlcv("binance:BTC_USDT@1h:futures|0*7")

2. Explicit parameters:
    get_ohlcv_pro("BTC_USDT", "1h", 0, 7)

3. Using global context:
    load_market_data("1h|0*7")
"""
function get_ohlcv_pro(source_str::String)
    # Parse source string into components
    exchange, market, timeframe, is_futures, from_day, to_day = parse_source_string(source_str)
    
    # Fetch raw data
    raw_data = fetch_ohlcv_data(exchange, market, timeframe, is_futures, from_day, to_day)
    
    # Process into final format
    process_ohlcv_data(raw_data, timeframe)
end

function get_ohlcv_pro(
    market::String,
    timeframe::String,
    from_day::Int,
    to_day::Int;
    exchange::String="binance",
    is_futures::Bool=false
)
    source = "$(exchange):$(market)@$(timeframe)$(is_futures ? ":futures" : "")|$(to_day)*$(from_day)"
    get_ohlcv(source)
end


function load_market_data(source::String)
    source = add_context_to_source(source, ctx)
    get_ohlcv(source)
end

"""
Load OHLCV market data with explicit parameters without relying on global context.
Example:
    get_ohlcv_pro("BTC_USDT", "15m", 580, 1580, exchange="binance", is_futures=true)
"""

"""
Load OHLCV market data with explicit parameters.
Example:
    load_market_data(timeframe="15m", from_day=580, to_day=1580, market="ETH_USDT")
"""
function load_market_data(;
    timeframe::String="1m",
    from_day::Int=0,
    to_day::Int=7,
    market::Union{String,Nothing}=nothing,
    exchange::Union{String,Nothing}=nothing,
    is_futures::Union{Bool,Nothing}=nothing
)
    isnothing(market)    || (ctx.market = market)
    isnothing(exchange)  || (ctx.exchange = exchange)
    isnothing(is_futures)|| (ctx.is_futures = is_futures)
    
    source = "$timeframe|$(to_day)*$(from_day)"
    get_ohlcv(source)
end


# Internal helper functions
function fetch_ohlcv_data(exchange, market, timeframe, is_futures, from_day, to_day)
    if exchange == "binance"
        if timeframe == "tick"
            return fetch_binance_tick_data(market, is_futures, from_day, to_day)
        else
            return fetch_binance_candle_data(market, is_futures, timeframe, from_day, to_day)
        end
    else
        return fetch_ccxt_data(exchange, market, is_futures, timeframe, from_day, to_day)
    end
end

function process_ohlcv_data(raw_data, timeframe)
    # Convert raw data to OHLCV format
    ohlcv = raw_to_ohlcv(raw_data)
    
    # Handle missing data points
    interpolate_missing_data!(ohlcv)
    
    # Resample to requested timeframe if needed
    resample_timeframe!(ohlcv, timeframe)
    
    ohlcv
end
