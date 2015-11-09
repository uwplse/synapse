.PHONY: deploy

deploy:
	jekyll build --destination $(shell ~/uwplse/getdir)
	cd popl16-aec && curl -O -z synapse.ova http://homes.cs.washington.edu/~bornholt/synapse.ova && ls -l synapse.ova