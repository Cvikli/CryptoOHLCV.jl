# Basic data structures for OHLCV data
abstract type CandleType end

# Fixed reference timestamp for consistent day calculations (March 26th, 2024)
const REFERENCE_TIMESTAMP = Int(Dates.datetime2unix(DateTime(2024, 3, 26)) * 1000)

@kwdef mutable struct OHLCVConfig
    exchange::String = "binance"
    market::String = "BTC_USDT"
    is_futures::Bool = false
    timeframe::String = "1m"
    from_day::Int = 0
    to_day::Int = 7
    data_path::String = joinpath(@__DIR__, "..", "data")
end

@kwdef mutable struct OHLCV <: CandleType
    t::Vector{Int64}   = Int64[]
    o::Vector{Float32} = Float32[]
    h::Vector{Float32} = Float32[]
    l::Vector{Float32} = Float32[]
    c::Vector{Float32} = Float32[]
    v::Vector{Float32} = Float32[]
    
    config::OHLCVConfig = OHLCVConfig()
    misses::Vector{UnitRange}  = UnitRange{Int}[]
    set::Symbol                = :TRAIN
end

# Helper functions for day-timestamp conversion
day_to_timestamp(day::Int) = REFERENCE_TIMESTAMP - day * 24 * 60 * 60 * 1000
timestamp_to_day(ts::Int) = round(Int, (REFERENCE_TIMESTAMP - ts) / (24 * 60 * 60 * 1000))
