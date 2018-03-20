module CanvasWebIO

using WebIO, JSExpr

export Canvas, addmovable!, addclickable!, addstatic!

mutable struct Canvas
    w::Scope
    size
    movables::Array
    clickables::Array
    static::Array
    getter::Dict
    selected::String #actually just the field for the selection
    handler::Observable
    selection::Observable
end

function Canvas(size)
    w = Scope()
    handler = Observable(w, "handler", ["id", 0, 0])
    selection = Observable(w, "selection", "id")
    getter = Dict()
    selected = WebIO.newid("selected")
    on(selection) do val
        val
    end
    on(handler) do val
        selection[] = val[1]
        try
            getter[val[1]][] = val[2:3]
        catch
            println("Failed to assign value $(val[2:3]) to $(val[1])")
        end
    end
    Canvas(w, size, [], [], [], getter, selected, handler, selection)
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
        name = document.getElementById($(canvas.selected)).innerHTML
        #make this saner with selected as attribute, internal data? who knows
        selected_obj = document.getElementById(name)
        selected_obj.style.stroke = "none"
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
        document.getElementById($(canvas.selected)).innerHTML = ""
    end
    canvas_events["dragover"]  = @js function(event) 
        console.log("dragover")
        event.preventDefault()
        event.stopPropagation() 
    end
    canvas_events["click"]  = @js function(event) 
        name = document.getElementById($(canvas.selected)).innerHTML
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
                document.getElementById($(canvas.selected)).innerHTML = ""
            end
        end

        event.preventDefault()
        event.stopPropagation() 
    end

    canvas.w(dom"svg:svg[id = canvas, 
        height = $(canvas.size[1]), 
        width = $(canvas.size[2])]"(
                                    canvas.static...,
                                    canvas.clickables...,
                                    canvas.movables...,
                                    Node(:div, attributes=Dict("id"=>canvas.selected), ""),
                                    events = canvas_events))
end

function addclickable!(canvas::Canvas, svg::WebIO.Node)
    attr = svg.props[:attributes]
    if "id" in keys(attr)
        id = attr["id"]
    else
        id = WebIO.newid("svg")
    end
    selection = canvas.selection
    clickable_events = Dict()
    clickable_events["click"]  = @js function(event) 
        name = document.getElementById($(canvas.selected)).innerHTML
        if name == this.id
            this.style.stroke = "none"
            document.getElementById($(canvas.selected)).innerHTML = ""
        else
            if name != ""
                selected_obj = document.getElementById(name)
                selected_obj.style.stroke = "none"
            end
            this.style.stroke = "green" #Change this later
            this.style.strokeWidth = 2 #Change this later
            document.getElementById($(canvas.selected)).innerHTML = this.id
            $selection[] = this.id
        end
    end
    push!(canvas.clickables,
          Node(svg.instanceof, attributes=attr, events=clickable_events))
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
    
    handler = canvas.handler
    attr["draggable"] = "true"
    style = Dict(:cursor => "move")
    movable_events = Dict()
    movable_events["dragstart"]  = @js function(event) 
        event.stopPropagation() 
        console.log("dragging", this.id)
        this.style.stroke = "red" #Change this later
        this.style.strokeWidth = 5 #Change this later
        document.getElementById($(canvas.selected)).innerHTML = this.id
    end
    movable_events["click"]  = @js function(event) 
        console.log("clicking", this.id)
        name = document.getElementById($(canvas.selected)).innerHTML
        if name == ""
            this.style.stroke = "red" #Change this later
            this.style.strokeWidth = 5 #Change this later
            document.getElementById($(canvas.selected)).innerHTML = this.id
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
                elseif(selected_obj.tagName=="circle")
                    xpos = x
                    ypos = y
                    selected_obj.setAttribute("cx", xpos)
                    selected_obj.setAttribute("cy", ypos)
                end
                $handler[] = [name, xpos, ypos]
            end
            document.getElementById($(canvas.selected)).innerHTML = ""
        end
    end
    push!(canvas.movables,
          Node(svg.instanceof, attributes=attr, style=style, events=movable_events))
end

function addstatic!(canvas::Canvas, svg::WebIO.Node)
    push!(canvas.static, svg)
end
end
