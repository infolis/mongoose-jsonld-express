Async = require 'async'
MongooseJSONLD = require 'mongoose-jsonld/src'
# MongooseJSONLD = require '../../mongoose-jsonld/src'
ExpressJSONLD = require 'express-jsonld/src'
# ExpressJSONLD = require '../../express-jsonld/src'

mongooseJSONLD = new MongooseJSONLD()
expressJSONLD = new ExpressJSONLD()

_conneg = (doc, req, res, next) ->
	if not req.headers.accept or req.headers.accept is 'application/json'
		return res.send doc
	doc.jsonldABox (err, doc) ->
		req.jsonld = doc
		return expressJSONLD.handle(req, res, next)

module.exports = class MongooseJSONLDExpress extends MongooseJSONLD

	_GET_Resource : (model, req, res, next) ->
		model.findOne {_id: req.params.id}, (err, doc) ->
			if err
				res.status 400
				return next new Error(err)
			if not doc
				res.status 404
				res.end()
			else
				res.status 200
				_conneg(doc, req, res, next)

	_GET_Collection : (model, req, res, next) ->
		console.log "Retrieving all docs for model #{model.modelName}"
		model.find {}, (err, docs) ->
			if err
				return next new Error(err)
			res.status = 200
			req.jsonld = docs.map (el) -> el.toJSON()
			next()
			# Async.map docs, (doc, cb) ->
			#     doc.jsonldABox cb
			# , (err, docs) ->
			#     req.jsonld = docs
			#     console.log docs
			#     try
			#         expressJSONLD.handle(req, res, next)
			#     catch e
			#         next new Error(e)

	_DELETE_Collection: (model, req, res, next) ->
		model.remove {}, (err, removed) ->
			return next new Error(err) if err
			res.status 200
			res.send {removed: removed}

	_POST_Resource: (model, req, res, next) ->
		console.log "Create new '#{model.modelName}' resource: "
		doc = new model(req.body)
		doc.save (err, created) ->
			if err
				return next new Error(err)
			created.jsonldABox (err, jsonld) ->
				res.status 201
				req.jsonld = jsonld
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
		console.log nextMiddleware.toString()
		if not nextMiddleware
			console.log "Should provide a middleware to handle this"
			nextMiddleware = (req, res, next) ->
				res.send req.jsonld

		self = @
		basePath = "#{@apiPrefix}/#{model.collection.name}"

		handlers = [
			# GET /api/somethings  => list all
				method: 'get'
				path: "#{basePath}"
				handler: @_GET_Collection
			,
				method: 'get'
				path: "#{basePath}/:id"
				handler: @_GET_Resource
			,
				method: 'post'
				path: "#{basePath}/?"
				handler: @_POST_Resource

		]

		console.log "Registering REST Handlers on basePath '#{basePath}'"
		for handler in handlers
			console.log handler
			app[handler.method](
				handler.path
				(req, res, next) -> handler.handler(model, req, res, next)
				(req, res, next) -> nextMiddleware(req, res, next)
			)

 
		# # GET /api/somethings  => list all
		# app.get "#{basePath}/:id", (req, res, next) =>
		#     @_GET_Resource(model, req, res, next)

		# # POST /api/somethings => create new something
		# app.put "#{basePath}/:id", (req, res, next) =>
		#     @_PUT_Resource(model, req, res, next)

		# POST /api/somethings => create new something
		# app.post "#{basePath}/?", (req, res, next) =>
		#     @_POST_Resource(model, req, res, next)

		# # DELETE /api/somethings/* => create new something
		# app.delete "#{basePath}/!", (req, res, next) =>
		#     @_DELETE_Collection(model, req, res, next)

		# PUT /api/somethings/:id => create/replace something with :id
		# TODO
