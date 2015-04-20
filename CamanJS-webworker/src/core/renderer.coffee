# Handles all of the various rendering methods in Caman. Most of the image modification happens 
# here. A new Renderer object is created for every render operation.
class Caman.Renderer
  # Working on:
  # - remove all references to blocks
  # Todo:
  # - a lot :)

  constructor: (@c) ->
    @renderQueue = []
    @modPixelData = null

  add: (job) ->
    return unless job?
    @renderQueue.push job

  # Grabs the next operation from the render queue and passes it to Renderer
  # for execution
  processNext: =>
    # If the queue is empty, fire the finished callback
    if @renderQueue.length is 0
      Event.trigger @, "renderFinished"
      @finishedFn.call(@c) if @finishedFn?

      @worker.postMessage {'cmd': 'sendResults'}
      return @

    @currentJob = @renderQueue.shift()

    switch @currentJob.type
      when Filter.Type.LayerDequeue
        layer = @c.canvasQueue.shift()
        @c.executeLayer layer
        @processNext()
      when Filter.Type.LayerFinished
        @c.applyCurrentLayer()
        @c.popContext()
        @processNext()
      when Filter.Type.LoadOverlay
        @loadOverlay @currentJob.layer, @currentJob.src
      when Filter.Type.Plugin
        @executePlugin()
      else
        @executeFilter()

  execute: (callback) ->
    @finishedFn = callback
    @modPixelData = Util.dataArray(@c.pixelData.length)

    @worker = new Worker('../../dist/worker.js')
    @worker.addEventListener('message', (e) =>
      if e.data.cmd?
        switch e.data.cmd
          when "filterDone"
            @processNext()
          else
            Log.debug 'unknown command'
      else if typeof e.data is 'string'
        Log.debug e.data
      else
        Log.debug 'image data sent from worker'
        newdata = new Uint8Array(e.data)
        for i in [0...@c.pixelData.length]
          @c.imageData.data[i] = newdata[i]
        @c.context.putImageData(@c.imageData, 0, 0)
    )

    @worker.postMessage = @worker.webkitPostMessage or @worker.postMessage
    ab = @c.context.getImageData( 0, 0, @c.canvas.width, @c.canvas.height ).data.buffer
    @worker.postMessage(ab, [ab])
    @processNext()

  # The core of the image rendering, this function executes the provided filter.
  #
  # NOTE: this does not write the updated pixel data to the canvas. That happens when all filters 
  # are finished rendering in order to be as fast as possible.
  executeFilter: ->
    Event.trigger @c, "processStart", @currentJob

    #send current context/image data to worker as an arraybuffer, 
    #ie. transferable object that can be sent to worker without copying
    

    if @currentJob.type is Filter.Type.Single
      ### TODO
      - push returned data to context (@c)
      - maybe ask for data only after checking if next filter is kernel as well
      - maybe implement commands for workers
        - change filter
        - run filter
        - here's image data
        - getData
      ###
      Log.debug @currentJob.processFn
      @worker.postMessage {'cmd': 'renderFilter', 'filter': window.JSONfn.stringify @currentJob.processFn}
    else
      @worker.postMessage {'cmd': window.JSONfn.stringify @renderKernel}

  # Executes a standalone plugin
  executePlugin: ->
    Log.debug "Executing plugin #{@currentJob.plugin}"
    Plugin.execute @c, @currentJob.plugin, @currentJob.args
    Log.debug "Plugin #{@currentJob.plugin} finished!"

    @processNext()

  # Applies an image kernel to the canvas
  renderKernel: (start, end) ->
    name = @currentJob.name
    bias = @currentJob.bias
    divisor = @currentJob.divisor
    n = @c.pixelData.length

    adjust = @currentJob.adjust
    adjustSize = Math.sqrt adjust.length

    kernel = []

    Log.debug "Rendering kernel - Filter: #{@currentJob.name}"

    start = Math.max start, @c.dimensions.width * 4 * ((adjustSize - 1) / 2)
    end = Math.min end, n - (@c.dimensions.width * 4 * ((adjustSize - 1) / 2))

    builder = (adjustSize - 1) / 2

    pixel = new Pixel()
    pixel.setContext(@c)

    for i in [start...end] by 4
      pixel.loc = i
      builderIndex = 0

      for j in [-builder..builder]
        for k in [builder..-builder]
          p = pixel.getPixelRelative j, k
          kernel[builderIndex * 3]     = p.r
          kernel[builderIndex * 3 + 1] = p.g
          kernel[builderIndex * 3 + 2] = p.b

          builderIndex++

      res = @processKernel adjust, kernel, divisor, bias

      @modPixelData[i]    = Util.clampRGB(res.r)
      @modPixelData[i+1]  = Util.clampRGB(res.g)
      @modPixelData[i+2]  = Util.clampRGB(res.b)
      @modPixelData[i+3]  = @c.pixelData[i+3]

    for i in [0...@c.pixelData.length]
        @c.pixelData[i] = @modPixelData[i]

    Log.debug "Filter #{@currentJob.name} finished!"
    Event queue.trigger @c, "processComplete", @currentJob

    @processNext()


  # The "filter function" for kernel adjustments.
  processKernel: (adjust, kernel, divisor, bias) ->
    val = r: 0, g: 0, b: 0

    for i in [0...adjust.length]
      val.r += adjust[i] * kernel[i * 3]
      val.g += adjust[i] * kernel[i * 3 + 1]
      val.b += adjust[i] * kernel[i * 3 + 2]

    val.r = (val.r / divisor) + bias
    val.g = (val.g / divisor) + bias
    val.b = (val.b / divisor) + bias
    val

  # Loads an image onto the current canvas
  loadOverlay: (layer, src) ->
    img = new Image()
    img.onload = =>
      layer.context.drawImage img, 0, 0, @c.dimensions.width, @c.dimensions.height
      layer.imageData = layer.context.getImageData 0, 0, @c.dimensions.width, @c.dimensions.height
      layer.pixelData = layer.imageData.data

      @c.pixelData = layer.pixelData

      @processNext()

    proxyUrl = IO.remoteCheck src
    img.src = if proxyUrl? then proxyUrl else src

Renderer = Caman.Renderer