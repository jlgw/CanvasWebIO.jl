module CanvasWebIO

using WebIO, JSExpr

export Canvas, addmovable!, addstatic!

mutable struct Canvas
    w::Scope
    size
    movables::Array
    static::Array
    getter::Dict
    dragged::String
    handler::Observable
end

function Canvas(size)
    w = Scope()
    handler = Observable(w, "handler", ["id", 0, 0])
    getter = Dict()
    dragged = WebIO.newid("dragged")
    on(handler) do val
        try
            getter[val[1]][] = val[2:3]
        catch
            error("Failed to assign value $(val[2:3]) to $(val[1])")
        end
    end
    Canvas(w, size, [], [], getter, dragged, handler)
end

function Canvas()
    Canvas([800,800])
end

function Base.getindex(canvas::Canvas, i)
    canvas.getter[i]
end
function (canvas::Canvas)()
    canvas_events = Dict()

    canvas_events["dragstart"]  = @js function(event) 
        event.stopPropagation() 
        event.preventDefault()
    end
    handler = canvas.handler
    canvas_events["drop"]  = @js function(event) 
        event.preventDefault()
        event.stopPropagation()
        #make this saner with dragged as attribute, internal data? who knows
        name = document.getElementById($(canvas.dragged)).innerHTML
        dragged_obj = document.getElementById(name)
        dim = dragged_obj.parentElement.getBoundingClientRect()
        x = event.pageX-dim.x
        y = event.pageY-dim.y
        console.log("dropping", name, "at", x, y)
        if(dragged_obj.tagName=="rect")
            xpos = x-dragged_obj.getAttribute("width")/2
            ypos = y-dragged_obj.getAttribute("height")/2
            dragged_obj.setAttribute("x", xpos)
            dragged_obj.setAttribute("y", ypos)
        elseif(dragged_obj.tagName=="circle")
            xpos = x
            ypos = y
            dragged_obj.setAttribute("cx", xpos)
            dragged_obj.setAttribute("cy", ypos)
        end

        $handler[] = [name, xpos, ypos]
    end
    canvas_events["dragover"]  = @js function(event) 
        console.log("dragover")
        event.preventDefault()
        event.stopPropagation() 
    end

    canvas.w(dom"svg:svg[id = canvas, 
        height = $(canvas.size[1]), 
        width = $(canvas.size[2])]"(
                                    canvas.static...,
                                    canvas.movables...,
                                    Node(:div, attributes=Dict("id"=>canvas.dragged), ""),
                                    events = canvas_events))
end

function addmovable!(canvas::Canvas, svg::WebIO.Node)
    attr = svg.props[:attributes]
    if "id" in keys(attr)
        id = attr["id"]
    else
        id = WebIO.newid("svg")
    end
    if svg.instanceof.tag==:rect
        pos = Observable(canvas.w, id, parse.([attr["x"], attr["y"]]))
    elseif svg.instanceof.tag==:circle
        pos = Observable(canvas.w, id, parse.([attr["cx"], attr["cy"]]))
    end
    on(pos) do val #This ensures it's updated from the js side
        val
    end
    canvas.getter[id] = pos
    
    attr["draggable"] = "true"
    style = Dict(:cursor => "move")
    box_events = Dict()
    box_events["dragstart"]  = @js function(event) 
        console.log("dragging", $(attr["id"]))
        document.getElementById($(canvas.dragged)).innerHTML = $(attr["id"])
        event.stopPropagation() 
    end
    push!(canvas.movables,
          Node(svg.instanceof, attributes=attr, style=style, events=box_events))
end

function addstatic!(canvas::Canvas, svg::WebIO.Node)
    push!(canvas.static, svg)
end
end
