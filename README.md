# CFEngine 3

CFEngine 3 is a popular open source configuration management system. Its primary
function is to provide automated configuration and maintenance of large-scale
computer systems.

## Installation

Please see the INSTALL file for prerequisites and build instructions.

## Example Usage

### Hello World

The following code demonstrates simple CFEngine output through a reports promise.

    body common control
    {
      bundlesequence => { "run" };
    }

    bundle agent run
    {
      reports:
        cfengine::
          "Hello, world";
    }

The following policy code may be executed with cf-agent (the main CFEngine binary) as follows.

    $ cf-agent/cf-agent -f ./hello.cf
    R: Hello, world

### Contributing

Please see the HACKING file.

### Relationship to CFEngine 2

CFEngine 3 is *not* a drop-in upgrade for CFEngine 2 installations.  It is a
significantly more powerful version, but it is incompatible with the CFEngine 2
policy language.

The server part of CFEngine 3 supports the network protocol of CFEngine 2, so you may
upgrade your installation gradually.
