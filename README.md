# Dev environment

This repo ships a devbox environment for all tools used in the pipeline (See [devbox.json](devbox.json)).

When working, always activate the devbox shell by running `devbox shell`.

## 1. Secrets

Secrets (and anything else I'd rather not have sitting in cleartext on a public repo) are encrypted with SOPS and committed.

Every file with `.enc` in its name is SOPS-encrypted. k3s Secrets use `.k3ssecret.enc`, instead of being fully encrypted they keep their metadata in cleartext.

Decrypt secrets on a fresh clone:

1. Put the SOPS key in [`.sops/keys.txt`](.sops/keys.txt),
1. Run `devbox run sops-open` to decrypt all secrets in place.

#### Committing secrets

This repo ships a pre-commit hook that checks that no unencrypted secrets are staged for commit. The hook is installed automatically when you activate the devbox shell.

Since `.enc` files are gitignored by default, you will need to run `devbox run sops-stage` to stage the encrypted version of every secret on disk.

So, again, the workflow is:

1. Supply the SOPS key in [`.sops/keys.txt`](.sops/keys.txt)
1. `devbox shell`
1. `devbox run sops-open` to decrypt secrets
1. do dev/deploy/whatever
1. `devbox run sops-stage` to stage the encrypted secrets for commit

## 2. Deploying

I use Makefiles for deploying stuff. This will probably come back to bite me.
The numbered directories are the pipeline, and `make` goes through them in order.

1. `devbox run sops-open` (once)
1. `make stages`

Each stage, and each app under `30-applications`, has its own Makefile; running `make` there deploys just that piece independently.
