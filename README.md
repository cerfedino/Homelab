



# Dev environment
This repo ships a devbox environment for all tools used in the pipeline (See [devbox.json](devbox.json)).

When working, always activate the devbox shell by running `devbox shell`.

## 1. Secrets
Until I deploy a proper secret management solution, I will be using SOPS to encrypt/decrypt secrets that are committed to this repository.

Every file that is fully encrypted by SOPS has `.enc` extension. Some files, such as k3s Secrets, have the `.k3ssecret.enc` extension. These files, instead of being fully encrypted, have their metadata in cleartext and only the `data` and `stringData` fields are encrypted.

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
