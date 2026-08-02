class Columbia < Formula
  desc "Operator-blind OHTTP middleware: relay, gateway, commons cache, token issuer"
  homepage "https://github.com/wbsmolen/columbia"
  url "https://github.com/wbsmolen/columbia/archive/refs/tags/v1.4.4.tar.gz"
  sha256 "fa5a1d6fcb49f1e91056746e58bfb90570853c6ce439d38841be05024446c938"
  license "PolyForm-Noncommercial-1.0.0"

  depends_on "go" => :build
  depends_on "node"

  def install
    # Gateway: static Go binary (deps are vendored in-tree).
    cd "ohttp-gateway" do
      system "go", "build", "-o", libexec/"columbia-gateway"
    end

    # Relay and commons are dependency-free single-file Node services.
    libexec.install "ohttp-relay/server.js" => "relay.js"
    libexec.install "commons-cache/server.js" => "commons.js"

    # Token issuer vendors its npm dependencies into libexec.
    (libexec/"token-issuer").install Dir["token-issuer/*"]
    cd libexec/"token-issuer" do
      system "npm", "ci", "--omit=dev"
    end

    node = formula_opt_bin("node")/"node"
    (bin/"columbia").write <<~SH
      #!/bin/bash
      set -euo pipefail
      LIBEXEC="#{libexec}"
      cmd="${1:-}"
      case "$cmd" in
        relay)   shift; exec "#{node}" "$LIBEXEC/relay.js" "$@" ;;
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

    port = free_port
    pid = spawn({ "PORT" => port.to_s }, bin/"columbia", "commons")
    begin
      sleep 3
      assert_match "ok", shell_output("curl -s http://127.0.0.1:#{port}/health")
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
