---
title: Optimizing Synthesis with Metasketches
---

<img class="aec" src="/img/popl-aec.png" />

# Optimizing Synthesis with Metasketches
{:.no_toc}

<p class="authors" markdown="1">
[James Bornholt](http://homes.cs.washington.edu/~bornholt/), 
[Emina Torlak](http://homes.cs.washington.edu/~emina/),
[Dan Grossman](http://homes.cs.washington.edu/~djg/), 
[Luis Ceze](http://homes.cs.washington.edu/~luisceze/)
<br>
[POPL 2016](http://conf.researchr.org/home/POPL-2016)
</p>

* [Paper](/synapse-popl16.pdf) (PDF, 333 kB)

Many advanced programming tools---for both end-users and expert
developers---rely on program synthesis to automatically generate implementations
from high-level specifications. These tools often need to employ tricky,
custom-built synthesis algorithms because they require synthesized programs to
be not only correct, but also *optimal* with respect to a desired cost metric,
such as program size.  Finding these optimal solutions efficiently requires
domain-specific search strategies, but existing synthesizers hard-code the
strategy, making them difficult to reuse.

We present *metasketches*, a general framework for specifying and solving
optimal synthesis problems. Metasketches make the search strategy a part of the
problem definition by specifying a fragmentation of the search space into an
ordered set of classic sketches. We provide two cooperating search algorithms to
effectively solve metasketches. A global optimizing search coordinates the
activities of local searches, informing them of the costs of potentially-optimal
solutions as they explore different regions of the candidate space in parallel.
The local searches execute an incremental form of counterexample-guided
inductive synthesis to incorporate information sent from the global search. We
present Synapse, an implementation of these algorithms, and show that it
effectively solves optimal synthesis problems with a variety of different cost
functions. In addition, metasketches can be used to accelerate classic
(non-optimal) synthesis by explicitly controlling the search strategy, and we
show that Synapse solves classic synthesis problems that state-of-the-art tools
cannot.

## Get the code

Coming soon!

## Download the artifact

[Artifact instructions](/popl16-aec/).
