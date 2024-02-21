module CryptoOHLCV


using Boilerplate

using BinanceAPI: query_klines, query_ticks, initialize_binance, marketdata2ohlcvt
using Dates
using JLD2
using FileIO
using Revise


using Glob

export @ohlcv_str, @ohlcv_v_str, ctx


include("Consts.jl")
include("Utils.jl")
include("Interpolations.jl")
include("Config.jl")

using Base: @kwdef



abstract type CandleType end

date_range(ohlcv::T) where T <: CandleType = date_range(first(ohlcv.timestamps),last(ohlcv.timestamps)) # format(DateTime(first(ohlcv.ts)), "yyyy.mm.dd HH:MM")
splatt(ohlcv::T)     where T <: CandleType = (ohlcv.o,ohlcv.h,ohlcv.l,ohlcv.c,ohlcv.v,ohlcv.ts)


@kwdef mutable struct OHLCV <: CandleType
	set::Symbol         = :UNINITIALIZED
	exchange::String    = ""
	market::String      = ""
	is_futures::Bool    = false
	candle_type::Symbol = :UNKNOWN   # :TICK, :SECOND, :MINUTE, :HOUR, :DAY
	candle_value::Int   = -1
	timestamps::UnitRange{Int} = UnitRange{Int}(first(ctx.timestamps),last(ctx.timestamps))

	misses::Vector{UnitRange}  = UnitRange{Int}[]

	ts::Vector{Int}     = Int[]
	o::Vector{Float32}  = Float32[]
	h::Vector{Float32}  = Float32[]
	l::Vector{Float32}  = Float32[]
	c::Vector{Float32}  = Float32[]
	v::Vector{Float32}  = Float32[]
end
@kwdef mutable struct OHLCV_v <: CandleType  # for validation to make sure we don't make mistakes!
	set::Symbol         = :UNINITIALIZED
	exchange::String    = ""
	market::String      = ""
	is_futures::Bool    = false
	candle_type::Symbol = :UNKNOWN   # :TICK, :SECOND, :MINUTE, :HOUR, :DAY
	candle_value::Int   = -1
	timestamps::UnitRange{Int} = UnitRange{Int}(first(ctx.timestamps_v),last(ctx.timestamps_v))

	misses::Vector{UnitRange}  = UnitRange{Int}[]

	ts::Vector{Int}     = Int[]
	o::Vector{Float32}  = Float32[]
	h::Vector{Float32}  = Float32[]
	l::Vector{Float32}  = Float32[]
	c::Vector{Float32}  = Float32[]
	v::Vector{Float32}  = Float32[]
end
set_OHLCV(d::OHLCV_v) = OHLCV(:TRAIN,d.exchange, d.market, d.is_futures, d.candle_type, d.candle_value, d.timestamps,
															d.misses, d.ts, d.o,d.h,d.l,d.c,d.v)
set_OHLCV_v(d::OHLCV) = OHLCV_v(:VALIDATION, d.exchange, d.market, d.is_futures, d.candle_type, d.candle_value, d.timestamps,
																d.misses, d.ts, d.o,d.h,d.l,d.c,d.v)
fix_type(d::OHLCV_v, ::Type{OHLCV_v}) = d
fix_type(d::OHLCV,   ::Type{OHLCV_v}) = set_OHLCV_v(d)
fix_type(d::OHLCV_v, ::Type{OHLCV})   = set_OHLCV(d)
fix_type(d::OHLCV,   ::Type{OHLCV})   = d
														

ohlcv_init(TYPE, ctx, candle) = begin
	exchange, market, isfutures = market_name_process(ctx.market)
	candle_type, candle_value   = parse_ohlcv_meta(candle)
	d=TYPE(exchange=    exchange,
          market=      market,
					is_futures=  isfutures, 
					candle_type= candle_type,
					candle_value=candle_value)
end


macro ohlcv_str(candle)
	global ctx, loaded_train_datasets
	fr, to = first(ctx.timestamps), last(ctx.timestamps)
	(ctx.market, candle, fr, to) in keys(loaded_train_datasets) && ctx.use_cache && return loaded_train_datasets[ctx.market, candle, fr, to]
	obj = ohlcv_init(OHLCV, ctx, candle)
	obj.timestamps = ceil_ts(fr, obj.candle_value):floor_ts(to, obj.candle_value)
	obj.set       = :TRAIN
	parse_ohlcv_data!(obj)
	loaded_train_datasets[ctx.market, candle, fr, to] = obj 
end

macro ohlcv_v_str(candle)
	global ctx, loaded_valid_datasets
	fr, to = first(ctx.timestamps_v), last(ctx.timestamps_v)
	(ctx.market, candle, fr, to) in keys(loaded_valid_datasets) && ctx.use_cache && return loaded_valid_datasets[ctx.market, candle, fr, to]
	obj = ohlcv_init(OHLCV_v, ctx, candle)
	obj.timestamps = ceil_ts(fr, obj.candle_value):floor_ts(to, obj.candle_value)
	obj.set       = :VALIDATION
	parse_ohlcv_data!(obj)
	loaded_valid_datasets[ctx.market, candle, fr, to] = obj
end


parse_ohlcv_meta(s::String) = begin
	@assert !(s[end]=='s') "Second bar isn't supported yet...!"
	s[end]=='s'     && return :SECOND,     parse(Int,s[1:end-1])
	s[end]=='m'     && return :MINUTE,     parse(Int,s[1:end-1])*60
	s[end]=='h'     && return :HOUR,       parse(Int,s[1:end-1])*60*60
	s[end]=='d'     && return :DAY,        parse(Int,s[1:end-1])*60*60*24
	s[1:4]=="tick"  && return :TICK,       parse(Int,s[5:end])
	return :UNKNOWN, -1
end
parse_ohlcv_data!(d::T) where T <: CandleType = begin
	if d.candle_type in [:TICK, 
		]
		@warn "from and to date isn't supported for tick data!! TODO"
		all_data = refresh_tick_data(  d.exchange, d.market, d.is_futures, first(d.timestamps), last(d.timestamps))
		cut_data_tick!(d, all_data)
		d.o, d.h, d.l, d.c, d.v, d.ts = combine_klines_fast_tick(d, d.candle_value, Val(d.candle_type))
	else
		all_data = refresh_minute_data(d.exchange, d.market, d.is_futures, first(d.timestamps), last(d.timestamps))
		cut_data_1m!(d, all_data)

		@assert d.candle_value>=60 "We cannot handle things under 1min(60s) d.candle_value=$(d.candle_value)"
		metric_round = cld(d.candle_value,60)
		d.o, d.h, d.l, d.c, d.v, d.ts = combine_klines_fast(d, metric_round)
	end
end


loaded_train_datasets = Dict{Tuple{String, String, Int, Int}, OHLCV  }()
loaded_valid_datasets = Dict{Tuple{String, String, Int, Int}, OHLCV_v}()
					

include("CryptoOHLCVUtils.jl")
include("CryptoOHLCVFns.jl")


end # module CryptoOHLCV
