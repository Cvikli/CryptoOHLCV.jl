
parse_source(source_str, ctxt) = begin
	exch,mark,fut = ctxt.exchange, ctxt.market, ctxt.is_futures
  res = String.(split(source_str, ":"))
	length(res) == 1                                                                     && return exch, res[1], fut
	length(res) == 2 && res[2] == "futures"              && return exch, res[1], true
	length(res) == 2 && res[2] == "spot"                      && return exch, res[1], false
	length(res) == 2                                                                    && return res[1], res[2], fut
	length(res) == 3 && res[3] == "futures"              && return res[1], res[2], true
	length(res) == 3 && res[3] == "spot"                      && return res[1], res[2], false
	@assert false "unparseable market source $source_str (format: [exchange:][market@]candle[:futures][|from*to])"
end
reconstruct_src(o::T) where T <: CandleType = reconstruct_src(o.exchange, o.market, o.is_futures)
reconstruct_src(ex, market, isfuture) = "$ex","$market","$(isfutures_long(isfuture))"

parse_candle(s::String) = begin
	@assert !(s[end]=='s') "Second bar isn't supported yet...!"
	s[end]=='s'     && return :SECOND,     parse(Int,s[1:end-1])
	s[end]=='m'     && return :MINUTE,     parse(Int,s[1:end-1])*60
	s[end]=='h'     && return :HOUR,       parse(Int,s[1:end-1])*60*60
	s[end]=='d'     && return :DAY,        parse(Int,s[1:end-1])*60*60*24
	s[1:4]=="tick"  && return :TICK,       parse(Int,s[5:end])
	return :UNKNOWN, -1
end
reverse_parse_candle(o::T) where T <: CandleType = reverse_parse_candle(o.candle_type, o.candle_value) 
reverse_parse_candle(candly_type, candle_value) = begin
	candly_type==:SECOND     && return "$(candle_value)s"
	candly_type==:MINUTE     && return "$(cld(candle_value, 60))m"
	candly_type==:HOUR       && return "$(cld(candle_value, 60*60))h"
	candly_type==:DAY        && return "$(cld(candle_value, 60*60*24))d"
	# candly_type==:TICK_STONE && return "sick$(candle_value)"
	# candly_type==:TICK_STONE && return "sick$(candle_value)"
	# candly_type==:TICK_MMM   && return "mick$(candle_value)"
	candly_type==:TICK       && return "tick$(candle_value)"
	throw("Unknown type")
end

parse_range(rang) = begin
	to,fr = parse.(Int64,(split(rang[2], '*')))
	abs(fr) < 100000         && abs(to) < 100000         && return rang[1], Δday2ts(fr):Δday2ts(to)
	abs(fr) < 10000000000    && abs(to) < 10000000000    && return rang[1], to*1000:fr*1000
	abs(fr) < 10000000000000 && abs(to) < 10000000000000 && return rang[1], to:fr
	@assert false "Invalid date ranges: (from= $fr,to =$to) We accept days, timestamps and timestamp  in ms precision only (The order is: [ts_from]:[ts_to] or [day_to]:[day_from] as we do it like this 0:100 for 100 day lookback from the reference time(ctx.init_now_ts))"
end
daystyle(range::UnitRange{Int})     = "$(first(range))*$(last(range))"

get_unique_data_key(TYPE::Type{T}, set, src, ctxt) where T <: CandleType = begin
	source, tframe = '|' in src ? parse_range(String.(split(src,'|'))) : (src, ctxt.timestamps)
	exchange, marketframe, is_futures = parse_source(source, ctxt)
	market, candle = '@' in marketframe ? String.(split((marketframe),"@"))  : (ctxt.market, marketframe)
	candle_type, candle_value = parse_candle(candle)
	fr, to = first(tframe), last(tframe)
	# @show source, tframe
	# @show exchange, marketframe, is_futures
	# @show market, candle

	TYPE, set, exchange, market, is_futures, candle_type, candle_value, fr, to
end

