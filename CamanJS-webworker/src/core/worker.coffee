# Various math-heavy helpers that are used throughout CamanJS.
class Calculate
  # Calculates the distance between two points.

  # @param [Number] x1 1st point x-coordinate.
  # @param [Number] y1 1st point y-coordinate.
  # @param [Number] x2 2nd point x-coordinate.
  # @param [Number] y2 2nd point y-coordinate.
  # @return [Number] The distance between the two points.
  @distance: (x1, y1, x2, y2) ->
    Math.sqrt Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2)

  # Generates a pseudorandom number that lies within the max - mix range. The number can be either 
  # an integer or a float depending on what the user specifies.

  # @param [Number] min The lower bound (inclusive).
  # @param [Number] max The upper bound (inclusive).
  # @param [Boolean] getFloat Return a Float or a rounded Integer?
  # @return [Number] The pseudorandom number, either as a float or integer.
  @randomRange: (min, max, getFloat = false) ->
    rand = min + (Math.random() * (max - min))
    return if getFloat then rand.toFixed(getFloat) else Math.round(rand)

  # Calculates the luminance of a single pixel using a special weighted sum.
  # @param [Object] rgba RGBA object describing a single pixel.
  # @return [Number] The luminance value of the pixel.
  @luminance: (rgba) -> (0.299 * rgba.r) + (0.587 * rgba.g) + (0.114 * rgba.b)

  # Generates a bezier curve given a start and end point, with control points in between.
  # Can also optionally bound the y values between a low and high bound.
  #
  # This is different than most bezier curve functions because it attempts to construct it in such 
  # a way that we can use it more like a simple input -> output system, or a one-to-one function. 
  # In other words we can provide an input color value, and immediately receive an output modified 
  # color value.
  #
  # Note that, by design, this does not force X values to be in the range [0..255]. This is to
  # generalize the function a bit more. If you give it a starting X value that isn't 0, and/or a
  # ending X value that isn't 255, you may run into problems with your filter!
  #
  # @param [Array] 2-item arrays describing the x, y coordinates of the control points. Minimum two.
  # @param [Number] lowBound (optional) Minimum possible value for any y-value in the curve.
  # @param [Number] highBound (optional) Maximum posisble value for any y-value in the curve.
  # @return [Array] Array whose index represents every x-value between start and end, and value
  #   represents the corresponding y-value.
  @bezier: (start, ctrl1, ctrl2, end, lowBound = 0, highBound = 255) ->
    #(controlPoints, lowBound, highBound) ->
    # 4.0 shim - change declaration to (controlPoints, lowBound, highBound) at 5.0
    if start[0] instanceof Array
      controlPoints = start
      lowBound = ctrl1
      highBound = ctrl2
    else
      controlPoints = [start, ctrl1, ctrl2, end]

    if controlPoints.length < 2
      throw "Invalid number of arguments to bezier"

    bezier = {}
    lerp = (a, b, t) -> return a * (1 - t) + b * t
    clamp = (a, min, max) -> return Math.min(Math.max(a, min), max)

    for i in [0...1000]
      t = i / 1000
      prev = controlPoints

      while prev.length > 1
        next = []

        for j in [0..(prev.length - 2)]
          next.push([
            lerp(prev[j][0], prev[j + 1][0], t),
            lerp(prev[j][1], prev[j + 1][1], t)
          ])

        prev = next

      bezier[Math.round(prev[0][0])] = Math.round(clamp(prev[0][1], lowBound, highBound))

    endX = controlPoints[controlPoints.length - 1][0]
    bezier = Caman.Calculate.missingValues(bezier, endX)

    # Edge case
    bezier[endX] = bezier[endX - 1] if not bezier[endX]?

    return bezier

  # Generates a hermite curve given a start and end point, with control points in between.
  # Can also optionally bound the y values between a low and high bound.
  #
  # This is different than most hermite curve functions because it attempts to construct it in such 
  # a way that we can use it more like a simple input -> output system, or a one-to-one function. 
  # In other words we can provide an input color value, and immediately receive an output modified 
  # color value.
  #
  # Note that, by design, this does not force X values to be in the range [0..255]. This is to
  # generalize the function a bit more. If you give it a starting X value that isn't 0, and/or a
  # ending X value that isn't 255, you may run into problems with your filter!
  #
  # @param [Array] 2-item arrays describing the x, y coordinates of the control points. Minimum two.
  # @param [Number] lowBound (optional) Minimum possible value for any y-value in the curve.
  # @param [Number] highBound (optional) Maximum possible value for any y-value in the curve.
  # @return [Array] Array whose index represents every x-value between start and end, and value
  #   represents the corresponding y-value.
  @hermite: (controlPoints, lowBound, highBound) ->
    if controlPoints.length < 2
        throw "Invalid number of arguments to hermite"

    ret = {}

    lerp = (a, b, t) -> return a * (1 - t) + b * t
    add = (a, b, c, d) => [a[0] + b[0] + c[0] + d[0], a[1] + b[1] + c[1] + d[1]]
    mul = (a, b) => [a[0] * b[0], a[1] * b[1]]
    sub = (a, b) => [a[0] - b[0], a[1] - b[1]]
    clamp = (a, min, max) -> return Math.min(Math.max(a, min), max)

    count = 0
    for i in [0..controlPoints.length - 2]
      p0 = controlPoints[i]
      p1 = controlPoints[i + 1]

      pointsPerSegment = p1[0] - p0[0]
      pointsPerStep = 1 / pointsPerSegment

      # the last point of the last segment should reach p1
      if(i == controlPoints.length - 2)
        pointsPerStep = 1 / (pointsPerSegment - 1)

      p = if i > 0 then controlPoints[i - 1] else p0
      m0 = mul(sub(p1, p), [0.5, 0.5])

      p = if i < controlPoints.length - 2 then controlPoints[i + 2] else p1
      m1 = mul(sub(p, p0), [0.5, 0.5])

      for j in [0..pointsPerSegment]
        t = j * pointsPerStep

        fac0 = 2.0 * t * t * t - 3.0 * t * t + 1.0
        fac1 = t * t * t - 2.0 * t * t + t
        fac2 = -2.0 * t * t * t + 3.0 * t * t
        fac3 = t * t * t - t * t

        pos = add(mul(p0, [fac0, fac0]), mul(m0, [fac1, fac1]), mul(p1, [fac2, fac2]), mul(m1, [fac3, fac3]))

        ret[Math.round(pos[0])] = Math.round(clamp(pos[1], lowBound, highBound))

        count += 1

    # add missing values
    endX = controlPoints[controlPoints.length - 1][0]
    ret = Caman.Calculate.missingValues(ret, endX)

    return ret

  # Calculates possible missing values from a given value array. Note that this returns a copy
  # and does not mutate the original. In case no values are missing the original array is
  # returned as that is convenient.
  #
  # @param [Array] 2-item arrays describing the x, y coordinates of the control points.
  # @param [Number] end x value of the array (maximum)
  # @return [Array] Array whose index represents every x-value between start and end, and value
  #   represents the corresponding y-value.
  @missingValues: (values, endX) ->
    # Do a search for missing values in the bezier array and use linear
    # interpolation to approximate their values
    if Object.keys(values).length < endX + 1
      ret = {}

      for i in [0..endX]
        if values[i]?
          ret[i] = values[i]
        else
          leftCoord = [i - 1, ret[i - 1]]

          # Find the first value to the right. Ideally this loop will break
          # very quickly.
          for j in [i..endX]
            if values[j]?
              rightCoord = [j, values[j]]
              break

          ret[i] = leftCoord[1] +
            ((rightCoord[1] - leftCoord[1]) / (rightCoord[0] - leftCoord[0])) *
            (i - leftCoord[0])

      return ret

    return values



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

    y = @imageHeight - Math.floor(@loc / (@imageWidth * 4))
    x = (@loc % (@imageWidth * 4)) / 4

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
self.processname = undefined
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
    for i in [0...self.imageData.length] by 4
      pixel.loc = i

      pixel.r = self.imageData[i]
      pixel.g = self.imageData[i+1]
      pixel.b = self.imageData[i+2]
      pixel.a = self.imageData[i+3]

      self.processFn pixel

      self.imageData[i]   = Util.clampRGB pixel.r
      self.imageData[i+1] = Util.clampRGB pixel.g
      self.imageData[i+2] = Util.clampRGB pixel.b
      self.imageData[i+3] = Util.clampRGB pixel.a

self.addEventListener('message', (e) ->
    if e.data.cmd?
        #Log.debug "worker #{@id}: receiving command: #{e.data.cmd}"
        switch e.data.cmd
            when 'id'
                @id = e.data.id
            when "renderFilter"
                if self.imageData.byteLength
                    self.processFn = parse(e.data.filter)   
                    if e.data.parameters?
                        #Log.debug 'we have params'
                        params = JSON.parse(e.data.parameters)
                        for key of params
                            @[key] = params[key]
                    self.processname = e.data.name
                    #Log.debug "worker #{@id}: rendering: #{e.data.name}"
                    self.renderFilter()  
                    self.postMessage('cmd': 'filterDone', 'id':@id)
                else
                    #Log.debug 'Cannot render filter with no image data.'
            when "imageSize"
                @imageHeight = e.data.height
                @imageWidth = e.data.width
            when "sendResults"
                self.postMessage(self.imageData.buffer, [self.imageData.buffer])
            else
                Log.debug 'unknown command'
    else if typeof e.data is 'string'
        self.processFn = parse e.data
        #Log.debug 'Filter sent to web worker' + @id
    else
        self.imageData = new Uint8Array(e.data)
        #Log.debug 'image data sent, length ' + self.imageData.length
        if self.imageData.length is 0
            Log.debug '0 length image'
            Log.debug e.data
    )