module CanvasWebIO

using WebIO, JSExpr, Observables

export Canvas, addmovable!, addclickable!, addstatic!

mutable struct Canvas
    w::WebIO.Scope
    size::Array{Int64, 1}
    objects::Array{WebIO.Node, 1}
    getter::Dict
    id::String
    handler::Observables.Observable
    selection::Observables.Observable
    synced::Bool # synced=true => julia listeners called on mousemove, not just drop
end

function Canvas(size::Array{Int64,1}, synced=false)
    w = Scope()
    handler = Observable(w, "handler", ["id", 0, 0])
    selection = Observable(w, "selection", "id")
    getter = Dict()
    id = WebIO.newid("canvas")
    on(selection) do val
        val
    end
    on(handler) do val
        selection[] = val[1]
        if val[1] in keys(getter)
            getter[val[1]][] = Int.(floor.(val[2:3]))
        else
            println("Failed to assign value $(val[2:3]) to $(val[1])")
        end
    end
    Canvas(w, size, Array{WebIO.Node,1}(), getter, id, handler, selection, synced)
end

function Canvas()
    Canvas([800,800])
end

function Canvas(synced::Bool)
    Canvas([800,800], synced)
end

function Base.getindex(canvas::Canvas, i)
    canvas.getter[i]
end

function (canvas::Canvas)()

    # js function setp sets the position of the object named name to the position of the mouse
    # returns the [draggable, xpos, ypos] where draggable is whether the object was movable,
    # and xpos,ypos the new position of the object
    #
    # Transform parser from https://stackoverflow.com/a/17838403
    # clean this up
    @async (sleep(1.0); evaljs(canvas.w, js""" setp = function(event, name){
        var selected_obj = document.getElementById(name)
        var draggable = (selected_obj.getAttribute("draggable")=="true")
        if(draggable){
            var dim = selected_obj.parentElement.getBoundingClientRect()
            var x = event.pageX-dim.x
            var y = event.pageY-dim.y
            var xpos, ypos
            if(selected_obj.tagName=="rect"){
                xpos = x-selected_obj.getAttribute("width")/2
                ypos = y-selected_obj.getAttribute("height")/2
                if(selected_obj.getAttribute("data-lock")!="x"){
                    selected_obj.setAttribute("x", xpos)
                }
                else{
                    xpos = parseInt(selected_obj.getAttribute("x"))
                }
                if(selected_obj.getAttribute("data-lock")!="y"){
                    selected_obj.setAttribute("y", ypos)
                }
                else{
                    ypos = parseInt(selected_obj.getAttribute("y"))
                }
            }
            if(selected_obj.tagName=="circle"){
                xpos = x
                ypos = y
                if(selected_obj.getAttribute("data-lock")!="x"){
                    selected_obj.setAttribute("cx", xpos)
                }
                else{
                    xpos = parseInt(selected_obj.getAttribute("cx"))
                }
                if(selected_obj.getAttribute("data-lock")!="y"){
                    selected_obj.setAttribute("cy", ypos)
                }
                else{
                    ypos = parseInt(selected_obj.getAttribute("cy"))
                }
            }
            if(selected_obj.tagName=="g"){
                xpos = x-selected_obj.getBoundingClientRect().width/2
                ypos = y-selected_obj.getBoundingClientRect().height/2
                var trfm = parse(selected_obj.getAttribute("transform"))
                if(selected_obj.getAttribute("data-lock")!="x"){
                    trfm["translate"][0] = xpos
                }
                else{
                    xpos = trfm["translate"][0]
                }
                if(selected_obj.getAttribute("data-lock")!="y"){
                    trfm["translate"][1] = ypos
                }
                else{
                    ypos = trfm["translate"][1]
                }
                selected_obj.setAttribute("transform", mk(trfm))
            }
        }
        return [draggable, xpos, ypos]};
        parse = function (a){
            var b={};
            for (var i in a = a.match(/(\w+\((\-?\d+\.?\d*e?\-?\d*,?)+\))+/g)){
                var c = a[i].match(/[\w\.\-]+/g);
                b[c.shift()] = c;
            }
            return b;
        }
        mk = function (a){
            return (Object.keys(a).map(n => n + "("+ a[n].join(",") + ")")).join(" ")
        }
            """))

    canvas_events = Dict()

    handler = canvas.handler
    synced  = canvas.synced

    canvas_events["mousemove"]  = @js function(event)
        event.preventDefault()
        event.stopPropagation()
        @var name = document.getElementById($(canvas.id)).getAttribute("data-selected")
        @var pos
        if name!=""
            pos = setp(event, name)
            if(pos[0]) #is dragged
                document.getElementById($(canvas.id)).setAttribute("is-dragged", true)
                if($synced)
                    $handler[] = [name, pos[1], pos[2]]
                end
            end
        end
    end

    canvas_events["mouseup"] = @js function(event)
        event.preventDefault()
        event.stopPropagation()
        console.log("canvas click")
        @var name = document.getElementById($(canvas.id)).getAttribute("data-selected")
        @var pos
        if name!=""
            pos = setp(event, name)
            if document.getElementById($(canvas.id)).getAttribute("is-dragged")=="true"
                $handler[] = [name, pos[1], pos[2]]
                document.getElementById(name).style.stroke = "none"
                document.getElementById($(canvas.id)).setAttribute("data-selected", "")
                document.getElementById($(canvas.id)).setAttribute("is-dragged", false)
            end
        end
    end

    canvas.w(dom"svg:svg[id = $(canvas.id),
        height = $(canvas.size[1]),
        width = $(canvas.size[2])]"(
                                    canvas.objects...,
                                    attributes = Dict("data-selected" => "",
                                                     "is-dragged" => false),
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
        name = document.getElementById($(canvas.id)).getAttribute("data-selected")
        #selected_obj
        if name == this.id
            this.style.stroke = "none"
            document.getElementById($(canvas.id)).setAttribute("data-selected", "")
        else
            if name != ""
                selected_obj = document.getElementById(name)
                selected_obj.style.stroke = "none"
            end
            this.style.stroke = "green" #Change this later
            this.style.strokeWidth = 2 #Change this later
            document.getElementById($(canvas.id)).setAttribute("data-selected", this.id)
            $selection[] = this.id
        end
    end
    push!(canvas.objects,
          Node(svg.instanceof, children..., attributes=attr, events=clickable_events))
end
"""
addmovable!(canvas::Canvas, svg::WebIO.Node, lock=" ")

Adds a movable object to the canvas based on the svg template. If the template has an id, this will be given to the canvas object, and the object will be associated with the id as a string (canvas[id] accesses the associated observable etc). If the template has no id, one will be generated. Note that the stroke property will be overwritten.

The optional lock argument allows locking of an axis. Setting lock="x" will lock the movable's x value, so it can only be moved up and down. Similarly, lock="y" will only permit movements to the left and right.
"""
function addmovable!(canvas::Canvas, svg::WebIO.Node, lock=" ")
    attr = svg.props[:attributes]
    if :style in keys(svg.props)
        style = svg.props[:style]
    else
        style = Dict()
    end
    children = svg.children
    if "id" in keys(attr)
        id = attr["id"]
    else
        id = WebIO.newid("svg")
        attr["id"] = id
    end
    attr["data-lock"] = lock
    if svg.instanceof.tag==:rect
        pos = Observable(canvas.w, id, parse.([attr["x"], attr["y"]]))
    elseif svg.instanceof.tag==:circle
        pos = Observable(canvas.w, id, parse.([attr["cx"], attr["cy"]]))
    elseif svg.instanceof.tag==:g
        pos = Observable(canvas.w, id, [50.0,50.0]) #change
    end

    push!(pos.listeners, (x)->(x))
    canvas.getter[id] = pos

    handler = canvas.handler
    attr["draggable"] = "true"
    style[:cursor] = "move"
    movable_events = Dict()

    movable_events["mousedown"]  = @js function(event)
        event.stopPropagation()
        event.preventDefault()
        console.log("clicking", this.id)
        @var name = document.getElementById($(canvas.id)).getAttribute("data-selected")
        @var pos
        if name == ""
            this.style.stroke = "red" #Change this later
            this.style.strokeWidth = 2 #Change this later
            document.getElementById($(canvas.id)).setAttribute("data-selected", this.id)
        else
            selected_obj = document.getElementById(name)
            selected_obj.style.stroke = "none"
            pos = setp(event,name)
            if(pos[0]) #is dragged
                $handler[] = [name, pos[1], pos[2]]
            end
            document.getElementById($(canvas.id)).setAttribute("data-selected", "")
            document.getElementById($(canvas.id)).setAttribute("is-dragged", false)
        end
    end
    push!(canvas.objects,
          Node(svg.instanceof, children..., attributes=attr, style=style, events=movable_events))
end

"""
addstatic!(canvas::Canvas, svg::WebIO.Node)

Adds the svg object directly to the canvas.
"""
function addstatic!(canvas::Canvas, svg::WebIO.Node)
    push!(canvas.objects, svg)
end

"""
setindex_(canvas::Canvas, pos, i::String)

Sets the position of the object i to pos on the javascript side.
"""
function setindex_(canvas::Canvas, pos, i::String)
    evaljs(canvas.w, js"""
           (function (){
               selected_obj = document.getElementById($i)
               var x = $(pos[1])
               var y = $(pos[2])
               var xpos, ypos
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
               if(selected_obj.tagName=="g"){
                   xpos = x-selected_obj.getBoundingClientRect().width/2
                   ypos = y-selected_obj.getBoundingClientRect().height/2
                   var trfm = parse(selected_obj.getAttribute("transform"))
                   if(selected_obj.getAttribute("data-lock")!="x"){
                       trfm["translate"][0] = xpos
                   }
                   else{
                       xpos = trfm["translate"][0]
                   }
                   if(selected_obj.getAttribute("data-lock")!="y"){
                       trfm["translate"][1] = ypos
                   }
                   else{
                       ypos = trfm["translate"][1]
                   }
                   selected_obj.setAttribute("transform", mk(trfm))
                   }
               })()"""
              )
end

function Base.setindex!(canvas::Canvas, val, i::String)
    setindex_(canvas::Canvas, val, i)
    canvas[i][] = val
end
end
