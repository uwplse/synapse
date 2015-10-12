.PHONY: deploy

deploy:
	cd www && jekyll build --destination $(shell ~/uwplse/getdir)
	cd www/popl16-aec && ls -l && curl -O -z synapse.ova http://homes.cs.washington.edu/~bornholt/synapse.ova && md5sum synapse.ova