# media

Manual steps for configuring a new instance. DOnt wanna automate it because its way too much work

## 1. Jellyfin

Setup wizard:

1. Create break-glass user `admin`
2. Add the libraries:

- Movies at `/media/movies`
- Shows at `/media/tvshows`

Install plugins:

- "LDAP Authentication"

Configure

- LDAP Server: `ak-outpost-ldap.authentik.svc.cluster.local`, port 389, no SSL, no StartTLS
- LDAP Bind User: `cn=ldapsearch,ou=users,dc=crfda,dc=com`, password is `ldap_search_password` in the authentik root's values
- LDAP Base DN: `dc=crfda,dc=com`
- LDAP Search Filter: `(memberOf=cn=jellyfin_users,ou=groups,dc=crfda,dc=com)`
- LDAP Admin Filter: `(memberOf=cn=jellyfin_admins,ou=groups,dc=crfda,dc=com)`
- LDAP Username Attribute: `cn`
- Enable creating users on first login
- Library access: All

## 2. Sonarr / Radarr / Prowlarr

Set `seedbox.pass_obscured` in [values.enc.yaml](./values.enc.yaml), the output of `rclone obscure <sftp password>`.

Manual part per app, once:

- Sonarr/Radarr/Prowlarr: set Authentication to Forms with Authentication Required: Disabled for Local Addresses (authentik fwauth protects it), copy the API key into the tfvars
- Add indexers in Prowlarr's GUI

## 3. Seerr

Setup wizard:

- Login as the jellyfin `admin` user

Amongst other things add Sonarr and Radarr

- `http://jellyfin.media.svc.cluster.local:8096`
- `http://radarr.media.svc.cluster.local`
- `http://sonarr.media.svc.cluster.local`

Go to settings:

- Disable Local sign in and leave Jellyfin Sign in as the only option
