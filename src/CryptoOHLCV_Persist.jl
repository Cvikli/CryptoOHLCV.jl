


using JLD2
using Glob

folder(o::T)          where T <: CandleType = "$(o.data_path)"
glob_pattern(o::T)    where T <: CandleType = "OHLCV_$(o.exchange)_$(o.market)_$(isfutures_str(o.is_futures))_$(metric2candle(o.candle_type, o.candle_value))_*-*.jld2" # throw("Unimplemented... So basically to get the files list it is advised for you to build this.") #"$(T)_$(obj.config)_*_*"*".jld2"
unique_filename(o::T) where T <: CandleType = "OHLCV_$(o.exchange)_$(o.market)_$(isfutures_str(o.is_futures))_$(metric2candle(o.candle_type, o.candle_value))_$(first(o.timestamps))-$(last(o.timestamps)).jld2" 
parse_filename(fname::String)   = split(strip_jld2(fname),"_")
parse_args(filename::String)                            = begin
	(TYPE,ex,m1,m2,future, candl_v, fr_to_ts) = parse_filename(filename)
	(fr, to) = split(fr_to_ts,"-")
	return String(ex), "$(m1)_$(m2)", isfutures_str(String(future)), String(candl_v), parse(Int,fr), parse(Int,to)
end
score(data::Tuple{String,String,Bool,String,Int,Int}) = begin # we specify types for avoiding precompilation issue! Type piracy 
	ex,maket,future, candl_v, fr, to = data
	return to - fr
end

load_disk(file_name::String)            = JLD2.load(file_name, "cached") 
load_disk(obj::T) where T <: CandleType = begin
	files = list_files(obj)
	return 0<length(files) ? load_disk(largest(files)) : nothing
end
save_disk(obj; needclean=true)          = begin
	needclean && clean_files(list_files(obj))
	JLD2.save(ensure_folder(obj) * unique_filename(obj), "cached", obj)
end

# Helper functions
list_files(obj)                        = glob(glob_pattern(obj), ensure_folder(obj))
TOP1_idx(files::Vector{String})        = argmax(score.(parse_args.(files)))
largest(files::Vector{String})         = files[TOP1_idx(files)]
endwithslash(dir)                      = ((dir[end] !== '/' && println("we add a slash to the end of the folder: ", dir ," appended: '/'")); return dir[end] == '/' ? dir : dir*"/")
ensure_folder(obj)                     = mkfolder_if_not_exist(endwithslash(folder(obj)))

# Utils
strip_jld2(fname::String)              = fname[1:end-5]
clean_files(files::Vector{String})     = rm_if_exist.(files)
rm_if_exist(fname::String)             = isfile(fname) && rm(fname)
mkfolder_if_not_exist(fname::String)   = begin
	whole_dir = ""
	for dir in split(fname, "/")
		whole_dir *= dir * "/"
		dir in [".", ""] && continue
		!isdir(whole_dir) && mkdir(whole_dir)
	end
	fname
end

