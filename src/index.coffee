MongooseJSONLD = require 'mongoose-jsonld'

module.exports = class MongooseJSONLDExpress extends MongooseJSONLD

	injectRestfulHandlers: (app, model) ->
		basePath = "#{@apiPrefix}/#{model.collection.name}"
		console.log model.db.readyState
		# GET /api/somethings  => list all
		app.get "#{basePath}", (req, res, next) ->
			console.log 'foo'
			model.find {}, (err, docs) ->
				res.status 200
				res.send docs
		# GET /api/somethings/:id  => return Iid
		app.get "#{basePath}/:id", (req, res, next) ->
			model.findOne {_id: req.params.id}, (err, doc) ->
				if err
					# console.log err
					res.status  404
					res.send {}
				else
					res.status 200
					res.send doc
		# POST /api/somethings => create new something
		app.post "#{basePath}", (req, res, next) ->
			console.log req.data
			next "FOO"
		# TODO
		# PUT /api/somethings/:id => create/replace something with :id
		# TODO
