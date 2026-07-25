.NOTPARALLEL:

STAGES := 10-infra 20-bootstrap 30-applications

stages: decrypt $(STAGES)

# Run make in each stage
$(STAGES):
	$(MAKE) -C $@

decrypt:
	devbox run sops-open

.PHONY: stages $(STAGES) decrypt
