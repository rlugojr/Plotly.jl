# __precompile__(true)

module Plotly
using Requests
using JSON
using Reexport: @reexport

@reexport using PlotlyJS

include("utils.jl")

#export default_kwargs, default_opts, get_config, get_plot_endpoint, get_credentials,get_content_endpoint,get_template

type CurrentPlot
    filename::ASCIIString
    fileopt::ASCIIString
    url::ASCIIString
end

const api_version = "v2"

const default_kwargs = Dict{Symbol,Any}(:filename=>"Plot from Julia API",
                                         :world_readable=> true)

## Taken from https://github.com/johnmyleswhite/Vega.jl/blob/master/src/Vega.jl#L51
# Open a URL in a browser
function openurl(url::ASCIIString)
    @osx_only run(`open $url`)
    @windows_only run(`start $url`)
    @linux_only run(`xdg-open $url`)
end

const default_opts = Dict{Symbol,Any}(:origin => "plot",
                                      :platform => "Julia",
                                      :version => "0.2")

get_plot_endpoint() = "$(get_config().plotly_domain)/clientresp"

function get_content_endpoint(file_id::ASCIIString, owner::ASCIIString)
    config = get_config()
    api_endpoint = "$(config.plotly_api_domain)/$api_version/files"
    detail = "$owner:$file_id"
    "$api_endpoint/$detail/content"
end

function Requests.post(p::Plot; kwargs...)
    creds = get_credentials()
    endpoint = get_plot_endpoint()
    opt = merge(default_kwargs, Dict(:layout => p.layout.fields),
                Dict(kwargs))

    data = merge(default_opts,
                 Dict("un" => creds.username,
                      "key" => creds.api_key,
                      "args" => json(p.data),
                      "kwargs" => json(opt)))

    r = post(endpoint, data=data)
    body=Requests.json(r)

    if statuscode(r) != 200
        error(["r.status"])
    elseif body["error"] != ""
        error(body["error"])
    else
        global currentplot
        currentplot=CurrentPlot(body["filename"], "new", body["url"])
        body
    end
end

function Reqeusts.post(l::AbstractLayout, meta_opts=Dict(); meta_kwargs...)
    creds = get_credentials()
    endpoint = get_plot_endpoint()

    meta = merge(meta_opts,
                 get_required_params(["filename", "fileopt"], meta_opts),
                 Dict(meta_kwargs))
    data = merge(default_opts,
                 Dict("un" => creds.username,
                      "key" => creds.api_key,
                      "args" => json(l),
                      "origin" => "layout",
                      "kwargs" => json(meta)))

    __parseresponse(post(endpoint, data=data))
end

function style(style_opts, meta_opts=Dict(); meta_kwargs...)
    creds = get_credentials()
    endpoint = get_plot_endpoint()

    meta = merge(meta_opts,
                 get_required_params(["filename", "fileopt"], meta_opts),
                 Dict(meta_kwargs))
    data = merge(default_opts,
                 Dict("un" => creds.username,
                      "key" => creds.api_key,
                      "args" => json([style_opts]),
                      "origin" => "style",
                      "kwargs" => json(meta_opts)))

    __parseresponse(post(endpoint, data=data))
end


function getFile(file_id::ASCIIString, owner=None)
    creds = get_credentials()
    username = creds.username
    api_key = creds.api_key

    if (owner == None)
        owner = username
    end

    endpoint = get_content_endpoint(file_id, owner)
    lib_version = string(default_opts["platform"], " ", default_opts["version"])

    auth = string("Basic ", base64("$username:$api_key"))

    options = Dict("Authorization"=>auth, "Plotly-Client-Platform"=>lib_version)

    r = get(endpoint, headers=options)
    print(r)

    __parseresponse(r)

end


function get_required_params(required,opts)
    # Priority given to user-inputted opts, then currentplot
    result=Dict()
    for p in required
        global currentplot
        if haskey(opts,p)
            result[p] = opts[p]
        elseif isdefined(Plotly,:currentplot)
            result[p] = getfield(currentplot,symbol(p))
        else
            msg = string("Missing required param $(p). ",
                         "Make sure to create a plot first. ",
                         " Please refer to http://plot.ly/api")
            error(msg)
        end
    end
    result
end

function __parseresponse(r)
    body=Requests.json(r)
    if statuscode(r) != 200
        error(["r.status"])
    elseif haskey(body, "error") && body["error"] != ""
        error(body["error"])
    elseif haskey(body, "detail") && body["detail"] != ""
        error(body["detail"])
    else
        body
    end
end

end
