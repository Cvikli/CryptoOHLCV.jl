

# init_now_ts::Int=1706_542_899  #_562    # 2024-01-29T15:41:39.562   DateTime("2024-01-29T15:41:39.562")
# init_now_ts::Int=1707_132_143  #_562    # 2024-01-29T15:41:39.562   DateTime("2024-01-29T15:41:39.562")
init_now_ts::Int=1711411200    #_562  	  # 2024-03-26T00:00:00       

module_directory = string(string(@__FILE__)[1:end-14]) # hardcoded... so basically we cut the "/src/Config.jl"

# TODO LIVE... so "from_timestamp" -> "datetime2unix(now())"
@kwdef mutable struct OHLCVConfig

	# use_cache::Bool   = true 
	use_cache::Bool   = false 

	exchange::String    = "binance"
	market::String      = "BTC_USDT"
	is_futures::Bool    = true

	dayframe::UnitRange{Int}     = 0:42
	timestamps::UnitRange{Int}   = -1:-1
	
	now_ts::Int       = init_now_ts          
	now_dt::DateTime  = unix2datetime(init_now_ts) 

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
	if s in [:dayframe,]
		# get_cutters_minute_correction(OHLCV_all, 1)
		println("Current  range $(join(string.(date_range(Δday2ts(last(getfield(a,s))), Δday2ts(first(getfield(a,s)))))," - "))")
		println("Updating to    $(join(string.(date_range(Δday2ts(last(v)),             Δday2ts(first(v))))," - "))")
	end
	setfield!(a, s, v)
	s==:now_ts       && setfield!(a, :now_dt,       unix2datetime(v))
	s==:now_dt       && setfield!(a, :now_ts,       floor(Int,datetime2unix(v)))
	s==:timestamps   && setfield!(a, :dayframe,     ts2Δday(last(v)):ts2Δday(first(v)))
	s==:dayframe     && setfield!(a, :timestamps,   Δday2ts(last(v)):Δday2ts(first(v)))
	# s==:LIVE         && (setfield!(a, :timestamps,   floor(Int,datetime2unix(now()))))
	v
end


ts2Δday(ts)    = (Day(ctx.now_dt) - Day(unix2datetime(ts))).value
Δday2ts(day)   = floor(Int,datetime2unix(Δday2date(day)))
Δday2date(day) = (global ctx; ctx.now_dt-Day(day))
initConfig(ctx::OHLCVConfig) = begin
	ctx.now_dt      = unix2datetime(ctx.now_ts) 
	setfield!(ctx, :timestamps,   Δday2ts(last(ctx.dayframe)):  Δday2ts(first(ctx.dayframe)))

	# @assert !(first(ctx.timestamps) < first(ctx.timestamps_v) < last(ctx.timestamps) || 
	# 					first(ctx.timestamps) < last(ctx.timestamps_v)  < last(ctx.timestamps_v)) "There are interleaving data between train and validation set... Train: $(ctx.timestamps)  and Validation: $(ctx.timestamps_v)"
end
# train_valid_ratio() = length(ctx.timestamps)/(length(timestamps)+length(timestamps_v))


initConfig(ctx)




