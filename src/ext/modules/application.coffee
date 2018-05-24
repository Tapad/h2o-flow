H2O.Application = (_) ->
  H2O.ApplicationContext _
  H2O.Proxy _

  link _.ready, ->
    do window.Tapad.Link.init
