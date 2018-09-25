messageHandlers = {}

init = ->
  sendCommand "loadState", (state) ->
    if state? and state.doc? and state.doc.cells? and state.doc.cells.length > 0
      flow.view.deserialize state.name, null, state.doc
      cells = do flow.view.cells
      setTimeout cells[cells.length - 1].scrollIntoView, 100
    do watchState

watchState = ->
  link flow.view.name, saveState

  cellLinks = []
  linkCells = (cells) ->
    forEach cellLinks, (subscription) -> unlink subscription
    cellLinks = map cells, (cell) -> link cell.input, saveState

  link flow.view.cells, (cells) ->
    do saveState
    linkCells cells
  
  linkCells do flow.view.cells

saveState = ->
  if saveState.timeout?
    saveState.changed = true
    clearTimeout saveState.timeout
  else
    saveState.changed = false
    do persistState
  
  debounced = ->
    delete saveState.timeout
    return if not saveState.changed
    do persistState

  saveState.timeout = setTimeout debounced, 1000

persistState = ->
  console.log 1
  state =
    name: do flow.view.name
    doc: do flow.view.serialize
  sendCommand "saveState", state

targetWindow = window.parent
targetOrigin = "http://localhost:8000"
messageId = 0
callbacks = {}

messageListener = (event) ->
  return if event.origin != targetOrigin

  data = event.data
  id = data.id

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
  saveState: saveState
  sendCommand: sendCommand
  sendReply: sendReply
