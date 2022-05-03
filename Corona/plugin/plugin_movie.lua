local Library = require('CoronaLibrary')

local function copy(table)
  local dst = {}
  for k, v in pairs(table) do
    if type(v) == 'table' then
      dst[k] = copy(v)
    else
      dst[k] = v
    end
  end
  return dst
end

-- Create stub library
local lib = Library:new({name = 'plugin.movie', publisherId = 'com.ansh3ll'})

local libMovie = require("plugin.movieLib")

local class = {}

local function onSystemEvent( event )
  print( "System event name and type: " .. event.name, event.type )
end

Runtime:addEventListener( "system", onSystemEvent )

class.set = function(obj, opts)
  --
  obj.x, obj.y = opts.x, opts.y
  obj._preserve = opts.preserve
  obj.listener = opts.listener
  --
  obj._delta = 0
  obj._stop = false
  obj.playing = false
  obj._started = false
  obj._complete = false

  --
  obj.update = function(event)
    if obj.playing then
      if obj._prevtime then
        obj._delta = event.time - obj._prevtime
      end
      --
      obj.texture:update(obj._delta)
      obj.texture:invalidate()
      --
      if not obj.texture.isActive then
        obj._complete = true
        obj.stop()
      end
    end
    --
    obj._prevtime = event.time
  end
  --
  obj.play = function()
    if obj.playing then return end
    --
    obj.texture:play()
    obj.playing = true
    --
    if not obj._started then
      obj._started = true
      Runtime:addEventListener('enterFrame', obj.update)
    end
  end
  --
  obj.pause = function()
    if not obj.playing then return end
    --
    obj.playing = false
    obj.texture:pause()
  end
  --
  obj.stop = function()
    if obj._stop then return end
    --
    Runtime:removeEventListener('enterFrame', obj.update)
    --
    obj.playing = false
    obj.texture:stop()
    obj._stop = true
    --
    if obj.listener then
      obj.listener({
        name = 'movie',
        phase = 'stopped',
        completed = obj._complete
      })
    end
    --
    if obj._preserve then return end
    --
    obj.dispose()
  end
  --
  obj.dispose = function()
    if obj.playing then return end

    timer.performWithDelay(100, function()
      if obj.texture then
        obj.texture:releaseSelf()
        obj.texture = nil
      end
      --
      obj:removeSelf()
    end)
  end
end

-- DIY
function lib.newMovieTexture(opts)
  local path = system.pathForFile(opts.filename,
  opts.baseDir or system.ResourceDirectory)
  local source = audio.getSourceFromChannel(opts.channel or
  audio.findFreeChannel())
  return libMovie._newMovieTexture(path, source, display.fps)
end

-- Plug-n-play
function lib.newMovieCircle(opts)
  local texture = lib.newMovieTexture(opts)
  local circle = display.newCircle(opts.x, opts.y, opts.radius)
  circle.texture, circle.channel = texture, opts.channel

  circle.fill = {
    type = "image",
    filename = texture.filename, -- "filename" property required
    baseDir = texture.baseDir -- "baseDir" property required
  }

  class.set(circle, opts)
  --
  return circle
end

function lib.newMovieRect(opts)
  local texture = lib.newMovieTexture(opts)
  local rect = display.newImageRect(texture.filename, texture.baseDir,
  opts.width, opts.height)
  rect.texture, rect.channel = texture, opts.channel

  class.set(rect, opts)
  --
  return rect
end

-- Looping video
function lib.newMovieLoop(opts)
  local group = display.newGroup()
  --
  group._stop = false
  group.iterations = 1
  group.playing = false
  group.listener = opts.listener
  --
  group.callback = function(event)
    if group._stop then return end
    --
    group.iterations = group.iterations + 1
    --
    if group.iterations % 2 == 0 then
      group.two.isVisible = true
      group.two.play()
      --
      timer.performWithDelay(200, group.one.dispose)
      timer.performWithDelay(500, function()
        group.one = lib.newMovieRect(group.options1)
        group.one.isVisible = false
        group:insert(group.one)
      end)
    else
      group.one.isVisible = true
      group.one.play()
      --
      timer.performWithDelay(200, group.two.dispose)
      timer.performWithDelay(500, function()
        group.two = lib.newMovieRect(group.options2)
        group.two.isVisible = false
        group:insert(group.two)
      end)
    end
    --
    if group.listener then
      group.listener({
        name = 'movie',
        phase = 'loop',
        iterations = group.iterations
      })
    end
  end
  --
  group.options1 = {
    x = opts.x,
    y = opts.y,
    listener = group.callback,
    preserve = true,
    channel = opts.channel1,
    width = opts.width,
    height = opts.height,
    filename = opts.filename,
    baseDir = opts.baseDir
  }
  --
  group.options2 = copy(group.options1)
  group.options2.channel = opts.channel2
  --
  group.one = lib.newMovieRect(group.options1)
  group.two = lib.newMovieRect(group.options2)
  group.two.isVisible = false
  --
  group:insert(group.one)
  group:insert(group.two)
  --
  group.rect = function()
    return group.iterations % 2 == 0 and group.two or group.one
  end
  --
  group.play = function()
    if group.playing then return end
    --
    group.rect().play()
    group.playing = true
  end
  --
  group.pause = function()
    if not group.playing then return end
    --
    group.playing = false
    group.rect().pause()
  end
  --
  group.stop = function()
    if group._stop then return end
    --
    group._stop = true
    group.playing = false
    --
    group.one.stop()
    group.two.stop()
    --
    group.one.dispose()
    group.two.dispose()
    --
    timer.performWithDelay(300, function() group:removeSelf() end)
    --
    if group.listener then
      group.listener({
        name = 'movie',
        phase = 'stopped',
        completed = group.iterations > 1 and true or false
      })
    end
  end
  --
  return group
end

-- Return an instance
return lib
