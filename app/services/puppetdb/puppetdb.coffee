angular.module('app').factory "PuppetDB", ($http,
                                           $location) ->
  new class PuppetDB

    apiVersion: 'v4'

    constructor: ->
      @servers = PUPPETDB_SERVERS.map (srv) -> srv[0]
      @puppetdbquery = require('node-puppetdbquery').parser

    # Public: Get/Set server
    #
    # server - The String name of the server to set
    #
    # Returns: the String current server
    server: (server) ->
      if server
        $location.search "server", server
      else
        $location.search().server or
          PUPPETDB_SERVERS[0][0]

    # Public: Get URL of current server
    #
    # Returns: The {String} URL
    serverUrl: () ->
      for server in PUPPETDB_SERVERS
        return server[1] if server[0] == @server()

    # Public: Parse a query
    #
    # query     - The {String} query to parse
    # nodeQuery - A {Boolean} specifying if it should be
    #             parsed for the nodes endpoint or other endpoints.
    #
    # Returns: The resulting query
    parse: (query, nodeQuery) ->
      if query
        @puppetdbquery.yy.nodeQuery = nodeQuery
        @puppetdbquery.parse query
      else
        null

    # Public: Query a endpoint, returns a promise just like $http
    #
    # endpoint - The {String} endpoint to query
    # params   - The {Object} query parameters
    #
    # Returns: A promise from $http
    query: (endpoint, params = {}) ->
      $http.get("#{@serverUrl()}/#{@apiVersion}/#{endpoint}", {params: params})

    # Public: Combined function to both parse and query PuppetDB.
    #
    # endpoint        - The {String} endpoint to query
    # nodeQuery       - The {String} query to parse
    # additionalQuery - The {Array} a raw API query that is added to the nodeQuery
    # params          - The {Object} additional parameters to the endpoint
    # success         - The {Function} callback on success
    #
    # Returns: The {Promise} from $http
    parseAndQuery: (endpoint, nodeQuery, additionalQuery, params = {}, success) ->
      # Handle all the parsing of the query and putting them together
      if nodeQuery
        query = @parse(nodeQuery, endpoint is "nodes")
      else
        query = null
      if additionalQuery
        query = if query
          [ "and", query, additionalQuery ]
        else
          additionalQuery
      else unless query # no query and no additional query either
        if endpoint in ["reports", "events", "event-count", "aggregate-event-count"]
          # PuppetDB really requires a valid query for some endpoints even
          # if we want to query all. So we just make something up that will
          # match all of them...
          query = [ ">", "timestamp", "1970-01-01T00:00:00.000Z" ]

      params.query = angular.toJson(query)
      if endpoint in ['nodes', 'reports', 'events', 'facts']
        params['include-total'] = true

      # Start querying
      @query(endpoint, params).success((data, status, headers, config) ->
        success(angular.fromJson(data), headers('X-Records'))
      ).error (data, status, headers, config) ->
        throw new Error(data or "Failed to fetch #{endpoint}")
