

# abstract type Universal <: Persistable end

# # cached_load(obj)  where T <: InitableLoadable = @memoize_typed T load(obj) unique_args(obj)
# # cached_load(t::Type{T}, args...; kw_args...)  where T <: InitableLoadable = @memoize_typed T load(t, args...; kw_args...)
# load(t::Type{T}, args...; kw_args...)   where T <: InitableLoadable = load_data!(init(t, args...; kw_args...))
# load(t::Type{T}, args...; kw_args...)   where T <: Persistable             = if :nocache in  keys(kw_args)
# 	@show "deleting key!!",kw_args
# 	kw_args=pairs(NamedTuple(q for q in kw_args if first(q)!==:nocache))  # TODO this is not so nice! Someone should figure out a better one!
# 	load_nocache(init(t, args...; kw_args...))
# else
# 	load(init(t, args...; kw_args...))
# end
# # load(t::Type{T}, args...; kw_args...)  where T <: Universal        = load(init(t, args...; kw_args...))
# load_nocache(t::Type{T}, args...; kw_args...)   where T <: Persistable   = load_nocache(init(t, args...; kw_args...))
# load_nocache(obj::T)                            where T <: Persistable   = load_data!(obj)
# load(obj::T)                           where T <: Persistable      = isfile((file_name=ensure_folder(obj) * unique_filename(obj);)) ? load_disk(file_name) : save_disk(load_data!(obj), false)
# load(obj::T)                           where T <: Universal        = begin # we could pass args and kw_args too...
# 	c = load_disk(obj)
# 	c, needsave = !isa(c, Nothing) ? extend!(obj,c) : (load_data!(obj), true)
# 	needsave && save_disk(c, !isa(c, Nothing))
# 	cut_requested!(obj, c)
# end
# savee(obj::T) where T <: Persistable = save_disk(obj, false)


