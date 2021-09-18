function analyze()
    @info """Start the analyze of files in $datadir("compositions")"""
    df = DataFrame()
    for f in readdir(datadir("compositions"); join = true)
        d = JSON.parsefile(f)
        inds1 = Indices(["icn_time", "nthreads"])
        d1 = view(Dictionary(d),inds1)
        inds2 = Indices(["icn_iterations", "loss_sampler", "domains_size", "memoize", "metric", "sampling", "generations", "search", "population"])
        d2 = view(Dictionary(d["params"]), inds2)
        d3 = merge(d1, d2)
        d3["loss_sampler"] = string(d3["loss_sampler"])

        if isempty(df)
            df = DataFrame(Dict(pairs(d3)))
        else
            push!(df, Dict(pairs(d3)))
        end
    end
    return Voyager(df)
end