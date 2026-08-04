# media

Manual steps for configuring a new instance. DOnt wanna automate it because its way too much work

## Jellyfin

Setup wizard:

1. Create service user `admin`
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
- Hide password reset button on the login form. Add CSS in Dashboard > Branding > Custom CSS:

```css
.btnForgotPassword {
  display: none !important;
}
```

## AirVpn

- Set the AirVPN client key and cert under in [values.enc.yaml](./values.enc.yaml) (remove headers)

## Sonarr/Radarr/Prowlarr

- set Authentication to Forms with Authentication Required: Disabled for Local Addresses (authentik fwauth protects it), copy the API key into the tfvars
- Add indexers in Prowlarr's GUI

## Bazarr

- Settings > Sonarr at `http://sonarr.media.svc.cluster.local:8989`
- Settings > Radarr at `http://radarr.media.svc.cluster.local:7878` with their API keys
- Settings > Languages
- Settings > Providers > OpenSubtitles.com provider with personal account
- Settings > Providers > Embedded Subtitles
- Disable Settings > Subtitles > Treat Embedded Subtitles as Downloaded
- Settings > Subtitles > Audio Synchronization

## Grimmory

- Create admin account in setup wizard (with a different email than any admins account)
- Point the library at `/media/books`
- Settings > Metadata 1 > Sidecar JSON Files
- Settings > Application > File Management
- Settings > OIDC: Take values from `generated.oidc.yaml`. The local login stays reachable at `/login?local=true`

## Unpackarr

- Set the Sonarr and Radarr API keys in [values.enc.yaml](values.enc.yaml)

## qBittorrent

In the settings:

- temporary WebUI password is in the pod log. Set a real one and put it in the tfvars
- Default Save Path `/media/downloads`, incomplete torrents in `/media/downloads/incomplete`.
- Pre-allocate disk space
- TOrrent management node automatic etc.
- Seeding limit action: "Remove torrent and its files"
- Disable torrent queueing
- Bind interface to gluetun's `tun0` under Advanced

## Seerr

Setup wizard:

- Login as the jellyfin `admin` user

Amongst other things add Sonarr and Radarr

- `http://jellyfin.media.svc.cluster.local:8096`
- `http://radarr.media.svc.cluster.local`
- `http://sonarr.media.svc.cluster.local`

Go to settings:

- Disable Local sign in and leave Jellyfin Sign in as the only option
- grant admin access to the personal user
