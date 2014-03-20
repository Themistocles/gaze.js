###

gaze.js

(c) Ralf Biedert, 2014
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###


# Version of this script
VERSION = 0.1

# Should suffice for the moment of getting the global
global = window

# Make backup of previous gaze object if there was any
_gaze = global.gaze

# Extensions that have been registered
extensions = {}
extensionorder = [] # order in which to initialize ["raw", "filtered", "dwell", ...]



# Potential problems
#   error = terminal failure to eye tracking until reinitialized
#   warning = temporary failure or data likely corrupt
#   info = might be problem, might be not
#
problems = {
    "E_CONNECTIONCLOSED": {
        message: "Connection to the tracker closed unexpectedly. All gaze data halted."
        type: "error"
    }

    "E_NOTIMPLEMENTED": {
        message: "This feature is not implemented at the moment."
        type: "error"
    }

    "W_DATASTALL": {
        message: "The gaze relay (or the eye tracker) unexpectedly stopped
                sending data. The application is currently unaware of gaze."
        type: "warning"
    }

    "I_MOUSEFALLBACK": {
        message: "Switched to mouse fallback."
        type: "info"
    }
}



### Handlers Class ###
handlers = () ->
    @_handlers = []
    return @

handlers.prototype = {
    ### Adds something to this handlers and returns a handle ###
    add: (x) ->
        that = @
        size = @_handlers.length

        @_handlers.push x

        # Construct removal handle
        handle = {
            handler: x
            remove: () -> that.remove this.handler
        }

        # If old size was 0, we are populated now
        if size == 0 then @onpopulated()

        return handle

    ### Checks if there are elements in the handlers ###
    has: () -> @_handlers.length > 0
        
    ### Calls every handler with the given message ###
    invoke: (msg) ->
        for handler in @_handlers
            handler msg

    ### Call f for each handler ###
    each: (f) ->
        for handler in @_handlers
            f handler

    ### Removes something from these handlers ###
    remove: (x) ->
        size = @_handlers.length
        @_handlers = @_handlers.filter (y) -> x isnt y

        if size > 0 and @_handlers.length == 0
            @onempty()

    onpopulated: () ->
    onempty: () ->
}


### Gaze Class ###
gaze = (@global) ->
    @_document = @global.document
    @_initialized = false
    @_onframe = new handlers()
    @_onframeconfig = new handlers()
    @_onproblem = new handlers()
    @_currentframe = {}
    return @


### Extend the gaze object with more functions  ###
gaze.extension = (fns, module) ->
    if not module
        module = {}
        module.id = ("unnamed" + Math.random()).replace(".", "")

    for key, value of fns
        if gaze.fn[key]
            console.log("Module '" + module.id + "' overrides '" + key + "()'")

        gaze.fn[key] = value

    # Safety check we don't override anything
    if module.functions
        alert("Extension module must not have attribute .functions")

    # Transcribe problem IDs
    if module.problems then problems[key] = value for key, value of module.problems

    # Store functions we added
    module.functions = fns

    # And store extension
    extensions[module.id] = module

    # Eventually update the extensionorder based on its dependency graph
    extensionorder = (name for name of extensions)
    extensionorder.sort (a, b) ->
        # If b does not have any dependencies, b goes left
        if not b.dependencies then return -1

        # If b depends on a, b goes right
        if b.dependencies.indexOf(a) >= 0 then return 1
        return -1



### Core methods ###
gaze.fn = gaze.prototype = {
    ### Initializes object and connects to an eye tracker ###
    init: (@url) ->
        if @_initialized then deinit()

        # Initialize extensions in proper order
        for id in extensionorder
            module = extensions[id]

            if module.init then module.init @, module

        gaze = @
        wasconnected = false
        connector = gaze.connectors["relay"]

        frame = (frame) -> gaze.frame frame
        status = (event) ->
            if event.type == "open"
                wasconnected = true

            if event.type == "close"
                if wasconnected then gaze.problem("E_CONNECTIONCLOSED")
                else
                    gaze.problem("I_MOUSEFALLBACK")

                    connector = gaze.connectors["mouse"]
                    gaze._tracker = connector(url, status, frame)

            if event.type == "error"
                if wasconnected
                    console.log event


        # Next initialize the eye tracker, or at least try
        @_tracker = connector(url, status, frame)
        @_initialized = true

        # Push empty frame as a hack to wake up watchdog
        frame {}


    ### Informs registered listeners about a problem ###
    problem: (id) ->
        @_onproblem.invoke problems[id] or { message: id }

    ### Register handler called when there was a problem ###
    onproblem: (handler) -> @_onproblem.add handler

    ### Deinitializes this object, can be used again afterwards. ###
    deinit: () ->
        @_tracker.deinit()

        for id, module of extensions
            if module.deinit then module.deinit @, module

        @_initialized = false

    ### Returns a new handlers object that can be used internally ###
    handlers: () -> new handlers()

    ### Sets the desired frame rate ###
    fps: (fps) ->

    ### Pushes a frame to all registered listeners or retrieves the currently
    pushed frame. ###
    frame: (frame) ->
        if frame
            @_currentframe = frame

            # First let all extensions do their work
            for id in extensionorder
                module = extensions[id]
                if module.onframe
                    module.onframe frame, @, module

            # Then push frame over official channel
            @_onframe.invoke frame
        else @_currentframe

    ### Registers for a frame ###
    onframe: (handler) -> @_onframe.add handler

    ### Returns the version ###
    version: () -> VERSION

    ### Sets or returns an extension ###
    extension: (fns, module) ->
        if not fns and not module
            return extensions

        if typeof fns == "string"
            return extensions[fns]

        gaze.extension(fns, module)


    ### Removes this gaze object again from global, restores the previous
    one and return this. ###
    noconflict: (x) ->
        @global.gaze = _gaze
        return this

    ### Returns the distance of a point and a rect or two points ###
    distance: (px, py, x, y, w, h) ->
        # In case we only have 2 parameters, treat as two points a = [x, y], b = [x, y]
        
        if not x
            a = px; b = py;
            return Math.sqrt( (a[0]-b[0])**2 + (a[1]-b[1])**2 )

        # In case we only have 4 parameters, treat as two points in form x1 y1, x2, y2
        if not w 
            x1 = px; y1 = py; x2 = x; y2 = y
            return Math.sqrt( (x1-x2)**2 + (y1-y2)**2 )

        # TODO: Return actual distance if outside
        if px >= x && px <= x + w && py >= y && py <= y + h then return 0
        return 1
}



### WATCHDOG ###
gaze.extension({} , {
    id: "watchdog"
    framecount: 0
    watchdog: null

    init: (gaze, module) ->
        time = Date.now()
        lastcount = 0
        lastwarn = 0

        check = () ->
            if module.framecount == lastcount and module.framecount != lastwarn
                gaze.problem("W_DATASTALL")
                lastwarn = module.framecount

            lastcount = module.framecount

        gaze.onframe () ->
            # If this was the first frame, set up watchdog
            if not module.framecount++
                module.watchdog = setInterval check, 1500

    deinit: (gaze, module) -> clearInterval module.watchdog
})



### BROWSER ###
gaze.extension({
    ### Returns the browser ID ###
    browser: () ->
        if !!global.opera || navigator.userAgent.indexOf(' OPR/') >= 0 then return "opera"
        if typeof InstallTrigger != 'undefined' then return "firefox"
        if Object.prototype.toString.call(global.HTMLElement).indexOf('Constructor') > 0 then return "safari"
        if !!global.chrome then return "chrome"
        if false || !!global.document.documentMode then return "ie"
        return "unknown"


    ### Returns the logical pixel ratio to the OS pixel ratio, i.e., how large the
    browser zoom level is. ###
    browserpixelratio: () ->
        if global.devicePixelRatio then return global.devicePixelRatio
        else if global.screen.deviceXDPI then return global.screen.deviceXDPI / global.screen.logicalXDPI

        @problem("W_ZOOMRATIO")
        return 1


    ### Converts a screen pixel position to a window position ###
    screen2window: (x, y) -> return [x, y] # Is overriden in module.init()!

    ### Notify user with a bubble ###
    notifiybubble: (string) ->
        document = global.document

        note = document.createElement "div"
        note.style.position = "fixed"
        note.style.top = "10px"
        note.style.right = "50px"
        note.style.padding = "50px"
        note.style.background = "red"
        note.style.opacity = "0"        
        note.style.transition = 'opacity 0.2s'
        note.style.borderRadius = '3px'
        
        note.innerHTML = """<div>""" + string + """</div>"""
        document.body.appendChild note

        setTimeout(
            () -> 
                note.style.opacity = "1"
            ,1)


}, {
    id: "browser"

    problems: {
        "W_ZOOMRATIO": {
            message: "Unable to determine browser zoom ratio. Your results may be wrong. Try
            zooming to 100% and hope for the best (and use another browser)."
            type: "warning"
        }
    }

    browser: "unknown"
    desktopzoom: 1.0
    windowoffsetx: 0
    windowoffsety: 0

    ### Click handler to translate coordinates ###
    click: (evt) ->
      p = @_gaze.browserpixelratio()
      z = @desktopzoom

      dx = 0
      dy = 0

      if @browser == "ie"
        dx = - ((evt.screenX) - (global.screenX * p) - (evt.clientX * p))
        dy = - ((evt.screenY) - (global.screenY * p) - (evt.clientY * p))

      if @browser == "chrome"
        dx = - ((evt.screenX) - (global.screenX) - (evt.clientX * p))
        dy = - ((evt.screenY) - (global.screenY) - (evt.clientY * p))

      if @browser == "safari"
        dx = - ((evt.screenX) - (global.screenX) - (evt.clientX * p))
        dy = - ((evt.screenY) - (global.screenY) - (evt.clientY * p))

      if @browser == "firefox"
        dx = - ((evt.screenX * z) - (global.screenX * p) - (evt.clientX * p))
        dy = - ((evt.screenY * z) - (global.screenY * p) - (evt.clientY * p))


      # DX now has the offsets in of the client area start relative to the
      # reported window.screenX and window.screenY positions in physical screen pixels

      @windowoffsetx = dx
      @windowoffsety = dy

      localStorage.setItem("_gaze_windowoffsetx", dx)
      localStorage.setItem("_gaze_windowoffsety", dy)


    deinit: (gaze, module) -> global.document.removeEventListener @click

    onframe: (frame, gaze, module) ->
        if not frame.screen then return
        if not frame.screen.scaletologic then return

        module.desktopzoom = 1.0 / frame.screen.scaletologic

        # Not sure if we should save that often ...
        localStorage.setItem("_gaze_desktopzoom", module.desktopzoom)


    init: (gaze, module) ->
        module._gaze = gaze

        document = global.document

        # Compute some values and get others from localstorage
        module.browser = gaze.browser()
        module.desktopzoom = parseFloat(localStorage.getItem("_gaze_desktopzoom")) or 1.0
        module.windowoffsetx = parseInt(localStorage.getItem("_gaze_windowoffsetx")) or 0
        module.windowoffsety = parseInt(localStorage.getItem("_gaze_windowoffsety")) or 0

        global.document.addEventListener 'click', @click.bind(@)

        # Sets the appropriate screen2window function based on browser
        if module.browser == "chrome"
            gaze.screen2window = (x, y) ->
                p = gaze.browserpixelratio()
                wx = (x - global.screenX + module.windowoffsetx) / p
                wy = (y - global.screenY + module.windowoffsety) / p
                return [wx, wy]

        if module.browser == "ie"
            gaze.screen2window = (x, y) ->
                p = gaze.browserpixelratio()
                wx = (x - global.screenX * p + module.windowoffsetx) / p
                wy = (y - global.screenY * p + module.windowoffsety) / p
                return [wx, wy]

        if module.browser == "safari" #TODO: safari currently wrong, measure again
            gaze.screen2window = (x, y) ->
                p = gaze.browserpixelratio()
                wx = (x - global.screenX + module.windowoffsetx) / p
                wy = (y - global.screenY + module.windowoffsety) / p
                return [wx, wy]

        if module.browser == "firefox"
            gaze.screen2window = (x, y) ->
                p = gaze.browserpixelratio()
                wx = (x - global.screenX * p + module.windowoffsetx) / p
                wy = (y - global.screenY * p + module.windowoffsety) / p
                return [wx, wy]
})



### RAW ###
gaze.extension({
    ### Adds a raw listener and returns a removal handle ###
    onraw: (listener) ->
        ext = @extension("raw")
        ext._handlers.add listener
}, {
    id: "raw"

    ### Initialize this module ###
    init: (gaze, module) ->
        module._handlers = gaze.handlers()
        removal = null

        func = (packet) ->
            # In case we don't have the focus, we don't do anything
            if not global.document.hasFocus() then return
            module._handlers.invoke packet.raw

        # Called when the first handler was added or removed
        module._handlers.onpopulated = () -> removal = gaze.onframe func
        module._handlers.onempty = () -> removal.remove()
})



### FILTERED ###
gaze.extension({
    ### Adds a filtered listener and returns a removal handle ###
    onfiltered: (listener) ->
        ext = @extension("filtered")
        ext._handlers.add listener

    filter: (filter) ->
        ext = @extension("filtered")
}, {
    id: "filtered"
    depends: ["raw", "browser"]

    ### Called when a new frame arrives ###
    onframe: (frame, gaze, module) ->
        # Nothing to filter, no raw = nothing to do
        if not frame.filtered and not frame.raw then return

        # Filter data here ...
        if not frame.filtered and frame.raw
            throw "Not implemented"
            frame.filtered = {}

        # And eventually convert to local coordinate system
        f = frame.filtered

        # See if we don't have already window coordintes
        if not f.windowX or not f.windowY
            p = gaze.screen2window(f.screenX, f.screenY)

            # Compute derived element for filtered data
            f.windowX = p[0]
            f.windowY = p[1]

        if not f.inwindow
            f.inwindow = gaze.distance(f.screenX, f.screenX, global.screenX, global.screenY, global.outerWidth, global.outerHeight) == 0

        f.documentX = f.windowX + global.pageXOffset
        f.documentY = f.windowY + global.pageYOffset


    ### Initialize this module ###
    init: (gaze, module) ->
        module._handlers = gaze.handlers()
        removal = null

        func = (packet) ->
            # In case we don't have the focus, we don't do anything
            if not global.document.hasFocus() then return
            module._handlers.invoke packet.filtered

        # Called when the first handler was added or removed
        module._handlers.onpopulated = () -> removal = gaze.onframe func
        module._handlers.onempty = () -> removal.remove()
})






### FIXATION ###
gaze.extension({
    ### Adds a filtered listener and returns a removal handle ###
    onfixation: (listener) ->
        ext = @extension("fixation")
        ext._handlers.add listener

}, {
    id: "fixation"
    depends: ["filtered"]

    radiusthreshold: 50
    currentfixation: null
    outliers: []

    ### Creates a new fixation structure ###
    fixationstruct: (point) ->
        {
                center: point
                points: [point]
        }

    ### Called to update the current fixation ###
    updatefixation: (gaze, point, newfixation, continuedfixation) -> 
        if not point then return

        # If we are not in a fixation, go ahead and create object        
        if not this.currentfixation
            this.currentfixation = this.fixationstruct(point)

        currentfixation = this.currentfixation            

        # Check how far away we are 
        distance = gaze.distance(currentfixation.center, point)

        # If we have an outlier ...        
        if distance > this.radiusthreshold
            this.outliers.push point

            # Very crude fixation start detection ...
            if this.outliers.length > 3
                this.outliers = []
                this.currentfixation = this.fixationstruct(point)

                # And call our handler
                newfixation this.currentfixation

        else
            currentfixation.points.push point

        # And call our handler
        continuedfixation this.currentfixation



    ### Called when a new frame arrives ###
    onframe: (frame, gaze, module) ->
        # Nothing to filter, no raw = nothing to do
        if not frame.filtered and not frame.raw then return

        # Filter data here ...
        if not frame.filtered and frame.raw
            throw "Not implemented"
            frame.filtered = {}

        # And eventually convert to local coordinate system
        f = frame.filtered

        newfixation = (fixation) ->            
            module._handlers.invoke fixation
            frame.fixation = fixation

        continuedfixation = (fixation) ->
            frame.fixation = fixation

        module.updatefixation gaze, [f.screenX, f.screenY], newfixation, continuedfixation

        
        
    ### Initialize this module ###
    init: (gaze, module) -> module._handlers = gaze.handlers()
})




### GAZE OVER / OUT ###
gaze.extension({
    ongazeover: (elements, listener, options) ->
        ext = @extension("gazeover")

        if typeof elements == "string"
            elements = @_document.querySelectorAll elements
        
        if not elements.length # Our test to see if it is an array
            elements = [elements]
    
        ext._handlers.add [elements, listener, options]
}, {
    id: "gazeover"
    depends: ["filtered"]

    init: (gaze, module) ->
        module._handlers = gaze.handlers()
        document = gaze.global.document
        removal = null

        func = (p) ->
            # In case we don't have the focus, we don't do anything
            if not global.document.hasFocus() then return

            # Every thing that was registered with on... will be treated individually
            module._handlers.each (f) ->
                elements = f[0]
                callback = f[1]

                for e in elements
                    # Ignore elements removed from tree 
                    if not document.body.contains(e) then continue

                    r = e.getBoundingClientRect()
                    dist = gaze.distance p.windowX, p.windowY, r.left, r.top, r.width, r.height

                    # Check if we hit the element
                    if dist == 0 and not e._gazeover
                        callback {type:"over", element: e}
                        e._gazeover = true

                    if dist > 0 and e._gazeover
                        callback {type:"out", element: e}
                        e._gazeover = false


        # Called when the first handler was added or removed
        module._handlers.onpopulated = () -> removal = gaze.onfiltered func
        module._handlers.onempty = () -> removal.remove()
})




### DWELL ###
gaze.extension({
    ondwell: (elements, listener, options) ->
        ext = @extension("dwell")

        if typeof elements == "string"
            elements = @_document.querySelectorAll elements
        
        if not elements.length # Our test to see if it is an array
            elements = [elements]


        _options = {
            dwellthreshold: options
            dwelldecay: 100
        }
    
        ext._handlers.add [elements, listener, _options]
}, {
    id: "dwell"
    depends: ["filtered"]

    init: (gaze, module) ->
        module._handlers = gaze.handlers()
        document = gaze.global.document
        removal = null

        func = (p) ->
            # In case we don't have the focus, we don't do anything
            if not global.document.hasFocus() then return

            # Every thing that was registered with on... will be treated individually
            module._handlers.each (f) ->
                elements = f[0]
                callback = f[1]
                options = f[2]

                for e in elements
                    # Ignore elements removed from tree 
                    if not document.body.contains(e) then continue

                    # Initialize values not present
                    e._dwellaccumulatedtime = e._dwellaccumulatedtime || 0
                    e._dwelllasttime = e._dwelllasttime || Date.now()

                    threshold = options.dwellthreshold

                    r = e.getBoundingClientRect();
                    dist = gaze.distance p.windowX, p.windowY, r.left, r.top, r.width, r.height
                    lasttime = e._dwelllasttime
                    currenttime = Date.now()

                    dt = currenttime - lasttime

                    # Check if we hit the element
                    if dist == 0
                        e._dwellaccumulatedtime += dt
                        if e._dwellaccumulatedtime > threshold
                            callback {type:"activate", element: e}
                            e._dwellaccumulatedtime = 0

                    else
                        e._dwellaccumulatedtime -= options.dwelldecay
                        e._dwellaccumulatedtime = 0 if e._dwellaccumulatedtime < 0

                    e._dwelllasttime = currenttime

        # Called when the first handler was added or removed
        module._handlers.onpopulated = () -> removal = gaze.onfiltered func
        module._handlers.onempty = () -> removal.remove()
})




### Connectors we use as backends ###
gaze.connectors = {
    "relay": (url, status, frame) ->
        url = "ws://127.0.0.1:44042" if not url?

        socket = new WebSocket(url)
        socket.onerror = status
        socket.onopen = status
        socket.onclose = status
        socket.onmessage = (evt) -> frame JSON.parse(evt.data)

        return {
            tracker: null
            type: "relay"
            frameinfo: {
                filtered: {

                }
            }
            deinit: () -> socket.close()
        }

    "mouse": (url, status, frame) ->
        last = null; timer = null
        number = 0

        motion = (e) -> last = e
        tick = () ->

            if last
                x = last.clientX
                y = last.clientY

            wx = x + (Math.random() - 0.5) * 20
            wy = y + (Math.random() - 0.5) * 20

            frame {
                filtered: {
                    windowX: wx
                    windowY: wy
                    screenX: wx + global.screenX
                    screenY: wy + global.screenX                    
                    inwindow: true
                }
            }

        document.addEventListener('mousemove', motion, false);
        timer = setInterval tick, 30

        return {
            tracker: null
            type: "mouse"
            frameinfo: {
                filtered: {

                }
            }
            deinit: () -> clearInterval timer            
        }
}


### Set global object ###
global.gaze = new gaze(global)
global.gaze.connectors = gaze.connectors





