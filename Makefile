.PHONY: deploy

deploy:
	jekyll build --destination $(shell ~/uwplse/getdir)