Async = require 'async'
MongooseJSONLD = require 'mongoose-jsonld/src'
# MongooseJSONLD = require '../../mongoose-jsonld/src'
ExpressJSONLD = require 'express-jsonld/src'
# ExpressJSONLD = require '../../express-jsonld/src'
JsonLD2RDF	 = require 'jsonld-rapper'

module.exports = class MongooseJSONLDExpress extends MongooseJSONLD

	constructor : () ->
		super
		@expressJsonld = new ExpressJSONLD(
			j2rOptions:
				expandContext: @expandContext
				baseURI: @baseURL # TODO meh bad naming
		)
		@expressJsonldMiddleware = @expressJsonld.getMiddleware()

	_conneg : (req, res, next) ->
		self = @
		if not req.mongooseDoc 
			res.end()
		else if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
			if Array.isArray(req.mongooseDoc)
				res.send req.mongooseDoc.map (el) -> el.toJSON()
			else
				res.send req.mongooseDoc.toJSON()
		else
			if Array.isArray(req.mongooseDoc)
				Async.map req.mongooseDoc, (doc, eachDoc) ->
					doc.jsonldABox eachDoc
				, (err, result) =>
					req.jsonld = result
					self.expressJsonldMiddleware(req, res, next)
			else
				req.mongooseDoc.jsonldABox req.mongooseDoc, (err, jsonld) ->
					req.jsonld = jsonld
					self.expressJsonldMiddleware(req, res, next)

	_GET_Resource : (model, req, res, next) ->
		console.log "GET #{model.modelName}##{req.params.id} "
		model.findOne {_id: req.params.id}, (err, doc) ->
			if err
				res.status 500
				return next new Error(err)
			if not doc
				res.status 404
			else
				res.status 200
				req.mongooseDoc = doc
			next()

	_GET_Collection : (model, req, res, next) ->
		console.log "GET all #{model.modelName}"
		model.find {}, (err, docs) ->
			if err
				res.status 500
				return next new Error(err)
			res.status = 200
			req.mongooseDoc = docs
			next()

	_DELETE_Collection: (model, req, res, next) ->
		console.log "DELETE all #{model.modelName}"
		model.remove {}, (err, removed) ->
			if err
				res.status 500
				return next new Error(err)
			res.status 200
			console.log "Removed #{removed} documents"
			next()

	_DELETE_Resource : (model, req, res, next) ->
		input = req.body
		console.log "DELETE #{model.modelName}##{req.params.id}"
		model.remove {_id: req.params.id}, (err, nrRemoved) ->
			if err
				res.status 400
				return next new Error(err)
			if nrRemoved == 0
				res.status 404
			else
				res.status 201
			next()

	_POST_Resource: (model, req, res, next) ->
		doc = new model(req.body)
		console.log "POST new '#{model.modelName}' resource: #{doc.toJSON()}"
		doc.save (err, newDoc) ->
			if err
				res.status 500
				return next new Error(err)
			else
				res.status 201
				req.mongooseDoc = newDoc
				next()

	_PUT_Resource : (model, req, res, next) ->
		input = req.body
		delete input._id
		model.update {_id: req.params.id}, input, {upsert: true}, (err, nrUpdated) ->
			if err
				res.status 400
				return next new Error(err)
			if nrUpdated == 0
				res.status 400
				return next new Error("No updates were made?!")
			else
				res.status 201
				res.end()

	injectRestfulHandlers: (app, model, nextMiddleware) ->
		if not nextMiddleware
			nextMiddleware = @_conneg.bind(@)

		self = @
		basePath = "#{@apiPrefix}/#{model.collection.name}"

		api = {}
		# GET /api/somethings/:id     => get a 'something' with :id
		api["GET #{basePath}/:id"]     = @_GET_Resource
		# GET /api/somethings         => List all somethings
		api["GET #{basePath}/?"]       = @_GET_Collection
		# POST /api/somethings        => create new something
		api["POST #{basePath}/?"]      = @_POST_Resource
		# PUT /api/somethings/:id     => create/replace something with :id
		api["PUT #{basePath}/:id"]     = @_PUT_Resource
		# DELETE /api/somethings/!    => delete all somethings [XXX DANGER ZONE]
		api["DELETE #{basePath}/!!"]   = @_DELETE_Collection
		# DELETE /api/somethings/:id  => delete something with :id
		api["DELETE #{basePath}/:id"]  = @_DELETE_Resource

		console.log "Registering REST Handlers on basePath '#{basePath}'"
		for methodAndPath, handle of api
			do (methodAndPath, handle, nextMiddleware) ->
				expressMethod = methodAndPath.substr(0, methodAndPath.indexOf(' ')).toLowerCase()
				path = methodAndPath.substr(methodAndPath.indexOf(' ') + 1)
				# console.log "#{expressMethod} '#{path}'"
				app[expressMethod](
					path
					(req, res, next) -> handle(model, req, res, next)
					(req, res, next) -> nextMiddleware(req, res, next)
				)
	
	injectSchemaHandlers : (app, model, nextMiddleware) ->
		if not nextMiddleware
			nextMiddleware = @_conneg.bind(@)

		basePath = @schemaPrefix

		self = @
		do (self) =>
			path = "#{@schemaPrefix}/#{model.modelName}"
			console.log "Binding schema handler #{path}"
			app.get path, 
				(req, res) -> 
					req.jsonld = model.schema.options['@context']
					if not req.headers.accept or req.headers.accept in ['*/*', 'application/json']
						res.send JSON.stringify(req.jsonld, null, 2)
					else
						self.expressJsonldMiddleware(req, res)

