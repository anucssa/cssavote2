# cssavote2

This program takes candidates from an admin interface, and places
them in a persistant store.  Students can vote on candidates by entering
a voting-code, and use a preferential system to vote.

Once the votes have been cast (or at any time for that matter),
a BLT file can be downloaded.

## Version

0.3.0

## Implementation

The server provides a JSON API, over which Angular is placed.

## API Definition

## Admin

All admin type endpoints require an authentication token.  This is
given in the query string as `token`.  The value of this token is
set in the environment variable `AUTH_TOKEN`.

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
      "code": "unique six-char code"
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

#### Candidates

    candidate:uID   # hash;  fields: name
    candidates      # set;   list of all candidates
    election:uID    # set;   elections candidate is in

#### Elections

    elections       # set;   names of elections
    election:name   # hash;  fields: positions (integer)

#### VotingCodes

    votingcodes     # set;   list of all codes
    votingcode:id   # hash;  fields: code (string), token (string),
                                     used (boolean), new (boolean)
    tokens          # set;   set of all valid tokens
    votingcode_increment # integer;

#### Votes

    votes:election:id  # list;  list of votes a candidate got for
                                an election (i.e. 1 1 4 3 1)


