


are_there_gap!(c::C, new_ts_f64::Float64, time_frame) where C <: CandleType = are_there_gap!(c, Int64(new_ts_f64), time_frame)
are_there_gap!(c::C, new_ts::Int64,       time_frame) where C <: CandleType = begin
	c_tsend = c.t[end]
	if (new_ts - c_tsend) / CANDLE_TO_MS[time_frame] > 1.05 
		@info "GAP in the system: $(c_tsend) - $(new_ts) -> $((new_ts - c_tsend) / CANDLE_TO_MS[time_frame])"
		@info "We are filling it."
		# +CANDLE_TO_MS["1m"]
		miss = UniversalStruct.load(C, :validation, c.exchange, c.market, c.is_futures, c.candle_type, c.candle_value, cld(c.t[end],1000), floor_ts(floor(Int,new_ts/1_000),60))
		postprocess_ohlcv!(miss)
		(length(miss.c) > 0) && append!(c, miss)
	end
end

stop_LIVE_data(c::C)  where C <: CandleType =  c.LIVE=false
start_LIVE_data(c::C) where C <: CandleType = (c.LIVE=true ; @async_showerr live_data_streaming(c))
live_data_streaming(c::C) where C <: CandleType = begin
	market_lowcase = lowercase(replace(c.market, "_" => ""))
	candle = reverse_parse_candle(c)
	# @assert false "1m-ben szedjük akkor... ezt majd ..."
	# candle = "1m"

	are_there_gap!(c, datetime2unix(now(UTC))*1000, candle)
	notify(c.used)

	url = get_stream_url(market_lowcase, candle)
	while c.LIVE
		try
			HTTP.WebSockets.open(url) do ws 
				println("Listening on Binance $(market_lowcase) $candle")
				display([c.h[end-2:end] c.l[end-2:end] c.c[end-2:end] c.v[end-2:end]])
				display(unix2datetime.(c.t[end-2:end]./1000))
				println("RUNNING!")
				for dd in ws #!eof(ws);
					c.LIVE==false && break
					rd = JSON.parse(String(dd))
					d=rd["data"]["k"]
					if d["x"]
						ts = Int64(d["t"])
						are_there_gap!(c, ts, candle)
						
						c.o = [c.o; parse(Float32, d["o"])]
						c.h = [c.h; parse(Float32, d["h"])]
						c.l = [c.l; parse(Float32, d["l"])]
						c.c = [c.c; parse(Float32, d["c"])]
						c.v = [c.v; parse(Float32, d["v"])]
						c.t = [c.t; [ts]]
						@show d
						notify(c.used)
					else
						# @show d
						# update and REACT!
					end
				end
			end
		catch e
			showerror(stdout, e, catch_backtrace())
			if e == EOFError
				@info "EOFError!! We continue the RUN, but this is not nice!" # EOFError: read end of file
			elseif e == DNSError
				@show e
				# elseif e == IOError
				# 	@info "IOError!! We continue the RUN, but this is not nice!" # IOError: read end of file
			else
				rethrow(e)
			end
		end
	end
	println("Streaming stopped!")
end

trade_on_notify(c) = begin
	while true
		wait(c.used)
		reset(c.used)
		orders = next_action(c.o, c.h, c.l, c.c, c.v)
		process_orders(orders) # TODO balance query has to be JUST before the wait!
		sleep(1)
	end
end