/// Status not assigned
var NONE = 0;

/// Local ID assigned, in progress to be sent.
var QUEUED = 1;

/// Transmission started.
var SENDING = 2;

/// At least one attempt was made to send the message.
var FAILED = 3;

/// Delivered to the server.
var SENT = 4;

///  Received by the client.
var RECEIVED = 5;

/// Read by the user.
var READ = 6;

/// Message from another user.
var TO_ME = 7;
