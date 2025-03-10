# Functions for extending OHLCV data with new data

using JLD2
using Dates

"""
    extend_ohlcv!(ohlcv::CandleType, to_time::Int)

Extend an existing OHLCV object with new data up to the specified timestamp.
"""
function extend_ohlcv!(ohlcv::T, to_time::Int) where T <: CandleType
    # If we're already up to date, return early
    if !isempty(ohlcv.t) && last(ohlcv.t) >= to_time
        return ohlcv
    end
    
    # Determine the start time for the new data
    start_time = isempty(ohlcv.t) ? day_to_timestamp(ohlcv.config.from_day) : last(ohlcv.t) + 1
    
    # Get candle type for query
    candle = ohlcv.config.timeframe
    
    # Query new data
    if startswith(candle, "tick")
        new_o, new_h, new_l, new_c, new_v, new_t, new_misses = dwnl_tick_data(
            ohlcv.config.market, ohlcv.config.is_futures, start_time, to_time
        )
    else
        new_o, new_h, new_l, new_c, new_v, new_t, new_misses = dwnl_candle_data(
            ohlcv.config.market, ohlcv.config.is_futures, start_time, to_time, candle
        )
    end
    
    # If we got new data, append it
    if !isempty(new_t)
        ohlcv.t = vcat(ohlcv.t, new_t)
        ohlcv.o = vcat(ohlcv.o, new_o)
        ohlcv.h = vcat(ohlcv.h, new_h)
        ohlcv.l = vcat(ohlcv.l, new_l)
        ohlcv.c = vcat(ohlcv.c, new_c)
        ohlcv.v = vcat(ohlcv.v, new_v)
        ohlcv.misses = vcat(ohlcv.misses, new_misses)
    end
    
    return ohlcv
end

"""
    get_cache_path(ohlcv::CandleType)

Generate a cache file path for an OHLCV object.
"""
function get_cache_path(ohlcv::T) where T <: CandleType
    dir = joinpath(ohlcv.config.data_path, ohlcv.config.exchange)
    mkpath(dir)
    
    # Format: exchange_market_candle_futures.jld2
    futures_str = ohlcv.config.is_futures ? "_futures" : "_spot"
    filename = "$(ohlcv.config.exchange)_$(ohlcv.config.market)_$(ohlcv.config.timeframe)$(futures_str).jld2"
    return joinpath(dir, filename)
end

"""
    save_ohlcv_cache(ohlcv::CandleType)

Save OHLCV data to cache file.
"""
function save_ohlcv_cache(ohlcv::T) where T <: CandleType
    filepath = get_cache_path(ohlcv)
    
    # Save to JLD2 file
    jldopen(filepath, "w") do file
        file["ohlcv"] = ohlcv
        file["last_updated"] = now(UTC)
    end
    
    return filepath
end

"""
    load_ohlcv_cache(exchange, market, timeframe, is_futures)

Load OHLCV data from cache if available.
"""
function load_ohlcv_cache(exchange, market, timeframe, is_futures)
    # Create a temporary OHLCV object to get the cache path
    config = OHLCVConfig(
        exchange = exchange,
        market = market,
        is_futures = is_futures,
        timeframe = timeframe
    )
    
    temp_ohlcv = OHLCV(config = config)
    
    filepath = get_cache_path(temp_ohlcv)
    
    if isfile(filepath)
        try
            return jldopen(filepath, "r") do file
                file["ohlcv"]::OHLCV
            end
        catch e
            @warn "Failed to load cache file: $filepath" exception=e
        end
    end
    
    return nothing
end

"""
    check_and_extend_cache!(ohlcv::CandleType, fr::Int, to::Int)

Check if the OHLCV data covers the requested time range, and extend if needed.
"""
function check_and_extend_cache!(ohlcv::T, fr::Int, to::Int) where T <: CandleType
    # If data is empty, download the full range
    if isempty(ohlcv.t)
        extend_ohlcv!(ohlcv, to)
        save_ohlcv_cache(ohlcv)
        return ohlcv
    end
    
    # Check if we need to extend the data
    data_start = first(ohlcv.t)
    data_end = last(ohlcv.t)
    
    # Extend backward if needed
    if fr < data_start
        # For simplicity, we'll redownload the entire range if we need earlier data
        @info "Extending data backward from $(unix2datetime(data_start ÷ 1000)) to $(unix2datetime(fr ÷ 1000))"
        
        candle = ohlcv.config.timeframe
        if startswith(candle, "tick")
            new_o, new_h, new_l, new_c, new_v, new_t, new_misses = dwnl_tick_data(
                ohlcv.config.market, ohlcv.config.is_futures, fr, data_start - 1
            )
        else
            new_o, new_h, new_l, new_c, new_v, new_t, new_misses = dwnl_candle_data(
                ohlcv.config.market, ohlcv.config.is_futures, fr, data_start - 1, candle
            )
        end
        
        if !isempty(new_t)
            # Prepend the new data
            ohlcv.t = vcat(new_t, ohlcv.t)
            ohlcv.o = vcat(new_o, ohlcv.o)
            ohlcv.h = vcat(new_h, ohlcv.h)
            ohlcv.l = vcat(new_l, ohlcv.l)
            ohlcv.c = vcat(new_c, ohlcv.c)
            ohlcv.v = vcat(new_v, ohlcv.v)
            ohlcv.misses = vcat(new_misses, ohlcv.misses)
        end
    end
    
    # Extend forward if needed
    if to > data_end
        @info "Extending data forward from $(unix2datetime(data_end ÷ 1000)) to $(unix2datetime(to ÷ 1000))"
        extend_ohlcv!(ohlcv, to)
    end
    
    # Update config from_day and to_day based on actual data
    ohlcv.config.from_day = timestamp_to_day(first(ohlcv.t))
    ohlcv.config.to_day = timestamp_to_day(last(ohlcv.t))
    
    # Save updated cache
    save_ohlcv_cache(ohlcv)
    
    return ohlcv
end
