# homebrew-columbia

Homebrew tap for [Columbia](https://github.com/wbsmolen/columbia) — operator-blind OHTTP middleware (relay, gateway, commons cache, token issuer).

```sh
brew tap wbsmolen/columbia
brew install columbia

columbia            # usage
columbia commons    # run a service: relay | gateway | commons | issuer
```

The formula packages Columbia 1.7.0 with the relay and issuer's locked production
dependencies. Existing installations can update with `brew update` followed by
`brew upgrade columbia`. Services are started explicitly; installation does not
enable token enforcement or configure signing keys or shared state.

Each service is configured via environment variables — see the service READMEs and
[SELFHOSTING.md](https://github.com/wbsmolen/columbia/blob/main/SELFHOSTING.md).
The operator-blind guarantee requires the relay and gateway to run under separate,
non-colluding operators; single-machine use is for development.
