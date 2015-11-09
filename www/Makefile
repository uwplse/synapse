.PHONY: deploy

deploy:
	cd www && jekyll build --destination $(shell ~/uwplse/getdir)
	cd www/popl16-aec && curl -O -z synapse.ova http://homes.cs.washington.edu/~bornholt/synapse.ova && ls -l synapse.ova