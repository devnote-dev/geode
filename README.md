<h1 align="center">Geode</h1>
<h3 align="center">An alternative Crystal package manager</h3>
<hr>

Geode is a drop-in replacement for [Shards](https://github.com/crystal-lang/shards) with additional features and tools for a better Crystal experience.

## Installation

### From Release

See the [releases page](https://github.com/devnote-dev/geode/releases) for available packaged binaries.

#### Linux

```sh
curl -L https://github.com/devnote-dev/geode/releases/download/nightly/geode-nightly-linux-x86_64.tar.gz -o geode.tar.gz
tar -xvf geode.tar.gz -C /usr/local/bin
```

#### Windows (PowerShell)

```ps1
Invoke-WebRequest "https://github.com/devnote-dev/geode/releases/download/nightly/geode-nightly-windows-x86_64-msvc.zip" -OutFile geode.zip
Expand-Archive .\geode.zip .
```

### From Source

[Crystal](https://crystal-lang.org/) version 1.5.0 or higher is required to build Geode. Make sure to add the `bin/` directory to `PATH` or move the Geode binaries to a directory in `PATH`.

```sh
git clone https://github.com/devnote-dev/geode
cd geode
shards build
```

## Usage

TODO.

## Contributing

1. Fork it (<https://github.com/devnote-dev/geode/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Devonte W](https://github.com/devnote-dev) - creator and maintainer

© 2023 devnote-dev
