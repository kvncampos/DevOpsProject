# Mindmeld Devops Take-home Exercise

This exercise is intended to test your knowledge and expertise of devops
tooling and commonly-used AWS products.

In this repository you'll find two directories:

* `api/` -- a simple key-value store API written in Rust
* `app/` -- a simple React frontend to interact with the KV store in a browser

The goal of the exercise is to operate a fully-functioning application stack on
AWS. Though we have no expections for high availability or resiliency, we do
wish for you to assume this is a production application that you would support
for an extended period of time.

At bare minimum, you will need to:

* host the API
* host a Redis database for the API to communicate with
* host the frontend application and have it communicate with the API

You are free to choose whichever AWS products/services you believe will best
help you achieve the goal. We expect you to implement a solution using well-
known infrastructure as code tools, though which of those tools you use is
entirely up to you.

When you are finished with the exercise, please submit the configuration for
your solution and any instructions we might need in order to apply that
configuration.
