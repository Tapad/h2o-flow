H2O.ExportModelsToTapadInput = (_, _go, modelKey, path, opt={}) ->
  _exportableModels = signal []
  _unexportableModels = signal []
  _rawModels = signal []
  _allSelected = signal true
  _canExportModels = signal true

  _isCheckingAll = false
  react _allSelected, (allSelected) ->
    return if _isCheckingAll
    _isCheckingAll = true
    forEach _exportableModels(), (model) ->
      model.selected allSelected
    _isCheckingAll = false
  
  checkAllSelected = () ->
    return if _isCheckingAll
    _isCheckingAll = true
    models = _exportableModels()
    _allSelected (filter models, (model) -> model.selected()).length == models.length
    _isCheckingAll = false

  checkExportable = () ->
    models = _exportableModels()
    _canExportModels (filter models, (model) -> model.selected()).length > 0

  exportModels = ->
    selectedModelIds = map (filter _exportableModels(), (model) -> model.selected()), (model) -> model.name
    _.insertAndExecuteCell 'cs', "exportModelsToTapad #{ stringify selectedModelIds }"

  _.requestModels (error, models) ->
    if error
      #TODO handle properly
    else
      _rawModels models

      exportableModels = filter models, (model) -> model.have_mojo == true
      _exportableModels map exportableModels, (model) ->
        _selected = signal true
        react _selected, () ->
          do checkAllSelected
          do checkExportable

        selected: _selected
        name: model.model_id.name

      unexportableModels = filter models, (model) -> model.have_mojo != true
      _unexportableModels unexportableModels

  defer _go

  exportableModels: _exportableModels
  unexportableModels: _unexportableModels
  allSelected: _allSelected
  canExportModels: _canExportModels
  exportModels: exportModels
  template: 'flow-export-models-to-tapad-input'

