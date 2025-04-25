
const ohlcv_load = Dict{Tuple{DataType, Symbol, String, String, Bool, Symbol, Int, Int, Int},OHLCV}()

function get_cache(key)
	return key in keys(ohlcv_load) ? ohlcv_load[key] : (ohlcv_load[key] = begin
		x = load(init(key...))
		postprocess_ohlcv!(x)
		x
	end)
end

get_ohlcv(source, context=ctx) = get_cache(get_unique_data_key(OHLCV, :TRAIN, source, context))
macro ohlcv_str(source); get_ohlcv(source); end

get_ohlcv_v(source, context=ctx) = begin
	d = get_cache(get_unique_data_key(OHLCV, :VALIDATION, source, context))
	d.set = :VALIDATION # TODO check if this is really needed
	d
end
macro ohlcv_v_str(source); get_ohlcv_v(source); end

get_ohlcv_t(source, context=ctx) = begin
	d = get_cache(get_unique_data_key(OHLCV, :TEST, source, context))
	d.set = :TEST # TODO check if this is really needed
	d
end
macro ohlcv_t_str(source); get_ohlcv_t(source); end


