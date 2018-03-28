setp = function(event, name){
    var selected_obj = document.getElementById(name)
    var draggable = (selected_obj.getAttribute("draggable")=="true")
    if(draggable){
        var dim = selected_obj.parentElement.getBoundingClientRect();
        var x = event.pageX-dim.x;
        var y = event.pageY-dim.y;
        var xpos, ypos;
        if(selected_obj.tagName=="g"){
            xpos = x;
            ypos = y;
            var trfm = parse(selected_obj.getAttribute("transform"));
            if(selected_obj.getAttribute("data-lock")!="x"){
                trfm["translate"][0] = xpos;
            }
            else{
                xpos = trfm["translate"][0];
            }
            if(selected_obj.getAttribute("data-lock")!="y"){
                trfm["translate"][1] = ypos;
            }
            else{
                ypos = trfm["translate"][1];
            }
            selected_obj.setAttribute("transform", mk(trfm));
        }
    }
    return [draggable, xpos, ypos];
}

parse = function (a){
    var b={};
    for (var i in a = a.match(/(\w+\((\-?\d+\.?\d*e?\-?\d*,?)+\))+/g)){
        var c = a[i].match(/[\w\.\-]+/g);
        b[c.shift()] = c;
    }
    return b;
}

mk = function (a){
    return (Object.keys(a).map(n => n + "("+ a[n].join(",") + ")")).join(" ");
}

setp_nonevent = function (pos, name){
    selected_obj = document.getElementById(name)
    var x = pos[0];
    var y = pos[1];
    var xpos, ypos
    if(selected_obj.tagName=="rect"){
        xpos = x-selected_obj.getAttribute("width")/2;
        ypos = y-selected_obj.getAttribute("height")/2;
        selected_obj.setAttribute("x", xpos);
        selected_obj.setAttribute("y", ypos);
    }
    if(selected_obj.tagName=="circle"){
        xpos = x;
        ypos = y;
        selected_obj.setAttribute("cx", xpos);
        selected_obj.setAttribute("cy", ypos);

    }
    if(selected_obj.tagName=="g"){
        xpos = x;
        ypos = y;
        var trfm = parse(selected_obj.getAttribute("transform"));
        if(selected_obj.getAttribute("data-lock")!="x"){
            trfm["translate"][0] = xpos;
        }
        else{
            xpos = trfm["translate"][0];
        }
        if(selected_obj.getAttribute("data-lock")!="y"){
            trfm["translate"][1] = ypos;
        }
        else{
            ypos = trfm["translate"][1];
        }
        selected_obj.setAttribute("transform", mk(trfm));
    }
}
