H2O.Application = (_) ->
  H2O.ApplicationContext _
  H2O.Proxy _

  link _.ready, -> setTimeout window.Tapad.Link.init, 100
