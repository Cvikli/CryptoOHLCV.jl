

# init_now_ts::Int=1706_542_899  #_562    # 2024-01-29T15:41:39.562   DateTime("2024-01-29T15:41:39.562")
init_now_ts::Int=1707_132_143  #_562    # 2024-01-29T15:41:39.562   DateTime("2024-01-29T15:41:39.562")

# TODO LIVE... so "from_timestamp" -> "now()"
@kwdef mutable struct Config
	# use_cache::Bool   = true 
	use_cache::Bool   = false 

	market::String    ="binance:BTC_USDT:futures"

	dayframe::UnitRange{Int}    = 30:41
	dayframe_v::UnitRange{Int}  = 1096:1460
	timeframe::UnitRange{Int}   = -1:-1
	timeframe_v::UnitRange{Int} = -1:-1

	now_ts::Int       = init_now_ts          
	now_dt::DateTime  = unix2datetime(init_now_ts) 

	min_max_move::Float32       = 0.002f0   # 0.2% maxdiff

	data_path::String = "./data"
end

ctx::Config = Config()

Base.setproperty!(a::Config, s::Symbol, v) = begin
	if s in [:timeframe, :timeframe_v]
		# get_cutters_minute_correction(OHLCV_all, 1)
		println("Current  range $(join(string.(date_range(first(a.timeframe), last(a.timeframe)))," - "))")
		println("Updating to    $(join(string.(date_range(first(v),           last(v)))," - "))")
	end
	if s in [:dayframe, :dayframe_v, ]
		# get_cutters_minute_correction(OHLCV_all, 1)

		println("Current  range $(join(string.(date_range(first(a.timeframe), last(a.timeframe)))," - "))")
		println("Updating to    $(join(string.(date_range(Δday2ts(last(v)),   Δday2ts(first(v))))," - "))")
	end
	setfield!(a, s, v)
	s==:now_ts      && setfield!(a, :now_dt,      unix2datetime(v))
	s==:now_dt      && setfield!(a, :now_ts,      floor(Int,datetime2unix(v)))
	s==:timeframe   && setfield!(a, :dayframe,    ts2Δday(last(v)):ts2Δday(first(v)))
	s==:timeframe_v && setfield!(a, :dayframe_v,  ts2Δday(last(v)):ts2Δday(first(v)))
	s==:dayframe    && setfield!(a, :timeframe,   Δday2ts(last(v)):Δday2ts(first(v)))
	s==:dayframe_v  && setfield!(a, :timeframe_v, Δday2ts(last(v)):Δday2ts(first(v)))
	v
end


ts2Δday(ts)    = (Day(ctx.now_dt) - Day(unix2datetime(ts))).value
Δday2ts(day)   = floor(Int,datetime2unix(Δday2date(day)))
Δday2date(day) = (global ctx; ctx.now_dt-Day(day))
init(ctx::Config) = begin
	ctx.now_dt      = unix2datetime(ctx.now_ts) 
	ctx.timeframe   = Δday2ts(last(ctx.dayframe)):  Δday2ts(first(ctx.dayframe))
	ctx.timeframe_v = Δday2ts(last(ctx.dayframe_v)):Δday2ts(first(ctx.dayframe_v))

	@assert !(first(ctx.timeframe) < first(ctx.timeframe_v) < last(ctx.timeframe) || 
						first(ctx.timeframe) < last(ctx.timeframe_v)  < last(ctx.timeframe_v)) "There are interleaving data between train and validation set... Train: $timeframe  and Validation: $(timeframe_v)"
end
train_valid_ratio() = length(timeframe)/(length(timeframe)+length(timeframe_v))


init(ctx)




