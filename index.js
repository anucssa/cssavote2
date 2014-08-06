var express = require('express');
var app = express();
var bodyParser = require('body-parser');
var redis = require("redis"),
        r = redis.createClient();
var underscore = require("underscore");


app.use(bodyParser.json());

app.use(express.static(__dirname + '/public'));


// Admin

// Candidates
app.get('/admin/candidates', function(req, res) {
  // Candidate ids stored in set "candidate"
  r.smembers("candidates", function(err, candidates) {

    // Hash info stored in key "candidate:id"
    var candidates_json = underscore.reduce(
      candidates, // list of candidates
      function(memo, uid) {
        r.hgetall('candidate:' + uid, function(err, reply) {
          var x = reply;
          x.id = uid;
          r.smembers('election:' + x.id, function(err, reply) {
            x.elections = reply;
            memo.push(x);
            if (memo.length == candidates.length) {
              res.json(memo);
              res.end();
            }
            return memo;
          });
        });
      },
    []);

  });
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
  // Try and find the code as a hash
  if (! req.body.hasOwnProperty("code")) {
    res.status(400).json({error: "code required"});
    return;
  }

  var code;
  r.hgetall(req.body.code, function(err, reply) {
    code = reply;
  });

  if (code == null || code.used) {
    res.status(404).json({error:"invalid code"})
  }

  // Set the code as being used
  code.used = true;
  r.hmset(req.body.code, code);

  res.json({token: "iwishiwasreal"});
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

