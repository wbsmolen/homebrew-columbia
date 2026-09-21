class Columbia < Formula
  desc "Operator-blind OHTTP middleware: relay, gateway, commons cache, token issuer"
  homepage "https://github.com/wbsmolen/columbia"
  url "https://github.com/wbsmolen/columbia/archive/refs/tags/v1.7.0.tar.gz"
  sha256 "bd4e4ad033d0ebc516ff3216121b2be903dc1670e992fceac4bd37ae4ebb4687"
  license all_of: ["PolyForm-Noncommercial-1.0.0", "BSD-3-Clause"]

  depends_on "go" => :build
  depends_on "node"

  def install
    # Build the gateway from its vendored Go dependencies.
    cd "ohttp-gateway" do
      system "go", "build", "-mod=vendor", "-trimpath", "-o", libexec/"columbia-gateway"
    end

    # Keep relative imports and locked production dependencies together.
    {
      "ohttp-relay"  => %w[server.js redemption-store.js issuer-key-cache.js],
      "token-issuer" => %w[server.js appattest.js epoch-keys.js state-store.js],
    }.each do |service, files|
      service_dir = libexec/service
      service_dir.install (files + %w[package.json package-lock.json]).map { |file| "#{service}/#{file}" }
      cd service_dir do
        system "npm", "ci", "--omit=dev", "--ignore-scripts", "--no-audit", "--no-fund"
      end
    end

    # Commons remains a dependency-free single-file service.
    libexec.install "commons-cache/server.js" => "commons.js"
    doc.install "LICENSE"
    (doc/"ohttp-gateway").install "ohttp-gateway/LICENSE", "ohttp-gateway/VENDORED.md"
    Pathname.glob("ohttp-gateway/vendor/**/{LICENSE*,COPYING*,NOTICE*,PATENTS*}").each do |notice|
      (doc/notice.dirname).install notice if notice.file?
    end

    node = formula_opt_bin("node")/"node"
    bin.mkpath
    (bin/"columbia").write <<~SH
      #!/bin/bash
      set -euo pipefail
      LIBEXEC="#{libexec}"
      cmd="${1:-}"
      case "$cmd" in
        relay)   shift; exec "#{node}" "$LIBEXEC/ohttp-relay/server.js" "$@" ;;
        gateway) shift; exec "$LIBEXEC/columbia-gateway" "$@" ;;
        commons) shift; exec "#{node}" "$LIBEXEC/commons.js" "$@" ;;
        issuer)  shift; exec "#{node}" "$LIBEXEC/token-issuer/server.js" "$@" ;;
        version|--version|-v) echo "columbia #{version}" ;;
        *)
          echo "columbia #{version} — operator-blind OHTTP middleware"
          echo ""
          echo "usage: columbia <relay|gateway|commons|issuer|version>"
          echo ""
          echo "Each service is configured by environment variables; see"
          echo "https://github.com/wbsmolen/columbia/blob/main/SELFHOSTING.md"
          if [ -n "$cmd" ]; then exit 1; else exit 0; fi
          ;;
      esac
    SH
    (bin/"columbia").chmod 0755
  end

  def caveats
    <<~EOS
      Columbia's operator-blind guarantee requires the relay and gateway to run
      under separate, non-colluding operators. Running every service on one
      machine is for development only. See:
        https://github.com/wbsmolen/columbia/blob/main/SELFHOSTING.md
    EOS
  end

  test do
    assert_match "columbia #{version}", shell_output("#{bin}/columbia version")
    assert_path_exists doc/"ohttp-gateway/LICENSE"
    assert_path_exists doc/"ohttp-gateway/vendor/github.com/cloudflare/circl/LICENSE"

    %w[ohttp-relay token-issuer].each do |service|
      assert_path_exists libexec/service/"node_modules/@azure/data-tables/package.json"
    end

    %w[commons gateway relay issuer].each do |service|
      port = free_port
      env = { "PORT" => port.to_s }
      env["GATEWAY_URL"] = "https://127.0.0.1:#{port}/gateway" if service == "relay"
      pid = spawn(env, bin/"columbia", service, unsetenv_others: true,
                  out: (testpath/"#{service}.log").to_s, err: [:child, :out])
      begin
        assert_match "ok", shell_output("curl --fail --silent --show-error --retry 10 " \
                                        "--retry-connrefused --retry-delay 1 --retry-max-time 15 " \
                                        "http://127.0.0.1:#{port}/health")
        next if service != "issuer"

        # A fresh installation has no signing key and must fail closed.
        assert_match "HTTP/1.1 503 Service Unavailable",
                     shell_output("curl --silent --include http://127.0.0.1:#{port}/issuer-keys")
      ensure
        if Process.waitpid(pid, Process::WNOHANG).nil?
          Process.kill("TERM", pid)
          Process.wait(pid)
        end
      end
    end
  end
end
