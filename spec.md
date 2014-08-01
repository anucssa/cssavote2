# Specification

This program takes candidates from an admin interface, and places
them in a persistant store.  Students can vote on candidates by entering
a voting-code, and use a preferential system to vote.

Once the votes have been cast (or at any time for that matter),
a BLT file can be downloaded.

## Implementation

The server provides a JSON API, over which Angular is placed.

## API Definition

## Admin

All admin type endpoints require an authentication token.

### Candidates

Two endpoints are given for candidates:

    GET /candidates
    POST /candidates

The first retrieves the list of candidates in the system,
and the second updates that list.

The following JSON schema is adopted:

    [
      {
        "Candidate uID":
        {
          "elections": ["genrep", "president", ...],
          "name": "Candidate name"
        }
      },
    ...
    ]

### Elections

Similar to candidates, two endpoints are given:

    GET /elections
    POST /elections

The following JSON schema is adopted:

    [
      "president",
      "secretary",
      "genrep"
    ]

All of the names should consist of only characters `[A-z]` for the sake of
simplicity.

### Voting codes

Three endpoints are given:

    GET /votingcodes
    GET /votingcodes/more
    POST /votingcodes

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
or not the code has been used to vote yet.

## General




