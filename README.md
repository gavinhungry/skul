skul
====
Create, format and mount loopback-based, encrypted
[LUKS](https://code.google.com/p/cryptsetup) containers.

Environment Variables
---------------------
  - `SKUL_CIPHER`: Defaults to `aes-xts-plain64`
  - `SKUL_KEYSIZE`: Defaults to `256`
  - `SKUL_HASH`: Defaults to `sha512`
  - `SKUL_ITER`: Defaults to `4000`

Usage
-----
    $ skul
    usage: skul.sh [create|open|close] FILENAME
      [--size|-s SIZE]
      [--keyfile|-k KEYFILE]
      [--header|-h HEADERFILE]

    # Create a 128MB LUKS container named 'private'
    $ skul create private --size 128

    skul: Creating container 'private' ...
    skul: Encrypting container 'private' ...
    skul: Opening container 'private' ...
    skul: Creating filesytem on 'skul-private' ...
    skul: Mounting 'skul-private' ...
    skul: Setting mountpoint permissions on '/media/skul-private' ...

After moving sensitive files into `/media/skul-private`:

    $ skul close private

License
-------
Released under the terms of the
[MIT license](http://tldrlegal.com/license/mit-license). See **LICENSE**.
