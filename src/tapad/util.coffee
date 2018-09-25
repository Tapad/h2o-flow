getCellInputs = ->
  cells = filter window.flow.view.cells(), (cell) -> cell.type() == "cs"
  map cells, (cell) -> cell.input()

getJsAst = (cs, go) ->
  kernel = Flow.CoffeescriptKernel
  (Flow.Async.pipe [
    (next) -> kernel.compileCoffeescript cs, next
    (js, next) -> kernel.parseJavascript js, next
  ]) (err, ast) ->
    if err?
      # failed to compile/parse but it doesn't matter, just skip input
      go null, {}
    else
      go null, ast

findInputWhere = (predicate, go) ->
  inputs = reverse do getCellInputs
  asts = []

  checkAstForMatch = (node) ->
    if predicate node
      true
    else
      some node, (child) -> (isObject child) && (checkAstForMatch child)

  findInput = (go) ->
    findInputPipe = Flow.Async.pipe map inputs, (input, i) ->
      (foundInput, nextInput) ->
        return nextInput null, foundInput if foundInput?

        checkInputPipe = Flow.Async.pipe [
          (next) ->
            return next null, asts[i] if asts[i]?
            getJsAst input, next
          (ast, next) ->
            asts[i] = ast if not asts[i]?
            next null, checkAstForMatch node 
        ]

        checkInputPipe (err, matched) -> nextInput err, if matched then input else null

    findInputPipe null, (err, foundInput) ->
      return go err if err?
      return go null, foundInput

findModelInputs = (modelKeys, go) ->
  results = {}
  (Flow.Async.pipe map modelKeys, (modelKey) ->
    (next) ->
      predicate = (node) ->
        (isObject node) &&
        node.type == "Property" &&
        (node.key.value ? node.key.name) == "model_id" &&
        node.value.value == modelKey

      findInputWhere predicate, (err, input) ->
        return next err if err?
        results[modelKey] = input
        do next
  ) (err) ->
    return go err if err?
    go null, results

findFrameInputs = (frameKeys, go) ->
  results = {}
  (Flow.Async.pipe map frameKeys, (frameKey) ->
    (next) ->
      predicate = (node) ->
        (isObject node) &&
        node.type == "Property" &&
        (node.key.value ? node.key.name) == "destination_frame" &&
        node.value.value == frameKey

      findInputWhere frameKey, (err, input) ->
        return next err if err?
        results[frameKey] = input
        do next
  ) (err) ->
    return go err if err?
    go null, results

simplifyModelResult = (result) ->
  simplifyModel = (model) ->
    modelKey: model.model_id.name
    frameKey: model.data_frame.name
    algorithm: model.algo
    responseColumnName: model.response_column_name
    parameters: simplifyModelParameters model.parameters
    output:
      summary: simplifyModelSummary model.output.model_summary
      trainingMetrics: simplifyModelTrainingMetrics model.output.training_metrics
      runTime: model.output.run_time

  simplifyModelParameters = (parameters) ->
    reduce parameters, ((memo, parameter) ->
      key = parameter.name
      defaultValue = parameter.default_value

      value = parameter.actual_value
      if isObject value
        value = switch parameter.type
          when "Key<Frame>" then value.name
          when "Key<Model>" then value.name
          when "VecSpecifier" then value.column_name
          else value
      
      if value != defaultValue
        memo[key] = value
      
      memo
    ), {}
  
  simplifyModelSummary = (summary) ->
    reduce summary.columns, ((memo, column, i) ->
      key = column.name
      if key?.length > 0
        memo[key] = summary.data[i][0]
      memo
    ), {}

  simplifyModelTrainingMetrics = (metrics) ->
    pick metrics, (value) -> (isArray value) || (not isObject value)

  simplifyFrame = (frame) ->
    frameKey: frame.frame_id.name
    columns: map frame.columns, simplifyFrameColumn

  simplifyFrameColumn = (column) ->
    column = pick column, ["type", "label", "domain"]
    if not column.domain?
      delete column.domain
    column

  model: simplifyModel result.model
  frame: simplifyFrame result.frame
  modelInput: result.modelInput
  frameInput: result.frameInput
  mojoPath: result.mojoPath


simplifyModelResults = (results) -> results.map simplifyModelResult

if not window.Tapad?
  window.Tapad = {}
window.Tapad.Util =
  getCellInputs: getCellInputs
  findModelInputs: findModelInputs
  findFrameInputs: findFrameInputs
  simplifyModelResults: simplifyModelResults
