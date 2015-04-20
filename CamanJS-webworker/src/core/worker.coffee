# Look what you make me do Javascript
slice = Array::slice

# DOM simplifier (no jQuery dependency)
# NodeJS compatible
$ = (sel, root = document) ->
  return sel if typeof sel is "object" or exports?
  root.querySelector sel

class Util
  # Unique value utility
  @uniqid = do ->
    id = 0
    get: -> id++

  # Helper function that extends one object with all the properies of other objects
  @extend = (obj, src...) ->
    dest = obj

    for copy in src
      for own prop of copy
        dest[prop] = copy[prop]

    return dest

  # In order to stay true to the latest spec, RGB values must be clamped between
  # 0 and 255. If we don't do this, weird things happen.
  @clampRGB = (val) ->
    return 0 if val < 0
    return 255 if val > 255
    return val

  @copyAttributes: (from, to, opts={}) ->
    for attr in from.attributes
      continue if opts.except? and attr.nodeName in opts.except
      to.setAttribute(attr.nodeName, attr.nodeValue)

  # Support for browsers that don't know Uint8Array (such as IE9)
  @dataArray: (length = 0) ->
    return new Uint8Array(length) if Caman.NodeJS or window.Uint8Array?
    return new Array(length)

# Represents a single Pixel in an image.
class Pixel
  @coordinatesToLocation: (x, y, width) ->
    (y * width + x) * 4

  @locationToCoordinates: (loc, width) ->
    y = Math.floor(loc / (width * 4))
    x = (loc % (width * 4)) / 4

    return x: x, y: y

  constructor: (@r = 0, @g = 0, @b = 0, @a = 255, @c = null) ->
    @loc = 0

  setContext: (c) -> @c = c

  # Retrieves the X, Y location of the current pixel. The origin is at the bottom left corner of 
  # the image, like a normal coordinate system.
  locationXY: ->
    throw "Requires a CamanJS context" unless @c?

    y = @c.dimensions.height - Math.floor(@loc / (@c.dimensions.width * 4))
    x = (@loc % (@c.dimensions.width * 4)) / 4

    return x: x, y: y

  pixelAtLocation: (loc) ->
    throw "Requires a CamanJS context" unless @c?

    new Pixel(
      @c.pixelData[loc], 
      @c.pixelData[loc + 1], 
      @c.pixelData[loc + 2], 
      @c.pixelData[loc + 3],
      @c
    )

  # Returns an RGBA object for a pixel whose location is specified in relation to the current 
  # pixel.
  getPixelRelative: (horiz, vert) ->
    throw "Requires a CamanJS context" unless @c?

    # We invert the vert_offset in order to make the coordinate system non-inverted. In laymans
    # terms: -1 means down and +1 means up.
    newLoc = @loc + (@c.dimensions.width * 4 * (vert * -1)) + (4 * horiz)

    if newLoc > @c.pixelData.length or newLoc < 0
      return new Pixel(0, 0, 0, 255, @c)

    return @pixelAtLocation(newLoc)

  # The counterpart to getPixelRelative, this updates the value of a pixel whose location is 
  # specified in relation to the current pixel.
  putPixelRelative: (horiz, vert, rgba) ->
    throw "Requires a CamanJS context" unless @c?

    nowLoc = @loc + (@c.dimensions.width * 4 * (vert * -1)) + (4 * horiz)

    return if newLoc > @c.pixelData.length or newLoc < 0

    @c.pixelData[newLoc] = rgba.r
    @c.pixelData[newLoc + 1] = rgba.g
    @c.pixelData[newLoc + 2] = rgba.b
    @c.pixelData[newLoc + 3] = rgba.a

    return true

  # Gets an RGBA object for an arbitrary pixel in the canvas specified by absolute X, Y coordinates
  getPixel: (x, y) ->
    throw "Requires a CamanJS context" unless @c?

    loc = @coordinatesToLocation(x, y, @width)
    return @pixelAtLocation(loc)

  # Updates the pixel at the given X, Y coordinate
  putPixel: (x, y, rgba) ->
    throw "Requires a CamanJS context" unless @c?

    loc = @coordinatesToLocation(x, y, @width)

    @c.pixelData[loc] = rgba.r
    @c.pixelData[loc + 1] = rgba.g
    @c.pixelData[loc + 2] = rgba.b
    @c.pixelData[loc + 3] = rgba.a

  toString: -> @toKey()
  toHex: (includeAlpha = false) ->
    hex = '#' + 
      @r.toString(16) +
      @g.toString(16) +
      @b.toString(16)

    if includeAlpha then hex + @a.toString(16) else hex

## Start of Leo's stuff

# Simple console logger class that covers for Caman.Logger not being present in worker
class Logger
  constructor: ->
    for name in ['log', 'info', 'warn', 'error']
      @[name] = do (name) ->
        (args...) ->
          try
            console[name].apply console, 'Web worker', args
          catch e
            # We're probably using IE9 or earlier
            console[name] 'Web worker', args

    @debug = @log

Log = new Logger()

 
parse = (str) ->

    return JSON.parse(str, (key, value) -> 
      prefix = value.substring(0, 8);

      return eval('(' + value + ')') if prefix is 'function'

      return value;
    )
self.imageData = 0
self.processFn = undefined

### TODO
- edit filters to manipulate arraybuffers instead of contexts
- edit filters to not access function context (this.*)
- return altered array buffer

###

# Renders the whole canvas with the current filter function
# Will be run in worker, so using worker's local variables
self.renderFilter = =>
    pixel = new Pixel()
    pixel.setContext @c
    Log.debug @
    for i in [0...self.imageData.length] by 4
      pixel.loc = i

      pixel.r = self.imageData[i]
      pixel.g = self.imageData[i+1]
      pixel.b = self.imageData[i+2]
      pixel.a = self.imageData[i+3]

      Log.debug self.processFn
      self.processFn pixel

      self.imageData[i]   = Util.clampRGB pixel.r
      self.imageData[i+1] = Util.clampRGB pixel.g
      self.imageData[i+2] = Util.clampRGB pixel.b
      self.imageData[i+3] = Util.clampRGB pixel.a

self.addEventListener('message', (e) ->
    if e.data.cmd?
        Log.debug 'receiving command: ' + e.data.cmd
        switch e.data.cmd
            when "renderFilter"
                if self.imageData.byteLength
                    self.processFn = parse(e.data.filter)
                    Log.debug self.processFn
                    self.renderFilter()  
                    self.postMessage('cmd': 'filterDone')
                else
                    Log.debug 'Cannot render filter with no image data.'
            when "sendResults"
                self.postMessage(self.imageData.buffer, [self.imageData.buffer])
            else
                Log.debug 'unknown command'
    else if typeof e.data is 'string'
        self.processFn = parse e.data
        Log.debug 'Filter sent to web worker'
    else
        self.imageData = new Uint8Array(e.data)
        Log.debug 'image data sent, length ' + self.imageData.length
        if self.imageData.length is 0
            Log.debug '0 length image'
            Log.debug e.data
    )