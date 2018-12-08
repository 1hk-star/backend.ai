Streaming
=========

The streaming mode provides a direct web-based terminal access to kernel containers.


Code Execution
--------------
* URI: ``/stream/kernel/:id/execute``
* Method: GET upgraded to WebSockets

This is a real-time streaming version of :doc:`exec-batch` and :doc:`exec-query` which uses
long polling via HTTP.

(under construction)

.. versionadded:: v4.20181215


Service Proxy (HTTP)
--------------------

* URI: ``/stream/kernel/:id/httpproxy?service=:service``
* Method: GET upgraded to WebSockets

The service proxy API allows clients to directly connect to service daemons running *inside*
compute sessions, such as Jupyter and TensorBoard.

(under construction)

.. versionadded:: v4.20181215


Service Proxy (TCP)
-------------------

* URI: ``/stream/kernel/:id/tcpproxy?service=:service``
* Method: GET upgraded to WebSockets

This is the TCP version of service proxy, so that client users can connect to native services
running inside compute sessions, such as SSH.

(under construction)

.. versionadded:: v4.20181215


Terminal Emulation
------------------

* URI: ``/stream/kernel/:id/pty?service=:service``
* Method: GET upgraded to WebSockets

This endpoint provides a duplex continuous stream of JSON objects via the native WebSocket.
Although WebSocket supports binary streams, we currently rely on TEXT messages only
conveying JSON payloads to avoid quirks in typed array support in Javascript
across different browsers.

.. note::

   We do *not* provide any legacy WebSocket emulation interfaces such as socket.io or SockJS.
   You need to set up your own proxy if you want to support legacy browser users.

.. versionchanged:: v4.20181215

   Added the ``service`` query parameter.

Parameters
""""""""""

.. list-table::
   :widths: 15 5 80
   :header-rows: 1

   * - Parameter
     - Type
     - Description
   * - ``:id``
     - ``slug``
     - The kernel ID.

Client-to-Server Protocol
"""""""""""""""""""""""""

The endpoint accepts the following four types of input messages.

Standard input stream
^^^^^^^^^^^^^^^^^^^^^

All ASCII (and UTF-8) inputs must be encoded as base64 strings.
The characters may include control characters as well.

.. code-block:: json

   {
     "type": "stdin",
     "chars": "<base64-encoded-raw-characters>"
   }

Terminal resize
^^^^^^^^^^^^^^^

Set the terminal size to the given number of rows and columns.
You should calculate them by yourself.

For instance, for web-browsers, you may do a simple math by measuring the width
and height of a temporarily created, invisible HTML element with the
(monospace) font styles same to the terminal container element that contains
only a single ASCII character.

.. code-block:: json

   {
     "type": "resize",
     "rows": 25,
     "cols": 80
   }

Ping
^^^^

Use this to keep the kernel alive (preventing it from auto-terminated by idle timeouts)
by sending pings periodically while the user-side browser is open.

.. code-block:: json

   {
     "type": "ping",
   }

Restart
^^^^^^^

Use this to restart the kernel without affecting the working directory and usage counts.
Useful when your foreground terminal program does not respond for whatever reasons.

.. code-block:: json

   {
     "type": "restart",
   }


Server-to-Client Protocol
"""""""""""""""""""""""""

Standard output/error stream
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Since the terminal is an output device, all stdout/stderr outputs are merged
into a single stream as we see in real terminals.
This means there is no way to distinguish stdout and stderr in the client-side,
unless your kernel applies some special formatting to distinguish them (e.g.,
make all stderr otuputs red).

The terminal output is compatible with xterm (including 256-color support).

.. code-block:: json

   {
     "type": "out",
     "data": "<base64-encoded-raw-characters>"
   }

Server-side errors
^^^^^^^^^^^^^^^^^^

.. code-block:: json

   {
     "type": "error",
     "data": "<human-readable-message>"
   }


Event Monitoring
----------------

* URI: ``/stream/kernel/:id/events``
* Method: GET upgraded to WebSockets

Provides a continuous message-by-message JSON object stream of lifecycle, code
execution, and proxy related events from a compute session.  This API function
is read-only --- meaning that you cannot send any data to this URI.

.. warning::

   This API is not implemented yet.

.. note::

   There is timeout enforced in the server-side but you may need to adjust
   defaults in your client-side WebSocket library.

.. versionchanged:: v4.20181215

   Renamed the URI to ``events``.


Parameters
""""""""""

.. list-table::
   :widths: 15 5 80
   :header-rows: 1

   * - Parameter
     - Type
     - Description
   * - ``:id``
     - ``slug``
     - The kernel ID.

Responses
"""""""""

.. list-table::
   :widths: 20 80
   :header-rows: 1

   * - Field Name
     - Value
   * - ``name``
     - The name of an event as a string. May be one of:
       ``"terminated"``, ``"restarted"``
   * - ``reason``
     - The reason for the event as a canonicalized string
       such as ``"out-of-memory"``, ``"bad-action"``, and ``"execution-timeout"``.

Example:

.. code-block:: json

   {
     "name": "terminated",
     "reason": "execution-timeout"
   }


Rate limiting
-------------

The streaming mode uses the same rate limiting policy as other APIs use.
The limitation only applies to all client-generated messages including the
initial WebSocket connection handshake but except stdin type messages such as
individual keystrokes in the terminal.
Server-generated messages are also exempted from rate limiting.

Usage metrics
-------------

The streaming mode uses the same method that the query mode uses to measure the
usage metrics such as the memory and CPU time used.
