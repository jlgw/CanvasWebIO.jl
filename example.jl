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
circ1 = dom"svg:circle[id=circ1, cx=200, cy=25, r=100]"()
addmovable!(canvas, box1)
addmovable!(canvas, box2)
addmovable!(canvas, circ1)
addstatic!(canvas, bg)

webio_serve(page("/", req -> canvas()), port)
