


UniversalStruct.folder(o::T)          where T <: CandleType = "$(o.data_path)"
UniversalStruct.glob_pattern(o::T)    where T <: CandleType = "OHLCV_$(o.exchange)_$(o.market)_$(isfutures_str(o.is_futures))_$(metric2candle(o.candle_type, o.candle_value))_*-*.jld2" # throw("Unimplemented... So basically to get the files list it is advised for you to build this.") #"$(T)_$(obj.config)_*_*"*".jld2"
UniversalStruct.unique_filename(o::T) where T <: CandleType = "OHLCV_$(o.exchange)_$(o.market)_$(isfutures_str(o.is_futures))_$(metric2candle(o.candle_type, o.candle_value))_$(first(o.timestamps))-$(last(o.timestamps)).jld2" 
UniversalStruct.parse_args(args)                            = begin
	(TYPE,ex,m1,m2,future, candl_v, fr_to_ts) = args
	(fr, to) = split(fr_to_ts,"-")
	return String(ex), "$(m1)_$(m2)", isfutures_str(String(future)), String(candl_v), parse(Int,fr), parse(Int,to)
end
UniversalStruct.score(data::Tuple{String,String,Bool,String,Int,Int}) = begin # we specify types for avoiding precompilation issue! Type piracy 
	ex,maket,future, candl_v, fr, to = data
	return to - fr
end



