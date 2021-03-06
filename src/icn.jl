function icn_benchmark_unit(params)
    @info "Running a benchmark unit with" params

    search_space_size = params[:domains_size]^params[:domains_size]
    if params[:search] == :complete
        if search_space_size > params[:complete_search_limit]
            @warn "Unit benchmark aborted (complete) search space is too large" search_space_size params[:complete_search_limit]
            return nothing
        end
        if search_space_size > params[:loss_sampling_threshold]
            if isnothing(params[:loss_sampler])
                @warn "Unit benchmark aborted (complete) search space is too large, and loss function is deterministically evaluated" search_space_size params[:loss_sampling_threshold] params[:loss_sampler]
                return nothing
            end
        end
    end
    if params[:search] == :partial
        if search_space_size < params[:partial_search_limit]
            @warn "Unit benchmark aborted (partial) search space is too small" search_space_size params[:partial_search_limit]
            return nothing
        end
        if search_space_size ≤ params[:loss_sampling_threshold]
            if !isnothing(params[:loss_sampler])
                @warn "Unit benchmark aborted (complete) search space is too small, and loss function is stochastically evaluated" search_space_size params[:loss_sampling_threshold] params[:loss_sampler]
                return nothing
            end
        end
    end
    json_name = savename(
        (
            con=string(params[:concept][1]),
            par=params[:concept][2],
            csl=params[:complete_search_limit],
            dom=params[:domains_size],
            gen=params[:generations],
            iter=params[:icn_iterations],
            lang=string(params[:language]),
            lst=params[:loss_sampling_threshold],
            ls=string(params[:loss_sampler]),
            metric=string(params[:metric]),
            psl=params[:partial_search_limit],
            pop=params[:population],
            sampling=params[:sampling],
            search=string(params[:search]),
            mem=params[:memoize],
        ),
        "json",
    )
    save_results = joinpath(datadir("compositions"), json_name)
    if isfile(save_results)
        @warn "The result file already exist" save_results
    else

        # Generate an appropriate parameter for the concept if relevant
        param = if isnothing(params[:concept][2])
            nothing
        elseif params[:concept][2] == 1
            rand(1:params[:domains_size])
        else
            rand(1:params[:domains_size], params[:concept][2])
        end

        # assign parameters
        constraint_concept = concept(BENCHED_CONSTRAINTS[params[:concept][1]])
        metric = params[:metric]
        domain_size = params[:domains_size]
        domains = fill(domain(1:domain_size), domain_size)

        # Time the data retrieval/generation
        t = @timed search_space(
            domain_size,
            constraint_concept,
            param;
            search=params[:search],
            complete_search_limit=params[:complete_search_limit],
            solutions_limit=params[:sampling],
        )
        solutions, non_sltns, has_data = t.value

        bench = @timed explore_learn_compose(
            domains,
            constraint_concept,
            param;
            global_iter=params[:icn_iterations],
            local_iter=params[:generations],
            metric,
            pop_size=params[:population],
            configurations=(solutions, non_sltns),
            sampler=params[:loss_sampler],
            memoize=params[:memoize],
        )
        _, _, all_compos = bench.value

        results = Dict{Any,Any}()

        # Global results
        push!(results, :data => has_data ? :loaded : :explored)
        push!(results, :data_time => t.time)
        push!(results, :data_bytes => t.bytes)
        push!(results, :data_gctime => t.gctime)
        push!(results, :data_gcstats => t.gcstats)
        push!(results, :icn_time => bench.time)
        push!(results, :icn_bytes => bench.bytes)
        push!(results, :icn_gctime => bench.gctime)
        push!(results, :icn_gcstats => bench.gcstats)
        push!(results, :total_time => t.time + bench.time)
        push!(results, :nthreads => Threads.nthreads())

        for (id, (compo, occurence)) in enumerate(pairs(all_compos))
            local_results = Dict{Symbol,Any}()

            # selection rate
            push!(local_results, :selection_rate => occurence / params[:icn_iterations])

            # Code composition
            for lang in (params[:language], :maths)
                push!(
                    local_results,
                    lang => CompositionalNetworks.code(
                        compo, lang; name=string(params[:concept][1])
                    ),
                )
            end
            push!(local_results, :symbols => CompositionalNetworks.symbols(compo))

            push!(results, :params => params)
            push!(results, id => local_results)
        end
        write(save_results, json(results, 2))
        @info "Temp results" results json_name
    end
    return nothing
end

function icn_benchmark(params=ALL_PARAMETERS; clear_results=false)
    # Ensure the folders for data output exist
    clear_results && rm(datadir(); recursive=true, force=true)
    mkpath(datadir("compositions"))

    # Run all the benchmarks for all the unit configuration from params
    configs = dict_list(params)
    @warn "Number of benchmark units is $(length(configs))"
    for (u, c) in enumerate(configs)
        @info "Starting the $u/$(length(configs)) benchmark unit"
        GC.gc()
        icn_benchmark_unit(c)
    end
    return nothing
end
