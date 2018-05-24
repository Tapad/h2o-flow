messageHandlers = {}

init = ->
  sendCommand "getMartAuthJwt", (jwt) ->
    $.ajaxSetup
      url: window.Flow.ContextPath
      headers:
        Authorization: "Bearer #{ jwt }"

targetWindow = window.parent
targetOrigin = "http://localhost:8000"
messageId = 0
callbacks = {}

messageListener = (event) ->
  return if event.origin != targetOrigin

  data = event.data
  id = data.id

  console.log data

  if data.type == "reply"
    callback = callbacks[id]
    return if not callbacks?
    delete callbacks[id]
    apply callback, null, data.args
  else
    messageHandler = messageHandlers[data.cmd]
    return if not messageHandler?
    reply = (args...) -> apply sendReply, null, concat [id], args
    apply messageHandler, null, concat [reply], data.args

sendCommand = (cmd, args...) ->
  id = messageId++

  if isFunction args[args.length - 1]
    callback = pop args
    callbacks[id] = callback
  
  message =
    type: "cmd"
    id: id
    cmd: cmd
    args: args
  console.log message
  targetWindow.postMessage(message, targetOrigin)

sendReply = (id, args...) ->
  message =
    type: "reply"
    id: id
    args: args
  targetWindow.postMessage(message, targetOrigin)

$(window).on "message", (e) -> messageListener e.originalEvent

if not window.Tapad?
  window.Tapad = {}
window.Tapad.Link =
  init: init
  sendCommand: sendCommand
  sendReply: sendReply
