.PHONY: deploy

deploy:
	jekyll build --destination $(DIR)
	cd popl16-aec && curl -O -z synapse.ova http://homes.cs.washington.edu/~bornholt/synapse.ova && ls -l synapse.ova