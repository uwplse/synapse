.PHONY: deploy

deploy:
	cd www && jekyll build --destination $(shell ~/uwplse/getdir)