module CryptoOHLCV

using BoilerplateCvikli
using BoilerplateCvikli: @async_showerr

using BinanceAPI: query_klines, query_ticks, initialize_binance, marketdata2ohlcvt, get_stream_url, CANDLE_TO_MS
using Dates
using Base: Event, notify, reset
using JLD2

export OHLCVConfig, OHLCV, CandleType
export get_ohlcv, get_ohlcv_v, get_ohlcv_t
export extend_ohlcv!, save_ohlcv_cache, load_ohlcv_cache
export @ohlcv_str, @ohlcv_v_str, @ohlcv_t_str

include("Consts.jl")
include("Types.jl")
include("Utils.jl")
include("Interpolations.jl")
include("Config.jl")
include("Normalizer.jl")

using Base: @kwdef
using HTTP
using HTTP.Exceptions: ConnectError

# Helper functions for OHLCV
splatt(ohlcv::OHLCV) = (ohlcv.o, ohlcv.h, ohlcv.l, ohlcv.c, ohlcv.v, ohlcv.t)
splatt_notime(ohlcv::OHLCV) = (ohlcv.o, ohlcv.h, ohlcv.l, ohlcv.c, ohlcv.v)
Base.length(ohlcv::OHLCV) = length(ohlcv.t)

include("CryptoOHLCVUtils.jl")
include("CryptoOHLCV_Memoizable.jl")
include("CryptoOHLCV_InitLoad.jl")
include("CryptoOHLCV_Extend.jl")
include("DataLoader.jl")

# Cache for loaded OHLCV objects
const ohlcv_cache = Dict{String, OHLCV}()

"""
    parse_source_string(source::String) -> (exchange, market, timeframe, is_futures, from_day, to_day)

Parse a source string like "binance:BTC_USDT@1h:futures|0*7" into its components.
"""
function parse_source_string(source::String)
    # Default values
    exchange = "binance"
    market = "BTC_USDT"
    timeframe = "1m"
    is_futures = false
    from_day = 0
    to_day = 7
    
    # Parse time range if present
    if occursin("|", source)
        parts = split(source, "|")
        source = parts[1]
        
        # Parse from_day and to_day
        if occursin("*", parts[2])
            range_parts = split(parts[2], "*")
            from_day = parse(Int, range_parts[2])
            to_day = parse(Int, range_parts[1])
        elseif occursin(":", parts[2])
            range_parts = split(parts[2], ":")
            from_day = parse(Int, range_parts[2])
            to_day = parse(Int, range_parts[1])
        else
            @assert false "Separators are wrong: $(parts[2]) ($parts)"
        end
    end
    
    # Parse exchange and market
    if occursin(":", source)
        parts = split(source, ":")
        
        if length(parts) >= 2
            exchange = parts[1]
            source = parts[2]
            
            # Check for futures flag
            if length(parts) >= 3 && parts[3] == "futures"
                is_futures = true
            end
        end
    end
    
    # Parse market and timeframe
    if occursin("@", source)
        parts = split(source, "@")
        market = parts[1]
        timeframe = parts[2]
    else
        # If no @ symbol, assume the whole string is the market
        market = source
    end
    
    return exchange, market, timeframe, is_futures, from_day, to_day
end

"""
    get_ohlcv(source::String) -> OHLCV

Get OHLCV data for the given source string, using cache if available.
Example: get_ohlcv("binance:BTC_USDT@1h:futures|0*7")
"""
function get_ohlcv(source::String)
    # Check if we already have this source in cache
    if haskey(ohlcv_cache, source)
        return ohlcv_cache[source]
    end
    
    # Parse the source string
    exchange, market, timeframe, is_futures, from_day, to_day = parse_source_string(source)
    
    # Convert from_day and to_day to timestamps
    from_ts = day_to_timestamp(from_day)
    to_ts = day_to_timestamp(to_day)
    
    # Try to load from cache first
    cached_ohlcv = load_ohlcv_cache(exchange, market, timeframe, is_futures)
    
    if cached_ohlcv !== nothing
        # Check if cache covers the requested time range, extend if needed
        check_and_extend_cache!(cached_ohlcv, from_ts, to_ts)
        ohlcv = cached_ohlcv
    else
        # If no cache exists, create a new OHLCV object
        config = OHLCVConfig(
            exchange = exchange,
            market = market,
            is_futures = is_futures,
            timeframe = timeframe,
            from_day = from_day,
            to_day = to_day
        )
        
        ohlcv = OHLCV(config = config)
        
        # Download the data
        extend_ohlcv!(ohlcv, to_ts)
        
        # Save to cache
        save_ohlcv_cache(ohlcv)
    end
    
    # Store in memory cache
    ohlcv_cache[source] = ohlcv
    
    return ohlcv
end

"""
    get_ohlcv_v(source::String) -> OHLCV

Get validation OHLCV data for the given source string.
"""
function get_ohlcv_v(source::String)
    ohlcv = get_ohlcv(source)
    ohlcv.set = :VALIDATION
    return ohlcv
end

"""
    get_ohlcv_t(source::String) -> OHLCV

Get test OHLCV data for the given source string.
"""
function get_ohlcv_t(source::String)
    ohlcv = get_ohlcv(source)
    ohlcv.set = :TEST
    return ohlcv
end


# Macro versions for convenience
macro ohlcv_str(source)
    :(get_ohlcv($(esc(source))))
end

macro ohlcv_v_str(source)
    :(get_ohlcv_v($(esc(source))))
end

macro ohlcv_t_str(source)
    :(get_ohlcv_t($(esc(source))))
end

include("CryptoOHLCV_LIVE.jl")

end # module CryptoOHLCV
