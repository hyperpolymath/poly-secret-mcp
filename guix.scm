;; poly-secret-mcp - Guix Package Definition
;; Run: guix shell -D -f guix.scm

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix build-system gnu)
             ((guix licenses) #:prefix license:)
             (gnu packages base))

(define-public poly-secret-mcp
  (package
    (name "poly-secret-mcp")
    (version "1.1.0")
    (source (local-file "." "poly-secret-mcp-checkout"
                        #:recursive? #t
                        #:select? (git-predicate ".")))
    (build-system gnu-build-system)
    (synopsis "Unified MCP server for secrets management")
    (description "Unified Model Context Protocol (MCP) server for secrets management.
Supports HashiCorp Vault and Mozilla SOPS with planned support for Infisical,
Doppler, 1Password, and Bitwarden. Part of the RSR ecosystem.")
    (home-page "https://github.com/hyperpolymath/poly-secret-mcp")
    (license license:expat)))  ; MIT license

;; Return package for guix shell
poly-secret-mcp
