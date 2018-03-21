module CanvasWebIO

using WebIO, JSExpr, Observables

export Canvas, addmovable!, addclickable!, addstatic!


mutable struct Canvas
    w::WebIO.Scope
    size::Array{Int64, 1}
    objects::Array{WebIO.Node, 1}
    getter::Dict
    selected_field::String
    handler::Observables.Observable
    selection::Observables.Observable
end

function Canvas(size)
    w = Scope()
    handler = Observable(w, "handler", ["id", 0, 0])
    selection = Observable(w, "selection", "id")
    getter = Dict()
    selected_field = WebIO.newid("selected")
    on(selection) do val
        val
    end
    on(handler) do val
        selection[] = val[1]
        try
            getter[val[1]][] = Int.(floor.(val[2:3]))
        catch
            println("Failed to assign value $(val[2:3]) to $(val[1])")
        end
    end
    Canvas(w, size, Array{WebIO.Node,1}(), getter, selected_field, handler, selection)
end

function Canvas()
    Canvas([800,800])
end

function Base.getindex(canvas::Canvas, i)
    canvas.getter[i]
end
function (canvas::Canvas)()
    canvas_events = Dict()

    handler = canvas.handler
    #Any reason to keep the drag event listeners? Do some tests.
    canvas_events["dragstart"]  = @js function(event)
        event.stopPropagation()
        event.preventDefault()
    end
    canvas_events["drop"]  = @js function(event)
        event.preventDefault()
        event.stopPropagation()
        name = document.getElementById($(canvas.selected_field)).innerHTML
        #make this saner with selected as attribute, internal data, metadata? who knows
        selected_obj = document.getElementById(name)
        selected_obj.style.stroke = "none"
        if selected_obj.getAttribute("draggable")=="true"
            #We perform the section below several times, how to remove duplicates?
            dim = selected_obj.parentElement.getBoundingClientRect()
            x = event.pageX-dim.x
            y = event.pageY-dim.y
            console.log("dropping", name, "at", x, y)
            if(selected_obj.tagName=="rect")
                xpos = x-selected_obj.getAttribute("width")/2
                ypos = y-selected_obj.getAttribute("height")/2
                selected_obj.setAttribute("x", xpos)
                selected_obj.setAttribute("y", ypos)
            elseif(selected_obj.tagName=="circle")
                xpos = x
                ypos = y
                selected_obj.setAttribute("cx", xpos)
                selected_obj.setAttribute("cy", ypos)
            end

            $handler[] = [name, xpos, ypos]
            document.getElementById($(canvas.selected_field)).innerHTML = ""
        end
    end
    canvas_events["mousemove"]  = @js function(event)
        event.preventDefault()
        event.stopPropagation()
        name = document.getElementById($(canvas.selected_field)).innerHTML
        #make this saner with selected as attribute, internal data? who knows
        selected_obj = document.getElementById(name)
        if selected_obj.getAttribute("draggable")=="true"
            #We perform the section below several times, how to remove duplicates?
            dim = selected_obj.parentElement.getBoundingClientRect()
            x = event.pageX-dim.x
            y = event.pageY-dim.y
            if(selected_obj.tagName=="rect")
                xpos = x-selected_obj.getAttribute("width")/2
                ypos = y-selected_obj.getAttribute("height")/2
                selected_obj.setAttribute("x", xpos)
                selected_obj.setAttribute("y", ypos)
            elseif(selected_obj.tagName=="circle")
                xpos = x
                ypos = y
                selected_obj.setAttribute("cx", xpos)
                selected_obj.setAttribute("cy", ypos)
            end
        end
    end
    canvas_events["dragover"]  = @js function(event)
        console.log("dragover")
        event.preventDefault()
        event.stopPropagation()
    end
    canvas_events["click"]  = @js function(event)
        name = document.getElementById($(canvas.selected_field)).innerHTML
        if(name!="")
            selected_obj = document.getElementById(name)
            if selected_obj.getAttribute("draggable")=="true"
                selected_obj.style.stroke = "none"
                dim = selected_obj.parentElement.getBoundingClientRect()
                x = event.pageX-dim.x
                y = event.pageY-dim.y
                console.log("click (drop)", name, "at", x, y)
                if(selected_obj.tagName=="rect")
                    xpos = x-selected_obj.getAttribute("width")/2
                    ypos = y-selected_obj.getAttribute("height")/2
                    selected_obj.setAttribute("x", xpos)
                    selected_obj.setAttribute("y", ypos)
                elseif(selected_obj.tagName=="circle")
                    xpos = x
                    ypos = y
                    selected_obj.setAttribute("cx", xpos)
                    selected_obj.setAttribute("cy", ypos)
                end
                $handler[] = [name, xpos, ypos]
                document.getElementById($(canvas.selected_field)).innerHTML = ""
            end
        end

        event.preventDefault()
        event.stopPropagation()
    end

    canvas.w(dom"svg:svg[id = canvas,
        height = $(canvas.size[1]),
        width = $(canvas.size[2])]"(
                                    canvas.objects...,
                                    Node(:div, attributes=Dict("id"=>canvas.selected_field), ""),
                                    events = canvas_events))
end

"""
addclickable!(canvas::Canvas, svg::WebIO.Node)

Adds a clickable (as in, can be clicked but not moved) object to the canvas based on the svg template. If the template has an id, this will be given to the canvas object, and the object will be associated with the id as a string (canvas[id] accesses the associated observable etc). If the template has no id, one will be generated. Note that the stroke property will be overwritten.
"""
function addclickable!(canvas::Canvas, svg::WebIO.Node)
    attr = svg.props[:attributes]
    children = svg.children
    if "id" in keys(attr)
        id = attr["id"]
    else
        id = WebIO.newid("svg")
    end
    selection = canvas.selection
    clickable_events = Dict()
    clickable_events["click"]  = @js function(event)
        name = document.getElementById($(canvas.selected_field)).innerHTML
        if name == this.id
            this.style.stroke = "none"
            document.getElementById($(canvas.selected_field)).innerHTML = ""
        else
            if name != ""
                selected_obj = document.getElementById(name)
                selected_obj.style.stroke = "none"
            end
            this.style.stroke = "green" #Change this later
            this.style.strokeWidth = 2 #Change this later
            document.getElementById($(canvas.selected_field)).innerHTML = this.id
            $selection[] = this.id
        end
    end
    push!(canvas.objects,
          Node(svg.instanceof, children..., attributes=attr, events=clickable_events))
end

"""
addmovable!(canvas::Canvas, svg::WebIO.Node)

Adds a movable object to the canvas based on the svg template. If the template has an id, this will be given to the canvas object, and the object will be associated with the id as a string (canvas[id] accesses the associated observable etc). If the template has no id, one will be generated. Note that the stroke property will be overwritten.
"""
function addmovable!(canvas::Canvas, svg::WebIO.Node)
    attr = svg.props[:attributes]
    children = svg.children
    if "id" in keys(attr)
        id = attr["id"]
    else
        id = WebIO.newid("svg")
        attr["id"] = id
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

    handler = canvas.handler
    attr["draggable"] = "true"
    style = Dict(:cursor => "move")
    movable_events = Dict()
    movable_events["dragstart"]  = @js function(event)
        event.stopPropagation()
        console.log("dragging", this.id)
        this.style.stroke = "red" #Change this later
        this.style.strokeWidth = 2 #Change this later
        document.getElementById($(canvas.selected_field)).innerHTML = this.id
    end
    movable_events["click"]  = @js function(event)
        console.log("clicking", this.id)
        name = document.getElementById($(canvas.selected_field)).innerHTML
        if name == ""
            this.style.stroke = "red" #Change this later
            this.style.strokeWidth = 2 #Change this later
            document.getElementById($(canvas.selected_field)).innerHTML = this.id
        else
            selected_obj = document.getElementById(name)
            selected_obj.style.stroke = "none"
            if selected_obj.getAttribute("draggable")=="true"
                dim = selected_obj.parentElement.getBoundingClientRect()
                x = event.pageX-dim.x
                y = event.pageY-dim.y

                console.log("click (drop)", name, "at", x, y)
                if(selected_obj.tagName=="rect")
                    xpos = x-selected_obj.getAttribute("width")/2
                    ypos = y-selected_obj.getAttribute("height")/2
                    selected_obj.setAttribute("x", xpos)
                    selected_obj.setAttribute("y", ypos)
                elseif(selected_obj.tagName=="circle") xpos = x
                    ypos = y
                    selected_obj.setAttribute("cx", xpos)
                    selected_obj.setAttribute("cy", ypos)
                end
                $handler[] = [name, xpos, ypos]
            end
            document.getElementById($(canvas.selected_field)).innerHTML = ""
        end
    end
    push!(canvas.objects,
          Node(svg.instanceof, children..., attributes=attr, style=style, events=movable_events))
end

"""
setindex_(canvas::Canvas, pos, i::String)

Sets the position of the object i to pos on the javascript side.
"""
function setindex_(canvas::Canvas, pos, i::String)
    #This pollutes global namespace (with temp vars), we may want to consider a function wrap
    evaljs(canvas.w, js"""
           selected_obj = document.getElementById($i)
           x = $(pos[1])
           y = $(pos[2])
           if(selected_obj.tagName=="rect"){
               xpos = x-selected_obj.getAttribute("width")/2
               ypos = y-selected_obj.getAttribute("height")/2
               selected_obj.setAttribute("x", xpos)
               selected_obj.setAttribute("y", ypos)
               }
           if(selected_obj.tagName=="circle"){
               xpos = x
               ypos = y
               selected_obj.setAttribute("cx", xpos)
               selected_obj.setAttribute("cy", ypos)
               }
           """)
end

"""
addstatic!(canvas::Canvas, svg::WebIO.Node)

Adds the svg object directly to the canvas.
"""
function addstatic!(canvas::Canvas, svg::WebIO.Node)
    push!(canvas.objects, svg)
end

function Base.setindex!(canvas::Canvas, val, i::String)
    setindex_(canvas::Canvas, val, i)
    canvas[i][] = val
end

end
