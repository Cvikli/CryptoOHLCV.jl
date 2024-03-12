



UniversalStruct.need_data_before(o::T1, c::T2)  where {T1 <: CandleType, T2 <: CandleType}= first(o.timestamps) < first(c.timestamps)
UniversalStruct.need_data_after(o::T1,  c::T2)  where {T1 <: CandleType, T2 <: CandleType}= last(c.timestamps)  < last(o.timestamps)

UniversalStruct.init_before_data(o::T1, c::T2)  where {T1 <: CandleType, T2 <: CandleType} = UniversalStruct.init(T1, reconstruct_src(o), reverse_parse_candle(o), first(o.timestamps), first(c.timestamps))
UniversalStruct.init_after_data(o::T1,  c::T2)  where {T1 <: CandleType, T2 <: CandleType} = UniversalStruct.init(T2, reconstruct_src(o), reverse_parse_candle(o), last(c.timestamps),  last(o.timestamps))


UniversalStruct.append(o::T1, c::T2) where {T1 <: CandleType, T2 <: CandleType} = append!(o, c)
append!(o::T1, c::T2)                where {T1 <: CandleType, T2 <: CandleType} = begin 
	o.t = vcat(o.t, c.t) # TODO... this seems bad!!
	o.o = vcat(o.o, c.o)
	o.h = vcat(o.h, c.h)
	o.l = vcat(o.l, c.l)
	o.c = vcat(o.c, c.c)
	o.v = vcat(o.v, c.v)
	o.timestamps = first(o.timestamps):last(c.timestamps)
	return o
end

UniversalStruct.cut_requested!(o::T1, c::T2)    where {T1 <: CandleType, T2 <: CandleType} = return if o.candle_type in [:SECOND,:MINUTE,:HOUR,:DAY]
	cut_data_1m!(o, c)
else
	cut_data_tick!(o, c)
end
cut_data_tick!(o, c) = begin
	o_fr, o_to = first(o.timestamps)*1000, last(o.timestamps)*1000
	offset = 1
	endset = length(c.t)
	while c.t[offset] < o_fr && offset < endset
		offset+=1; end
	while c.t[endset] > o_to && endset > offset-1
		endset-=1; end
	
	o.t = c.t[offset:endset]
	o.o = c.o[offset:endset]
	o.h = c.h[offset:endset]
	o.l = c.l[offset:endset]
	o.c = c.c[offset:endset]
	o.v = c.v[offset:endset]
	o
end
cut_data_1m!(o, c) = begin
	min_candle_value = 60
	o_fr, o_to = first(o.timestamps), last(o.timestamps)
	c_fr       = first(c.timestamps)

	offset = cld(o_fr - c_fr, min_candle_value)
	endset = cld(o_to - c_fr, min_candle_value)
	
	@assert endset<=length(c.h) "how can this be bigger?? $(endset), $(length(c.h))"
	
	o.t = c.t[1+offset:endset]
	o.o = c.o[1+offset:endset]
	o.h = c.h[1+offset:endset]
	o.l = c.l[1+offset:endset]
	o.c = c.c[1+offset:endset]
	o.v = c.v[1+offset:endset]
	o
end


