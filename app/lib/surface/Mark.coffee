CocoClass = require 'lib/CocoClass'
Camera = require './Camera'
ThangType = require 'models/ThangType'
markThangTypes = {}

module.exports = class Mark extends CocoClass
  subscriptions: {}
  alpha: 1

  constructor: (options) ->
    super()
    options ?= {}
    @name = options.name
    @sprite = options.sprite
    @camera = options.camera
    @layer = options.layer
    @thangType = options.thangType
    @listenTo @layer, 'new-spritesheet', @onLayerMadeSpriteSheet
    console.error @toString(), 'needs a name.' unless @name
    console.error @toString(), 'needs a camera.' unless @camera
    console.error @toString(), 'needs a layer.' unless @layer
    @build()

  destroy: ->
    createjs.Tween.removeTweens @mark if @mark
    @mark?.parent?.removeChild @mark
    @markSprite?.destroy()
    @sprite = null
    super()

  toString: -> "<Mark #{@name}: Sprite #{@sprite?.thang?.id ? 'None'}>"

  onLayerMadeSpriteSheet: ->
    return unless @mark
    return @update() if @markSprite
    # need to update the mark display object manually...
    @mark = null
    @build()
    @layer.addChild @mark
    @layer.updateLayerOrder()
    
  toggle: (to) ->
    return @ if to is @on
    return @toggleTo = to unless @mark
    @on = to
    delete @toggleTo
    if @on
      if @markSprite
        @layer.addCocoSprite(@markSprite)
      else
        @layer.addChild @mark
        @layer.updateLayerOrder()
    else
      if @markSprite
        @layer.removeCocoSprite(@markSprite)
      else
        @layer.removeChild @mark
      if @highlightTween
        @highlightDelay = @highlightTween = null
        createjs.Tween.removeTweens @mark
        @mark.visible = true
    @

  setLayer: (layer) ->
    return if layer is @layer
    wasOn = @on
    @toggle false
    @layer = layer
    @toggle true if wasOn

  setSprite: (sprite) ->
    return if sprite is @sprite
    @sprite = sprite
    @build()
    @

  build: ->
    unless @mark
      if @name is 'bounds' then @buildBounds()
      else if @name is 'shadow' then @buildShadow()
      else if @name is 'debug' then @buildDebug()
      else if @name.match(/.+(Range|Distance|Radius)$/) then @buildRadius(@name)
      else if @thangType then @buildSprite()
      else console.error 'Don\'t know how to build mark for', @name
      @mark?.mouseEnabled = false
    @

  buildBounds: ->
    @mark = new createjs.Container()
    @mark.mouseChildren = false
    style = @sprite.thang.drawsBoundsStyle
    @drawsBoundsIndex = @sprite.thang.drawsBoundsIndex
    return if style is 'corner-text' and @sprite.thang.world.age is 0

    # Confusingly make some semi-random colors that'll be consistent based on the drawsBoundsIndex
    colors = (128 + Math.floor(('0.'+Math.sin(3 * @drawsBoundsIndex + i).toString().substr(6)) * 128) for i in [1 ... 4])
    color = "rgba(#{colors[0]}, #{colors[1]}, #{colors[2]}, 0.5)"
    [w, h] = [@sprite.thang.width * Camera.PPM, @sprite.thang.height * Camera.PPM * @camera.y2x]

    if style in ['border-text', 'corner-text']
      @drawsBoundsBorderShape = shape = new createjs.Shape()
      shape.graphics.setStrokeStyle 5
      shape.graphics.beginStroke color
      if style is 'border-text'
        shape.graphics.beginFill color.replace('0.5', '0.25')
      else
        shape.graphics.beginFill color
      if @sprite.thang.shape in ['ellipsoid', 'disc']
        shape.drawEllipse 0, 0, w, h
      else
        shape.graphics.drawRect -w / 2, -h / 2, w, h
      shape.graphics.endStroke()
      shape.graphics.endFill()
      @mark.addChild shape

    if style is 'border-text'
      text = new createjs.Text '' + @drawsBoundsIndex, '20px Arial', color.replace('0.5', '1')
      text.regX = text.getMeasuredWidth() / 2
      text.regY = text.getMeasuredHeight() / 2
      text.shadow = new createjs.Shadow('#000000', 1, 1, 0)
      @mark.addChild text
    else if style is 'corner-text'
      return if @sprite.thang.world.age is 0
      letter = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[@drawsBoundsIndex % 26]
      text = new createjs.Text letter, '14px Arial', '#333333'   # color.replace('0.5', '1')
      text.x = -w / 2 + 2
      text.y = -h / 2 + 2
      @mark.addChild text
    else
      console.warn @sprite.thang.id, 'didn\'t know how to draw bounds style:', style

    if w > 0 and h > 0 and style is 'border-text'
      @mark.cache -w / 2, -h / 2, w, h, 2
    @lastWidth = @sprite.thang.width
    @lastHeight = @sprite.thang.height

  buildShadow: ->
    shapeName = if @sprite.thang.shape in ['ellipsoid', 'disc'] then 'ellipse' else 'rect'
    key = "#{shapeName}-shadow"
    SHADOW_SIZE = 10
    unless key in @layer.spriteSheet.getAnimations()
      shape = new createjs.Shape()
      shape.graphics.beginFill "rgba(0,0,0)"
      bounds = [-SHADOW_SIZE/2, - SHADOW_SIZE/2, SHADOW_SIZE, SHADOW_SIZE]
      if shapeName is 'ellipse'
        shape.graphics.drawEllipse bounds...
      else
        shape.graphics.drawRect bounds...
      shape.graphics.endFill()
      @layer.addCustomGraphic(key, shape, bounds)
    alpha = @sprite.thang?.alpha ? 1 
    width = (@sprite.thang?.width ? 0) + 0.5
    height = (@sprite.thang?.height ? 0) + 0.5
    longest = Math.max width, height
    actualLongest = @sprite.thangType.get('shadow') ? longest
    width = width * actualLongest / longest
    height = height * actualLongest / longest
    width *= Camera.PPM
    height *= Camera.PPM * @camera.y2x  # TODO: doesn't work with rotation
    @mark = new createjs.Sprite(@layer.spriteSheet)
    @mark.gotoAndStop(key)
    @mark.mouseEnabled = false
    @mark.alpha = alpha
    @baseScaleX = @mark.scaleX = width / (@layer.resolutionFactor * SHADOW_SIZE)
    @baseScaleY = @mark.scaleY = height / (@layer.resolutionFactor * SHADOW_SIZE)

  buildRadius: (range) ->
    alpha = 0.15
    colors =
      voiceRange: "rgba(0,145,0,#{alpha})"
      visualRange: "rgba(0,0,145,#{alpha})"
      attackRange: "rgba(145,0,0,#{alpha})"

    # Fallback colors which work on both dungeon and grass tiles
    extraColors = [
      "rgba(145,0,145,#{alpha})"
      "rgba(0,145,145,#{alpha})"
      "rgba(145,105,0,#{alpha})"
      "rgba(225,125,0,#{alpha})"
    ]

    # Find the index of this range, to find the next-smallest radius
    rangeNames = @sprite.ranges.map((range, index) ->
      range['name']
    )
    i = rangeNames.indexOf(range)

    @mark = new createjs.Shape()

    fillColor = colors[range] ? extraColors[i]
    @mark.graphics.beginFill fillColor

    # Draw the outer circle
    @mark.graphics.drawCircle 0, 0, @sprite.thang[range] * Camera.PPM

    # Cut out the hollow part if necessary
    if i+1 < @sprite.ranges.length
      @mark.graphics.arc 0, 0, @sprite.ranges[i+1]['radius'], Math.PI*2, 0, true

    @mark.graphics.endFill()

    strokeColor = fillColor.replace '' + alpha, '0.75'
    @mark.graphics.setStrokeStyle 2
    @mark.graphics.beginStroke strokeColor
    @mark.graphics.arc 0, 0, @sprite.thang[range] * Camera.PPM, Math.PI*2, 0, true
    @mark.graphics.endStroke()

    # Add perspective
    @mark.scaleY *= @camera.y2x

  buildDebug: ->
    @mark = new createjs.Shape()
    PX = 3
    [w, h] = [Math.max(PX, @sprite.thang.width * Camera.PPM), Math.max(PX, @sprite.thang.height * Camera.PPM) * @camera.y2x]  # TODO: doesn't work with rotation
    @mark.alpha = 0.5
    @mark.graphics.beginFill '#abcdef'
    if @sprite.thang.shape in ['ellipsoid', 'disc']
      @mark.graphics.drawEllipse -w / 2, -h / 2, w, h
    else
      @mark.graphics.drawRect -w / 2, -h / 2, w, h
    @mark.graphics.endFill()

  buildSprite: ->
    if _.isString @thangType
      thangType = markThangTypes[@thangType]
      return @loadThangType() if not thangType
      @thangType = thangType

    return @listenToOnce(@thangType, 'sync', @onLoadedThangType) if not @thangType.loaded
    CocoSprite = require './CocoSprite'
    # don't bother with making these render async for now, but maybe later for fun and more complexity of code
    markSprite = new CocoSprite @thangType
    markSprite.queueAction 'idle'
    @mark = markSprite.imageObject
    @markSprite = markSprite
    @listenTo @markSprite, 'new-image-object', (@mark) ->

  loadThangType: ->
    name = @thangType
    @thangType = new ThangType()
    @thangType.url = -> "/db/thang.type/#{name}"
    @listenToOnce(@thangType, 'sync', @onLoadedThangType)
    @thangType.fetch()
    markThangTypes[name] = @thangType

  onLoadedThangType: ->
    @build()
    @toggle(@toggleTo) if @toggleTo?
    Backbone.Mediator.publish 'sprite:loaded', {sprite: @}

  update: (pos=null) ->
    return false unless @on and @mark
    return false if @sprite? and not @sprite.thangType.isFullyLoaded()
    @mark.visible = not @hidden
    @updatePosition pos
    @updateRotation()
    @updateScale()
    if @name is 'highlight' and @highlightDelay and not @highlightTween
      @mark.visible = false
      @highlightTween = createjs.Tween.get(@mark).to({}, @highlightDelay).call =>
        @mark.visible = true
        @highlightDelay = @highlightTween = null
    @updateAlpha @alpha if @name in ['shadow', 'bounds']
    true

  updatePosition: (pos) ->
    if @sprite?.thang and @name in ['shadow', 'debug', 'target', 'selection', 'repair']
      pos = @camera.worldToSurface x: @sprite.thang.pos.x, y: @sprite.thang.pos.y
    else
      pos ?= @sprite?.imageObject
    @mark.x = pos.x
    @mark.y = pos.y
    if @statusEffect or @name is 'highlight'
      offset = @sprite.getOffset 'aboveHead'
      @mark.x += offset.x
      @mark.y += offset.y
      @mark.y -= 3 if @statusEffect

  updateAlpha: (@alpha) ->
    return if not @mark or @name is 'debug'
    if @name is 'shadow'
      worldZ = @sprite.thang.pos.z - @sprite.thang.depth / 2 + @sprite.getBobOffset()
      @mark.alpha = @alpha * 0.451 / Math.sqrt(worldZ / 2 + 1)
    else if @name is 'bounds'
      @drawsBoundsBorderShape?.alpha = Math.floor @sprite.thang.alpha  # Stop drawing bounds as soon as alpha is reduced at all
    else
      @mark.alpha = @alpha

  updateRotation: ->
    if @name is 'debug' or (@name is 'shadow' and @sprite.thang?.shape in ['rectangle', 'box'])
      @mark.rotation = -@sprite.thang.rotation * 180 / Math.PI

  updateScale: ->
    if @name is 'bounds' and ((@sprite.thang.width isnt @lastWidth or @sprite.thang.height isnt @lastHeight) or (@sprite.thang.drawsBoundsIndex isnt @drawsBoundsIndex))
      oldMark = @mark
      @buildBounds()
      oldMark.parent.addChild @mark
      oldMark.parent.swapChildren oldMark, @mark
      oldMark.parent.removeChild oldMark

    if @markSprite?
      @markSprite.scaleFactor = 1.2
      @markSprite.updateScale()

    if @name is 'shadow' and thang = @sprite.thang
      @mark.scaleX = @baseScaleX * (thang.scaleFactor ? thang.scaleFactorX ? 1)
      @mark.scaleY = @baseScaleY * (thang.scaleFactor ? thang.scaleFactorY ? 1)

    return unless @name in ['selection', 'target', 'repair', 'highlight']

    # scale these marks to 10m (100px). Adjust based on sprite size.
    factor = 0.3 # default size: 3m width, most commonly for target when pointing to a location

    if @sprite?.imageObject
      width = @sprite.imageObject.getBounds()?.width or 0
      width /= @sprite.options.resolutionFactor
      # all targets should be set to have a width of 100px, and then be scaled accordingly
      factor = width / 100 # normalize
      factor *= 1.1 # add margin
      factor = Math.max(factor, 0.3) # lower bound
    @mark.scaleX *= factor
    @mark.scaleY *= factor

    if @name in ['selection', 'target', 'repair']
      @mark.scaleY *= @camera.y2x  # code applies perspective

  stop: -> @markSprite?.stop()
  play: -> @markSprite?.play()
  hide: -> @hidden = true
  show: -> @hidden = false
