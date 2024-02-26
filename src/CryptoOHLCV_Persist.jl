


UniversalStruct.folder(o::T)          where T <: CandleType = "$(ctx.data_path)"
UniversalStruct.glob_pattern(o::T)    where T <: CandleType = "OHLCV_$(o.exchange)_$(o.market)_$(isfutures_str(o.is_futures))_$(metric2candle(o.candle_value))_*-*.jld2" # throw("Unimplemented... So basically to get the files list it is advised for you to build this.") #"$(T)_$(obj.config)_*_*"*".jld2"
UniversalStruct.unique_filename(o::T) where T <: CandleType = "OHLCV_$(o.exchange)_$(o.market)_$(isfutures_str(o.is_futures))_$(metric2candle(o.candle_value))_$(first(o.timestamps))-$(last(o.timestamps)).jld2" 
UniversalStruct.parse_args(args)                            = begin
	(TYPE,ex,m1,m2,future, candl_v, fr_to_ts) = args
	(fr, to) = split(fr_to_ts,"-")
	return String(ex), "$(m1)_$(m2)", isfutures_str(String(future)), String(candl_v), parse(Int,fr), parse(Int,to)
end
UniversalStruct.score(data)                                 = begin 
	ex,maket,future, candl_v, fr, to = data
	return to - fr
end

UniversalStruct.save_disk(o::OHLCV_v, needclean=true)       = UniversalStruct.save_disk(fix_type(o,OHLCV),needclean)


