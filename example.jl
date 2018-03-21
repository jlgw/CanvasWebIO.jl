using CanvasWebIO, WebIO, Mux

try 
    global port += 1 
catch 
    global port = 8000 
end 

canvas = Canvas()
bg = dom"svg:rect[height=800, width=800, fill=blue]"()
box1 = dom"svg:rect[id=box1, height=50, width=50, x=50, y=50]"()
box2 = dom"svg:rect[id=box2, height=100, width=25, x=250, y=250]"()
box3 = dom"svg:rect[id=box3, height=100, width=25, x=550, y=350]"()
circ1 = dom"svg:circle[id=circ1, cx=200, cy=25, r=100]"()
addstatic!(canvas, bg)
addmovable!(canvas, box1)
addmovable!(canvas, box2)
addmovable!(canvas, circ1)
addclickable!(canvas, box3)

on(canvas.selection) do val
    println("selected $val")
end

on(canvas["box1"]) do val
    println("box1 moved to $(val[1]), $(val[2])")
end

on(canvas["box2"]) do val
    println("box2 moved to $(val[1]), $(val[2])")
end

on(canvas["circ1"]) do val
    println("circ1 moved to $(val[1]), $(val[2])")
end

webio_serve(page("/", req -> canvas()), port)
