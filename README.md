skul
====
Create, format and mount loopback-based, encrypted
[LUKS](https://code.google.com/p/cryptsetup) containers.


Usage
=====
    $ skul
    usage: skul [create|open|close] FILENAME [SIZE] [KEYFILE]

    # Create a 128MB LUKS container named 'private'
    $ skul create private 128

    skul: Creating container 'private' ...
    skul: Encrypting container 'private' ...
    skul: Opening container 'private' ...
    skul: Creating filesytem on 'skul-private' ...
    skul: Mounting 'skul-private' ...
    skul: Setting mountpoint permissions on '/media/skul-private' ...

After moving sensitive files into `/media/skul-private`:

    skul close private


License
-------
Released under the terms of the
[MIT license](http://tldrlegal.com/license/mit-license). See **LICENSE**.
