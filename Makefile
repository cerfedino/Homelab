
STAGES := 10-infra 20-bootstrap 30-applications

stages: $(STAGES)

10-infra: decrypt
20-bootstrap: decrypt 10-infra
30-applications: decrypt 10-infra 20-bootstrap

# Run make in each stage
$(STAGES):
	$(MAKE) -C $@

.PHONY: stages $(STAGES) decrypt





decrypt:
	devbox run sops-open

