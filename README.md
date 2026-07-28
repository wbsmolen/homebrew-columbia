# homebrew-columbia

Homebrew tap for [Columbia](https://github.com/wbsmolen/columbia) — operator-blind OHTTP middleware (relay, gateway, commons cache, token issuer).

```sh
brew tap wbsmolen/columbia
brew install columbia

columbia            # usage
columbia commons    # run a service: relay | gateway | commons | issuer
```

Each service is configured via environment variables — see the service READMEs and
[SELFHOSTING.md](https://github.com/wbsmolen/columbia/blob/main/SELFHOSTING.md).
The operator-blind guarantee requires the relay and gateway to run under separate,
non-colluding operators; single-machine use is for development.
