# Office Oates Support for Windows

This Windows remote support client is derived from [RustDesk](https://github.com/rustdesk/rustdesk).
Upstream source baseline: [`1297da6d186e58d9096be24072ae3998cdbbf8fe`](https://github.com/rustdesk/rustdesk/commit/1297da6d186e58d9096be24072ae3998cdbbf8fe).
See [LICENCE](LICENCE) and upstream copyright notices.

The session edition runs for a single support session. The resident edition
requires installation and can accept subsequent connections after registration.
During registration, the customer opens a ZIP received from Office Oates,
enters an eight-character code sent by SMS, reviews the consent notice and
submits their connection details. RustDesk provides the remote connection.

The enrollment endpoint is hosted by Office Oates. On customer submission the
client sends the invitation, SMS code, RustDesk ID, connection password and
edition to that endpoint over HTTPS. In the current implementation the endpoint
emails the connection ID and password to Office Oates. This disclosure describes
the current code. Publication and production use require approval of the data
handling arrangements. For privacy practices of the underlying remote desktop
software, see the [RustDesk project](https://rustdesk.com/).

To build Windows x64, initialize the upstream submodule with
`git submodule update --init --recursive`. Run the **Office Oates Windows**
workflow manually with `mode=session` or `mode=resident`. The workflow produces
unsigned EXE and MSI artifacts. Code signing is pending.

## Code signing policy

Draft. Office Oates will document the authorized maintainers, reviewers and
release approvers here before using a signing service. Signing will be tied to
reviewed source builds and approved releases. The project has not been approved
by a signing provider.
