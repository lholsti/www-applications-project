parse = (str) ->

    return JSON.parse(str, (key, value) -> 
      prefix = value.substring(0, 8);

      return eval('(' + value + ')') if prefix is 'function'

      return value;
    )

### TODO
- add pixel.coffee functions here
- edit filters to manipulate arraybuffers instead of contexts
- edit filters to not access function context (this.*)
- return altered array buffer

###

self.addEventListener('message', (e) ->
	if typeof e.data is 'string'
		filter = parse e.data
	else
      console.log 'image data'
      #filter.call this, 1, 1, 200
    
	self.postMessage('worker done'))