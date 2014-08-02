var express = require('express');
var app = express();
var bodyParser = require('body-parser');
var redis = require("redis"),
        client = redis.createClient();


app.use(bodyParser.json());

// Admin

// Candidates
app.get('/admin/candidates', function(req, res){
  res.status(200).json({error: "not implemented yet"});
});

app.post('/admin/candidates', function(req, res){
  console.log(req.body);
  res.send('not implemented yet');
});

// Elections
app.get('/admin/elections', function(req, res){
  res.send('not implemented yet');
});

app.post('/admin/elections', function(req, res){
  res.send('not implemented yet');
});

// Voting Codes

app.get('/admin/votingcodes', function(req, res){
  res.send('not implemented yet');
});

app.get('/admin/votingcodes/more', function(req, res){
  res.send('not implemented yet');
});

app.post('/admin/votingcodes', function(req, res){
  res.send('not implemented yet');
});



// Public

app.post('/votingcode', function(req, res){
  res.send('not implemented yet');
});

app.get('/elections', function(req, res){
  res.send('not implemented yet');
});

app.post('/votes', function(req, res){
  res.send('not implemented yet');
});



var server = app.listen(3000, function() {
    console.log('Listening on port %d', server.address().port);
});

