# CanvasWebIO

Warning: This package is experimental and buggy.


The purpose of this package is to allow the construction of movable SVG objects inside a WebIO Scope, with the objects having their positions accesssible through observables in Julia. 

To create a canvas:

```julia
canvas = Canvas()
```

Adding movable objects using a template node:

```julia
box = dom"svg:rect[id=box, height=50, width=50, x=100, y=100]"()
addmovable!(canvas, box)
```

Serving with Mux, canvas() returns canvas Scope
```julia
webio_serve(page("/", req -> canvas()))
```

Accessing position of movable object (currently the position cannot be assigned from the julia side):
```julia
canvas["box"][]
```
