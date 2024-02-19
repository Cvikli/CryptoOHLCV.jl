


download_data(market::String, isfutures, start_date, end_date, candle="5m") = begin
  market_data = query_klines(replace(market, "_"=>""), candle, start_date, end_date, isfutures ? Val(:FUTURES) : Val(:SPOT));
  o, h, l, c, v, ts = marketdata2ohlcvt(market_data)
end

strip_jld2(s) = s[1:end-5] 
get_filename(d::T) where T <: CandleType = "OHLCVT_$(d.exchange)_$(d.market)_$(isfutures_str(d.is_futures))_$(metric2candle(d.candle_value))_$(first(d.timestamps))-$(last(d.timestamps)).jld2"
get_filename(d::Tuple)                   = get_filename(d[2], "$(d[3])_$(d[4])", isfutures_str(d[5]), d[7], d[8], d[6])
get_filename(exch::String, market::String, isfutures::Bool, start_date, end_date, candle) = "OHLCVT_$(exch)_$(market)_$(isfutures_str(isfutures))_$(candle)_$(start_date)-$(end_date).jld2"
get_past_data_minute(exchange, market, isfutures) = [String.(split(strip_jld2(split(f,"/")[end]),"_")) for f in glob("OHLCVT_$(exchange)_$(market)_$(isfutures_str(isfutures))_*1m_*", "$(ctx.data_path)/")]
get_past_data_tick(exchange, market, isfutures) = [String.(split(strip_jld2(split(f,"/")[end]),"_")) for f in glob("OHLCVT_$(exchange)_$(market)_$(isfutures_str(isfutures))_*tick_*", "$(ctx.data_path)/")]


market_name_process(market_str) = begin
  res = String.(split(market_str, ":"))
	length(res) == 1 && return "binance", market_str, false
  length(res) == 2 && res[2] !== "futures" && return res[1], res[2], false
  length(res) == 2 && res[2]  == "futures" && return "binance", res[1], true
  length(res) == 3 && return res[1], res[2], res[3] == "futures"
	@assert false "unparseable market source $market_str"
end
isfutures_str(isfutures::String) = isfutures=="F" ? true : false
isfutures_str(isfutures::Bool)   = isfutures ? "F" : "N"
candle2metric(candle) = Dict("1m" => 60, "5m" => 300, "15m" => 900, "30m" => 1800, "1s" => 1, "2s" => 2, "15s" => 15, "5s" => 5, "1h" => 3600, "tick"=>0)[candle]
metric2candle(metric) = Dict(60 => "1m", 300 => "5m", 900 => "15m", 1800 => "30m", 1 => "1s", 2 => "2s", 5 => "5s", 15 => "15s", 3600 => "1h", 0=>"tick")[metric]





print_file(o::OHLCV)   = println("$(get_filename(o)) train: $(unix2datetime(first(o.timestamps))) -> $(unix2datetime(last(o.timestamps)))")
print_file(o::OHLCV_v) = println("$(get_filename(o)) valid: $(unix2datetime(first(o.timestamps))) -> $(unix2datetime(last(o.timestamps)))")

save_it(ohlcv::OHLCV_v) = save_it(fix_type(ohlcv,OHLCV))
save_it(ohlcv::OHLCV)   = (isfile("$(ctx.data_path)/$(get_filename(ohlcv))") && return; print("Saving: "); print_file(ohlcv); @save "$(ctx.data_path)/$(get_filename(ohlcv))" ohlcv)

extend(d::T, o, h, l, c, v, OHLCV_time, misses) where T <: CandleType = begin
	!isempty(d.ts) && (d.ts = vcat(d.ts,OHLCV_time))
	 isempty(d.ts) && (d.ts = OHLCV_time)
	!isempty(d.misses) && (d.misses = vcat(d.misses,misses))
	 isempty(d.misses) && (d.misses = misses)
	d.o,d.h,d.l,d.c,d.v = o, h, l, c, v
end
dwnl_data_ccxt(src, start_date, end_date, candle, ct_now) = @assert false "unimplemented... I need to copy this yet..."
load_new_minute_data(exchange, market, isfutures, start_date, end_date) = begin
	ohlcv = OHLCV(set=:undefined, exchange=exchange, market=market, is_futures=isfutures, candle_type=:MINUTE, candle_value=60, timestamps=start_date:end_date)
	end_date <= start_date && return ohlcv
	if exchange !== "binance"
    data_OHLCV, ts, misses = dwnl_data_ccxt("$(exchange):$(market):$(isfutures)", start_date, end_date, "1m", now)
	else
		o, h, l, c, v, ts, misses = dwnl_minute_data(market, isfutures, start_date, end_date)
	end
	extend(ohlcv, o, h, l, c, v, ts, misses)
	ohlcv
end

load_new_tick_data(exchange, market, isfutures, start_date, end_date) = begin
	ohlcv = OHLCV(set=:undefined, exchange=exchange, market=market, is_futures=isfutures, candle_type=:TICK, candle_value=0, timestamps=start_date:end_date)
	end_date <= start_date && return ohlcv
	if exchange !== "binance"
    data_OHLCV, ts, misses = dwnl_data_ccxt("$(exchange):$(market):$(isfutures)", start_date, end_date, "tick", now)
	else
		maket = replace(market, "_" => "")
		o, h, l, c, v, ts, misses = dwnl_tick_data(maket, isfutures, start_date, end_date)
	end
	extend(ohlcv, o, h, l, c, v, ts, misses)
	ohlcv
end

dwnl_minute_data(market, isfutures, start_date, end_date) = begin
	metric = candle2metric("1m")
	misses = UnitRange{Int}[]
	o, h, l, c, v, ts           = download_data(market, isfutures, start_date, end_date, "1m")
	(o, h, l, c, v), misses, ts = interpolate_missing((o, h, l, c, v), ts, metric*1000)
	return o, h, l, c, v, ts, misses
end

dwnl_tick_data(market, isfutures, start_date, end_date) = begin
	misses = UnitRange{Int}[]
	tick_raw = query_ticks(market, isfutures, start_date, end_date)
	id, ts, c, v = tick_raw
	o=[c[1];c[1:end-1]]
	h=max.(o,c)
	l=min.(o,c)
	return o, h, l, c, v, ts, misses
end



mergg(d1::T, d2::T) where T <: CandleType = begin
	d1.ts = vcat(d1.ts[1:end-1],d2.ts)
	d1.o  = vcat(d1.o[1:end-1],d2.o)
	d1.h  = vcat(d1.h[1:end-1],d2.h)
	d1.l  = vcat(d1.l[1:end-1],d2.l)
	d1.c  = vcat(d1.c[1:end-1],d2.c)
	d1.v  = vcat(d1.v[1:end-1],d2.v)
	d1.timestamps = first(d1.timestamps):last(d2.timestamps)
	return d1
end

refresh_minute_data(exchange, market, isfutures, start_date, end_date) = begin
	all_data = get_past_data_minute(exchange, market, isfutures)
	if length(all_data) > 0
		filedata  = [(s[1], s[2], s[3], s[4], s[5], s[6], parse(Int64,split(s[7],"-")[1]), parse(Int64,split(s[7],"-")[2])) for s in all_data ]
		largest_data = sort(filedata, by=(v) -> (v[8],2e9-v[7]), rev=true)
		_,ex,m1,m2,fu,candl,fr_ts,to_ts = largest_data[1]
		# @display largest_data
		filename  = get_filename(exchange,market, isfutures, fr_ts,to_ts, "1m")
		@load "$(ctx.data_path)/$filename" ohlcv
		OHLCV_all = ohlcv::OHLCV
		OHLCV_p   = load_new_minute_data(exchange, market, isfutures, start_date, fr_ts)
		OHLCV_n   = load_new_minute_data(exchange, market, isfutures, to_ts, end_date)
		length(OHLCV_p.c)>0 && (OHLCV_all = mergg(OHLCV_p, OHLCV_all))
		length(OHLCV_n.c)>0 && (OHLCV_all = mergg(OHLCV_all, OHLCV_n))

		clean_unused_datasets(largest_data)
	else
		OHLCV_all = load_new_minute_data(exchange, market, isfutures, start_date, end_date)
	end
	
	
	save_it(OHLCV_all) 

	OHLCV_all
end

refresh_tick_data(exchange, market, isfutures, start_date, end_date) = begin
	all_data = get_past_data_tick(exchange, market, isfutures)
	if length(all_data) > 0
		filedata  = [(s[1], s[2], s[3], s[4], s[5], s[6], parse(Int64,split(s[7],"-")[1]), parse(Int64,split(s[7],"-")[2])) for s in all_data ]
		largest_data = sort(filedata, by=(v) -> (v[8],2e9-v[7]), rev=true)
		_,ex,m1,m2,fu,candl,fr_ts,to_ts = largest_data[1]
		filename  = get_filename(exchange,market, isfutures, fr_ts,to_ts, "tick")
		@load "$(ctx.data_path)/$filename" ohlcv
		OHLCV_all = ohlcv::OHLCV
		OHLCV_p   = load_new_tick_data(exchange, market, isfutures, start_date, fr_ts)
		OHLCV_n   = load_new_tick_data(exchange, market, isfutures, to_ts, end_date)
		length(OHLCV_p.c)>0 && (OHLCV_all = mergg(OHLCV_p, OHLCV_all))
		length(OHLCV_n.c)>0 && (OHLCV_all = mergg(OHLCV_all, OHLCV_n))

		clean_unused_datasets(largest_data)
	else
		OHLCV_all  = load_new_tick_data(exchange, market, isfutures, start_date, end_date)
		@sizes OHLCV_all.c
		@sizes OHLCV_all.ts
	end
	
	save_it(OHLCV_all) 

	OHLCV_all
end
cut_data_tick!(d, OHLCV_all) = begin
	fr_ts, to_ts=first(d.timestamps)*1000, last(d.timestamps)*1000
	offset = 1
	endset = length(OHLCV_all.ts)
	while OHLCV_all.ts[offset] < fr_ts && offset < endset
		offset+=1; end
	while OHLCV_all.ts[endset] > to_ts && endset > offset-1
		endset-=1; end
	
	d.ts = OHLCV_all.ts[offset:endset]
	d.o  = OHLCV_all.o[offset:endset]
	d.h  = OHLCV_all.h[offset:endset]
	d.l  = OHLCV_all.l[offset:endset]
	d.c  = OHLCV_all.c[offset:endset]
	d.v  = OHLCV_all.v[offset:endset]
	d
end
cut_data_1m!(d, OHLCV_all) = begin
	min_candle_value = 60
	fr_ts, to_ts=first(d.timestamps), last(d.timestamps)

	offset =     cld(fr_ts - first(OHLCV_all.timestamps), min_candle_value)+1
	endset = cld(to_ts - first(OHLCV_all.timestamps) + 1, min_candle_value)
	@assert endset<=length(OHLCV_all.h) "how can this be bigger?? $endset, $(length(OHLCV_all.h))"
	
	d.ts = OHLCV_all.ts[offset:endset]
	d.o  = OHLCV_all.o[offset:endset]
	d.h  = OHLCV_all.h[offset:endset]
	d.l  = OHLCV_all.l[offset:endset]
	d.c  = OHLCV_all.c[offset:endset]
	d.v  = OHLCV_all.v[offset:endset]
	d
end

# WARN! We are taking the lower end of the timeframe! 
# ceil_ts( ts, mv) = ts - (ts%max(mv, ctx.maximum_candle_size)) #(m = ts%max(mv, ctx.maximum_candle_size); m>0 ? ts-m+max(mv, ctx.maximum_candle_size) : ts)
ceil_ts( ts, mv) = ctx.floor_instead_of_ceil ? ts - (ts%max(mv, ctx.maximum_candle_size)) : (m = ts%max(mv, ctx.maximum_candle_size); m>0 ? ts-m+max(mv, ctx.maximum_candle_size) : ts)
floor_ts(ts, mv) = ts - (ts%max(mv, ctx.maximum_candle_size))-1

rm_if_exist(fname) = if isfile("$(ctx.data_path)/$fname")
	rm("$(ctx.data_path)/$fname")
else
	println("Why isn't this exist? $(ctx.data_path)/$fname")
end

clean_unused_datasets(largest_data) = begin
	old_files = largest_data[3:end]
	if length(old_files) > 0
		println("Deleting:")
		for file_dat in old_files
			fname = get_filename(file_dat)
			@display fname
			rm_if_exist(fname)
		end
	end
end









