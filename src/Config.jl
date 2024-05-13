

# init_now_ts::Int=1706_542_899  #_562    # 2024-01-29T15:41:39.562   DateTime("2024-01-29T15:41:39.562")
# init_now_ts::Int=1707_132_143  #_562    # 2024-01-29T15:41:39.562   DateTime("2024-01-29T15:41:39.562")
init_now_ts::Int=1711411200_000    #  	  # 2024-03-26T00:00:00       

module_directory = string(string(@__FILE__)[1:end-14]) # hardcoded... so basically we cut the "/src/Config.jl"

# TODO LIVE... so "from_timestamp" -> "datetime2unix(now())"
@kwdef mutable struct OHLCVConfig

	# use_cache::Bool   = true 
	use_cache::Bool   = false 

	exchange::String    = "binance"
	market::String      = "BTC_USDT"
	is_futures::Bool    = true

	timestamps::UnitRange{Int}   = init_now_ts -  1000*60*60*24  *  42:init_now_ts
	
	now_ts::Int       = init_now_ts          

	maximum_candle_size::Int  = 3600
  
	min_max_move::Float32     = 0.002f0   # 0.2% maxdiff

	data_path::String = module_directory*"/data/"
end

ctx::OHLCVConfig = OHLCVConfig()

Base.setproperty!(a::OHLCVConfig, s::Symbol, v) = begin
	getfield(a,s) == v && return v
	if s in [:timestamps]
		# get_cutters_minute_correction(OHLCV_all, 1)
		println("Current  range $(join(string.(date_range(first(getfield(a,s)), last(getfield(a,s))))," - "))")
		println("Updating to    $(join(string.(date_range(first(v),             last(v)))," - "))")
	end

	setfield!(a, s, v)
	# s==:LIVE         && (setfield!(a, :timestamps,   floor(Int,datetime2unix(now()))))
	v
end

set_day_range!(ctx; dayframe=0:42) = ctx.timestamps= ts2Δday(last(dayframe)):ts2Δday(first(dayframe))

ts2Δday(ts)    = (Day(unix2datetime(ctx.now_ts)) - Day(unix2datetime(ts/1000))).value
Δday2ts(day)   = cld(ctx.now_ts-day*60*60*24*1000, 60*60*24*1000) * 60*60*24 * 1000
# Δday2date(day) = (global ctx; unix2datetime(ctx.now_ts/1000-day*60*60*24))




