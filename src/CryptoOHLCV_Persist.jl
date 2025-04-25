


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




using JLD2
using Glob

load_disk(file_name::String)           = return JLD2.load(file_name, "cached") 
load_disk(obj)                         = return 0<length((files=list_files(obj);)) ? JLD2.load(largest(files), "cached") : nothing
save_disk(obj, needclean=true)         = (needclean && clean_files(list_files(obj));                JLD2.save(ensure_folder(obj) * unique_filename(obj), "cached", obj); obj)
save_disk_SAFE(obj, needclean=true)    = (needclean && clean_files(excluded_best(list_files(obj))); JLD2.save(ensure_folder(obj) * unique_filename(obj), "cached", obj); obj)



# Helper functions
list_files(obj)                        = glob(glob_pattern(obj), ensure_folder(obj))
TOP1_idx(files::Vector{String})        = argmax(score.(parse_args.(parse_filename.(files))))
excluded_best(files::Vector{String})   = (top_idx = TOP1_idx(files); [files[i] for i in 1:length(files) if i !==top_idx])  # IF WE would like to be VERY safe... then we can keep the last 2 version!
largest(files::Vector{String})         = files[TOP1_idx(files)]
endwithslash(dir)                      = ((dir[end] !== '/' && println("we add a slash to the end of the folder: ", dir ," appended: '/'")); return dir[end] == '/' ? dir : dir*"/")
ensure_folder(obj)                       = (mkfolder_if_not_exist((foldname=endwithslash(folder(obj));)); return foldname)


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
end

