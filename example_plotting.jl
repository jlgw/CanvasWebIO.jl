using CanvasWebIO, WebIO, InteractNext, Mux, Plots

inspectdr(show=false)
port = 8000

height = 800
width = 800
linesy = 8
linesx = 8
scaling = 1./400
style = Dict(:stroke=>"black", :strokeWidth=>"2")
svggrid = [[dom"svg:line[x1=0, y1=$(i*height/linesy), x2=$width, y2=$(i*height/linesy)]"(style=style)
            for i in 0:linesy]...,
           [dom"svg:line[x1=$(i*width/linesx), y1=0, x2=$(i*width/linesx), y2=$height]"(style=style)
            for i in 1:linesx]...,
           dom"svg:text[x = $(width/2-10), y=$(height+15)]"("1.0"),
           dom"svg:text[x = $(width-10), y=$(height+15)]"("2.0"),
           dom"svg:text[x = 0, y=$(height/2-5)]"("1.0"),
           dom"svg:text[x = 0, y=$(15)]"("2.0"),
          ]

canvas = Canvas([width+15, height+15])
marker1 = dom"svg:circle[id=marker1, cy=153, cx=273, r=10]"()
marker2 = dom"svg:rect[id=marker2, height=20, width=20, x=210, y=210]"()
addmovable!(canvas, marker1)
addmovable!(canvas, marker2)
for i in svggrid
    addstatic!(canvas, i)
end
ui = @manipulate for r in 0.1:0.1:10 
    t = 0:0.02:2pi

    xf1 = canvas["marker1"][][1]*scaling
    yf1 = (height-canvas["marker1"][][2])*scaling
    plot(xf1*cos.(t), yf1*sin.(t), xlim = [-r,r], ylim=[-r,r])

    xf2 = canvas["marker2"][][1]*scaling
    yf2 = (height-canvas["marker2"][][2])*scaling
    plot(xf1*cos.(t), yf1*sin.(t), xlim = [-r,r], ylim=[-r,r])
    plot!([-xf2, -xf2, xf2, xf2, -xf2], [-yf2, yf2, yf2, -yf2, -yf2])
end

on(canvas["marker1"]) do val
    observe(r)[] = observe(r)[]
end

on(canvas["marker2"]) do val
    observe(r)[] = observe(r)[]
end

style = Dict(:display => "inline-table",
             :verticalAlign => "top",
             :width => "50%")

webio_serve(page("/", 
                 req -> Node(:div, 
                             Node(:div, canvas(), style=style),
                             Node(:div, ui, style=style))), 
                 port)
