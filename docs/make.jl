using GEMB
using Documenter
import Glob

# ========== Recursively discover GEMB submodules ==========

"Return a dictionary containing a module and all of its GEMB submodules."
function get_all_submodules(
    mod::Module,
    found::Dict{String,Module}=Dict{String,Module}(),
)
    # Register the current module before traversing its bindings.
    fullname_string = join(fullname(mod), ".")
    haskey(found, fullname_string) && return found
    found[fullname_string] = mod

    # Inspect all defined bindings in the current module.
    for name in names(mod, all=true)
        # Skip compiler-generated and module-internal bindings.
        startswith(string(name), "#") && continue
        name == :eval && continue
        name == :include && continue
        isdefined(mod, name) || continue

        object = getfield(mod, name)
        object isa Module || continue

        # Traverse only modules that belong to the GEMB namespace.
        object_fullname = join(fullname(object), ".")
        if object_fullname == "GEMB" || startswith(object_fullname, "GEMB.")
            get_all_submodules(object, found)
        end
    end

    return found
end

# Collect and sort all modules by their fully qualified names.
all_modules = get_all_submodules(GEMB)
modules_to_document = collect(all_modules)
sort!(modules_to_document, by=first)

println("Discovered $(length(modules_to_document)) GEMB modules:")
for (name, _) in modules_to_document
    println("  - ", name)
end

# ========== Generate example pages ==========

examples_directory = joinpath(@__DIR__, "..", "examples")
examples_source_directory = joinpath(@__DIR__, "src", "examples")
mkpath(examples_source_directory)

# Continue building the manual even when the package has no examples directory.
julia_files = if isdir(examples_directory)
    Glob.glob("*.jl", examples_directory)
else
    @warn "Examples directory does not exist; no example pages will be generated." examples_directory
    String[]
end
sort!(julia_files)

example_pages = Pair{String,String}[]

for julia_file in julia_files
    # Derive the page title and output filename from the Julia source filename.
    base_name = basename(julia_file)
    name_without_extension = splitext(base_name)[1]
    markdown_filename = "$(name_without_extension).md"
    markdown_filepath = joinpath(
        examples_source_directory,
        markdown_filename,
    )

    julia_content = read(julia_file, String)

    # Display the complete example as source code without executing it.
    # Four backticks allow embedded docstrings to contain triple-backtick blocks.
    markdown_content = """
    # $(name_without_extension)

    Source file: `examples/$(base_name)`

    ````julia
    $(julia_content)
    ````
    """

    write(markdown_filepath, markdown_content)
    push!(
        example_pages,
        name_without_extension => "examples/$(markdown_filename)",
    )
end

# ========== Generate API reference pages ==========

api_source_directory = joinpath(@__DIR__, "src", "api")
mkpath(api_source_directory)

# API pages in this directory are generated files. Remove pages from earlier
# module layouts before regenerating the current API reference. This prevents
# Documenter from evaluating stale @autodocs blocks for modules that no longer
# exist.
for stale_api_page in readdir(
    api_source_directory;
    join=true,
)
    endswith(
        stale_api_page,
        ".md",
    ) || continue

    rm(
        stale_api_page;
        force=true,
    )
end

api_subpages = Pair{String,String}[]

for (module_name, _) in modules_to_document
    # Convert the fully qualified module name into a filesystem-safe name.
    filename = replace(module_name, "." => "_") * ".md"
    filepath = joinpath(api_source_directory, filename)

    # Include the module docstring as well as its documented public objects.
    content = """
    # `$(module_name)`

    ```@autodocs
    Modules = [$(module_name)]
    Order = [:module, :type, :function, :macro, :constant]
    ```
    """

    write(filepath, content)
    push!(api_subpages, module_name => "api/$(filename)")
end

# ========== Assemble the navigation tree ==========

pages_list = Any[
    "Home" => "index.md",
]

guide_pages = Pair{String,String}[
    "Condition Agents" => "condition_agents.md",
    "Ad Valorem Claims" => "ad_valorem_claims.md",
    "Intertemporal Equilibrium" => "intertemporal_equilibrium.md",
]

push!(pages_list, "Guides" => guide_pages)

if !isempty(api_subpages)
    push!(pages_list, "API Reference" => api_subpages)
end

if !isempty(example_pages)
    push!(pages_list, "Examples" => example_pages)
end

# ========== Build the documentation ==========

makedocs(
    modules = [mod for (_, mod) in modules_to_document],

    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = nothing,
    ),

    sitename = "GEMB.jl Documentation",
    authors = "Wu Li",

    # Disable remote source links for local documentation builds.
    remotes = nothing,

    pages = pages_list,

    # Keep selected documentation warnings non-fatal during development.
    warnonly = [
        :missing_docs,
        :cross_references,
        :eval_block,
    ],
)

# Deploy documentation from GitHub Actions.
deploydocs(
    repo = "github.com/LiWuR/GEMB.jl.git",
    devbranch = "main",
)
