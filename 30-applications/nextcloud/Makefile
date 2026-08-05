.NOTPARALLEL:

apply: helmfile-apply oidc-config apps-config

helmfile-apply:
	cd ..; helmfile apply --skip-refresh -l name=nextcloud

oidc-config:
	kubectl -n nextcloud exec deploy/nextcloud -- su -s /bin/sh www-data -c \
		'php occ app:install user_oidc || true; php occ app:enable user_oidc; \
		 php occ user_oidc:provider authentik \
		   --clientid "$$OIDC_CLIENT_ID" --clientsecret "$$OIDC_CLIENT_SECRET" \
		   --discoveryuri "$$OIDC_DISCOVERY_URI" --scope "openid email profile groups" \
		   --group-provisioning=1 --unique-uid=0 --mapping-uid preferred_username \
		   --mapping-quota nextcloud_quota; \
		 php occ config:app:set --value=0 user_oidc allow_multiple_user_backends'

apps-config:
	kubectl -n nextcloud exec deploy/nextcloud -- su -s /bin/sh www-data -c \
		'for a in calendar contacts tasks notes richdocuments whiteboard forms groupfolders recognize; do php occ app:install $$a || php occ app:enable $$a; done; \
		 php occ config:app:set richdocuments wopi_url --value "$$COLLABORA_WOPI_URL"; \
		 php occ config:app:set richdocuments public_wopi_url --value "$$COLLABORA_WOPI_URL"; \
		 php occ richdocuments:activate-config; \
		 php occ config:app:set whiteboard collabBackendUrl --value "$$WHITEBOARD_URL"; \
		 php occ config:app:set whiteboard jwt_secret_key --value "$$WHITEBOARD_JWT_SECRET"; \
		 php occ config:app:set files default_quota --value "5 GB"; \
		 php occ db:add-missing-indices; \
		 php occ app:disable app_api || true'

maintenance-repair:
	kubectl -n nextcloud exec deploy/nextcloud -- su -s /bin/sh www-data -c \
		'php occ maintenance:repair --include-expensive'
