

# init_now_ts::Int=1706_542_899  #_562    # 2024-01-29T15:41:39.562   DateTime("2024-01-29T15:41:39.562")
init_now_ts::Int=1707_132_143  #_562    # 2024-01-29T15:41:39.562   DateTime("2024-01-29T15:41:39.562")

module_directory = string(string(@__FILE__)[1:end-14]) # hardcoded... so basically we cut the "/src/Config.jl"

# TODO LIVE... so "from_timestamp" -> "now()"
@kwdef mutable struct Config
	use_cache::Bool   = true 
	# use_cache::Bool   = false 

	market::String    ="binance:BTC_USDT:futures"

	dayframe::UnitRange{Int}     = 0:42
	dayframe_v::UnitRange{Int}   = 42:84
	timestamps::UnitRange{Int}   = -1:-1
	timestamps_v::UnitRange{Int} = -1:-1

	now_ts::Int       = init_now_ts          
	now_dt::DateTime  = unix2datetime(init_now_ts) 

	maximum_candle_size::Int     = 3600
  

	data_path::String = module_directory*"/data"
end

ctx::Config = Config()

Base.setproperty!(a::Config, s::Symbol, v) = begin
	if s in [:timestamps, :timestamps_v]
		# get_cutters_minute_correction(OHLCV_all, 1)
		println("Current  range $(join(string.(date_range(first(getfield(a,s)), last(getfield(a,s))))," - "))")
		println("Updating to    $(join(string.(date_range(first(v),           last(v)))," - "))")
	end
	if s in [:dayframe, :dayframe_v, ]
		# get_cutters_minute_correction(OHLCV_all, 1)
		println("Current  range $(join(string.(date_range(Δday2ts(first(getfield(a,s))), Δday2ts(last(getfield(a,s)))))," - "))")
		println("Updating to    $(join(string.(date_range(Δday2ts(last(v)),   Δday2ts(first(v))))," - "))")
	end
	setfield!(a, s, v)
	s==:now_ts      && setfield!(a, :now_dt,      unix2datetime(v))
	s==:now_dt      && setfield!(a, :now_ts,      floor(Int,datetime2unix(v)))
	s==:timestamps   && setfield!(a, :dayframe,    ts2Δday(last(v)):ts2Δday(first(v)))
	s==:timestamps_v && setfield!(a, :dayframe_v,  ts2Δday(last(v)):ts2Δday(first(v)))
	s==:dayframe    && setfield!(a, :timestamps,   Δday2ts(last(v)):Δday2ts(first(v)))
	s==:dayframe_v  && setfield!(a, :timestamps_v, Δday2ts(last(v)):Δday2ts(first(v)))
	v
end


ts2Δday(ts)    = (Day(ctx.now_dt) - Day(unix2datetime(ts))).value
Δday2ts(day)   = floor(Int,datetime2unix(Δday2date(day)))
Δday2date(day) = (global ctx; ctx.now_dt-Day(day))
init(ctx::Config) = begin
	ctx.now_dt      = unix2datetime(ctx.now_ts) 
	setfield!(ctx, :timestamps,   Δday2ts(last(ctx.dayframe)):  Δday2ts(first(ctx.dayframe)))
	setfield!(ctx, :timestamps_v, Δday2ts(last(ctx.dayframe_v)):Δday2ts(first(ctx.dayframe_v)))

	@assert !(first(ctx.timestamps) < first(ctx.timestamps_v) < last(ctx.timestamps) || 
						first(ctx.timestamps) < last(ctx.timestamps_v)  < last(ctx.timestamps_v)) "There are interleaving data between train and validation set... Train: $(ctx.timestamps)  and Validation: $(ctx.timestamps_v)"
end
train_valid_ratio() = length(ctx.timestamps)/(length(timestamps)+length(timestamps_v))


init(ctx)




