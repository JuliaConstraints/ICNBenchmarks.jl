
function search_space(
    #search_space_SA::SharedVector{Int64},
    dom_size,
    concept,
    param=nothing;
    search=:flexible,
    complete_search_limit=1000,
    solutions_limit=100,
)

    # Define the domains by on the domain size
    domains = fill(domain(1:dom_size), dom_size)

    max_samplings = sum(domain_size, domains)

    # # Determine if the search is partial or complete
    if search == :flexible
        search = max_samplings < complete_search_limit ? :complete : :partial
    end

    # Define the output folder and make the related path if necessary
    output_folder = joinpath(datadir("search_spaces"))
    mkpath(output_folder)

    # Define the file names TODO: make better metaprogramming
    name_solutions = ""
    name_non_sltns = ""
    if search == :complete
        configurations = :solutions
        name_solutions = savename(
            @dict constraint = Symbol(concept) param dom_size search configurations
        )
        configurations = :non_sltns
        name_non_sltns = savename(
            @dict constraint = Symbol(concept) param dom_size search configurations
        )
    else
        configurations = :solutions
        name_solutions = savename(
            @dict constraint = Symbol(concept) param dom_size search solutions_limit configurations
        )
        configurations = :non_sltns
        name_non_sltns = savename(
            @dict constraint = Symbol(concept) param dom_size search solutions_limit configurations
        )
    end
    file_solutions = joinpath(output_folder, "$name_solutions.csv")
    file_non_sltns = joinpath(output_folder, "$name_non_sltns.csv")

    # Check if existing data are present
    has_data = isfile(file_solutions) && isfile(file_non_sltns)

    function read_csv_as_set(file)
        configs = Set{Vector{Int}}()
        for r in CSV.Rows(file; header=false, types=Int)
            push!(configs, collect(Int, r))
        end
        return configs
    end

    # Load or compute the exploration of the search space
    solutions, non_sltns = Set{Vector{Int}}(), Set{Vector{Int}}()
    if has_data
        @warn "has data"
        solutions, non_sltns = read_csv_as_set(file_solutions), read_csv_as_set(file_non_sltns)
    else
        @warn "doesn't have data, generating solutions & non_solutions...."
        file_solutions, file_non_sltns = tryopen_exclusive(file_solutions), tryopen_exclusive(file_non_sltns)
        if (!isnothing(file_solutions))
            solutions, non_sltns = explore(domains, concept, param; 
                search, complete_search_limit, max_samplings, solutions_limit)
            files = [file_solutions]
            configs = [solutions]
            for (file, config) in zip(files, configs), x in config
                CSV.write(file, Tables.table(reshape(x, (1, length(x)))); append=true)
            end
        end

        if (!isnothing(file_non_sltns))
            # solutions, non_sltns = explore(domains, concept, param; 
            #     search, complete_search_limit, max_samplings, solutions_limit)
            files = [file_non_sltns]
            configs = [non_sltns]
            for (file, config) in zip(files, configs), x in config
                CSV.write(file, Tables.table(reshape(x, (1, length(x)))); append=true)
            end
        end
    end

    return solutions, non_sltns, has_data
end

# function write_configs(c::Channel)
#     for (file, x) in c
#         CSV.write(file, Tables.table(reshape(x, (1, length(x)))); append=true)
#     end
# end

# 681KB, 6 files in search space