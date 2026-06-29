build-SharedLayer:
	pip install -r requirements.txt -t "$(ARTIFACTS_DIR)/python/lib/python3.12/site-packages/" --quiet
	cp -r python/lib/python3.12/site-packages/shared_db "$(ARTIFACTS_DIR)/python/lib/python3.12/site-packages/"
	cp -r python/lib/python3.12/site-packages/shared_helpers "$(ARTIFACTS_DIR)/python/lib/python3.12/site-packages/"