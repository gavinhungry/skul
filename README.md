skul
====
Quickly create, format and mount a loopback-based encrypted
[LUKS](https://code.google.com/p/cryptsetup) container.


Usage
=====
    $ skul
    usage: FILENAME SIZE [KEYFILE]

    # Create a 128MB LUKS container named 'secretFiles'
    $ skul secretFiles 128

    skul: Creating container 'secretFiles' ...
    skul: Encrypting container 'secretFiles' ...
    skul: Opening container 'secretFiles' ...
    skul: Creating filesytem on 'skul-secretfiles' ...
    skul: Mounting 'skul-secretfiles' ...
    skul: Setting mountpoint permissions on '/media/skul-secretfiles' ...

After moving sensitive files into `/media/skul-secretfiles`, unmount and
`luksClose` the container.


License
-------
Released under the terms of the
[MIT license](http://tldrlegal.com/license/mit-license). See **LICENSE**.
