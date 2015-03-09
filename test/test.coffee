Fs = require 'fs'
Async = require 'async'
test = require 'tapes'
mongoose = require 'mongoose'
request = require 'supertest'
{Schema} = mongoose
SuperAgent = require 'superagent'

MongoseJSONLD = require '../src'
mongooseJSONLD = new MongoseJSONLD(
	baseURL: 'http://www-test.bib-uni-mannheim.de/infolis'
	apiPrefix: '/api/v1'
	expandContext: 'basic'
)
dump = (stuff) ->
	console.log JSON.stringify stuff, null, 2

schemaDefinitions = require '../data/infolis-schema'
db = mongoose.createConnection()

PublicationSchema = new Schema(schemaDefinitions.Publication.schema, {'@context': schemaDefinitions.Publication.jsonld})
PublicationSchema.plugin(mongooseJSONLD.createMongoosePlugin())
PublicationModel = db.model('Publication', PublicationSchema)

test 'CRUD', (t) ->
	app = require('express')()
	bodyParser = require('body-parser')
	app.use(bodyParser.json())
	mongooseJSONLD.injectRestfulHandlers(app, PublicationModel)
	db.open  'localhost:27018/test'
	id = null
	db.once 'open', ->
		Async.series [
			(cb) -> 
				request(app)
				.delete('/api/v1/publications/!')
				.end (err, res) ->
					t.equals res.statusCode, 200, "DELETE /! 200"
					cb()
			(cb) -> 
				request(app)
				.post '/api/v1/publications'
				.send {'title': 'The Art of Kung-Foo'}
				.end (err, res) ->
					t.equals res.statusCode, 201, 'POST / 201'
					id = res.body._id
					request(app)
					.get "/api/v1/publications/#{id}"
					.accept('text/turtle')
					.end (err, res) ->
						t.ok res.text.indexOf('@prefix') > -1, 'Converted to Turtle'
						t.ok res.headers['content-type'].indexOf('text/turtle') > -1, 'Correct content-type'
						t.equals res.statusCode, 200, 'GET /:id 200'
						cb()
			(cb) -> 
				request(app)
				.get "/api/v1/publications/64fd946ceaa8dd8e5d2e202e"
				.end (err, res) ->
					t.equals res.statusCode, 404, 'GET /:id 404'
					cb()
			(cb) -> 
				request(app)
				.put "/api/v1/publications/#{id}"
				.send {title: 'Bars and Quuxes'}
				.end (err, res) ->
					t.equals res.statusCode, 201, 'PUT /:id 201'
					request(app)
					.get "/api/v1/publications/#{id}"
					.end (err, res) ->
						t.equals res.body.title, 'Bars and Quuxes', 'Title updated'
						t.equals res.statusCode, 200, 'GET /:id 200'
						cb()
			(cb) -> 
				request(app)
				.delete('/api/v1/publications/!')
				.accept('text/turtle')
				.end (err, res) ->
					t.equals res.statusCode, 200, "DELETE /! 200"
					request(app)
					.get "/api/v1/publications/"
					.end (err, res) ->
						t.equals res.body.length, 0, 'No more docs after delete'
						cb()
		], (err) ->
			db.close()
			t.end()
