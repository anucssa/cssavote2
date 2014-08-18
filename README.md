# cssavote2

This program takes candidates from an admin interface, and places
them in a persistant store.  Students can vote on candidates by entering
a voting-code, and use a preferential system to vote.

Once the votes have been cast (or at any time for that matter),
a BLT file can be downloaded.

## Version

0.5.1

## Implementation

The server provides a JSON API, over which Angular is placed.

## Tests

An rspec test suite exists for the API which can be invoked from the repository root:
```bash
RACK_ENV=test rspec spec/server_spec.rb
```

## API Definition

## Admin

All admin type endpoints require an authentication token.  This is
given in the query string as `token`.  The value of this token is
set in the environment variable `AUTH_TOKEN`.

If the system is locked, an offending post request will be responded
to with a 403.

### Vote lock

The system can be in one of two states.  Either preparation, or voting.
In the preparation state, candidates and elections can be modified,
but voting cannot occur (voting tokens are not given).
In the voting state, candidates and elections cannot be modified, but
votes can be cast.

This provides two endpoints:

    GET /admin/votelock
    POST /admin/votelock

It accepts the followed schema:

    {
      "state": one of either "voting" or "editing"
    }


### Candidates

Two endpoints are given for candidates:

    GET /admin/candidates
    POST /admin/candidates

The first retrieves the list of candidates in the system,
and the second updates that list.

The following JSON schema is adopted:

    [
      {
        "id": "Candidate uID",
        "elections": ["genrep", "president", ...],
        "name": "Candidate name"
      },
    ...
    ]

### Elections

Similar to candidates, two endpoints are given:

    GET /admin/elections
    POST /admin/elections

The following JSON schema is adopted:

    [
      {
        "name": "president",
        "positions": 1
      },
      {
        "name": "secretary",
        "positions": 1
      },
      {
        "name": "genrep",
        "positions": 5
      }
    ]

All of the names should consist of only characters `[A-z]` for the sake of
simplicity.  Positions refers to the number of people that can run for
it.

### Voting codes

Three endpoints are given:

    GET /admin/votingcodes
    GET /admin/votingcodes/more
    POST /admin/votingcodes

The first retrieves the set of codes in the system, the second
retries more codes, and the third modifies the set in the system.

Please note that unlike in the top two examples, voting codes cannot
be deleted.

The following JSON schema is adopted:

    [
      {
        "code": "unique six-char code",
        "used": true/false,
        "new": true/false
      },
      ...
    ]

Each code is six characters long.  The used value refers to whether
or not the code has been used to vote yet.  The new value
is used to tell whether or not the code has been handed out
to someone.

### Ballot files

One endpoint is given:

    GET /admin/votes.blt

Each election is separated by two new lines.

## General

This section is primarily concerned with having users vote on people.

The public interface initially shows a dialog that allows you to
enter a voting code, after which you are taken to a page with
all of the elections that allows you to vote.  At the bottom is a big
"vote" button.  Once this is clicked, you can't change anything.

On the server side, once the voting code is entered, a token is generated
and sent back to the client, and the voting code is marked as used.
This token allows the user to submit
their votes, and is linked to the voting code.

### Voting Code

Only has one endpoint:

    POST /votingcode

The following JSON schema is adopted:

    {
      "votingcode": "unique six-char code"
    }

A token is returned if successful:

    {
      "token": "token string"
    }

If the voting code has been used or doesn't exist, a 404 is returned.

### Elections

One endpoint:

    GET /elections

Returns the following JSON schema:

    [
      {
        "election": "e.g. president",
        "positions": "integer",
        "candidates": [
          {
            "name": "candidate name",
            "id": "candidate uid"
          }
        ]
      }
    ]

### Votes

Only has one endpoint:

    POST /votes?token=...

Where the token parameter was given by `/votingcode`.

Accepts the following schema:

    [
      {
        "election": "e.g. president",
        "votes": [
          {
            "id": "candidate id",
            "rank": "e.g. 1,2,3"
          }
        ]
      }
    ]

### Redis Summary

#### System state

    votelock        # string; what state the system is in

#### Candidates

    candidate:uID   # hash;  fields: name
    candidates      # set;   list of all candidates
    elections:uID   # set;   elections candidate is in

#### Elections

    elections       # set;   names of elections
    election:name   # hash;  fields: positions --> (integer),
                                     candidate id --> numbers (1, 2, 3),
                                     candidates --> (integer)

#### VotingCodes

    votingcodes     # set;   list of all codes
    votingcode:id   # hash;  fields: code (string), token (string),
                                     used (boolean), new (boolean)
    tokens          # set;   set of all valid tokens
    votingcode_increment # integer;

#### Votes

    votes:election  # list;  list of votes a for an election
                             (i.e. "1 3 4 2", "2 3 4 1")
                             [0] is the first candidate

#### Caches

    cache:votes.blt  # string;
